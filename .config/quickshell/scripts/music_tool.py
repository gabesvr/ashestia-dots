#!/usr/bin/env python3
import os
import sys
import json
import time
import socket
import subprocess
import re

SOCKET_PATH = "/tmp/mpv_music.sock"
STATE_FILE = "/tmp/mpv_music_state.json"
CACHE_FILE = os.path.expanduser("~/.config/quickshell/.music_cache.json")
MUSIC_DIRS = [os.path.expanduser("~/Musics"), os.path.expanduser("~/Music")]
AUDIO_EXTS = (".mp3", ".flac", ".wav", ".ogg", ".m4a", ".opus", ".aac", ".wma")

def is_socket_alive():
    if not os.path.exists(SOCKET_PATH):
        return False
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(0.2)
        s.connect(SOCKET_PATH)
        s.close()
        return True
    except Exception:
        return False

def ensure_mpv():
    if is_socket_alive():
        return True
    if os.path.exists(SOCKET_PATH):
        try:
            os.remove(SOCKET_PATH)
        except Exception:
            pass
    # Spawn mpv daemon in background
    cmd = [
        "mpv",
        "--idle=yes",
        f"--input-ipc-server={SOCKET_PATH}",
        "--no-video",
        "--volume=85",
        "--audio-display=no"
    ]
    subprocess.Popen(
        cmd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        stdin=subprocess.DEVNULL,
        start_new_session=True
    )
    # Wait briefly for socket to appear
    for _ in range(25):
        time.sleep(0.04)
        if is_socket_alive():
            return True
    return False

def send_mpv_command(cmd_list, timeout=0.8):
    if not is_socket_alive():
        if not ensure_mpv():
            return None
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(timeout)
        s.connect(SOCKET_PATH)
        req = json.dumps({"command": cmd_list}) + "\n"
        s.sendall(req.encode("utf-8"))
        res = ""
        while True:
            chunk = s.recv(4096).decode("utf-8")
            if not chunk:
                break
            res += chunk
            if "\n" in chunk:
                break
        s.close()
        for line in res.strip().split("\n"):
            if line:
                try:
                    data = json.loads(line)
                    if "data" in data or "error" in data:
                        return data.get("data")
                except Exception:
                    pass
        return None
    except Exception:
        return None

def get_mpv_property(prop_name):
    return send_mpv_command(["get_property", prop_name])

def clean_song_title(filename):
    base = os.path.splitext(filename)[0]
    base = base.replace("_", " ").replace("-", " ")
    # Check if all upper or all lower
    words = base.split()
    clean_words = []
    for w in words:
        if w.upper() in ["POV", "DJ", "MC", "EP", "VIP"]:
            clean_words.append(w.upper())
        elif w.isupper() or w.islower():
            clean_words.append(w.capitalize())
        else:
            clean_words.append(w)
    return " ".join(clean_words) if clean_words else base

def format_duration(seconds):
    try:
        sec = int(round(float(seconds)))
        m = sec // 60
        s = sec % 60
        return f"{m}:{s:02d}"
    except Exception:
        return "0:00"

def load_cache():
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {}

def save_cache(cache):
    try:
        with open(CACHE_FILE, "w") as f:
            json.dump(cache, f, indent=2)
    except Exception:
        pass

def inspect_media_file(path, cache):
    mtime = os.path.getmtime(path)
    cached = cache.get(path)
    if cached and cached.get("mtime") == mtime:
        return cached

    title = clean_song_title(os.path.basename(path))
    artist = "Local"
    album = ""
    duration = 0.0

    try:
        cmd = ["ffprobe", "-v", "quiet", "-print_format", "json", "-show_format", "-show_streams", path]
        out = subprocess.check_output(cmd, timeout=3)
        data = json.loads(out)
        fmt = data.get("format", {})
        duration = float(fmt.get("duration", 0))
        tags = fmt.get("tags", {})
        if "title" in tags and tags["title"].strip():
            title = tags["title"].strip()
        if "artist" in tags and tags["artist"].strip() and tags["artist"].strip().lower() != "unknown":
            artist = tags["artist"].strip()
        if "album" in tags and tags["album"].strip():
            album = tags["album"].strip()
    except Exception:
        pass

    info = {
        "mtime": mtime,
        "title": title,
        "artist": artist,
        "album": album,
        "duration": duration,
        "duration_str": format_duration(duration)
    }
    cache[path] = info
    return info

def discover_songs():
    cache = load_cache()
    songs = []
    seen = set()

    for d in MUSIC_DIRS:
        if not os.path.exists(d):
            continue
        try:
            for f in sorted(os.listdir(d)):
                full = os.path.realpath(os.path.join(d, f))
                if full in seen or not os.path.isfile(full):
                    continue
                if f.lower().endswith(AUDIO_EXTS):
                    seen.add(full)
                    meta = inspect_media_file(full, cache)
                    songs.append({
                        "file": f,
                        "path": full,
                        "title": meta.get("title") or clean_song_title(f),
                        "artist": meta.get("artist") or "Local",
                        "album": meta.get("album") or "",
                        "duration": meta.get("duration") or 0.0,
                        "duration_str": meta.get("duration_str") or "0:00"
                    })
        except Exception:
            pass

    save_cache(cache)
    return songs

def discover_gifs():
    p = os.path.expanduser("~/Musics/music_center.gif")
    if os.path.exists(p):
        return [{"name": "music_center.gif", "path": "file://" + p, "local_path": p}]
    return []

