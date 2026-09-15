package stock

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"sync"
	"time"
)

const (
	defaultBaseURL = "https://www.alphavantage.co/query"
	maxResponse    = 2 << 20
)

var (
	ErrUnavailable = errors.New("stock data unavailable")
	ErrBadData     = errors.New("invalid upstream data")
)

type Price struct {
	Date  string  `json:"date"`
	Close float64 `json:"close"`
}

type Result struct {
	Symbol        string    `json:"symbol"`
	RequestedDays int       `json:"requested_days"`
	ReturnedDays  int       `json:"returned_days"`
	Prices        []Price   `json:"prices"`
	AverageClose  float64   `json:"average_close"`
	FetchedAt     time.Time `json:"fetched_at"`
}

type Fetcher interface {
	Fetch(context.Context, string, int) (Result, error)
}

type AlphaClient struct {
	httpClient *http.Client
	apiKey     string
	function   string
	baseURL    string
	now        func() time.Time
}

func NewAlphaClient(httpClient *http.Client, apiKey, function string) *AlphaClient {
	return &AlphaClient{
		httpClient: httpClient,
		apiKey:     apiKey,
		function:   function,
		baseURL:    defaultBaseURL,
		now:        time.Now,
	}
}

func (c *AlphaClient) Fetch(ctx context.Context, symbol string, n int) (Result, error) {
	if symbol == "" || n <= 0 {
		return Result{}, fmt.Errorf("%w: invalid stock request", ErrBadData)
	}

	endpoint, err := url.Parse(c.baseURL)
	if err != nil {
		return Result{}, fmt.Errorf("%w: invalid endpoint", ErrBadData)
	}
	query := endpoint.Query()
	query.Set("function", c.function)
	query.Set("symbol", symbol)
	query.Set("outputsize", "compact")
	query.Set("apikey", c.apiKey)
	endpoint.RawQuery = query.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint.String(), nil)
	if err != nil {
		return Result{}, fmt.Errorf("%w: create request", ErrBadData)
	}
	resp, err := c.httpClient.Do(req)
	if err != nil {
		// Client errors can contain the full request URL, including the API key.
		return Result{}, fmt.Errorf("%w: upstream request failed", ErrUnavailable)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return Result{}, fmt.Errorf("%w: upstream status %d", ErrUnavailable, resp.StatusCode)
	}

	body, err := io.ReadAll(io.LimitReader(resp.Body, maxResponse+1))
	if err != nil {
		return Result{}, fmt.Errorf("%w: read response", ErrBadData)
	}
	if len(body) > maxResponse {
		return Result{}, fmt.Errorf("%w: response exceeds limit", ErrBadData)
	}

	var payload struct {
		TimeSeries   map[string]map[string]string `json:"Time Series (Daily)"`
		Note         string                       `json:"Note"`
		Information  string                       `json:"Information"`
		ErrorMessage string                       `json:"Error Message"`
	}
	if err := json.Unmarshal(body, &payload); err != nil {
		return Result{}, fmt.Errorf("%w: malformed JSON", ErrBadData)
	}
	if payload.Note != "" || payload.Information != "" {
		return Result{}, fmt.Errorf("%w: provider quota or availability message", ErrUnavailable)
	}
	if payload.ErrorMessage != "" {
		return Result{}, fmt.Errorf("%w: provider rejected request", ErrBadData)
	}
	if len(payload.TimeSeries) == 0 {
		return Result{}, fmt.Errorf("%w: empty time series", ErrBadData)
	}

	dates := make([]string, 0, len(payload.TimeSeries))
	for date := range payload.TimeSeries {
		dates = append(dates, date)
	}
	sort.Sort(sort.Reverse(sort.StringSlice(dates)))
	if len(dates) > n {
		dates = dates[:n]
	}

	prices := make([]Price, 0, len(dates))
	var total float64
	for _, date := range dates {
		closeValue, ok := payload.TimeSeries[date]["4. close"]
		if !ok {
			return Result{}, fmt.Errorf("%w: missing closing price", ErrBadData)
		}
		closePrice, err := strconv.ParseFloat(closeValue, 64)
		if err != nil {
			return Result{}, fmt.Errorf("%w: malformed closing price", ErrBadData)
		}
		prices = append(prices, Price{Date: date, Close: closePrice})
		total += closePrice
	}

	return Result{
		Symbol:        symbol,
		RequestedDays: n,
		ReturnedDays:  len(prices),
		Prices:        prices,
		AverageClose:  total / float64(len(prices)),
		FetchedAt:     c.now().UTC(),
	}, nil
}

type Cache struct {
	fetcher Fetcher
	ttl     time.Duration
	backoff time.Duration
	now     func() time.Time

	mu          sync.Mutex
	result      Result
	expiresAt   time.Time
	nextAttempt time.Time
	lastErr     error
	refreshing  bool
	refreshed   chan struct{}
}

func NewCache(fetcher Fetcher, ttl time.Duration) *Cache {
	return &Cache{
		fetcher: fetcher,
		ttl:     ttl,
		backoff: time.Minute,
		now:     time.Now,
	}
}

func (c *Cache) Get(ctx context.Context, symbol string, n int) (Result, error) {
	for {
		c.mu.Lock()
		now := c.now()
		if !c.expiresAt.IsZero() && now.Before(c.expiresAt) {
			result := c.result
			c.mu.Unlock()
			return result, nil
		}
		if now.Before(c.nextAttempt) && c.lastErr != nil {
			err := c.lastErr
			c.mu.Unlock()
			return Result{}, err
		}
		if c.refreshing {
			done := c.refreshed
			c.mu.Unlock()
			select {
			case <-done:
				continue
			case <-ctx.Done():
				return Result{}, fmt.Errorf("%w: %v", ErrUnavailable, ctx.Err())
			}
		}

		c.refreshing = true
		c.refreshed = make(chan struct{})
		done := c.refreshed
		c.mu.Unlock()

		result, err := c.fetcher.Fetch(ctx, symbol, n)

		c.mu.Lock()
		if err == nil {
			c.result = result
			c.expiresAt = c.now().Add(c.ttl)
			c.nextAttempt = time.Time{}
			c.lastErr = nil
		} else {
			c.nextAttempt = c.now().Add(c.backoff)
			c.lastErr = err
		}
		c.refreshing = false
		close(done)
		c.mu.Unlock()
		return result, err
	}
}
