#include "pb_internal.h"

#define SELECT_MAX_FLOWS 4096
typedef struct {
    UINT64 id, upload, download;
    ULONGLONG updated;
    DWORD pid;
    UINT16 local_port, port;
    BOOL udp, v6;
    char process[256], ip[48], domain[256], rule[256];
} SELECT_FLOW;
typedef void (*SelectTrafficCallback)(UINT64, const char*, DWORD, const char*, const char*, const char*, UINT16, int, UINT64, UINT64, UINT64);
static SRWLOCK select_stats_lock = SRWLOCK_INIT;
static SELECT_FLOW select_flows[SELECT_MAX_FLOWS];
static UINT32 select_slots[262144];
static UINT64 select_next_id;

static UINT32 select_key(UINT16 port, BOOL udp, BOOL v6) {
    return port + (udp ? 65536 : 0) + (v6 ? 131072 : 0);
}

void select_stats_begin(UINT16 local, BOOL udp, BOOL v6, DWORD pid, const void *destination, UINT16 port, UINT32 initial_bytes) {
    char ip[48], process[MAX_PROCESS_NAME];
    if (!pid || !get_process_name_from_pid(pid, process, sizeof(process))) return;
    InetNtopA(v6 ? AF_INET6 : AF_INET, destination, ip, sizeof(ip));
    AcquireSRWLockExclusive(&select_stats_lock);
    UINT32 key = select_key(local, udp, v6);
    UINT32 slot = select_slots[key];
    if (!slot) {
        UINT32 oldest = 0;
        for (UINT32 i = 0; i < SELECT_MAX_FLOWS; i++) {
            if (!select_flows[i].id) { oldest = i; break; }
            if (select_flows[i].updated < select_flows[oldest].updated) oldest = i;
        }
        SELECT_FLOW *previous = &select_flows[oldest];
        if (previous->id) select_slots[select_key(previous->local_port, previous->udp, previous->v6)] = 0;
        slot = oldest + 1;
        select_slots[key] = slot;
    }
    SELECT_FLOW *flow = &select_flows[slot-1];
    memset(flow, 0, sizeof(*flow));
    flow->id = ++select_next_id; flow->pid = pid;
    flow->local_port = local; flow->port = port; flow->udp = udp; flow->v6 = v6;
    flow->upload = initial_bytes; flow->updated = GetTickCount64();
    const char *name = strrchr(process, '\\');
    strncpy_s(flow->process, sizeof(flow->process), name ? name + 1 : process, _TRUNCATE);
    strncpy_s(flow->ip, sizeof(flow->ip), ip, _TRUNCATE);
    if (v6) dns_cache_lookup_v6(destination, flow->domain, sizeof(flow->domain));
    else dns_cache_lookup(*(const UINT32*)destination, flow->domain, sizeof(flow->domain));
    extern _Thread_local unsigned long select_last_rule_id;
    AcquireSRWLockShared(&g_rules_lock);
    UINT32 proxy_id;
    RuleAction action = v6
        ? match_rule_v6_inner(process, destination, port, udp, &proxy_id)
        : match_rule_inner(process, *(const UINT32*)destination, port, udp, &proxy_id);
    if (action == RULE_ACTION_PROXY) {
        for (PROCESS_RULE *rule = rules_list; rule; rule = rule->next) {
            if (rule->rule_id == select_last_rule_id) {
                const char *label = strcmp(rule->process_name, "*") == 0 ? rule->target_domains : rule->process_name;
                strncpy_s(flow->rule, sizeof(flow->rule), label ? label : "", _TRUNCATE);
                break;
            }
        }
    }
    ReleaseSRWLockShared(&g_rules_lock);
    ReleaseSRWLockExclusive(&select_stats_lock);
}

void select_stats_count(UINT16 local, BOOL udp, BOOL v6, BOOL down, UINT32 bytes) {
    if (!bytes) return;
    AcquireSRWLockExclusive(&select_stats_lock);
    UINT32 slot = select_slots[select_key(local, udp, v6)];
    if (slot) {
        SELECT_FLOW *flow = &select_flows[slot-1];
        if (down) flow->download += bytes; else flow->upload += bytes;
        flow->updated = GetTickCount64();
    }
    ReleaseSRWLockExclusive(&select_stats_lock);
}

void select_stats_packet(PWINDIVERT_IPHDR ip, PWINDIVERT_IPV6HDR ip6, PWINDIVERT_TCPHDR tcp, PWINDIVERT_UDPHDR udp, BOOL outbound, UINT32 bytes) {
    if (!outbound || !bytes || (!tcp && !udp)) return;
    BOOL datagram = tcp == NULL, v6 = ip == NULL;
    UINT16 src = ntohs(tcp ? tcp->SrcPort : udp->SrcPort);
    UINT16 dst = ntohs(tcp ? tcp->DstPort : udp->DstPort);
    UINT16 relay = datagram ? LOCAL_UDP_RELAY_PORT : g_local_relay_port;
    BOOL down = src == relay;
    UINT16 local = down ? dst : src;
    UINT32 destination, cfg; UINT8 destination6[16]; UINT16 port;
    BOOL tracked = v6
        ? get_connection_full_v6(local, datagram, destination6, &port, &cfg)
        : get_connection_full(local, datagram, &destination, &port, &cfg);
    if (!tracked) return;
    if (!down && (dst != port || (v6 ? memcmp(ip6->DstAddr, destination6, 16) != 0 : ip->DstAddr != destination))) return;
    select_stats_count(local, datagram, v6, down, bytes);
}

PROXYBRIDGE_API void ProxyBridge_VisitSelectiveTraffic(SelectTrafficCallback callback) {
    if (!callback) return;
    ULONGLONG now = GetTickCount64();
    AcquireSRWLockShared(&select_stats_lock);
    for (UINT32 i = 0; i < SELECT_MAX_FLOWS; i++) {
        SELECT_FLOW *flow = &select_flows[i];
        if (flow->id && now - flow->updated <= 30000)
            callback(flow->id, flow->process, flow->pid, flow->domain, flow->ip, flow->rule, flow->port,
                flow->udp ? 1 : 0, flow->upload, flow->download, now - flow->updated);
    }
    ReleaseSRWLockShared(&select_stats_lock);
}

void select_stats_reset(void) {
    AcquireSRWLockExclusive(&select_stats_lock);
    memset(select_flows, 0, sizeof(select_flows));
    memset(select_slots, 0, sizeof(select_slots));
    ReleaseSRWLockExclusive(&select_stats_lock);
}
