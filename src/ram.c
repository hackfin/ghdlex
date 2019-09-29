/** Virtual RAM implementation v2
 *
 * 2015, Martin Strubel <hackfin@section5.ch>
 *
 * Note 1: We assume that client and server are running on the same
 * endianness (typically little). This will turn out in a mess when
 * porting ghdlex to other endian architectures.
 * For now, we live with it.
 * 
 * Note 2: netpp handles endianness, however, the raw FIFO code does
 * not. Transferred buffers are always byte-oriented!
 *
 * Note 3: This RAM, due to configureable address widths, has
 * BIG ENDIAN conversion routines. Otherwise, the I/O conversion will
 * follow the hosts endianness, which caused a mess in the v1 implementation.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include "ghpi.h"
#include "netpp.h"
#include "netppwrap.h"

typedef struct RamDesc {
	unsigned short addrsize;
	uint32_t offset;
	short bitwidth;
	short width;
	int size;
} Ram;

static
void endian_safe_memory_copy(unsigned char *dest, uint32_t v, int sz)
{
	int s = sz * 8;
	while (sz--) {
		s -= 8;
		*dest++ = (v >> s) & 0xff;
	}
}

static
void endian_safe_value_copy(uint32_t *v, unsigned char *dest, int sz)
{
	uint32_t val = 0;
	while (sz--) {
		val <<= 8;
		val |= *dest++;
	}
	*v = val;
}

rambuf_t_ghdl sim_ram_new_wrapped(string_ghdl name, integer_ghdl bits,
	integer_ghdl size)
{
	char propname[64];
	int error;
	int n = 1 << size;
	int ws = (bits + 7) / 8;
	if (bits > 32) {
		fprintf(stderr, "More than 32 bits not supported. Abort.\n");
		return NULL;
	}
	Ram *r = (Ram *) calloc(1, n * ws + sizeof(Ram));
	r->addrsize = size;
	r->bitwidth = bits;
	r->width = ws;
	r->offset = 0;
	r->size = n;
	ghdlname_to_propname(name->base, propname, sizeof(propname));
	printf("Reserved RAM '%s' with word size 0x%x(%d bytes), width: %d bits\n",
		propname,
		r->size, r->size * ws, bits);

	error = register_ram(r, propname);
	if (error < 0) return 0;
	return (rambuf_t_ghdl) r;
}

void_ghdl sim_ram_write(rambuf_t_ghdl *ram,
	struct fat_pointer *addr, ram_port_t_ghdl data)
{
	unsigned char *p;
	uint32_t i, val;
	Ram *r = (Ram *) ram[0];

	p = (unsigned char *) &r[1];
	logic_to_uint(data, 8 * sizeof(val), &val);
	logic_to_uint(addr->base, r->addrsize, &i);
	if (i > r->size) {
		fprintf(stderr, "write: Bad boundaries; addr = %08x\n", i);
		return;
	}
#ifdef ENABLE_RAM_TRACE
	printf("Write %08x : %08x\n", i, val);
#endif
	endian_safe_memory_copy(&p[i * r->width], val, r->width);
}

void_ghdl sim_ram_read(rambuf_t_ghdl *ram,
	struct fat_pointer *addr, ram_port_t_ghdl data)
{
	int error;
	unsigned char *p;
	uint32_t i, val;
	Ram *r = (Ram *) ram[0];
	p = (unsigned char *) &r[1];
	error = logic_to_uint(addr->base, r->addrsize, &i);
	if (error < 0) {
		fprintf(stderr, "RAM content undefined\n");
	}
	if (i > r->size) {
		fprintf(stderr, "read: Bad boundaries; addr = %08x\n", i);
		return;
	}
	endian_safe_value_copy(&val, &p[i * r->width], r->width);
	uint_to_logic(data, 8 * sizeof(val), val);
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
	int size = r->size * r->width;

	size -= r->offset;

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
			in->value.p = &((char *) &r[1])[r->offset];
			break;
		default:
			return DCERR_PROPERTY_TYPE_MATCH;
	}
	return 0;
}

int get_ram(DEVICE d, DCValue *out)
{
	int ret = 0;
	Ram *r = (Ram *) d;
	if (!r) return DCERR_BADPTR;

	int size = r->size * r->width;
	size -= r->offset;

	switch (out->type) {
		case DC_COMMAND:  // This is a buffer update action
			break;
		case DC_UNDEFINED:
		case DC_BUFFER:
			// You must do a buffer size check here:
			// netpp_log(DCLOG_VERBOSE, "Set buffer len %d", out->len);
			if (out->len > size) {
				out->len = size;
				ret = DCWARN_PROPERTY_MODIFIED;
			} else
			if (out->len == 0) { // Python handler
				out->len = size;
				// We must return this to Python for proper buffer
				// reservation
				return DCERR_PROPERTY_SIZE_MATCH;
			}

			// Tell engine where the data will come from:
			out->value.p = &((char *) &r[1])[r->offset];
			break;
		default:
			ret = DCERR_PROPERTY_TYPE_MATCH;
	}

	return ret;
}

/** Netpp custom handler */
int handle_rambuf(void *p, int write, DCValue *val)
{
	// printf("%s (%d)\n", __FUNCTION__, write);
	if (write) {
		return set_ram((DEVICE) p, val);
	} else {
		return get_ram((DEVICE) p, val);
	}
}

int handle_ramoffset(void *p, int write, DCValue *val)
{
	Ram *r = (Ram *) p;
	if (write) {
		if (val->value.u >= (r->size * r->width))
			return DCERR_PROPERTY_RANGE;
		r->offset = val->value.i;
	}
	else       val->value.u = r->offset;
	return 0;
}
