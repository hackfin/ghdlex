/** \file helpers.c
 *
 * GHDL simulator interface auxiliaries
 *
 * (c) 2009-2011 Martin Strubel <hackfin@section5.ch>
 *
 */

#include <stdio.h>
#ifdef __WIN32__
#include <winsock2.h> // abuse htons/ntohs
#endif

#ifdef __linux__
#include <arpa/inet.h>
#endif
#include "ghpi.h"

/** Dump buffer */

void hexdump(const char *buf, unsigned long n)
{
	int i = 0;
	int c = 0;

	while (i < n) {
		// Testing: Bitreverse display:
		// printf("%02x ", reverse32(buf[2 * i]) >> 24);
		printf("%02x ", (unsigned char) buf[i]);
		c++;
		if (c == 16) { c = 0; printf("\r\n"); }
		i++;
	}
	if (c)
		printf("\r\n");
}

char slv_desc(unsigned char c)
{
	char *s = "UX01Z???";

	c &= 7;

	return s[c];
}

int logic_to_uint(const char *l, int nbits, uint32_t *val)
{
	uint32_t v = 0;
	int error = 0;
	while (nbits--) {
		v <<= 1;
		switch (*l) {
			case HIGH: v |= 1; break;
			case LOW: break;
			default:
				fprintf(stderr, "Warning: Undefined value('%c')[%d] in %s\n",
					slv_desc(*l), nbits, __FUNCTION__);
				*val = 0xffffffff;
				error = -1;
		}
		l++;
	}
	*val = v;
	return error;
}

void uint_to_logic(char *l, int nbits, uint32_t val)
{
	uint32_t pos;
	
	while (nbits--) {
		pos = 1 << nbits;
		if (val & pos) {
			*l = HIGH;
		} else {
			*l = LOW;
		}
		l++;
	}
}

int logic_to_bytes(char *l, int n, void *data)
{
	uint32_t v;
	uint8_t *b = (uint8_t *) data;
	int err;

	while (n--) {
		err = logic_to_uint(l, 8, &v);
		if (err < 0) {
			return err;
		}
		*b++ = v; l += 8;
	}
	return err;
}

int logic_to_words(char *l, int n, void *data)
{
	uint16_t *w = (uint16_t *) data;
	uint32_t v;
	int err;

	while (n--) {
		err = logic_to_uint(l, 16, &v);
		if (err < 0) {
			return err;
		}
		*w++ = htons(v); l += 16;
	}

	return err;
}

void bytes_to_logic(char *l, int n, const void *data)
{
	uint8_t *b = (uint8_t *) data;
	while (n--) {
		uint_to_logic(l, 8, *b++);
		l += 8;
	}
}

void words_to_logic(char *l, int n, const void *data)
{
	const uint16_t *w = (const uint16_t *) data;

	while (n--) {
		uint_to_logic(l, 16, ntohs(*w++));
		l += 16;
	}
}

void fill_slv(char *l, int nbits, unsigned char val)
{
	while (nbits--) {
		*l++ = val;
	}
}

// TESTING
	
void sim_set_ptr(handle_t_ghdl p)
{
	printf("Got ptr: %lx\n", p);
}

handle_t_ghdl sim_get_ptr(netpphandle_t_ghdl i)
{
	printf("Got int: %x\n", i);
	return (void *) 0xdeadbeef;
}

