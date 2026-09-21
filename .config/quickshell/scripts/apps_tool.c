#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <unistd.h>
#include <ctype.h>
#include <stdbool.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/wait.h>

#define MAX_APPS 256
#define PATH_MAX_LEN 1024

typedef struct {
    char id[128];
    char desktop_file[128];
    char name[128];
    char exec[256];
    char icon[128];
    char icon_path[512];
    char comment[256];
    char categories[256];
    bool terminal;
} AppEntry;

static const char* THEMES[] = {
    "WhiteSur-dark",
    "WhiteSur",
    "hicolor",
    "breeze-dark",
    "breeze",
    "Adwaita",
    NULL
};

static const char* SUBDIRS[] = {
    "apps/scalable",
    "scalable/apps",
    "apps/512x512",
    "apps/256x256",
    "apps/128x128",
    "apps/64x64",
    "apps/48x48",
    "apps/32x32",
    "apps",
    "categories/scalable",
    "categories/48x48",
    "categories/32",
    "devices/scalable",
    "places/scalable",
    "status/scalable",
    "512x512/apps",
    "256x256/apps",
    "128x128/apps",
    "64x64/apps",
    "48x48/apps",
    "32x32/apps",
    NULL
};

static const char* EXTS[] = { ".svg", ".png", ".xpm", "", NULL };

static void trim_trailing_newline(char* str) {
    size_t len = strlen(str);
    while (len > 0 && (str[len - 1] == '\n' || str[len - 1] == '\r' || isspace((unsigned char)str[len - 1]))) {
        str[--len] = '\0';
    }
}

static void clean_exec(const char* in, char* out, size_t max_len) {
    size_t j = 0;
    size_t len = strlen(in);
    for (size_t i = 0; i < len && j + 1 < max_len; i++) {
        if (in[i] == '%' && i + 1 < len && isalpha((unsigned char)in[i + 1])) {
            i++; // skip %u, %f, etc.
            continue;
        }
        out[j++] = in[i];
    }
    out[j] = '\0';
    trim_trailing_newline(out);
}

static void find_icon_path(const char* icon_name, char* out_path, size_t max_len) {
    out_path[0] = '\0';
    if (!icon_name || !*icon_name) return;

    if (icon_name[0] == '/' && access(icon_name, R_OK) == 0) {
        snprintf(out_path, max_len, "%s", icon_name);
        return;
    }

    // Variations
    char base[128];
    strncpy(base, icon_name, sizeof(base) - 1);
    base[sizeof(base) - 1] = '\0';
    char* dot = strrchr(base, '.');
    if (dot) *dot = '\0';

    char lower[128];
    strncpy(lower, base, sizeof(lower) - 1);
    lower[sizeof(lower) - 1] = '\0';
    for (int i = 0; lower[i]; i++) lower[i] = tolower((unsigned char)lower[i]);

    // Reverse domain last part (e.g. org.xfce.thunar -> thunar)
    char last_part[128] = "";
    char* rdot = strrchr(base, '.');
    if (rdot && *(rdot + 1)) {
        strncpy(last_part, rdot + 1, sizeof(last_part) - 1);
        for (int i = 0; last_part[i]; i++) last_part[i] = tolower((unsigned char)last_part[i]);
    }

    const char* names[6];
    int nnames = 0;
    names[nnames++] = icon_name;
    if (strcmp(base, icon_name) != 0) names[nnames++] = base;
    if (strcmp(lower, base) != 0) names[nnames++] = lower;
    if (last_part[0] && strcmp(last_part, lower) != 0) names[nnames++] = last_part;

    const char* home = getenv("HOME");
    char user_icons[512] = "";
    if (home) snprintf(user_icons, sizeof(user_icons), "%s/.local/share/icons", home);

    const char* roots[3];
    int nroots = 0;
    roots[nroots++] = "/usr/share/icons";
    if (user_icons[0]) roots[nroots++] = user_icons;

    // Search themes
    for (int t = 0; THEMES[t]; t++) {
        for (int r = 0; r < nroots; r++) {
            for (int s = 0; SUBDIRS[s]; s++) {
                char test_dir[PATH_MAX_LEN];
                snprintf(test_dir, sizeof(test_dir), "%s/%s/%s", roots[r], THEMES[t], SUBDIRS[s]);
                for (int n = 0; n < nnames; n++) {
                    for (int e = 0; EXTS[e]; e++) {
                        char candidate[PATH_MAX_LEN];
                        snprintf(candidate, sizeof(candidate), "%s/%s%s", test_dir, names[n], EXTS[e]);
                        if (access(candidate, R_OK) == 0) {
                            snprintf(out_path, max_len, "%s", candidate);
                            return;
                        }
                    }
                }
            }
        }
    }

    // Pixmaps fallback
    for (int n = 0; n < nnames; n++) {
        for (int e = 0; EXTS[e]; e++) {
            char candidate[PATH_MAX_LEN];
            snprintf(candidate, sizeof(candidate), "/usr/share/pixmaps/%s%s", names[n], EXTS[e]);
            if (access(candidate, R_OK) == 0) {
                snprintf(out_path, max_len, "%s", candidate);
                return;
            }
        }
    }
}

