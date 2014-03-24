/** \file thread.c
 *
 * Thread demo for GHDL C simulator interface
 * (c) 2011, Martin Strubel <hackfin@section5.ch>
 *
 * Compile with -DUSE_NETPP if you want to use the netpp server
 * interface.
 *
 */

#ifdef __linux__
#include <pthread.h>
#endif
#include <stdio.h>
#include <unistd.h>

#include "ghpi.h"
#include "example.h"
#include "fifo.h"

#ifdef USE_NETPP
// #include "example.h"
#include "slave.h"
#include "netpp.h"
#else
#define DCERR_COMM_TIMEOUT -1
#endif

#define FIFO_SIZE   32*1024


#ifdef USE_NETPP

int init_backend(void)
{
	register_proplist(g_devices, g_ndevices);
	init_registermap();
	return 0;
}

extern TOKEN g_t_fifobuf;
extern TOKEN g_t_fifo_infill;
extern TOKEN g_t_fifo_outfill;
/** Legacy global FIFO */
struct duplexfifo_t g_dfifo;

#ifdef __WIN32__
#define THREAD_RETURN DWORD
#define THREAD_DECO   WINAPI
#else
#define THREAD_RETURN void *
#define THREAD_DECO
#endif

THREAD_RETURN THREAD_DECO fifo_thread(void *arg)
{
	PropertyDesc *fifo;
	int error;
	char *argv[] = {
		"", (char *) arg
	};

	error = init_backend();
	if (error < 0) return 0;

	// HACK:
	// The FIFO buffer is using CUSTOM handlers. For the global FIFO,
	// we need to pre-initialize them:
	fifo = getProperty_ByToken(g_t_fifobuf); // Obtain descriptor
	fifo->access.custom.p = &g_dfifo;      // Store FIFO handle

	fifo = getProperty_ByToken(g_t_fifo_infill); // Obtain descriptor
	fifo->access.custom.p = &g_dfifo;      // Store FIFO handle

	fifo = getProperty_ByToken(g_t_fifo_outfill); // Obtain descriptor
	fifo->access.custom.p = &g_dfifo;      // Store FIFO handle


	error = start_server(1, argv);
	if (error < 0) return 0;
	return (THREAD_RETURN) 1;
}

#else

enum {
	FROM_SIM,
	TO_SIM
};

void *fifo_thread(void *arg)
{
	int n;
	int error;

	static
	unsigned char buf[FIFO_SIZE];

	char flags[6];

	static
	unsigned char seq[] = "Don't you wanna know what's cool?";

	int i = 3;

	Fifo *fifos = (Fifo *) arg;

	while (i--) {
		usleep(1000);
		fifo_status(&fifos[TO_SIM], FIFO_WRITE, 1, flags);

		if (flags[TXF] == HIGH) {
			n = fifo_write(&fifos[TO_SIM], seq, sizeof(seq));
			if (n > 0) {
				error = fifo_blocking_read(&fifos[FROM_SIM], buf, n);
				if (error < 0) {
					printf("Timed out\n");
				} else {
					printf("Return %d bytes from Simulator:\n", n);
					printf("%s\n", buf);
					hexdump((char *) buf, n);
				}
			}
		} else {
			printf("FIFO to Sim not ready. Skipping.\n");
		}
#ifdef USE_NETPP
		usleep(g_timeout);
#endif
	}
	// Send TERMINATE command:
	// This is a bit dirty. We have to send two bytes, because we're
	// polling the RXAE (almost empty) flag from the VHDL code.
	// If just one byte resides in the FIFO, only the RXE flag is high.
	n = fifo_write(&fifos[TO_SIM], (unsigned char *) "\377\000", 2);

	return 0;
}


#endif

#ifdef __WIN32__
HANDLE g_thread;
#else
pthread_t g_thread;
#endif

/* XXX Legacy. Will leave in future */

#include "netppwrap.h"

int sim_fifo_thread_init(struct ghdl_string *str, int wordsize)
{
	int error;

	netpp_root_init("Legacy_Fifo_Thread");


	error = fifo_init(&g_dfifo.out, FIFO_SIZE, wordsize);
	if (error < 0) return error;
	error = fifo_init(&g_dfifo.in, FIFO_SIZE, wordsize);
	if (error < 0) return error;

#ifdef __WIN32__
	DWORD thid;
	g_thread = CreateThread(NULL, 0x20000, fifo_thread, (PVOID) &g_dfifo,
		0, &thid);
	if (!g_thread) {
		error = -1;
		printf("Failed to create thread\n");
	}
#else

#ifdef USE_NETPP
	error = pthread_create(&g_thread, NULL, &fifo_thread, NULL);
#else
	error = pthread_create(&g_thread, NULL, &fifo_thread, &g_dfifo);
#endif
#endif
	if (error < 0) return error;
	return 0;
}


void fifo_thread_exit()
{
	int error;
#ifdef __WIN32__
	error = TerminateThread(g_thread, -1);
	if (error == 0) { printf("Failed to terminate thread\n"); }
#else
	error = pthread_cancel(g_thread);
#endif
	fifo_exit(&g_dfifo.out);
	fifo_exit(&g_dfifo.in);
}
