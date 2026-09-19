#!/usr/bin/env python3
import sys
import subprocess
import json

def get_status():
    radio_res = subprocess.run(["nmcli", "radio", "wifi"], capture_output=True, text=True)
    enabled = "enabled" in radio_res.stdout.strip()
    if not enabled:
        return {"enabled": False, "ssid": "", "signal": 0}
    
    res = subprocess.run(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL", "dev", "wifi", "list"], capture_output=True, text=True)
    for line in res.stdout.strip().split("\n"):
        if line.startswith("*"):
            parts = line.split(":")
            if len(parts) >= 3:
                ssid = parts[1]
                sig = int(parts[2]) if parts[2].isdigit() else 0
                return {"enabled": True, "ssid": ssid, "signal": sig}
    return {"enabled": True, "ssid": "", "signal": 0}

def list_networks():
    radio_res = subprocess.run(["nmcli", "radio", "wifi"], capture_output=True, text=True)
    enabled = "enabled" in radio_res.stdout.strip()
    if not enabled:
        return {"enabled": False, "networks": []}

    res = subprocess.run(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list"], capture_output=True, text=True)
    networks = []
    seen = set()
    for line in res.stdout.strip().split("\n"):
        if not line:
            continue
        parts = line.split(":")
        if len(parts) >= 4:
            in_use = parts[0] == "*"
            ssid = parts[1].strip()
            signal = int(parts[2]) if parts[2].isdigit() else 0
            sec = parts[3].strip()
            if ssid and ssid not in seen:
                seen.add(ssid)
                networks.append({
                    "in_use": in_use,
                    "ssid": ssid,
                    "signal": signal,
                    "security": sec,
                    "is_locked": len(sec) > 0 and sec != "--"
                })
    # Sort: in_use first, then descending signal
    networks.sort(key=lambda x: (not x["in_use"], -x["signal"]))
    return {"enabled": True, "networks": networks}

def toggle_wifi(target=None):
    if target in ("on", "off"):
        subprocess.run(["nmcli", "radio", "wifi", target])
    else:
        status = get_status()
        new_state = "off" if status["enabled"] else "on"
        subprocess.run(["nmcli", "radio", "wifi", new_state])
    print(json.dumps(get_status()))

def connect_wifi(ssid, password=None):
    cmd = ["nmcli", "dev", "wifi", "connect", ssid]
    if password:
        cmd.extend(["password", password])
    res = subprocess.run(cmd, capture_output=True, text=True)
    success = res.returncode == 0
    print(json.dumps({"success": success, "output": res.stdout.strip() or res.stderr.strip()}))

def disconnect_wifi():
    # Find wifi device
    res = subprocess.run(["nmcli", "-t", "-f", "DEVICE,TYPE", "dev"], capture_output=True, text=True)
    for line in res.stdout.strip().split("\n"):
        parts = line.split(":")
        if len(parts) >= 2 and parts[1] == "wifi":
            dev = parts[0]
            subprocess.run(["nmcli", "dev", "disconnect", dev])
            print(json.dumps({"success": True}))
            return
    print(json.dumps({"success": False}))

def forget_wifi(ssid):
    res = subprocess.run(["nmcli", "connection", "delete", "id", ssid], capture_output=True, text=True)
    print(json.dumps({"success": res.returncode == 0}))

def main():
    if len(sys.argv) < 2:
        print(json.dumps(get_status()))
        return
    cmd = sys.argv[1]
    if cmd == "status":
        print(json.dumps(get_status()))
    elif cmd == "list":
        print(json.dumps(list_networks()))
    elif cmd == "toggle":
        target = sys.argv[2] if len(sys.argv) > 2 else None
        toggle_wifi(target)
    elif cmd == "connect":
        if len(sys.argv) > 2:
            ssid = sys.argv[2]
            pwd = sys.argv[3] if len(sys.argv) > 3 else None
            connect_wifi(ssid, pwd)
    elif cmd == "disconnect":
        disconnect_wifi()
    elif cmd == "forget":
        if len(sys.argv) > 2:
            forget_wifi(sys.argv[2])

if __name__ == "__main__":
    main()
