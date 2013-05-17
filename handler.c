/** Handler example code.
 *
 * All handlers (getters and setters) start with get_ respectively with
 * set_.
 *
 * Note that for readonly/writeonly properties, only the relevant handler
 * functions need to be specified.
 *
 */

#include <stdio.h> // printf debugging only
#include <stdlib.h>
#include <pthread.h>
#include "devlib.h"
#include "devlib_error.h"
#include "registermap.h"
#include "property_protocol.h"
#include "fifo.h"
#include "bus.h"

#include "vpi_user.h"
#include "ghpi.h"


int fifo_blocking_read(Fifo *f, unsigned char *buf, unsigned int n);
int fifo_blocking_write(Fifo *f, unsigned char *buf, unsigned int n);

// Global variables exposed to property access:

struct fifoconfig g_fifoconfig = {
	.timeout = 100000, // Default FIFO timeout
	.retry = 20
};

struct vpi_handle_cache {
	vpiHandle emuir;
};

Bus *g_bus;

/*
int get_uint32(DEVICE d, DCValue *out)
{
	vpiHandle v;
	s_spi_value vpival;

	uint32_t u32;

	v = vpi_put_value(vpi_handle_cache.emuir, &vpival);
	if (format != vpiVectorVal) return DCERR_PROPERTY_TYPE_MATCH;

	
}
*/

int get_fifo(Fifo *f, DCValue *out)
{
	int warn = 0;
	int n;

	static unsigned char buf[BUFSIZE];

	switch (out->type) {
		case DC_COMMAND:  // This is a buffer update action
			// netpp_log(DCLOG_VERBOSE, "Release buffer");
			break;
		case DC_UNDEFINED:
		case DC_BUFFER:
			// You must do a buffer size check here:
			// netpp_log(DCLOG_VERBOSE, "Get buffer, len %d", out->len);
			if (out->len > BUFSIZE) {
				out->len = BUFSIZE;
				warn = DCWARN_PROPERTY_MODIFIED;
			}

			if (out->len == 0) { // Python handler
				n = fifo_fill(f);
				out->len = n;
				// We must return this to Python for proper buffer
				// reservation
				return DCERR_PROPERTY_SIZE_MATCH;
			} else {
#ifdef DEBUG
				printf("----------------------------------------\n");
				printf("H <- S fill: %d\n", fifo_fill(f));
				printf("Request %ld bytes\n", out->len);
#endif
				n = fifo_blocking_read(f, buf, out->len);
				if (n < 0) {
					printf("FIFO timed out\n");
					return DCERR_COMM_TIMEOUT;
				}
				// Set data gathering pointer:
			}
			out->value.p = buf; // ONLY BECAUSE IT'S STATIC!!
			break;
		default:
			return DCERR_PROPERTY_TYPE_MATCH;
	}
	return warn;
}

int set_fifo(Fifo *f, DCValue *in)
{
	int error;
	int warn = 0;

	static unsigned char buf[BUFSIZE];

	switch (in->type) {
		case DC_COMMAND:  // This is a buffer update action
			// Fill in update code
			// netpp_log(DCLOG_VERBOSE, "Update buffer len %d", in->len);
			error = fifo_blocking_write(f, buf, in->len);
			if (error < 0) return error;
			break;
		case DC_UNDEFINED:
		case DC_BUFFER:
			// You must do a buffer size check here:
			// netpp_log(DCLOG_VERBOSE, "Set buffer len %d", in->len);
			if (in->len > BUFSIZE) {
				in->len = BUFSIZE;
				return DCERR_PROPERTY_SIZE_MATCH;
			}

			// Tell engine where the data will go to:
			in->value.p = buf; // ONLY BECAUSE IT'S STATIC!
			break;
		default:
			return DCERR_PROPERTY_TYPE_MATCH;
	}

	return warn;
}

/* Custom FIFO handler for netpp */

int handle_fifo(void *p, int write, DCValue *val)
{
	// printf("%s (%d)\n", __FUNCTION__, write);
	DuplexFifo *df = (DuplexFifo *) p;
	if (write) {
		return set_fifo(&df->out, val);
	} else {
		return get_fifo(&df->in, val);
	}
}

int handle_fifo_infill(DuplexFifo *df, int write, DCValue *out)
{
	if (write) return DCERR_PROPERTY_ACCESS;
	out->value.i = fifo_fill(&df->in);
	return 0;
}

int handle_fifo_outfill(DuplexFifo *df, int write, DCValue *out)
{
	if (write) return DCERR_PROPERTY_ACCESS;
	out->value.i = fifo_fill(&df->out);
	return 0;
}


/** Dummy register space. Just a RAM.
 * This is accessed by sim_regmap_read()/sim_regmap_write()
 */

static unsigned char _registermap[256] = {
	0xaa, 0x55, 
};

// FIXME: No more global stuff

pthread_mutex_t reg_mutex;


void init_registermap(void)
{
	pthread_mutex_init(&reg_mutex, NULL);
	_registermap[R_FPGA_Registers_Control] = THROTTLE;
}

