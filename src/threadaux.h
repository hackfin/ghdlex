/** \file
 *
 * Thread auxiliaries (platform dependent)
 */

#ifdef __WIN32__
#include <windows.h>
// #include "property_protocol.h"
#define MUTEX HANDLE
// int mutex_init(MUTEX *m, void *p);
// int mutex_lock(MUTEX *m);
// int mutex_unlock(MUTEX *m);
#define USLEEP Sleep
#define MUTEX_LOCK   my_mutex_lock
#define MUTEX_UNLOCK my_mutex_unlock
#define MUTEX_INIT   my_mutex_init
#define MUTEX_EXIT   my_mutex_exit
#else
#include <pthread.h>
#define USLEEP          usleep
#define MUTEX           pthread_mutex_t
#define MUTEX_INIT(m)   pthread_mutex_init(m, NULL)
#define MUTEX_LOCK      pthread_mutex_lock
#define MUTEX_UNLOCK    pthread_mutex_unlock
#define MUTEX_EXIT      pthread_mutex_destroy
#endif


