/** Virtual RAM implementation
 *
 * 2012, Martin Strubel <hackfin@section5.ch>
 *
 * Note 1: We assume that client and server are running on the same
 * endianness (typically little). This will turn out in a mess when
 * porting ghdlex to other endian architectures.
 * For now, we live with it.
 * 
 * Note 2: netpp handles endianness, however, the raw FIFO code does
 * not. Transferred buffers are always byte-oriented!
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include "ghpi.h"
#include "netpp.h"
#include "netppwrap.h"

typedef struct RamDesc {
	unsigned short addrsize;
	int size;
} Ram;

rambuf_t_ghdl sim_ram_new_wrapped(string_ghdl name, integer_ghdl size)
{
	char propname[64];
	int error;
	int n = 1 << size;
	Ram *r = (Ram *) malloc(n * sizeof(uint16_t) + sizeof(Ram));
	r->addrsize = size;
	r->size = n;
	ghdlname_to_propname(name->base, propname, sizeof(propname));
	printf("Reserved RAM '%s' with word size 0x%x(%ld bytes)\n", propname,
		r->size, r->size * sizeof(uint16_t));

	error = register_ram(r, propname);
	if (error < 0) return 0;
	return (rambuf_t_ghdl) r;
}

void_ghdl sim_ram_write(rambuf_t_ghdl *ram,
	struct fat_pointer *addr, ram16_t_ghdl data)
{
	uint16_t *p;
	uint32_t i, val;
	Ram *r = (Ram *) ram[0];

	p = (uint16_t *) &r[1];
	logic_to_uint(data, 16, &val);
	logic_to_uint(addr->base, r->addrsize, &i);
	if (i > r->size) {
		fprintf(stderr, "write: Bad boundaries; addr = %08x\n", i);
		return;
	}
	p[i] = val;
}

void_ghdl sim_ram_read(rambuf_t_ghdl *ram,
	struct fat_pointer *addr, ram16_t_ghdl data)
{
	uint16_t *p;
	uint32_t i, val;
	Ram *r = (Ram *) ram[0];
	p = (uint16_t *) &r[1];
	logic_to_uint(addr->base, r->addrsize, &i);
	if (i > r->size) {
		fprintf(stderr, "read: Bad boundaries; addr = %08x\n", i);
		return;
	}
	val = p[i];
	uint_to_logic(data, 16, val);
}

void_ghdl sim_ram_del(rambuf_t_ghdl *ram)
{
	free(ram[0]);
}

////////////////////////////////////////////////////////////////////////////
// netpp handlers to read out RAM remotely

int set_ram(DEVICE d, DCValue *in)
{
	Ram *r = (Ram *) d;
	if (!r) return DCERR_BADPTR;
	int size = r->size * sizeof(uint16_t);

	switch (in->type) {
		case DC_COMMAND:  // This is a buffer update action
			break;
		case DC_INVALID:
		case DC_BUFFER:
			// You must do a buffer size check here:
			// netpp_log(DCLOG_VERBOSE, "Set buffer len %d", in->len);
			if (in->len > size) {
				in->len = size;
				return DCERR_PROPERTY_SIZE_MATCH;
			}

			// Tell engine where the data will go to:
			in->value.p = &r[1];
			break;
		default:
			return DCERR_PROPERTY_TYPE_MATCH;
	}
	return 0;
}

int get_ram(DEVICE d, DCValue *out)
{
	Ram *r = (Ram *) d;
	if (!r) return DCERR_BADPTR;

	int size = r->size * sizeof(uint16_t);

	switch (out->type) {
		case DC_COMMAND:  // This is a buffer update action
			break;
		case DC_UNDEFINED:
		case DC_BUFFER:
			// You must do a buffer size check here:
			// netpp_log(DCLOG_VERBOSE, "Set buffer len %d", out->len);
			if (out->len > size) {
				out->len = size;
				return DCWARN_PROPERTY_MODIFIED;
			} else
			if (out->len == 0) { // Python handler
				out->len = size;
				// We must return this to Python for proper buffer
				// reservation
				return DCERR_PROPERTY_SIZE_MATCH;
			}

			// Tell engine where the data will come from:
			out->value.p = &r[1];
			break;
		default:
			return DCERR_PROPERTY_TYPE_MATCH;
	}

	return 0;
}

/** Netpp custom handler */
int buffer_handler(void *p, int write, DCValue *val)
{
	// printf("%s (%d)\n", __FUNCTION__, write);
	if (write) {
		return set_ram((DEVICE) p, val);
	} else {
		return get_ram((DEVICE) p, val);
	}
}


