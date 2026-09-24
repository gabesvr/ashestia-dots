#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>
#include <glob.h>

static void get_brightness(int *br) {
    *br = 80;
    glob_t g;
    if (glob("/sys/class/backlight/*/brightness", 0, NULL, &g) == 0 && g.gl_pathc > 0) {
        FILE *f = fopen(g.gl_pathv[0], "r");
        if (f) {
            int cur = 0;
            if (fscanf(f, "%d", &cur) == 1) {
                char max_path[256];
                snprintf(max_path, sizeof(max_path), "%s", g.gl_pathv[0]);
                char *last_slash = strrchr(max_path, '/');
                if (last_slash) {
                    strcpy(last_slash, "/max_brightness");
                    FILE *fm = fopen(max_path, "r");
                    if (fm) {
                        int max_val = 100;
                        if (fscanf(fm, "%d", &max_val) == 1 && max_val > 0) {
                            *br = (int)(((double)cur / max_val) * 100.0 + 0.5);
                        }
                        fclose(fm);
                    }
                }
            }
            fclose(f);
        }
        globfree(&g);
    }
}

static void get_volume(double *vol, bool *muted) {
    *vol = 0.5;
    *muted = false;
    FILE *fp = popen("wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null", "r");
    if (fp) {
        char buf[128];
        if (fgets(buf, sizeof(buf), fp)) {
            char *vpos = strstr(buf, "Volume:");
            if (vpos) {
                double val = 0.0;
                if (sscanf(vpos, "Volume: %lf", &val) == 1) {
                    *vol = val;
                }
            }
            if (strstr(buf, "[MUTED]")) {
                *muted = true;
            }
        }
        pclose(fp);
    }
}

static void get_wifi(bool *wifi_on, char *ssid_out, size_t max_len) {
    *wifi_on = false;
    ssid_out[0] = '\0';

    FILE *fp = popen("nmcli radio wifi 2>/dev/null", "r");
    if (fp) {
        char buf[64];
        if (fgets(buf, sizeof(buf), fp)) {
            if (strstr(buf, "enabled")) {
                *wifi_on = true;
            }
        }
        pclose(fp);
    }

    if (*wifi_on) {
        FILE *fp2 = popen("nmcli -t -f active,ssid dev wifi 2>/dev/null", "r");
        if (fp2) {
            char line[256];
            while (fgets(line, sizeof(line), fp2)) {
                if (strncmp(line, "yes:", 4) == 0) {
                    char *nl = strchr(line + 4, '\n');
                    if (nl) *nl = '\0';
                    char *cr = strchr(line + 4, '\r');
                    if (cr) *cr = '\0';
                    snprintf(ssid_out, max_len, "%s", line + 4);
                    break;
                }
            }
            pclose(fp2);
        }
    }

    if (ssid_out[0] == '\0') {
        if (*wifi_on) {
            strncpy(ssid_out, "Connected", max_len - 1);
        } else {
            strncpy(ssid_out, "Off", max_len - 1);
        }
    }
}

static void get_bluetooth(bool *bt_on) {
    *bt_on = false;
    FILE *fp = popen("bluetoothctl show 2>/dev/null", "r");
    if (fp) {
        char buf[256];
        while (fgets(buf, sizeof(buf), fp)) {
            if (strstr(buf, "Powered: yes")) {
                *bt_on = true;
                break;
            }
        }
        pclose(fp);
    }
}

// Modo de energia (power-mode / tile de 3 posições): 0 = silencioso, 1 = equilibrado, 2 = desempenho.
// Lido direto do sysfs (sem processo a cada ciclo).
static void get_power(int *power) {
    *power = 1;
    FILE *fp = fopen("/sys/firmware/acpi/platform_profile", "r");
    if (fp) {
        char buf[32] = {0};
        if (fgets(buf, sizeof(buf), fp)) {
            if (strncmp(buf, "quiet", 5) == 0 || strncmp(buf, "low-power", 9) == 0) *power = 0;
            else if (strncmp(buf, "performance", 11) == 0) *power = 2;
        }
        fclose(fp);
    }
}

static void get_dnd(bool *dnd) {
    *dnd = false;
    FILE *fp = popen("makoctl mode 2>/dev/null", "r");
    if (fp) {
        char buf[128];
        if (fgets(buf, sizeof(buf), fp)) {
            if (strstr(buf, "dnd") || strstr(buf, "do-not-disturb")) {
                *dnd = true;
            }
        }
        pclose(fp);
    }
}

static void get_xwayland(bool *xw) {
    *xw = false;
    char path[512];
    snprintf(path, sizeof(path), "%s/.config/hypr/xwayland_state", getenv("HOME") ? getenv("HOME") : "");
    FILE *f = fopen(path, "r");
    if (f) {
        char buf[64];
        if (fgets(buf, sizeof(buf), f)) {
            if (strstr(buf, "true") || strstr(buf, "TRUE") || strstr(buf, "1")) {
                *xw = true;
            }
        }
        fclose(f);
    }
}

static void escape_json_string(const char *in, char *out, size_t max_len) {
    size_t j = 0;
    for (size_t i = 0; in[i] && j + 2 < max_len; ++i) {
        if (in[i] == '"' || in[i] == '\\') {
            out[j++] = '\\';
            out[j++] = in[i];
        } else if (in[i] == '\n' || in[i] == '\r') {
            continue;
        } else {
            out[j++] = in[i];
        }
    }
    out[j] = '\0';
}

int main(void) {
    // Unbuffered stdout for instantaneous IPC delivery
    setvbuf(stdout, NULL, _IONBF, 0);

    while (1) {
        double vol = 0.5;
        bool muted = false;
        int br = 80;
        bool wifi_on = false;
        char wifi_ssid[256] = {0};
        bool bt_on = false;
        int power = 1;
        bool dnd = false;
        bool xwayland = false;

        get_volume(&vol, &muted);
        get_brightness(&br);
        get_wifi(&wifi_on, wifi_ssid, sizeof(wifi_ssid));
        get_bluetooth(&bt_on);
        get_power(&power);
        get_dnd(&dnd);
        get_xwayland(&xwayland);

        char clean_ssid[256];
        escape_json_string(wifi_ssid, clean_ssid, sizeof(clean_ssid));

        printf("{\"vol\":%.2f,\"muted\":%s,\"br\":%d,\"wifi_on\":%s,\"wifi_ssid\":\"%s\",\"bt_on\":%s,\"power\":%d,\"dnd\":%s,\"xwayland\":%s}\n",
               vol,
               muted ? "true" : "false",
               br,
               wifi_on ? "true" : "false",
               clean_ssid,
               bt_on ? "true" : "false",
               power,
               dnd ? "true" : "false",
               xwayland ? "true" : "false");

        usleep(1200000); // 1.2s
    }

    return 0;
}
