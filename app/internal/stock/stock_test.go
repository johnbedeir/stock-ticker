package stock

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func TestAlphaClientSortsLimitsAndAveragesFixture(t *testing.T) {
	server := fixtureServer(t, "testdata/daily.json")
	defer server.Close()

	client := testClient(server)
	result, err := client.Fetch(context.Background(), "MSFT", 2)
	if err != nil {
		t.Fatalf("Fetch() error = %v", err)
	}
	if result.ReturnedDays != 2 || result.RequestedDays != 2 {
		t.Fatalf("days = %d/%d, want 2/2", result.ReturnedDays, result.RequestedDays)
	}
	if result.Prices[0].Date != "2026-09-12" || result.Prices[1].Date != "2026-09-11" {
		t.Fatalf("prices are not newest first: %#v", result.Prices)
	}
	if result.AverageClose != 106 {
		t.Fatalf("average = %v, want 106", result.AverageClose)
	}
}

func TestAlphaClientReturnsFewerThanRequested(t *testing.T) {
	server := fixtureServer(t, "testdata/daily.json")
	defer server.Close()

	result, err := testClient(server).Fetch(context.Background(), "MSFT", 7)
	if err != nil {
		t.Fatalf("Fetch() error = %v", err)
	}
	if result.ReturnedDays != 3 || result.AverageClose != 105 {
		t.Fatalf("result = %#v, want three records averaged to 105", result)
	}
}

func TestAlphaClientRejectsInvalidData(t *testing.T) {
	tests := []struct {
		name string
		body string
	}{
		{"empty series", `{"Time Series (Daily)":{}}`},
		{"malformed json", `{`},
		{"missing close", `{"Time Series (Daily)":{"2026-09-12":{"1. open":"1"}}}`},
		{"bad close", `{"Time Series (Daily)":{"2026-09-12":{"4. close":"nope"}}}`},
		{"provider error", `{"Error Message":"Invalid API call."}`},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
				_, _ = w.Write([]byte(tt.body))
			}))
			defer server.Close()
			_, err := testClient(server).Fetch(context.Background(), "MSFT", 7)
			if !errors.Is(err, ErrBadData) {
				t.Fatalf("Fetch() error = %v, want ErrBadData", err)
			}
		})
	}
}

func TestAlphaClientHandlesHTTP200QuotaFixture(t *testing.T) {
	server := fixtureServer(t, "testdata/quota.json")
	defer server.Close()

	_, err := testClient(server).Fetch(context.Background(), "MSFT", 7)
	if !errors.Is(err, ErrUnavailable) {
		t.Fatalf("Fetch() error = %v, want ErrUnavailable", err)
	}
}

func TestAlphaClientTimeout(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		time.Sleep(100 * time.Millisecond)
		_, _ = w.Write([]byte(`{}`))
	}))
	defer server.Close()

	client := testClient(server)
	client.httpClient.Timeout = 10 * time.Millisecond
	_, err := client.Fetch(context.Background(), "MSFT", 7)
	if !errors.Is(err, ErrUnavailable) {
		t.Fatalf("Fetch() error = %v, want ErrUnavailable", err)
	}
}

func TestCacheCoalescesConcurrentRefresh(t *testing.T) {
	fetcher := &countingFetcher{
		release: make(chan struct{}),
		result: Result{
			Symbol:        "MSFT",
			RequestedDays: 7,
			ReturnedDays:  1,
			Prices:        []Price{{Date: "2026-09-12", Close: 100}},
			AverageClose:  100,
		},
	}
	cache := NewCache(fetcher, time.Hour)

	const callers = 20
	start := make(chan struct{})
	errs := make(chan error, callers)
	var wg sync.WaitGroup
	for range callers {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			_, err := cache.Get(context.Background(), "MSFT", 7)
			errs <- err
		}()
	}
	close(start)
	for fetcher.calls.Load() == 0 {
		time.Sleep(time.Millisecond)
	}
	close(fetcher.release)
	wg.Wait()
	close(errs)

	for err := range errs {
		if err != nil {
			t.Fatalf("Get() error = %v", err)
		}
	}
	if calls := fetcher.calls.Load(); calls != 1 {
		t.Fatalf("Fetch() calls = %d, want 1", calls)
	}
}

func TestCacheBacksOffAfterFailure(t *testing.T) {
	fetcher := &countingFetcher{err: ErrUnavailable}
	cache := NewCache(fetcher, time.Hour)

	_, _ = cache.Get(context.Background(), "MSFT", 7)
	_, _ = cache.Get(context.Background(), "MSFT", 7)
	if calls := fetcher.calls.Load(); calls != 1 {
		t.Fatalf("Fetch() calls = %d, want 1 during backoff", calls)
	}
}

type countingFetcher struct {
	calls   atomic.Int32
	release chan struct{}
	result  Result
	err     error
}

func (f *countingFetcher) Fetch(context.Context, string, int) (Result, error) {
	f.calls.Add(1)
	if f.release != nil {
		<-f.release
	}
	return f.result, f.err
}

func fixtureServer(t *testing.T, path string) *httptest.Server {
	t.Helper()
	body, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read fixture: %v", err)
	}
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write(body)
	}))
}

func testClient(server *httptest.Server) *AlphaClient {
	client := NewAlphaClient(server.Client(), "not-a-real-key", "TIME_SERIES_DAILY")
	client.baseURL = server.URL
	client.now = func() time.Time { return time.Date(2026, 9, 14, 0, 0, 0, 0, time.UTC) }
	return client
}
