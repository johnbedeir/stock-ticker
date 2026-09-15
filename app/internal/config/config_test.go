package config

import (
	"strings"
	"testing"
	"time"
)

func TestLoadFrom(t *testing.T) {
	values := map[string]string{
		"SYMBOL": "MSFT",
		"NDAYS":  "7",
		"APIKEY": "test-key",
	}
	cfg, err := LoadFrom(func(key string) string { return values[key] })
	if err != nil {
		t.Fatalf("LoadFrom() error = %v", err)
	}
	if cfg.Port != "8080" || cfg.Function != Daily || cfg.CacheTTL != 12*time.Hour {
		t.Fatalf("defaults not applied: %#v", cfg)
	}
}

func TestLoadFromRejectsInvalidConfiguration(t *testing.T) {
	base := map[string]string{
		"SYMBOL": "MSFT",
		"NDAYS":  "7",
		"APIKEY": "test-key",
	}
	tests := []struct {
		name    string
		change  func(map[string]string)
		message string
	}{
		{"missing symbol", func(v map[string]string) { delete(v, "SYMBOL") }, "SYMBOL"},
		{"missing key", func(v map[string]string) { delete(v, "APIKEY") }, "APIKEY"},
		{"zero days", func(v map[string]string) { v["NDAYS"] = "0" }, "NDAYS"},
		{"bad days", func(v map[string]string) { v["NDAYS"] = "seven" }, "NDAYS"},
		{"bad function", func(v map[string]string) { v["ALPHAVANTAGE_FUNCTION"] = "OTHER" }, "ALPHAVANTAGE_FUNCTION"},
		{"bad ttl", func(v map[string]string) { v["CACHE_TTL"] = "-1s" }, "CACHE_TTL"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			values := make(map[string]string, len(base))
			for key, value := range base {
				values[key] = value
			}
			tt.change(values)
			_, err := LoadFrom(func(key string) string { return values[key] })
			if err == nil || !strings.Contains(err.Error(), tt.message) {
				t.Fatalf("LoadFrom() error = %v, want message containing %q", err, tt.message)
			}
		})
	}
}
