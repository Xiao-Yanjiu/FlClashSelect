package main

import (
	"context"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/mihomo/log"
)

func fixtureProxy(t *testing.T, count *atomic.Int32) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		count.Add(1)
		connection, err := net.DialTimeout("tcp", r.Host, time.Second)
		if err != nil {
			http.Error(w, err.Error(), 502)
			return
		}
		client, _, err := w.(http.Hijacker).Hijack()
		if err != nil {
			connection.Close()
			return
		}
		_, _ = client.Write([]byte("HTTP/1.1 200 Connection Established\r\n\r\n"))
		go func() { _, _ = io.Copy(connection, client); connection.Close() }()
		go func() { _, _ = io.Copy(client, connection); client.Close() }()
	}))
}

func fixtureConfig(t *testing.T, selected, other string) string {
	t.Helper()
	first, _ := url.Parse(selected)
	second, _ := url.Parse(other)
	port1, _ := strconv.Atoi(first.Port())
	port2, _ := strconv.Atoi(second.Port())
	path := filepath.Join(t.TempDir(), "config.yaml")
	value := fmt.Sprintf(`proxies:
  - {name: selected, type: http, server: 127.0.0.1, port: %d}
  - {name: other, type: http, server: 127.0.0.1, port: %d}
proxy-groups:
  - {name: GLOBAL, type: select, proxies: [other, selected]}
rules: []
`, port1, port2)
	if err := os.WriteFile(path, []byte(value), 0600); err != nil {
		t.Fatal(err)
	}
	return path
}

func TestDownloadPinsSelectedNodeAndCountsBytes(t *testing.T) {
	log.SetLevel(log.SILENT)
	var selectedCount, otherCount atomic.Int32
	selected := fixtureProxy(t, &selectedCount)
	defer selected.Close()
	other := fixtureProxy(t, &otherCount)
	defer other.Close()
	target := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/octet-stream")
		_, _ = w.Write(make([]byte, 65536))
	}))
	defer target.Close()
	proxy, err := loadProxy(fixtureConfig(t, selected.URL, other.URL), "selected", `{"GLOBAL":"other"}`)
	if err != nil {
		t.Fatal(err)
	}
	result, err := download(context.Background(), proxy, target.URL, 65536, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	if result.Bytes != 65536 || result.State != "done" || result.Proxy != "selected" {
		t.Fatalf("unexpected result: %+v", result)
	}
	if selectedCount.Load() != 1 || otherCount.Load() != 0 {
		t.Fatal("test used a different node")
	}
}

func TestUnreachableSelectedNodeDoesNotFallBackDirect(t *testing.T) {
	log.SetLevel(log.SILENT)
	var nodeCalls, targetCalls atomic.Int32
	node := fixtureProxy(t, &nodeCalls)
	closedURL := node.URL
	node.Close()
	target := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		targetCalls.Add(1)
		_, _ = w.Write([]byte("data"))
	}))
	defer target.Close()
	proxy, err := loadProxy(fixtureConfig(t, closedURL, closedURL), "selected", "")
	if err != nil {
		t.Fatal(err)
	}
	_, err = download(context.Background(), proxy, target.URL, 1024, time.Second)
	if err == nil || targetCalls.Load() != 0 {
		t.Fatal("failed node bypassed proxy")
	}
}

func TestHeaderErrorIsNotReportedAsSpeed(t *testing.T) {
	log.SetLevel(log.SILENT)
	var calls atomic.Int32
	node := fixtureProxy(t, &calls)
	defer node.Close()
	target := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "blocked", 403)
	}))
	defer target.Close()
	proxy, err := loadProxy(fixtureConfig(t, node.URL, node.URL), "selected", "")
	if err != nil {
		t.Fatal(err)
	}
	result, err := download(context.Background(), proxy, target.URL, 1024, time.Second)
	if err == nil || result.Bytes != 0 {
		t.Fatal("HTTP error counted as download speed")
	}
}

func TestWarmupBytesAreExcludedFromSteadyMeasurement(t *testing.T) {
	log.SetLevel(log.SILENT)
	var counter atomic.Int32
	selected := fixtureProxy(t, &counter)
	defer selected.Close()
	target := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/octet-stream")
		for i := 0; i < 20; i++ {
			if _, err := w.Write(make([]byte, 1024)); err != nil {
				return
			}
			w.(http.Flusher).Flush()
			time.Sleep(25 * time.Millisecond)
		}
	}))
	defer target.Close()
	proxy, err := loadProxy(fixtureConfig(t, selected.URL, selected.URL), "selected", "")
	if err != nil {
		t.Fatal(err)
	}
	result, err := downloadWindow(context.Background(), proxy, target.URL, 1024*1024, 250*time.Millisecond, 100*time.Millisecond)
	if err != nil {
		t.Fatal(err)
	}
	if result.Bytes <= 0 || result.Bytes >= 20*1024 || result.Micros < 150000 {
		t.Fatalf("warmup was not excluded: %+v", result)
	}
}
