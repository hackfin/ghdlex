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
#include "devlib.h"
#include "devlib_error.h"
#include "registermap.h"
#include "property_protocol.h"
#include "fifo.h"

#include "vpi_user.h"
#include "ghpi.h"

// #define DEBUG

int fifo_blocking_read(Fifo *f, unsigned char *buf, unsigned int n);
int fifo_blocking_write(Fifo *f, unsigned char *buf, unsigned int n);

// Global variables exposed to property access:

struct fifoconfig g_fifoconfig = {
	.timeout = 100000, // Default FIFO timeout
	.retry = 30
};

struct vpi_handle_cache {
	vpiHandle emuir;
};

// Global netpp accessible bus:
Bus *g_bus = 0;


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

int handle_pty(void *pty, int write, DCValue *out)
{
	return DCERR_PROPERTY_HANDLER;
}


/** Dummy register space. Just a RAM.
 * This is accessed by sim_regmap_read()/sim_regmap_write()
 */

#ifdef SUPPORT_LEGACY_REGISTERMAP

static unsigned char _registermap[256] = {
	0xaa, 0x55, 
};

// FIXME: No more global stuff

MUTEX reg_mutex;

void init_registermap(void)
{
	MUTEX_INIT(&reg_mutex);
	// Default Throttle on:
	_registermap[R_FPGA_Registers_Control] = THROTTLE;
}

#endif

int device_write(RemoteDevice *d,
		uint32_t addr, const unsigned char *buf,
		unsigned long size)
{
#ifdef SUPPORT_LEGACY_REGISTERMAP

	if (addr < VBUS_ADDR_OFFSET) {
		printf("Write to register %04x:", addr);

		MUTEX_LOCK(&reg_mutex);
		memcpy(&_registermap[addr & 0xff], buf, size);
		MUTEX_UNLOCK(&reg_mutex);

	} else {
#endif
#ifdef DEBUG
		printf("Write to VBUS %04x (%lu bytes)\n", addr, size);
		hexdump(buf, size);
#endif

		if (!g_bus) return DCERR_BADPTR;
		g_bus->addr = addr;
		return bus_write(g_bus, buf, size);

#ifdef SUPPORT_LEGACY_REGISTERMAP
	}
#endif
	return 0;
}

/** Device flat address register map read access.
 * For low level device access (SPI, I2C, etc.) this normally wants to
 * be implemented
 *
 * NOTE: We define register sizes in BITS! Therefore, convert to bytes
 * for host side processing.
 */

int device_read(RemoteDevice *d,
		uint32_t addr, unsigned char *buf, unsigned long size)
{
#ifdef SUPPORT_LEGACY_REGISTERMAP
	if (addr < VBUS_ADDR_OFFSET) {
		printf("Read from register %04x (%lu bytes)\n", addr, size);
		MUTEX_LOCK(&reg_mutex);
		memcpy(buf, &_registermap[addr & 0xff], size);
		MUTEX_UNLOCK(&reg_mutex);
	} else {
#endif
#ifdef DEBUG
		printf("Read from VBUS %04x (%lu bytes)\n", addr, size);
#endif
		// Make sure no write is still pending:
		if (!g_bus) return DCERR_BADPTR;
		g_bus->addr = addr;
		return bus_read(g_bus, buf, size);

#ifdef SUPPORT_LEGACY_REGISTERMAP
	}
#endif
	return 0;
}

#ifdef SUPPORT_LEGACY_REGISTERMAP
void sim_regmap_read(regaddr_t_ghdl address, unsigned_ghdl data)
{
	int nbytes;
	uint32_t addr, val;
	logic_to_uint(address, sizeof(regaddr_t_ghdl), &addr);
	addr &= 0xff;

	nbytes = (data->bounds->len + 7) >> 3;
	
	val = 0;
	// Big endian shift:
	MUTEX_LOCK(&reg_mutex);
	while (nbytes--) {
		val <<= 8;
		val |= _registermap[addr++];
	}
	MUTEX_UNLOCK(&reg_mutex);
	uint_to_logic(data->base, data->bounds->len, val);
}

void sim_regmap_write(regaddr_t_ghdl address, unsigned_ghdl data)
{
	uint32_t addr, val;
	int nbytes;
	logic_to_uint(address, sizeof(regaddr_t_ghdl), &addr);
	addr &= 0xff;
	logic_to_uint(data->base, data->bounds->len, &val);
	
	nbytes = (data->bounds->len + 7) >> 3;
	addr += nbytes - 1;
	MUTEX_LOCK(&reg_mutex);
	while (nbytes--) {
		_registermap[addr--] = val & 0xff;
		val >>= 8;
	}
	MUTEX_UNLOCK(&reg_mutex);
}
#endif

int handle_vbus_width(Bus *b, int write, DCValue *val)
{
	val->value.i = b->width;
	return 0;
}

int handle_vbus_addr(Bus *b, int write, DCValue *val)
{
	if (write) {
		b->addr = (uint32_t) val->value.i;
	} else {
		val->value.i = b->addr;
	}
	return 0;
}

int handle_vbus_data(Bus *b, int write, DCValue *val)
{
	int error = 0;
	switch (val->type) {
		case DC_BUFFER:
		case DC_STRING:
			val->value.p = b->tmpbuf;
			if (val->len > b->bufsize) {
				val->len = b->bufsize;
				error = DCWARN_PROPERTY_MODIFIED;
			// Python "dump" query support:
			}  else
			// Are we reading? Then fire a request.
			if (val->len == 0) {
				val->len = 16; // Packet of 16 bytes is default
				error = DCERR_PROPERTY_SIZE_MATCH;
			}

			if (error >= 0 && !write) {
				error = bus_read(b, b->tmpbuf, val->len);
			}
			break;
		case DC_UNDEFINED:
			break;
		case DC_COMMAND:
			if (write) {
				error = bus_write(b, b->tmpbuf, val->len);
			} else error = 0;
			break;
		case DC_REGISTER:
			if (write) {
				error = bus_val_wr(b, b->addr, val->value.i);
			} else {
				error = bus_val_rd(b, b->addr, (uint32_t *) &val->value.i);
			}
			error = 0;
			break;
		default:
			error = DCERR_PROPERTY_TYPE_MATCH;
		}
	return error;
}

