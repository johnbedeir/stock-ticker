package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strconv"
	"sync/atomic"
	"time"

	"stock-ticker/internal/stock"
)

type Service interface {
	Get(context.Context, string, int) (stock.Result, error)
}

type API struct {
	service  Service
	symbol   string
	nDays    int
	logger   *slog.Logger
	ready    atomic.Bool
	requests atomic.Uint64
	failures atomic.Uint64
}

func New(service Service, symbol string, nDays int, logger *slog.Logger) *API {
	api := &API{service: service, symbol: symbol, nDays: nDays, logger: logger}
	api.ready.Store(true)
	return api
}

func (a *API) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /", a.stock)
	mux.HandleFunc("GET /health", a.health)
	mux.HandleFunc("GET /ready", a.readiness)
	mux.HandleFunc("GET /metrics", a.metrics)
	return mux
}

func (a *API) Shutdown() {
	a.ready.Store(false)
}

func (a *API) stock(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	a.requests.Add(1)
	result, err := a.service.Get(r.Context(), a.symbol, a.nDays)
	if err != nil {
		a.failures.Add(1)
		status := http.StatusBadGateway
		message := "invalid response from stock provider"
		if errors.Is(err, stock.ErrUnavailable) {
			status = http.StatusServiceUnavailable
			message = "stock provider unavailable"
		}
		a.logger.Warn("stock request failed", "status", status, "error", err)
		writeJSON(w, status, map[string]string{"error": message})
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func (a *API) health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (a *API) readiness(w http.ResponseWriter, _ *http.Request) {
	if !a.ready.Load() {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "shutting_down"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}

func (a *API) metrics(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/plain; version=0.0.4")
	_, _ = fmt.Fprintf(w,
		"# HELP stock_ticker_http_requests_total Stock endpoint requests.\n"+
			"# TYPE stock_ticker_http_requests_total counter\n"+
			"stock_ticker_http_requests_total %s\n"+
			"# HELP stock_ticker_http_failures_total Failed stock endpoint requests.\n"+
			"# TYPE stock_ticker_http_failures_total counter\n"+
			"stock_ticker_http_failures_total %s\n",
		strconv.FormatUint(a.requests.Load(), 10),
		strconv.FormatUint(a.failures.Load(), 10),
	)
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func NewServer(address string, handler http.Handler) *http.Server {
	return &http.Server{
		Addr:              address,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
		MaxHeaderBytes:    1 << 20,
	}
}
