using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;

class SelectRelay {
    const string Dll = "ProxyBridgeCore.dll";
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate void LogCallback(IntPtr message);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate void ConnectionCallback(IntPtr process, uint pid, IntPtr ip, ushort port, IntPtr action);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern uint ProxyBridge_AddProxyConfig(int type, byte[] host, ushort port, byte[] user, byte[] pass, int remoteDns);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern uint ProxyBridge_AddRule(byte[] process, byte[] hosts, byte[] ports, byte[] domains, int protocol, int action, uint config);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern int ProxyBridge_DeleteRule(uint rule);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern int ProxyBridge_DeleteProxyConfig(uint config);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern void ProxyBridge_SetLogCallback(LogCallback callback);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern void ProxyBridge_SetConnectionCallback(ConnectionCallback callback);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern void ProxyBridge_SetTrafficLoggingEnabled(int enabled);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern void ProxyBridge_SetLocalhostViaProxy(int enabled);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern int ProxyBridge_Start();
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern int ProxyBridge_Stop();
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern int ProxyBridge_GetObservedDomain(byte[] ip, byte[] domain, uint size);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate void TrafficCallback(ulong id, IntPtr process, uint pid, IntPtr domain, IntPtr ip, IntPtr rule, ushort port, int udp, ulong upload, ulong download, ulong age);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] static extern void ProxyBridge_VisitSelectiveTraffic(TrafficCallback callback);
    static void WriteTraffic() {
        var rows = new List<object>();
        TrafficCallback callback = delegate(ulong id, IntPtr process, uint pid, IntPtr domain, IntPtr ip, IntPtr rule, ushort port, int udp, ulong upload, ulong download, ulong age) {
            rows.Add(new { id = Token + ":" + id, process = Decode(process), pid = pid, domain = Decode(domain), ip = Decode(ip), rule = Decode(rule), port = port, protocol = udp == 1 ? "UDP" : "TCP", upload = upload, download = download, ageMs = age });
        };
        ProxyBridge_VisitSelectiveTraffic(callback);
        string temporary = Path.Combine(Folder, "traffic.json.tmp"), path = Path.Combine(Folder, "traffic.json");
        File.WriteAllText(temporary, Json.Serialize(new { updated = DateTime.UtcNow.ToString("o"), flows = rows }), new UTF8Encoding(false));
        if (File.Exists(path)) File.Replace(temporary, path, null); else File.Move(temporary, path);
        GC.KeepAlive(callback);
    }
    static readonly object Gate = new object();
    static readonly JavaScriptSerializer Json = new JavaScriptSerializer();
    static readonly LogCallback Logger = delegate(IntPtr p) { Append("engine", Decode(p)); };
    static readonly ConnectionCallback Connection = delegate(IntPtr p, uint id, IntPtr ip, ushort port, IntPtr action) {
        string address = Decode(ip), route = Decode(action);
        byte[] domain = new byte[256];
        ProxyBridge_GetObservedDomain(Utf8(address), domain, (uint)domain.Length);
        int length = Array.IndexOf(domain, (byte)0);
        string host = Encoding.UTF8.GetString(domain, 0, length < 0 ? domain.Length : length);
        WriteEvent("connections.jsonl", new {
            time = DateTime.UtcNow.ToString("o"), kind = "connection", process = Decode(p), pid = id,
            domain = host, ip = address, port = port, action = route.StartsWith("Proxy") ? "proxy" : "direct",
            protocol = route.Contains("(UDP)") ? "UDP" : "TCP", route = route, domainSource = host.Length > 0 ? "observed-dns" : "unknown"
        });
    };
    static string Folder;
    static string Token;
    static bool Started;
    static uint Config;
    static readonly List<uint> Rules = new List<uint>();
    static byte[] Utf8(string value) { return Encoding.UTF8.GetBytes(value + "\0"); }
    static string Decode(IntPtr p) {
        if (p == IntPtr.Zero) return "";
        int length = 0;
        while (length < 8192 && Marshal.ReadByte(p, length) != 0) length++;
        byte[] bytes = new byte[length]; Marshal.Copy(p, bytes, 0, length);
        return Encoding.UTF8.GetString(bytes);
    }
    static void Append(string kind, string message) {
        WriteEvent("events.jsonl", new { time = DateTime.UtcNow.ToString("o"), kind = kind, message = message });
    }
    static void WriteEvent(string name, object value) {
        if (Folder == null) return;
        try { lock (Gate) {
            string path = Path.Combine(Folder, name);
            if (File.Exists(path) && new FileInfo(path).Length > 4194304) {
                string previous = path + ".previous";
                if (File.Exists(previous)) File.Delete(previous);
                File.Move(path, previous);
            }
            string line = Json.Serialize(value) + "\n";
            using (var stream = new FileStream(path, FileMode.Append, FileAccess.Write, FileShare.ReadWrite)) {
                byte[] bytes = Encoding.UTF8.GetBytes(line); stream.Write(bytes, 0, bytes.Length);
            }
        }} catch { }
    }
    static void Status(string state, string error) {
        try { lock (Gate) {
            string value = Json.Serialize(new { token = Token, state = state, error = error, pid = Process.GetCurrentProcess().Id, updated = DateTime.UtcNow.ToString("o") });
            using (var stream = new FileStream(Path.Combine(Folder, "status.json"), FileMode.Create, FileAccess.Write, FileShare.ReadWrite)) {
                byte[] bytes = Encoding.UTF8.GetBytes(value); stream.Write(bytes, 0, bytes.Length);
            }
        }} catch { }
    }
    static void Reset() {
        if (Started) { ProxyBridge_Stop(); Started = false; }
        foreach (uint rule in Rules) ProxyBridge_DeleteRule(rule);
        Rules.Clear();
        if (Config != 0) { ProxyBridge_DeleteProxyConfig(Config); Config = 0; }
    }
    static void Add(string process, string hosts, string domains, int action) {
        uint id = ProxyBridge_AddRule(Utf8(process), Utf8(hosts), Utf8("*"), Utf8(domains), 2, action, Config);
        if (id == 0) throw new InvalidOperationException("Cannot add routing rule");
        Rules.Add(id);
    }
    static void Apply(Dictionary<string, object> profile, bool capture = true) {
        if (!Started) Reset();
        else { foreach (uint id in Rules) ProxyBridge_DeleteRule(id); Rules.Clear(); }
        int port = Convert.ToInt32(profile["port"]);
        if (port != 17891) throw new InvalidOperationException("Invalid private ingress port");
        if (Config == 0) Config = ProxyBridge_AddProxyConfig(1, Utf8("127.0.0.1"), (ushort)port, Utf8(""), Utf8(""), 1);
        if (Config == 0) throw new InvalidOperationException("Cannot add proxy endpoint");
        Add("FlClashSelect.exe;FlClash.exe;FlClashCore.exe;FlClashHelperService.exe;FlClashSelectRelay.exe;FlClashSelectSpeed.exe;ProxyBridge.exe;ProxyBridge_CLI.exe;v2rayN.exe;xray.exe;sing-box.exe", "*", "*", 1);
        Add("*", "127.*;::1;10.*;192.168.*;172.16.0.0-172.31.255.255", "*", 1);
        var rules = profile["rules"] as IList;
        if (rules == null) throw new InvalidDataException("Rule list is not an array");
        if (rules.Count > 240) throw new InvalidOperationException("Too many routing rules");
        foreach (object item in rules) {
            var rule = (Dictionary<string, object>)item;
            if (!Convert.ToBoolean(rule["enabled"])) continue;
            string pattern = (string)rule["pattern"];
            if (Encoding.UTF8.GetByteCount(pattern) > 240 || pattern.IndexOf('\0') >= 0) throw new InvalidOperationException("Invalid rule");
            bool process = (string)rule["kind"] == "application";
            Add(process ? pattern : "*", "*", process ? "*" : pattern, 0);
        }
        Add("*", "*", "*", 1);
        ProxyBridge_SetLocalhostViaProxy(0);
        ProxyBridge_SetTrafficLoggingEnabled(1);
        if (!capture || Started) return;
        if (ProxyBridge_Start() == 0) throw new InvalidOperationException("Packet engine start failed. Check administrator rights and WinDivert driver logs.");
        Started = true;
        Append("status", "Selective proxy started; unmatched connections remain direct");
    }
    static bool CoreAvailable() {
        try { using (var client = new TcpClient()) {
            var result = client.BeginConnect("127.0.0.1", 17891, null, null);
            if (!result.AsyncWaitHandle.WaitOne(600)) return false;
            client.EndConnect(result); return true;
        }} catch { return false; }
    }
    static int Main(string[] args) {
        Directory.SetCurrentDirectory(AppDomain.CurrentDomain.BaseDirectory);
        if (args.Length == 1 && args[0] == "--is-admin") {
            var identity = System.Security.Principal.WindowsIdentity.GetCurrent();
            return new System.Security.Principal.WindowsPrincipal(identity).IsInRole(
                System.Security.Principal.WindowsBuiltInRole.Administrator) ? 0 : 3;
        }
        if ((args.Length == 1 && args[0] == "--self-test") ||
            (args.Length == 2 && args[0] == "--self-test-profile")) {
            try {
                string value = args.Length == 2 ? File.ReadAllText(args[1]) :
                    "{\"port\":17891,\"rules\":[{\"kind\":\"application\",\"pattern\":\"Discord.exe\",\"enabled\":true},{\"kind\":\"domain\",\"pattern\":\"*.github.com\",\"enabled\":true},{\"kind\":\"domain\",\"pattern\":\"disabled.example\",\"enabled\":false}]}";
                Apply(Json.Deserialize<Dictionary<string, object>>(value), false);
                if (args.Length == 1 && Rules.Count != 5) return 2;
                Reset(); return 0;
            } catch { Reset(); return 2; }
        }
        if (args.Length != 3) return 2;
        Folder = Path.GetFullPath(args[0]); Token = args[1];
        Guid session; int parentId;
        if (!Guid.TryParse(Token, out session) || !int.TryParse(args[2], out parentId)) return 2;
        Process parent;
        try { parent = Process.GetProcessById(parentId); var stamp = parent.StartTime; } catch { return 2; }
        string active = Path.Combine(Folder, "session.json");
        if (!Directory.Exists(Folder) || !File.Exists(active)) return 2;
        ProxyBridge_SetLogCallback(Logger); ProxyBridge_SetConnectionCallback(Connection);
        try {
            string previous = null;
            while (!parent.HasExited) {
                try { WriteTraffic(); } catch (Exception error) { Append("warning", "Traffic snapshot: " + error.Message); }
                var control = Json.Deserialize<Dictionary<string, object>>(File.ReadAllText(active));
                if ((string)control["token"] != Token || !Convert.ToBoolean(control["enabled"])) break;
                string profile = File.ReadAllText(Path.Combine(Folder, "rules.json"));
                if (!CoreAvailable()) { Reset(); Status("waiting", "Proxy core is stopped"); }
                else if (!Started || profile != previous) { Apply(Json.Deserialize<Dictionary<string, object>>(profile)); previous = profile; }
                if (Started) Status("running", "");
                Thread.Sleep(500);
            }
            Reset(); Status("stopped", ""); return 0;
        } catch (Exception error) {
            Append("error", error.Message); Reset(); Status("failed", error.Message); return 1;
        } finally { GC.KeepAlive(Logger); GC.KeepAlive(Connection); }
    }
}
