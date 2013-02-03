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
#include "devlib.h"
#include "devlib_error.h"
#include "example.h"
#include "registermap.h"
#include "property_protocol.h"
#include "fifo.h"

#include "vpi_user.h"
#include "ghpi.h"

int fifo_blocking_read(Fifo *f, unsigned char *buf, unsigned int n);
int fifo_blocking_write(Fifo *f, unsigned char *buf, unsigned int n);

// Global variables exposed to property access:

int g_timeout = 500000; // FIFO default timeout

struct vpi_handle_cache {
	vpiHandle emuir;
};

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
				if (n < 0) return DCERR_COMM_TIMEOUT;
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

void init_registermap(void)
{
	_registermap[R_FPGA_Registermap_Control] = THROTTLE;
}

int device_write(RemoteDevice *d,
		uint32_t addr, const unsigned char *buf,
		unsigned long size)
{
	if (addr > 255) {
		printf("Address 0x%x out of range.\n", addr);
		return DCERR_PROPERTY_RANGE;
	}
	printf("Write to register %04x:", addr);
	memcpy(&_registermap[addr & 0xff], buf, size);
	while (size--) {
		printf(" %02x", *buf++);
	}
	printf("\n");
	return 0;
}


/** Device flat address register map read access.
 * For low level device access (SPI, I2C, etc.) this normally wants to
 * be implemented */

int device_read(RemoteDevice *d,
		uint32_t addr, unsigned char *buf, unsigned long size)
{
	if (addr > 255) {
		printf("Address 0x%x out of range.\n", addr);
		return DCERR_PROPERTY_RANGE;
	}
	printf("Read from register %04x (%lu bytes)\n", addr, size);
	memcpy(buf, &_registermap[addr & 0xff], size);
	return 0;
}

void sim_regmap_read(regaddr_t_ghdl address, byte_t_ghdl data)
{
	uint32_t addr, val;
	logic_to_uint(address, sizeof(address), &addr);
	addr &= 0xff;
	
	val = _registermap[addr];
	uint_to_logic(data, sizeof(data), val);
}

void sim_regmap_write(regaddr_t_ghdl address, byte_t_ghdl data)
{
	uint32_t addr, val;
	logic_to_uint(address, sizeof(address), &addr);
	addr &= 0xff;
	logic_to_uint(data, sizeof(data), &val);
	
	_registermap[addr] = val;
}
