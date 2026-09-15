package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"stock-ticker/internal/config"
	"stock-ticker/internal/httpapi"
	"stock-ticker/internal/stock"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	cfg, err := config.Load()
	if err != nil {
		logger.Error("invalid configuration", "error", err)
		os.Exit(1)
	}

	upstream := &http.Client{Timeout: 10 * time.Second}
	client := stock.NewAlphaClient(upstream, cfg.APIKey, cfg.Function)
	cache := stock.NewCache(client, cfg.CacheTTL)
	api := httpapi.New(cache, cfg.Symbol, cfg.NDays, logger)
	server := httpapi.NewServer(":"+cfg.Port, api.Handler())

	shutdownSignal, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	go func() {
		<-shutdownSignal.Done()
		api.Shutdown()
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := server.Shutdown(ctx); err != nil {
			logger.Error("graceful shutdown failed", "error", err)
		}
	}()

	logger.Info("server listening", "address", server.Addr, "symbol", cfg.Symbol, "days", cfg.NDays)
	if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		logger.Error("server failed", "error", err)
		os.Exit(1)
	}
}