int device_write(RemoteDevice *d,
		uint32_t addr, const unsigned char *buf,
		unsigned long size)
{
	if (addr < VBUS_ADDR_OFFSET) {
		printf("Write to register %04x:", addr);

		pthread_mutex_lock(&reg_mutex);
		memcpy(&_registermap[addr & 0xff], buf, size);
		pthread_mutex_unlock(&reg_mutex);

		while (size--) {
			printf(" %02x", *buf++);
		}
		printf("\n");
	} else {
		if (!g_bus) return DCERR_BADPTR;
		uint32_t val;
		val = 0;
		while (size--) {
			val <<= 8;
			val |= *buf++;
		}
		// Wait until slave has read previous data sent
		while (g_bus->flags & TX_PEND) {
			// printf("Poll until slave ready\n");
			usleep(1000); // XXX
		}
		pthread_mutex_lock(&g_bus->mutex);
			g_bus->addr = addr & 0xff;
			g_bus->data = val;
			g_bus->flags |= TX_PEND;
		pthread_mutex_unlock(&g_bus->mutex);
	}
	return 0;
}

/** Device flat address register map read access.
 * For low level device access (SPI, I2C, etc.) this normally wants to
 * be implemented */

int device_read(RemoteDevice *d,
		uint32_t addr, unsigned char *buf, unsigned long size)
{
	if (addr < VBUS_ADDR_OFFSET) {
		printf("Read from register %04x (%lu bytes)\n", addr, size);
		pthread_mutex_lock(&reg_mutex);
		memcpy(buf, &_registermap[addr & 0xff], size);
		pthread_mutex_unlock(&reg_mutex);
	} else {
		// Make sure no write is still pending:
		if (!g_bus) return DCERR_BADPTR;
		while ((g_bus->flags & (TX_PEND))) usleep(1000);

		uint32_t val;
		g_bus->addr = addr & 0xff;
		pthread_mutex_lock(&g_bus->mutex);
			g_bus->flags |= RX_PEND;
		pthread_mutex_unlock(&g_bus->mutex);
		while ((g_bus->flags & (RX_PEND))) {
			// printf("Poll read...\n");
			usleep(1000); // XXX
		}
		// printf("Read %08x\n", g_bus->data);
		pthread_mutex_lock(&g_bus->mutex);
			g_bus->flags &= ~RX_BUSY;
		pthread_mutex_unlock(&g_bus->mutex);

		buf += size - 1;
		val = g_bus->data;
		while (size--) {
			*buf-- = val;
			val >>= 8;
		}
	}
	return 0;
}

void sim_regmap_read(regaddr_t_ghdl address, unsigned_ghdl data)
{
	int nbytes;
	uint32_t addr, val;
	logic_to_uint(address, sizeof(address), &addr);
	addr &= 0xff;

	nbytes = (data->bounds->len + 7) >> 3;
	
	val = 0;
	// Big endian shift:
	pthread_mutex_lock(&reg_mutex);
	while (nbytes--) {
		val <<= 8;
		val |= _registermap[addr++];
	}
	pthread_mutex_unlock(&reg_mutex);
	uint_to_logic(data->base, data->bounds->len, val);
}

void sim_regmap_write(regaddr_t_ghdl address, unsigned_ghdl data)
{
	uint32_t addr, val;
	int nbytes;
	logic_to_uint(address, sizeof(address), &addr);
	addr &= 0xff;
	logic_to_uint(data->base, data->bounds->len, &val);
	
	nbytes = (data->bounds->len + 7) >> 3;
	addr += nbytes - 1;
	pthread_mutex_lock(&reg_mutex);
	while (nbytes--) {
		_registermap[addr--] = val & 0xff;
		val >>= 8;
	}
	pthread_mutex_unlock(&reg_mutex);
}

bus_t_ghdl sim_bus_new_wrapped(string_ghdl name, integer_ghdl width)
{
	Bus *b =
		(Bus *) malloc(sizeof(Bus));
	printf("Reserved Bus '%s' with word size %d\n", (char *) name->base,
		width);
	pthread_mutex_init(&b->mutex, NULL);
	b->flags = 0;

	g_bus = b; // XXX
	return (bus_t_ghdl) b;
}

void sim_bus_rxtx(bus_t_ghdl *bus, unsigned_ghdl addr, unsigned_ghdl data,
	char *flag)
{
	Bus *b = (Bus *) *bus;

	pthread_mutex_lock(&b->mutex);

	if (b->flags & TX_PEND) {
		flag[1] = HIGH; b->flags &= ~TX_PEND;
		// printf("Write %x\n", b->data);
		uint_to_logic(data->base, data->bounds->len, b->data);
		uint_to_logic(addr->base, addr->bounds->len, b->addr);
	} else {
		flag[1] = LOW;
	}

	if ((b->flags & (RX_BUSY | RX_PEND)) == RX_PEND) {
		flag[0] = HIGH;
		b->flags |= RX_BUSY;
		uint_to_logic(addr->base, addr->bounds->len, b->addr);
	}
	else        { flag[0] = LOW; }

	if (flag[2] == HIGH) {
		logic_to_uint(data->base, data->bounds->len, &b->data);
		b->flags &= ~(RX_PEND);
		flag[2] = LOW;
	}

	pthread_mutex_unlock(&b->mutex);
}
