#!/usr/bin/env python3
import sys
import subprocess
import json
import time

def get_status():
    res = subprocess.run(["bluetoothctl", "show"], capture_output=True, text=True)
    powered = "Powered: yes" in res.stdout
    if not powered:
        return {"powered": False, "enabled": False, "connected_name": "", "connected_mac": ""}
    
    # Check connected devices
    dev_res = subprocess.run(["bluetoothctl", "devices", "Connected"], capture_output=True, text=True)
    conn_name = ""
    conn_mac = ""
    for line in dev_res.stdout.strip().split("\n"):
        parts = line.split(" ", 2)
        if len(parts) >= 3 and parts[0] == "Device":
            conn_mac = parts[1]
            conn_name = parts[2].strip()
            break
        elif len(parts) == 2 and parts[0] == "Device":
            conn_mac = parts[1]
            conn_name = parts[1]
            break
    return {"powered": True, "enabled": True, "connected_name": conn_name, "connected_mac": conn_mac}

def list_devices():
    status = get_status()
    if not status["powered"]:
        return {"powered": False, "enabled": False, "devices": []}
        
    # BlueZ 5.70+ uses "devices Paired", older uses "paired-devices"
    paired_res = subprocess.run(["bluetoothctl", "devices", "Paired"], capture_output=True, text=True)
    if paired_res.returncode != 0 or "Invalid command" in paired_res.stdout:
        paired_res = subprocess.run(["bluetoothctl", "paired-devices"], capture_output=True, text=True)
    
    paired_macs = set()
    for line in paired_res.stdout.strip().split("\n"):
        parts = line.split(" ", 2)
        if len(parts) >= 2 and parts[0] == "Device":
            paired_macs.add(parts[1])

    all_res = subprocess.run(["bluetoothctl", "devices"], capture_output=True, text=True)
    conn_res = subprocess.run(["bluetoothctl", "devices", "Connected"], capture_output=True, text=True)
    conn_macs = set()
    for line in conn_res.stdout.strip().split("\n"):
        parts = line.split(" ", 2)
        if len(parts) >= 2 and parts[0] == "Device":
            conn_macs.add(parts[1])

    devices = []
    seen = set()
    combined = paired_res.stdout.strip().split("\n") + all_res.stdout.strip().split("\n")
    for line in combined:
        if not line or "Invalid command" in line:
            continue
        parts = line.split(" ", 2)
        if len(parts) >= 2 and parts[0] == "Device":
            mac = parts[1]
            name = parts[2].strip() if len(parts) >= 3 else mac
            if mac and mac not in seen:
                seen.add(mac)
                devices.append({
                    "mac": mac,
                    "name": name,
                    "paired": mac in paired_macs,
                    "connected": mac in conn_macs
                })
    # Sort: connected first, paired second, others last
    devices.sort(key=lambda x: (not x["connected"], not x["paired"], x["name"].lower()))
    return {"powered": True, "enabled": True, "devices": devices}

def toggle_bt(target=None):
    if target in ("on", "off"):
        new_state = target
    else:
        st = get_status()
        new_state = "off" if st["powered"] else "on"
    
    if new_state == "on":
        subprocess.run(["rfkill", "unblock", "bluetooth"], capture_output=True)
        subprocess.run(["bluetoothctl", "power", "on"], capture_output=True, text=True)
    else:
        subprocess.run(["bluetoothctl", "power", "off"], capture_output=True, text=True)

    is_on = (new_state == "on")
    res = get_status()
    res["powered"] = is_on
    res["enabled"] = is_on
    print(json.dumps(res))

