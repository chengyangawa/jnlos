#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/utsname.h>
#include <sys/sysinfo.h>

#define COLOR_BLUE "\033[1;34m"
#define COLOR_GREEN "\033[1;32m"
#define COLOR_CYAN "\033[1;36m"
#define COLOR_GRAY "\033[1;30m"
#define COLOR_RESET "\033[0m"

static char* read_line(const char* path, char* buf, size_t bufsz) {
    FILE* f = fopen(path, "r");
    if (!f) return NULL;
    if (!fgets(buf, bufsz, f)) { fclose(f); return NULL; }
    fclose(f);
    size_t len = strlen(buf);
    while (len > 0 && (buf[len-1] == '\n' || buf[len-1] == '\r')) buf[--len] = '\0';
    return buf;
}

static char* get_value_after_colon(const char* line) {
    const char* p = strchr(line, ':');
    if (!p) return (char*)line;
    p++;
    while (*p == ' ') p++;
    return (char*)p;
}

static void print_logo(void) {
    printf(COLOR_BLUE
        "       ______ _   _  _       \n"
        "      |  ____| \\ | || |      \n"
        "      | |__  |  \\| || |      \n"
        "      |  __| | . ` || |      \n"
        "      | |____| |\\  || |____  \n"
        "      |______|_| \\_||______| \n"
        "                            \n" COLOR_RESET);
}

int main(void) {
    char buf[512];
    struct utsname uts;
    struct sysinfo si;

    uname(&uts);
    sysinfo(&si);

    char version[64] = "unknown";
    read_line("/etc/jnl-os-version", version, sizeof(version));

    char hostname[256];
    gethostname(hostname, sizeof(hostname));

    char cpu_model[256] = "unknown";
    FILE* cpuinfo = fopen("/proc/cpuinfo", "r");
    if (cpuinfo) {
        while (fgets(buf, sizeof(buf), cpuinfo)) {
            if (strncmp(buf, "model name", 10) == 0) {
                strncpy(cpu_model, get_value_after_colon(buf), sizeof(cpu_model)-1);
                break;
            }
        }
        fclose(cpuinfo);
    }

    char total_mem[64];
    long mb = (si.totalram * si.mem_unit) / (1024*1024);
    if (mb >= 1024) {
        snprintf(total_mem, sizeof(total_mem), "%.1f GB", (float)mb / 1024.0);
    } else {
        snprintf(total_mem, sizeof(total_mem), "%ld MB", mb);
    }

    int cpus = get_nprocs();

    char shell_env[256] = "unknown";
    char* sh = getenv("SHELL");
    if (sh) strncpy(shell_env, sh, sizeof(shell_env)-1);

    char user[256] = "unknown";
    char* u = getenv("USER");
    if (u) strncpy(user, u, sizeof(user)-1);

    char de[256] = "KDE Plasma 6";
    char* d = getenv("XDG_CURRENT_DESKTOP");
    if (d) strncpy(de, d, sizeof(de)-1);

    char kernel_ver[256];
    snprintf(kernel_ver, sizeof(kernel_ver), "%s %s", uts.sysname, uts.release);

    print_logo();

    printf(COLOR_GREEN "  Java Net Lava OS" COLOR_RESET " %s\n", version);
    printf(COLOR_GRAY "  --------------------" COLOR_RESET "\n");
    printf(COLOR_CYAN "  OS: " COLOR_RESET "Java Net Lava OS %s\n", version);
    printf(COLOR_CYAN "  Host: " COLOR_RESET "%s\n", hostname);
    printf(COLOR_CYAN "  Kernel: " COLOR_RESET "%s\n", kernel_ver);
    printf(COLOR_CYAN "  Uptime: " COLOR_RESET "%ld days, %ld hours, %ld mins\n",
           si.uptime / 86400, (si.uptime % 86400) / 3600, (si.uptime % 3600) / 60);
    printf(COLOR_CYAN "  Shell: " COLOR_RESET "%s\n", shell_env);
    printf(COLOR_CYAN "  DE: " COLOR_RESET "%s\n", de);
    printf(COLOR_CYAN "  CPU: " COLOR_RESET "%s (%d cores)\n", cpu_model, cpus);
    printf(COLOR_CYAN "  Memory: " COLOR_RESET "%s\n", total_mem);
    printf(COLOR_CYAN "  User: " COLOR_RESET "%s\n", user);
    printf(COLOR_GRAY "\n  © 2026 FEPT" COLOR_RESET "\n");

    return 0;
}