static void escape_json(const char* in, char* out, size_t max_len) {
    size_t j = 0;
    for (size_t i = 0; in[i] && j + 2 < max_len; i++) {
        if (in[i] == '"' || in[i] == '\\') {
            out[j++] = '\\';
            out[j++] = in[i];
        } else if (in[i] == '\n') {
            out[j++] = '\\';
            out[j++] = 'n';
        } else if (in[i] == '\r') {
            continue;
        } else if (in[i] == '\t') {
            out[j++] = '\\';
            out[j++] = 't';
        } else {
            out[j++] = in[i];
        }
    }
    out[j] = '\0';
}

static int compare_apps(const void* a, const void* b) {
    const AppEntry* ea = (const AppEntry*)a;
    const AppEntry* eb = (const AppEntry*)b;
    return strcasecmp(ea->name, eb->name);
}

static void list_apps(void) {
    AppEntry apps[MAX_APPS];
    int count = 0;

    const char* home = getenv("HOME");
    char user_apps[512] = "";
    if (home) snprintf(user_apps, sizeof(user_apps), "%s/.local/share/applications", home);

    const char* dirs[3];
    int ndirs = 0;
    if (user_apps[0]) dirs[ndirs++] = user_apps;
    dirs[ndirs++] = "/usr/share/applications";

    char seen[MAX_APPS][128];
    int seen_count = 0;

    for (int d = 0; d < ndirs; d++) {
        DIR* dp = opendir(dirs[d]);
        if (!dp) continue;
        struct dirent* ep;
        while ((ep = readdir(dp)) != NULL && count < MAX_APPS) {
            char* ext = strrchr(ep->d_name, '.');
            if (!ext || strcmp(ext, ".desktop") != 0) continue;

            // Check if seen
            bool already_seen = false;
            for (int s = 0; s < seen_count; s++) {
                if (strcmp(seen[s], ep->d_name) == 0) {
                    already_seen = true;
                    break;
                }
            }
            if (already_seen) continue;
            if (seen_count < MAX_APPS) {
                strncpy(seen[seen_count++], ep->d_name, 127);
            }

            char file_path[PATH_MAX_LEN];
            snprintf(file_path, sizeof(file_path), "%s/%s", dirs[d], ep->d_name);

            FILE* fp = fopen(file_path, "r");
            if (!fp) continue;

            char line[1024];
            bool in_entry = false;
            bool no_display = false;
            bool is_terminal = false;
            char name[128] = "";
            char exec_raw[256] = "";
            char icon[128] = "";
            char comment[256] = "";
            char categories[256] = "";

            while (fgets(line, sizeof(line), fp)) {
                trim_trailing_newline(line);
                if (line[0] == '[') {
                    if (strcmp(line, "[Desktop Entry]") == 0) in_entry = true;
                    else if (in_entry) break;
                    continue;
                }
                if (!in_entry) continue;

                if (strncmp(line, "NoDisplay=", 10) == 0) {
                    if (strcasecmp(line + 10, "true") == 0) no_display = true;
                } else if (strncmp(line, "Terminal=", 9) == 0) {
                    if (strcasecmp(line + 9, "true") == 0) is_terminal = true;
                } else if (strncmp(line, "Name=", 5) == 0 && !name[0]) {
                    strncpy(name, line + 5, sizeof(name) - 1);
                } else if (strncmp(line, "Exec=", 5) == 0 && !exec_raw[0]) {
                    strncpy(exec_raw, line + 5, sizeof(exec_raw) - 1);
                } else if (strncmp(line, "Icon=", 5) == 0 && !icon[0]) {
                    strncpy(icon, line + 5, sizeof(icon) - 1);
                } else if (strncmp(line, "Comment=", 8) == 0 && !comment[0]) {
                    strncpy(comment, line + 8, sizeof(comment) - 1);
                } else if (strncmp(line, "Categories=", 11) == 0 && !categories[0]) {
                    strncpy(categories, line + 11, sizeof(categories) - 1);
                }
            }
            fclose(fp);

            if (no_display || !name[0] || !exec_raw[0]) continue;

            AppEntry* e = &apps[count++];
            strncpy(e->desktop_file, ep->d_name, sizeof(e->desktop_file) - 1);
            strncpy(e->id, ep->d_name, sizeof(e->id) - 1);
            char* dot_id = strrchr(e->id, '.');
            if (dot_id) *dot_id = '\0';

            strncpy(e->name, name, sizeof(e->name) - 1);
            clean_exec(exec_raw, e->exec, sizeof(e->exec));
            strncpy(e->icon, icon, sizeof(e->icon) - 1);
            strncpy(e->comment, comment, sizeof(e->comment) - 1);
            strncpy(e->categories, categories, sizeof(e->categories) - 1);
            e->terminal = is_terminal;
            find_icon_path(icon, e->icon_path, sizeof(e->icon_path));
        }
        closedir(dp);
    }

    qsort(apps, count, sizeof(AppEntry), compare_apps);

    // Print JSON
    fputs("[", stdout);
    for (int i = 0; i < count; i++) {
        char esc_id[256], esc_df[256], esc_name[256], esc_exec[512], esc_icon[256], esc_ipath[1024], esc_comm[512], esc_cat[512];
        escape_json(apps[i].id, esc_id, sizeof(esc_id));
        escape_json(apps[i].desktop_file, esc_df, sizeof(esc_df));
        escape_json(apps[i].name, esc_name, sizeof(esc_name));
        escape_json(apps[i].exec, esc_exec, sizeof(esc_exec));
        escape_json(apps[i].icon, esc_icon, sizeof(esc_icon));
        escape_json(apps[i].icon_path, esc_ipath, sizeof(esc_ipath));
        escape_json(apps[i].comment, esc_comm, sizeof(esc_comm));
        escape_json(apps[i].categories, esc_cat, sizeof(esc_cat));

        printf("%s{\"id\":\"%s\",\"desktop_file\":\"%s\",\"name\":\"%s\",\"exec\":\"%s\",\"icon\":\"%s\",\"icon_path\":\"%s\",\"comment\":\"%s\",\"categories\":\"%s\",\"terminal\":%s}",
            (i > 0 ? "," : ""),
            esc_id, esc_df, esc_name, esc_exec, esc_icon, esc_ipath, esc_comm, esc_cat,
            apps[i].terminal ? "true" : "false"
        );
    }
    puts("]");
}

