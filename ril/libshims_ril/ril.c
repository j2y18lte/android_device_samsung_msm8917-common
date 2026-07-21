#define LOG_TAG "libshims_ril"

#include <cutils/properties.h>
#include <log/log.h>

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/statfs.h>
#include <sys/types.h>
#include <unistd.h>

/*
 * Samsung/J415 compatibility shim for LineageOS 16.
 *
 * The signatures below match the Samsung RIL ABI used by the J415
 * libsec-ril blobs. The simple POSIX wrappers are suitable for bring-up.
 */

int64_t _ZN14TrafficControl15connectToServeeEb(uint8_t value) {
    (void)value;
    return -1;
}

int64_t RIL_GetSettingValue(char *key, char *value) {
    if (key == NULL || value == NULL) {
        errno = EINVAL;
        return -1;
    }

    property_get(key, value, "");
    return 0;
}

int64_t RIL_GetFd(char *path, int flags, int mode) {
    if (path == NULL) {
        errno = EINVAL;
        return -1;
    }

    return open(path, flags, (mode_t)mode);
}

int64_t RIL_Execute(char *command) {
    if (command == NULL) {
        errno = EINVAL;
        return -1;
    }

    return system(command);
}

int64_t RIL_Unlink(char *path) {
    if (path == NULL) {
        errno = EINVAL;
        return -1;
    }

    return unlink(path);
}

int64_t RIL_Mkdir(char *path, int permission) {
    if (path == NULL) {
        errno = EINVAL;
        return -1;
    }

    return mkdir(path, (mode_t)permission);
}

int64_t RIL_Chmod(char *path, int permission) {
    if (path == NULL) {
        errno = EINVAL;
        return -1;
    }

    return chmod(path, (mode_t)permission);
}

int64_t RIL_Chown(char *path, int user, int group) {
    if (path == NULL) {
        errno = EINVAL;
        return -1;
    }

    return chown(path, (uid_t)user, (gid_t)group);
}

int64_t RIL_Stat(char *path) {
    if (path == NULL) {
        errno = EINVAL;
        return -1;
    }

    return access(path, F_OK);
}

int64_t RIL_Rename(char *path, char *new_path) {
    if (path == NULL || new_path == NULL) {
        errno = EINVAL;
        return -1;
    }

    return rename(path, new_path);
}

int64_t RIL_StatFs(char *path, struct statfs *buffer) {
    if (path == NULL || buffer == NULL) {
        errno = EINVAL;
        return -1;
    }

    return statfs(path, buffer);
}

int64_t RIL_IoCtl(int fd, int64_t request, int *argument) {
    return ioctl(fd, (unsigned long)request, argument);
}

int64_t RIL_GetFdWithSetAttr(char *path, int flags, int mode, int *result_fd) {
    int fd;

    if (path == NULL) {
        errno = EINVAL;
        return -1;
    }

    fd = open(path, flags, (mode_t)mode);
    if (result_fd != NULL) {
        *result_fd = fd;
    }

    return fd;
}

void RIL_LoadApnProfFromDB(char *profile, void *context) {
    (void)profile;
    (void)context;

    /*
     * No-op for initial RIL bring-up.
     * Mobile-data/APN handling can be revisited after SIM and radio power work.
     */
}