def get_player_status(songs):
    current = {
        "path": "",
        "file": "",
        "title": "Nenhuma música tocando",
        "artist": "Local Music",
        "pos": 0.0,
        "pos_str": "0:00",
        "duration": 0.0,
        "duration_str": "0:00",
        "status": "Stopped", # "Playing", "Paused", "Stopped"
        "volume": 85,
        "index": -1
    }

    if not is_socket_alive():
        # Check playerctl fallback
        try:
            p_stat = subprocess.check_output(["playerctl", "-p", "mpv", "status"], stderr=subprocess.DEVNULL, timeout=0.3).decode().strip()
            if p_stat in ["Playing", "Paused"]:
                current["status"] = p_stat
        except Exception:
            pass
        return current

    try:
        path = get_mpv_property("path")
        pause = get_mpv_property("pause")
        pos = get_mpv_property("time-pos")
        dur = get_mpv_property("duration")
        vol = get_mpv_property("volume")

        if path:
            real_path = os.path.realpath(str(path))
            current["path"] = real_path
            current["file"] = os.path.basename(real_path)
            current["title"] = clean_song_title(current["file"])
            current["status"] = "Paused" if pause is True else "Playing"
            current["pos"] = float(pos) if pos is not None else 0.0
            current["pos_str"] = format_duration(current["pos"])
            current["duration"] = float(dur) if dur is not None else 0.0
            current["duration_str"] = format_duration(current["duration"])
            current["volume"] = int(vol) if vol is not None else 85

            for idx, s in enumerate(songs):
                if s["path"] == real_path:
                    current["title"] = s["title"]
                    current["artist"] = s["artist"]
                    current["index"] = idx
                    if current["duration"] <= 0:
                        current["duration"] = s["duration"]
                        current["duration_str"] = s["duration_str"]
                    break
    except Exception:
        pass

    return current

def cmd_list():
    songs = discover_songs()
    gifs = discover_gifs()
    status = get_player_status(songs)
    out = {
        "status": "ok",
        "songs": songs,
        "gifs": gifs,
        "current": status
    }
    print(json.dumps(out))

def pause_external_players():
    try:
        subprocess.run(
            ["playerctl", "-a", "-i", "mpv", "pause"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=0.4
        )
    except Exception:
        pass

def cmd_play(arg=None):
    songs = discover_songs()
    if not songs:
        print(json.dumps({"status": "error", "message": "Nenhuma música encontrada"}))
        return

    target_path = None
    if arg:
        arg_str = str(arg).strip()
        if arg_str.isdigit():
            idx = int(arg_str)
            if 0 <= idx < len(songs):
                target_path = songs[idx]["path"]
        else:
            for s in songs:
                if s["path"] == arg_str or s["file"] == arg_str or arg_str.lower() in s["title"].lower():
                    target_path = s["path"]
                    break
            if not target_path and os.path.exists(arg_str):
                target_path = os.path.realpath(arg_str)

    if not target_path:
        target_path = songs[0]["path"]

    ensure_mpv()
    pause_external_players()
    send_mpv_command(["loadfile", target_path, "replace"])
    send_mpv_command(["set_property", "pause", False])

    # Return updated list / status
    time.sleep(0.15)
    cmd_list()

def cmd_toggle():
    if not is_socket_alive():
        # Start playback from first song
        cmd_play()
        return
    pause = get_mpv_property("pause")
    if pause is None:
        cmd_play()
        return
    new_state = not pause
    if not new_state: # resuming playback
        pause_external_players()
    send_mpv_command(["set_property", "pause", new_state])
    time.sleep(0.1)
    cmd_list()

def cmd_next():
    songs = discover_songs()
    if not songs:
        return
    status = get_player_status(songs)
    curr_idx = status.get("index", -1)
    next_idx = (curr_idx + 1) % len(songs)
    cmd_play(next_idx)

def cmd_prev():
    songs = discover_songs()
    if not songs:
        return
    status = get_player_status(songs)
    curr_idx = status.get("index", -1)
    prev_idx = (curr_idx - 1) % len(songs) if curr_idx > 0 else (len(songs) - 1)
    cmd_play(prev_idx)

def cmd_seek(seconds_or_pct):
    try:
        val = str(seconds_or_pct).strip()
        if val.endswith("%"):
            pct = float(val[:-1])
            send_mpv_command(["seek", pct, "absolute-percent"])
        else:
            sec = float(val)
            send_mpv_command(["seek", sec, "absolute"])
    except Exception:
        pass

def cmd_volume(vol_str):
    try:
        vol = max(0, min(100, int(vol_str)))
        send_mpv_command(["set_property", "volume", vol])
    except Exception:
        pass

def main():
    if len(sys.argv) < 2 or sys.argv[1] == "list":
        cmd_list()
    elif sys.argv[1] == "play":
        target = sys.argv[2] if len(sys.argv) > 2 else None
        cmd_play(target)
    elif sys.argv[1] == "toggle":
        cmd_toggle()
    elif sys.argv[1] == "next":
        cmd_next()
    elif sys.argv[1] == "prev":
        cmd_prev()
    elif sys.argv[1] == "seek":
        if len(sys.argv) > 2:
            cmd_seek(sys.argv[2])
    elif sys.argv[1] == "volume":
        if len(sys.argv) > 2:
            cmd_volume(sys.argv[2])
    elif sys.argv[1] == "status":
        songs = discover_songs()
        status = get_player_status(songs)
        print(json.dumps(status))
    else:
        cmd_list()

if __name__ == "__main__":
    main()
