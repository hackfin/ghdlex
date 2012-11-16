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



int get_fifo(DEVICE d, DCValue *out)
{
	return -1;
}

int set_fifo(DEVICE d, DCValue *in)
{
	return -1;
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