def scan_bt(timeout=5):
    status = get_status()
    if not status["powered"]:
        subprocess.run(["rfkill", "unblock", "bluetooth"], capture_output=True)
        subprocess.run(["bluetoothctl", "power", "on"], capture_output=True, text=True)
        time.sleep(0.3)

    scan_res = subprocess.run(["bluetoothctl", "--timeout", str(timeout), "scan", "on"], capture_output=True, text=True)
    
    # Extract any devices seen in scan stdout
    extra_devices = {}
    for line in scan_res.stdout.splitlines():
        line = line.strip()
        if "Device" in line:
            parts = line.split("Device ", 1)
            if len(parts) == 2:
                dev_info = parts[1].strip()
                if " Name: " in dev_info:
                    mac, name = dev_info.split(" Name: ", 1)
                    mac = mac.strip()
                    name = name.strip()
                    if mac:
                        extra_devices[mac] = name
                elif " " in dev_info:
                    tokens = dev_info.split(" ", 1)
                    mac = tokens[0].strip()
                    name = tokens[1].strip()
                    if not name.startswith("RSSI:") and not name.startswith("TxPower:") and not name.startswith("ManufacturerData"):
                        extra_devices[mac] = name
                else:
                    mac = dev_info.strip()
                    if mac not in extra_devices:
                        extra_devices[mac] = ""

    result = list_devices()
    existing_macs = {d["mac"] for d in result.get("devices", [])}
    for mac, name in extra_devices.items():
        if mac not in existing_macs:
            result.get("devices", []).append({
                "mac": mac,
                "name": name if name else mac,
                "paired": False,
                "connected": False
            })
        else:
            for d in result.get("devices", []):
                if d["mac"] == mac and (not d["name"] or d["name"].replace("-", ":").lower() == mac.lower()) and name:
                    d["name"] = name

    result.get("devices", []).sort(key=lambda x: (not x["connected"], not x["paired"], x["name"].lower()))
    print(json.dumps(result))

def connect_bt(mac):
    res = subprocess.run(["bluetoothctl", "connect", mac], capture_output=True, text=True)
    success = "Connection successful" in res.stdout
    msg = "Conectado com sucesso!" if success else (res.stdout.strip() or "Falha ao conectar")
    print(json.dumps({"success": success, "output": msg}))

def disconnect_bt(mac):
    res = subprocess.run(["bluetoothctl", "disconnect", mac], capture_output=True, text=True)
    msg = "Desconectado" if res.returncode == 0 else "Falha ao desconectar"
    print(json.dumps({"success": res.returncode == 0, "output": msg}))

def pair_bt(mac):
    subprocess.run(["bluetoothctl", "pair", mac], capture_output=True, text=True)
    subprocess.run(["bluetoothctl", "trust", mac], capture_output=True, text=True)
    res = subprocess.run(["bluetoothctl", "connect", mac], capture_output=True, text=True)
    success = "Connection successful" in res.stdout
    msg = "Pareado e conectado!" if success else (res.stdout.strip() or "Pareado")
    print(json.dumps({"success": res.returncode == 0, "output": msg}))

def remove_bt(mac):
    res = subprocess.run(["bluetoothctl", "remove", mac], capture_output=True, text=True)
    print(json.dumps({"success": res.returncode == 0, "output": "Dispositivo esquecido"}))

def main():
    if len(sys.argv) < 2:
        print(json.dumps(get_status()))
        return
    cmd = sys.argv[1]
    if cmd == "status":
        print(json.dumps(get_status()))
    elif cmd == "list":
        print(json.dumps(list_devices()))
    elif cmd == "toggle":
        target = sys.argv[2] if len(sys.argv) > 2 else None
        toggle_bt(target)
    elif cmd == "scan":
        timeout = 5
        if len(sys.argv) > 2:
            try:
                timeout = int(sys.argv[2])
            except ValueError:
                pass
        scan_bt(timeout)
    elif cmd == "connect" and len(sys.argv) > 2:
        connect_bt(sys.argv[2])
    elif cmd == "disconnect" and len(sys.argv) > 2:
        disconnect_bt(sys.argv[2])
    elif cmd == "pair" and len(sys.argv) > 2:
        pair_bt(sys.argv[2])
    elif cmd == "remove" and len(sys.argv) > 2:
        remove_bt(sys.argv[2])

if __name__ == "__main__":
    main()
