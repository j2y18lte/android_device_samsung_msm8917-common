#include <errno.h>
#include <pthread.h>

extern "C" int pthread_mutex_destroy(pthread_mutex_t* mutex) {
    if (mutex == nullptr) {
        return EINVAL;
    }

    /*
     * Old Qualcomm camera blobs can destroy the same mutex twice.
     * Android 9 aborts the daemon on the second call.
     *
     * This library is injected only into mm-qcamera-daemon.
     */
    return 0;
}
