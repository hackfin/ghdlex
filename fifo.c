/** \file fifo.c
 *
 * Stupid software FIFO for test purposes.
 * Update: not so stupid anymore.
 *
 * (c) 2009 Martin Strubel <hackfin@section5.ch>
 *
 * Changes:
 *  09/2011 Martin Strubel <hackfin@section5.ch>
 *     Implemented a first-fall-through FIFO for the GHDL simulator
 *     interface.
 *  10/2012 Martin Strubel <hackfin@section5.ch>
 *     Added 16 bit option (wordsize parameter)
 *
 * The first version of this FIFO exhibited a pitfall: When burst
 * reading, the FIFO empty condition can not be handled in time.
 * Therefore, another flag RXAE is introduced. This flag goes
 * low when there is only one byte left to read from the FIFO.
 * Likewise, there is a TXAF flag. A sane VHDL implementation should
 * really check for both flags (we don't, in the provided example).
 * Things can go wrong if there is only ONE byte written to an empty FIFO.
 *
 */

#include <pthread.h>
#include <unistd.h> // usleep()
#include <stdio.h>
#include <stdlib.h>
#include "fifo.h"
#include "ghpi.h"
#include "netpp.h"
#include "netppwrap.h"
#include "example.h"

/* Global FIFO struct for legacy support */
extern struct duplexfifo_t g_dfifo;

int fifo_init(Fifo *f, unsigned short size, unsigned short wordsize)
{
	int error;
	f->size = size;
	switch (wordsize) {
		case 1:
			f->tologic = bytes_to_logic;
			f->fromlogic = logic_to_bytes;
			break;
		case 2:
			f->tologic = words_to_logic;
			f->fromlogic = logic_to_words;
			break;
		default:
			fprintf(stderr, "Unsupported word size\n");
			return -1;
	}
	printf("Initialize FIFO with word width of %d bits\n", wordsize * 8);
	error = pthread_mutex_init(&f->mutex, NULL);
	if (error < 0) return error;
	f->buf = (unsigned char*) malloc(size * wordsize);
	if (!f->buf) return -1;
	f->head = 0;
	f->tail = 0;
	f->fill = 0;
	f->ovr = LOW;
	f->unr = LOW;
	return 0;
}

void fifo_exit(Fifo *f)
{
	pthread_mutex_destroy(&f->mutex);
	free(f->buf);
}

int fifo_getbyte(Fifo *f, unsigned char *byte)
{
	if (f->fill == 0) {
		return 0;
	}
	*byte = f->buf[f->tail];
	return 1;
}

static
int fifo_get(Fifo *f, unsigned char *dst, int n)
{
	unsigned short p;

	int ret = f->fill;

	p = f->tail;
	do {
		*dst++ = f->buf[p++];
		p %= f->size;
		n--;
	} while (p != f->head && n > 0);

	return ret;
}

int fifo_advance(Fifo *f, int n)
{
	int ret = 0;

	pthread_mutex_lock(&f->mutex);

	if (f->fill == 0) {
		f->unr = HIGH;
		fprintf(stderr, "Error: FIFO underrun (advance)\n");
	} else {
		f->tail += n; f->tail %= f->size;
		f->fill -= n;
		ret = 1;
	}

	pthread_mutex_unlock(&f->mutex);

	return ret;
}

int fifo_read(Fifo *f, unsigned char *byte, unsigned short n)
{
	int i = 0;
	if (n == 0) return 0;

	pthread_mutex_lock(&f->mutex);

	if (f->fill == 0) {
		f->unr = HIGH;
		fprintf(stderr, "Error: FIFO underrun (read)\n");
		i = 0;
	} else {
		do {
			*byte++ = f->buf[f->tail++];
			f->tail %= f->size;
			n--; i++;
		} while (f->tail != f->head && n > 0);
		f->fill -= i;
	}

	pthread_mutex_unlock(&f->mutex);

	return i;
}

