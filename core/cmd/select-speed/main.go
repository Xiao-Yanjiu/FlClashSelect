package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"github.com/metacubex/http"
	"io"
	"net"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/metacubex/mihomo/component/ca"
	M "github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	_ "github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel"
)

type measurement struct {
	State  string `json:"state"`
	Proxy  string `json:"proxy"`
	Bytes  int64  `json:"bytes"`
	Micros int64  `json:"micros"`
	Error  string `json:"error,omitempty"`
}

func emit(value measurement) {
	_ = json.NewEncoder(os.Stdout).Encode(value)
}

func loadProxy(path, name, picks string) (C.Proxy, error) {
	contents, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	raw, err := M.UnmarshalRawConfig(contents)
	if err != nil {
		return nil, err
	}
	// This process only constructs outbound adapters; it starts no listener,
	// virtual interface, DNS service or external controller.
	raw.Listeners = nil
	raw.Rule = nil
	raw.RuleProvider = nil
	raw.Tun.Enable = false
	raw.NTP.Enable = false
	raw.Profile.StoreSelected = false
	raw.Profile.StoreFakeIP = false
	C.SetHomeDir(filepath.Dir(path))
	cfg, err := M.ParseRawConfig(raw)
	if err != nil {
		return nil, err
	}
	tunnel.UpdateProxies(cfg.Proxies, cfg.Providers)
	for _, provider := range cfg.Providers {
		if err := provider.Initial(); err != nil {
			return nil, fmt.Errorf("provider %s: %w", provider.Name(), err)
		}
	}
	selected := map[string]string{}
	if picks != "" {
		if err := json.Unmarshal([]byte(picks), &selected); err != nil {
			return nil, err
		}
	}
	for group, pick := range selected {
		if proxy := cfg.Proxies[group]; proxy != nil {
			if setter, ok := proxy.Adapter().(interface{ Set(string) error }); ok {
				_ = setter.Set(pick)
			}
		}
	}
	proxy := cfg.Proxies[name]
	if proxy == nil {
		return nil, fmt.Errorf("selected proxy %q is missing from the current config", name)
	}
	return proxy, nil
}

func download(ctx context.Context, proxy C.Proxy, url string, limit int64, budget time.Duration) (measurement, error) {
	return downloadWindow(ctx, proxy, url, limit, budget, 0)
}

func downloadWindow(ctx context.Context, proxy C.Proxy, url string, limit int64, budget, warmup time.Duration) (measurement, error) {
	tlsConfig, err := ca.GetTLSConfig(ca.Option{})
	if err != nil {
		return measurement{}, err
	}
	transport := &http.Transport{
		DisableCompression:  true,
		TLSClientConfig:     tlsConfig,
		TLSHandshakeTimeout: 8 * time.Second,
		DialContext: func(ctx context.Context, _, address string) (net.Conn, error) {
			metadata := &C.Metadata{NetWork: C.TCP, Type: C.INNER, DNSMode: C.DNSNormal}
			if err := metadata.SetRemoteAddress(address); err != nil {
				return nil, err
			}
			return proxy.DialContext(ctx, metadata)
		},
	}
	defer transport.CloseIdleConnections()
	client := &http.Client{Transport: transport, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return measurement{}, err
	}
	request.Header.Set("Accept-Encoding", "identity")
	request.Header.Set("Cache-Control", "no-cache")
	response, err := client.Do(request)
	if err != nil {
		return measurement{}, err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return measurement{}, fmt.Errorf("test server returned HTTP %d", response.StatusCode)
	}
	if strings.HasPrefix(strings.ToLower(response.Header.Get("Content-Type")), "text/html") {
		return measurement{}, errors.New("test server returned an HTML page")
	}
	start := time.Now()
	last := start
	result := measurement{State: "running", Proxy: proxy.Name()}
	finish := time.AfterFunc(budget+warmup, func() { _ = response.Body.Close() })
	defer finish.Stop()
	buffer := make([]byte, 64*1024)
	var transferred int64
	sampleStart := start
	warmed := warmup == 0
	for transferred < limit {
		remaining := min(int64(len(buffer)), limit-transferred)
		n, readErr := response.Body.Read(buffer[:remaining])
		transferred += int64(n)
		if warmed {
			result.Bytes += int64(n)
			result.Micros = max(time.Since(sampleStart).Microseconds(), 1)
		} else if time.Since(start) >= warmup {
			warmed = true
			sampleStart = time.Now()
		}
		if time.Since(last) >= 200*time.Millisecond {
			emit(result)
			last = time.Now()
		}
		if readErr != nil {
			if readErr == io.EOF || (result.Bytes > 0 && time.Since(start) >= budget+warmup) {
				break
			}
			return result, readErr
		}
	}
	if result.Bytes == 0 {
		return result, errors.New("test returned no download data")
	}
	result.State = "done"
	return result, nil
}

func main() {
	path := flag.String("config", "", "current applied configuration")
	name := flag.String("proxy", "", "exact outbound adapter")
	picks := flag.String("picks", "", "current group selections")
	flag.Parse()
	log.SetLevel(log.SILENT)
	emit(measurement{State: "loading", Proxy: *name})
	proxy, err := loadProxy(*path, *name, *picks)
	if err == nil {
		targets := []string{
			fmt.Sprintf("https://speed.cloudflare.com/__down?bytes=268435456&nonce=%d", time.Now().UnixNano()),
			"https://proof.ovh.net/files/1Gb.dat",
		}
		for _, target := range targets {
			ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
			var result measurement
			result, err = downloadWindow(ctx, proxy, target, 256*1024*1024, 8*time.Second, time.Second)
			if err == nil && result.Micros < int64(2*time.Second/time.Microsecond) {
				err = errors.New("download sample was too short for a reliable speed result")
			}
			cancel()
			if err == nil {
				emit(result)
				return
			}
			if result.Bytes > 0 {
				break
			}
		}
	}
	emit(measurement{State: "failed", Proxy: *name, Error: err.Error()})
	os.Exit(1)
}
