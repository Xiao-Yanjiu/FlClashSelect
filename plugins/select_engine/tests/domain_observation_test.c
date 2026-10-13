#include "pb_internal.h"
#include <assert.h>

int ProxyBridge_GetObservedDomain(const char *ip, char *domain, UINT32 size);

void select_stats_count(UINT16, BOOL, BOOL, BOOL, UINT32);
typedef void (*SelectTrafficCallback)(UINT64, const char*, DWORD, const char*, const char*, const char*, UINT16, int, UINT64, UINT64, UINT64);
void ProxyBridge_VisitSelectiveTraffic(SelectTrafficCallback);
static int snapshots;
static void verify_traffic(UINT64 id, const char *process, DWORD pid, const char *domain, const char *ip, const char *rule, UINT16 port, int udp, UINT64 up, UINT64 down, UINT64 age) {
    assert(id != 0 && pid == GetCurrentProcessId());
    assert(strcmp(domain, "github.com") == 0);
    assert(strcmp(ip, "20.205.243.166") == 0);
    assert(port == 443 && udp == 0);
    assert(strcmp(rule, "github.com") == 0);
    assert(up == 76 && down == 128);
    snapshots++;
}
int main(void)
{
    UINT32 ip;
    UINT8 ip6[16];
    char domain[256];
    assert(InetPtonA(AF_INET, "20.205.243.166", &ip) == 1);
    dns_cache_store(ip, "github.com");
    assert(ProxyBridge_GetObservedDomain("20.205.243.166", domain, sizeof(domain)) == 1);
    assert(strcmp(domain, "github.com") == 0);
    assert(InetPtonA(AF_INET6, "2001:db8::1", ip6) == 1);
    dns_cache_store_v6(ip6, "example.com");
    assert(ProxyBridge_GetObservedDomain("2001:db8::1", domain, sizeof(domain)) == 1);
    assert(strcmp(domain, "example.com") == 0);
    assert(ProxyBridge_GetObservedDomain("192.0.2.123", domain, sizeof(domain)) == 0);
    assert(domain[0] == 0);
    assert(ProxyBridge_GetObservedDomain("invalid", domain, sizeof(domain)) == 0);
    assert(domain[0] == 0);
    ProxyBridge_AddRule("*", "*", "*", "github.com", RULE_PROTOCOL_BOTH, RULE_ACTION_PROXY, 1);
    select_stats_begin(45001, FALSE, FALSE, GetCurrentProcessId(), &ip, 443, 12);
    add_connection(45001, FALSE, 0, ip, 443, 1);
    WINDIVERT_IPHDR packet_ip = {0}; WINDIVERT_TCPHDR packet_tcp = {0};
    packet_ip.DstAddr = ip; packet_tcp.SrcPort = htons(45001); packet_tcp.DstPort = htons(443);
    select_stats_packet(&packet_ip, NULL, &packet_tcp, NULL, TRUE, 64);
    packet_tcp.SrcPort = htons(g_local_relay_port); packet_tcp.DstPort = htons(45001);
    select_stats_packet(&packet_ip, NULL, &packet_tcp, NULL, TRUE, 128);
    select_stats_count(45001, TRUE, FALSE, TRUE, 900);
    ProxyBridge_VisitSelectiveTraffic(verify_traffic);
    assert(snapshots == 1);
    return 0;
}