int fifo_fill(Fifo *f)
{
	unsigned short fill;
	pthread_mutex_lock(&f->mutex);
	fill = f->fill;
	pthread_mutex_unlock(&f->mutex);
	return fill;
}

int fifo_status(Fifo *f, char which, int width, char *flags)
{
	pthread_mutex_lock(&f->mutex);

	if (which == FIFO_WRITE) {
		if (f->fill >= f->size - width) {
			flags[TXF] = HIGH; flags[TXAF] = LOW;
			if (f->fill == f->size) flags[TXF] = LOW;
		} else {
			flags[TXF] = HIGH; flags[TXAF] = HIGH;
		}
	} else {
		if (f->fill <= width) {
			flags[RXE] = HIGH; flags[RXAE] = LOW;
			if (f->fill == 0)  flags[RXE] = LOW;
		} else {
			flags[RXE] = HIGH; flags[RXAE] = HIGH;
		}
	}
	pthread_mutex_unlock(&f->mutex);
	return 1;
}

void fifo_reset(Fifo *f)
{
	f->unr = LOW;
	f->ovr = LOW;
}

int fifo_write(Fifo *f, const unsigned char *byte, unsigned short n)
{
	int i = 0;

	if (n == 0) return 0;

	pthread_mutex_lock(&f->mutex);

	if (f->fill == f->size) {
		f->ovr = HIGH;
		fprintf(stderr, "Error: FIFO overrun\n");
		i = 0;
	} else {
		do {
			f->buf[f->head++] = *byte++;
			f->head %= f->size;
			n--; i++;
		} while (f->tail != f->head && n > 0);

		f->fill += i;
	}

	pthread_mutex_unlock(&f->mutex);

	return i;
}

/** This is the FIFO filler/emptier
 * 
 * ..for the FALLTHROUGH FIFO type.
 *
 * \param flag   0: read (set out), 1: write (get in)
 *
 *
 */

void fifo_pump(struct duplexfifo_t *df, struct fat_pointer *data, char *flag)
{
// 	printf("in: %p, out: %p, flag: %x\n", in, out, flag);
	static
	unsigned char valuebytes[32];
	unsigned char rx, tx;
	short n;
	short nbits = data->bounds->len;
	short nbytes = (nbits + 7) >> 3;

	Fifo *fifo_in, *fifo_out;

	fifo_in = &df->in; fifo_out = &df->out;

	// Guard maximum chunk size:
	if (nbytes > sizeof(valuebytes)) {
		nbytes = sizeof(valuebytes);
		fprintf(stderr, "Warning: FIFO request size truncated\n");
	}


	// Buffer action flags:
	rx = flag[RXE] == HIGH ? 1 : 0;
	tx = flag[TXF] == HIGH ? 1 : 0;

	// Check W1C error flags:
	if (flag[OVR] == HIGH) fifo_out->ovr = LOW;
	if (flag[UNR] == HIGH) fifo_in->unr = LOW;
	
	// Do we write?
	if (tx) {
		fifo_in->fromlogic(data->base, nbytes, valuebytes);
		fifo_write(fifo_in, valuebytes, nbytes);
		// printf("S -> H fill: %d\n", fifo_in->fill);
	}

	// Did we read advance?
	if (rx) {
		// printf("S <- H fill: %d\n", fifo_out->fill);
		fifo_advance(fifo_out, nbytes);
	}

	// Query status and set flags
	fifo_status(fifo_in, FIFO_WRITE, nbytes, flag);
	fifo_status(fifo_out, FIFO_READ, nbytes, flag);

	if (flag[RXE] == HIGH) { // We do at least have 'nbytes' bytes in the FIFO
		n = fifo_get(fifo_out, valuebytes, nbytes);
		fifo_out->tologic(data->base, nbytes, valuebytes);
		// printf("n: %d: %02x %02x\n", n, valuebytes[0], valuebytes[1]);
	} else {
		fill_slv(data->base, nbits, UNDEFINED);
	}

	// Return OVR/UNR flags
	flag[OVR] = fifo_in->ovr;
	flag[UNR] = fifo_out->unr;
}