static void clean_launch_env(void) {
    unsetenv("LD_PRELOAD");
    unsetenv("MALLOC_CONF");
    unsetenv("MALLOC_ARENA_MAX");
    unsetenv("MALLOC_TRIM_THRESHOLD_");
    unsetenv("MALLOC_MMAP_THRESHOLD_");
}

static void launch_app(const char* identifier, const char* fallback_exec) {
    if (!identifier || !*identifier) return;

    clean_launch_env();

    char desktop_file[256] = "";
    char clean_name[256] = "";
    if (strstr(identifier, ".desktop")) {
        snprintf(desktop_file, sizeof(desktop_file), "%s", identifier);
        strncpy(clean_name, identifier, sizeof(clean_name) - 1);
        char* d = strstr(clean_name, ".desktop");
        if (d) *d = '\0';
    } else {
        snprintf(desktop_file, sizeof(desktop_file), "%s.desktop", identifier);
        strncpy(clean_name, identifier, sizeof(clean_name) - 1);
    }

    char sys_path[512], user_path[512];
    snprintf(sys_path, sizeof(sys_path), "/usr/share/applications/%s", desktop_file);
    const char* home = getenv("HOME");
    snprintf(user_path, sizeof(user_path), "%s/.local/share/applications/%s", home ? home : "", desktop_file);

    char launch_cmd[1024];
    if (fallback_exec && *fallback_exec) {
        snprintf(launch_cmd, sizeof(launch_cmd), 
            "gtk-launch %s 2>/dev/null || gtk-launch %s 2>/dev/null || gio launch /usr/share/applications/%s 2>/dev/null || %s",
            desktop_file, clean_name, desktop_file, fallback_exec);
    } else {
        snprintf(launch_cmd, sizeof(launch_cmd), 
            "gtk-launch %s 2>/dev/null || gtk-launch %s 2>/dev/null || gio launch /usr/share/applications/%s 2>/dev/null || %s",
            desktop_file, clean_name, desktop_file, clean_name);
    }

    // Try hyprctl dispatch hl.dsp.exec_cmd with Lua raw string [=[...]=]
    // Using fork/waitpid directly instead of system() avoids shell quote escaping pitfalls
    char lua_cmd[2048];
    snprintf(lua_cmd, sizeof(lua_cmd), "hl.dsp.exec_cmd([=[%s]=])", launch_cmd);
    pid_t hpid = fork();
    if (hpid == 0) {
        int devnull = open("/dev/null", O_WRONLY);
        if (devnull >= 0) {
            dup2(devnull, STDOUT_FILENO);
            dup2(devnull, STDERR_FILENO);
            close(devnull);
        }
        execlp("hyprctl", "hyprctl", "dispatch", lua_cmd, (char*)NULL);
        _exit(1);
    }
    if (hpid > 0) {
        int status = 0;
        waitpid(hpid, &status, 0);
        if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
            printf("{\"status\":\"ok\",\"launched\":\"%s\",\"method\":\"hyprctl\"}\n", identifier);
            return;
        }
    }

    // Completely detached double-fork fallback with /dev/null redirection
    // and systemd-run to decouple from quickshell.service cgroup
    int null_fd = open("/dev/null", O_RDWR);
    pid_t pid = fork();
    if (pid == 0) {
        if (fork() != 0) _exit(0);
        setsid();
        if (null_fd >= 0) {
            dup2(null_fd, STDIN_FILENO);
            dup2(null_fd, STDOUT_FILENO);
            dup2(null_fd, STDERR_FILENO);
            close(null_fd);
        }
        for (int fd = 3; fd < 256; fd++) close(fd);
        clean_launch_env();
        execlp("systemd-run", "systemd-run", "--user", "--slice=app.slice", "/bin/sh", "-c", launch_cmd, (char*)NULL);
        execl("/bin/sh", "sh", "-c", launch_cmd, (char*)NULL);
        _exit(1);
    }
    if (null_fd >= 0) close(null_fd);
    waitpid(pid, NULL, 0);

    printf("{\"status\":\"ok\",\"launched\":\"%s\",\"method\":\"fork\"}\n", identifier);
}

int main(int argc, char* argv[]) {
    if (argc < 2 || strcmp(argv[1], "list") == 0) {
        list_apps();
        return 0;
    }
    if (strcmp(argv[1], "launch") == 0 && argc >= 3) {
        const char* fallback = (argc >= 4) ? argv[3] : NULL;
        launch_app(argv[2], fallback);
        return 0;
    }
    list_apps();
    return 0;
}
