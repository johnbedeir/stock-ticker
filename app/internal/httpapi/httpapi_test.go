package httpapi

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"stock-ticker/internal/stock"
)

func TestOperationalEndpointsDoNotCallProvider(t *testing.T) {
	service := &stubService{}
	api := New(service, "MSFT", 7, discardLogger())
	server := httptest.NewServer(api.Handler())
	defer server.Close()

	for _, path := range []string{"/health", "/ready", "/metrics"} {
		response, err := http.Get(server.URL + path)
		if err != nil {
			t.Fatalf("GET %s: %v", path, err)
		}
		_ = response.Body.Close()
		if response.StatusCode != http.StatusOK {
			t.Fatalf("GET %s status = %d, want 200", path, response.StatusCode)
		}
	}
	if service.calls != 0 {
		t.Fatalf("provider calls = %d, want 0", service.calls)
	}
}

func TestStockEndpointMapsSanitizedErrors(t *testing.T) {
	tests := []struct {
		name       string
		err        error
		wantStatus int
		wantBody   string
	}{
		{"unavailable", stock.ErrUnavailable, http.StatusServiceUnavailable, "stock provider unavailable"},
		{"bad data", stock.ErrBadData, http.StatusBadGateway, "invalid response from stock provider"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			api := New(&stubService{err: tt.err}, "MSFT", 7, discardLogger())
			request := httptest.NewRequest(http.MethodGet, "/", nil)
			recorder := httptest.NewRecorder()
			api.Handler().ServeHTTP(recorder, request)

			if recorder.Code != tt.wantStatus || !strings.Contains(recorder.Body.String(), tt.wantBody) {
				t.Fatalf("response = %d %q", recorder.Code, recorder.Body.String())
			}
			if strings.Contains(recorder.Body.String(), tt.err.Error()) {
				t.Fatalf("response leaked internal error: %q", recorder.Body.String())
			}
		})
	}
}

func TestReadinessChangesDuringShutdown(t *testing.T) {
	api := New(&stubService{}, "MSFT", 7, discardLogger())
	api.Shutdown()
	recorder := httptest.NewRecorder()
	api.Handler().ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/ready", nil))
	if recorder.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want 503", recorder.Code)
	}
}

func TestUnknownPathDoesNotCallProvider(t *testing.T) {
	service := &stubService{}
	api := New(service, "MSFT", 7, discardLogger())
	recorder := httptest.NewRecorder()
	api.Handler().ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/not-found", nil))
	if recorder.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404", recorder.Code)
	}
	if service.calls != 0 {
		t.Fatalf("provider calls = %d, want 0", service.calls)
	}
}

type stubService struct {
	calls int
	err   error
}

func (s *stubService) Get(context.Context, string, int) (stock.Result, error) {
	s.calls++
	return stock.Result{}, s.err
}

func discardLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(io.Discard, nil))
}