void sim_fifo_rxtx(duplexfifo_t_ghdl *fifo,
	struct fat_pointer *data, char *flag)
{
	DuplexFifo *f = (DuplexFifo *) fifo[0];
	fifo_pump(f, data, flag);
}

void sim_fifo_io(struct fat_pointer *data, char *flag)
{
	fifo_pump(&g_dfifo, data, flag);
}

duplexfifo_t_ghdl sim_fifo_new_wrapped(string_ghdl name, integer_ghdl size,
	integer_ghdl wordsize)
{
	char propname[32];
	int error;
	struct duplexfifo_t *df =
		(struct duplexfifo_t *) malloc(sizeof(struct duplexfifo_t));
	ghdlname_to_propname(name->base, propname, sizeof(propname));
	printf("Reserved FIFO '%s' with word size %d, size 0x%x\n", propname,
		wordsize, size * sizeof(uint16_t));

	error = fifo_init(&df->in, size, wordsize);
	if (error < 0) return NULL;
	error = fifo_init(&df->out, size, wordsize);
	if (error < 0) return NULL;

	netpp_root_init("FIFOwrapper");
	register_fifo(df, propname);
	return (duplexfifo_t_ghdl) df;
}

void_ghdl sim_fifo_del(duplexfifo_t_ghdl *fifo)
{
	DuplexFifo *f = fifo[0];
	fifo_exit(&f->out);
	fifo_exit(&f->in);
}

////////////////////////////////////////////////////////////////////////////
// Auxiliary, blocking reads

int fifo_blocking_read(Fifo *f, unsigned char *buf, unsigned int n)
{
	int i;
	int retry = 5;

	while (n > 0) {
		while (!fifo_fill(f)) {
			usleep(g_timeout);
			retry--;
			if (retry == 0) return DCERR_COMM_TIMEOUT;
		}
		i = fifo_read(f, buf, n);
		buf += i; n -= i;
		// printf("Read %d from FIFO (%d left)\n", i, n);
	}
	return n;
}

int fifo_blocking_write(Fifo *f, unsigned char *buf, unsigned int n)
{
	int i;
	int retry = 5;

	while (n) {
		while (fifo_fill(f) == f->size ) {
			usleep(g_timeout);
			retry--;
			if (retry == 0) return DCERR_COMM_TIMEOUT;
		}

		i = fifo_write(f, buf, n);
		// printf("Wrote %d to FIFO\n", i);
		buf += i; n -= i;
	}
	return n;
}

// not first fall through
// Unused and unmaintained.
#if 0
void sim_fifo_io_ex(char *data, char *flag)
{
	uint32_t v;
	unsigned char b;


	// Check W1C error flags:
	if (flag[OVR] == HIGH) g_fifos[TO_SIM].unr = LOW;
	if (flag[UNR] == HIGH) g_fifos[FROM_SIM].ovr = LOW;

	// Are we serious to operate?
	if (flag[RXE] == HIGH) {
		if (fifo_read(&g_fifos[TO_SIM], &b, 1) == 1) {
			uint_to_logic(data, 8, b);
		}
	}

	if (flag[TXF] == HIGH) {
		logic_to_uint(data, 8, &v);
		b = v;
		fifo_write(&g_fifos[FROM_SIM], &b, 1);
	}

	// Query status and set flags
	fifo_status(&g_fifos[TO_SIM], FIFO_READ, flag);
	fifo_status(&g_fifos[FROM_SIM], FIFO_WRITE, flag);

	// Return OVR/UNR flags
	flag[OVR] = g_fifos[FROM_SIM].ovr;
	flag[UNR] = g_fifos[TO_SIM].unr;
}

#endif
