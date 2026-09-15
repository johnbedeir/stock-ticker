package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

const (
	Daily         = "TIME_SERIES_DAILY"
	DailyAdjusted = "TIME_SERIES_DAILY_ADJUSTED"
)

type Config struct {
	Symbol   string
	NDays    int
	APIKey   string
	Port     string
	Function string
	CacheTTL time.Duration
}

func Load() (Config, error) {
	return LoadFrom(os.Getenv)
}

func LoadFrom(getenv func(string) string) (Config, error) {
	cfg := Config{
		Symbol:   getenv("SYMBOL"),
		APIKey:   getenv("APIKEY"),
		Port:     valueOrDefault(getenv("PORT"), "8080"),
		Function: valueOrDefault(getenv("ALPHAVANTAGE_FUNCTION"), Daily),
	}

	if cfg.Symbol == "" {
		return Config{}, fmt.Errorf("SYMBOL is required")
	}
	if cfg.APIKey == "" {
		return Config{}, fmt.Errorf("APIKEY is required")
	}

	var err error
	cfg.NDays, err = strconv.Atoi(getenv("NDAYS"))
	if err != nil || cfg.NDays <= 0 {
		return Config{}, fmt.Errorf("NDAYS must be a positive integer")
	}

	if cfg.Function != Daily && cfg.Function != DailyAdjusted {
		return Config{}, fmt.Errorf("ALPHAVANTAGE_FUNCTION must be %s or %s", Daily, DailyAdjusted)
	}

	cfg.CacheTTL, err = time.ParseDuration(valueOrDefault(getenv("CACHE_TTL"), "12h"))
	if err != nil || cfg.CacheTTL <= 0 {
		return Config{}, fmt.Errorf("CACHE_TTL must be a positive duration")
	}

	return cfg, nil
}

func valueOrDefault(value, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}
