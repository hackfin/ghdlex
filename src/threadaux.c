#include <windef.h>
#include "threadaux.h"

int my_mutex_init(MUTEX *mutex)
{
	*mutex = CreateMutex(NULL, FALSE, NULL);
	if (!*mutex) return -1;
	return 0;
}

int my_mutex_exit(MUTEX *mutex)
{
	CloseHandle(*mutex);
	return 0;
}

int my_mutex_lock(MUTEX *mutex)
{
	int error;

	int tries = 100;

	do {
		tries--;
		error = WaitForSingleObject(*mutex, 100);
	} while (error != WAIT_OBJECT_0 && tries);

	if (error != WAIT_OBJECT_0) return -1;

	return 0;
}

int my_mutex_unlock(MUTEX *mutex)
{
	if (!ReleaseMutex(*mutex)) return -1;
	return 0;
}

