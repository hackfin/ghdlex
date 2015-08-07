#include <stdlib.h>
#include <stdio.h>
#include "bus.h"
#include "ghpi.h"
#include "netpp.h"
#include "netppwrap.h"

extern Bus *g_bus;

uint32_t g_vbus_addr;

bus_t_ghdl sim_bus_new_wrapped(string_ghdl name, integer_ghdl width, 
	integer_ghdl type)
{
	int error;
	char propname[32];

	Bus *b =
		(Bus *) malloc(sizeof(Bus) + BUS_AUXBUFSIZE);
	printf("Reserved Bus '%s' with word size %d\n", (char *) name->base,
		width);
	MUTEX_INIT(&b->mutex);
	b->width = (width + 7) / 8; // Convert to byte width and remember
	b->flags = 0;
	b->timeout_ms = 3000;
	b->tmpbuf = (char *) &b[1];
	b->bufsize = BUS_AUXBUFSIZE;

	switch (type) {
	case 1:
		if (g_bus) {
			fprintf(stderr,
				"You can only have one global bus (property-accessible)\n"
				"Overriding previous global bus.\n");
		}
		g_bus = b;
	}

	ghdlname_to_propname(name->base, propname, sizeof(propname));
	error = register_bus(b, propname);
	if (error < 0) return 0;
	
	return (bus_t_ghdl) b;
}

void sim_bus_rxtx(bus_t_ghdl *bus, unsigned_ghdl addr, unsigned_ghdl data,
	char *flag)
{
	Bus *b = (Bus *) *bus;

	MUTEX_LOCK(&b->mutex);

	if (b->flags & TX_PEND) {
		flag[1] = HIGH; b->flags &= ~TX_PEND;
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

	// Data ready?
	if (flag[2] == HIGH) {
		logic_to_uint(data->base, data->bounds->len, &b->data);
		b->flags &= ~(RX_PEND);
		flag[2] = LOW;
	}

	MUTEX_UNLOCK(&b->mutex);
}

/* Cosimulation side bus write */
int bus_val_wr(Bus *bus, uint32_t addr, uint32_t val)
{
	int error = 0;
	// Wait until slave has read previous data sent
	int retry = 0;
	while (bus->flags & TX_PEND) {
		printf("Poll until slave ready\n");
		USLEEP(1000); // Wait 1 ms
		retry++;
		if (retry > bus->timeout_ms) {
			fprintf(stderr, "Bus timeout. No response from Simulation?\n");
			return DCERR_COMM_TIMEOUT;
		}
	}

	MUTEX_LOCK(&bus->mutex);
		bus->addr = addr;
		bus->data = val;
		bus->flags |= TX_PEND;
	MUTEX_UNLOCK(&bus->mutex);
	// Wait for the simulation thread to actually commit the data:
	return error;
}

int bus_val_rd(Bus *bus, uint32_t addr, uint32_t *val)
{
	MUTEX_LOCK(&bus->mutex);
		bus->addr = addr;
		bus->flags |= RX_PEND;
	MUTEX_UNLOCK(&bus->mutex);
	int retry = 0;
	while ((bus->flags & (RX_PEND))) {
		// printf("Poll read...\n");
		USLEEP(1000);
		retry++;
		if (retry > bus->timeout_ms) {
			fprintf(stderr, "Bus timeout. No response from Simulation?\n");
			return DCERR_COMM_TIMEOUT;
		}

	}
	MUTEX_LOCK(&bus->mutex);
		bus->flags &= ~RX_BUSY;
	MUTEX_UNLOCK(&bus->mutex);

	*val = bus->data;
	return 0;
}

int bus_write(Bus *bus, const unsigned char *buf, int size)
{
	uint32_t val;
	uint32_t addr;
	int n, k;
	int s;
	val = 0;
	int error = 0;

	const unsigned char *end = &buf[size];

	k = size % bus->width;

	if (k) end -= k;

	addr = bus->addr;

	while (buf < end) {
		n = bus->width;

		// Little endian conversion:
		s = 0; val = 0;
		while (n--) {
			val |= (*buf++) << s; s += 8;
		}
		error = bus_val_wr(bus, addr, val);
		if (error < 0) return error;
		addr += bus->width;
	}

	if (k) {
		s = 0; val = 0;
		while (k--) {
			val |= (*buf++) << s; s += 8;
		}
		error = bus_val_wr(bus, addr, val);
		addr += bus->width;
	}

	// Wait for last write to finish:
	while (bus->flags & TX_PEND);

	MUTEX_LOCK(&bus->mutex);
		bus->addr = addr; // Store incremented address for subsequent writes
	MUTEX_UNLOCK(&bus->mutex);
	return error;
}


int bus_read(Bus *bus, unsigned char *buf, int size)
{
	uint32_t val;
	uint32_t addr;
	int error;
	while ((bus->flags & (TX_PEND))) USLEEP(1000);
	int n, k;
	val = 0;

	k = size % bus->width;

	unsigned char *end = &buf[size];
	if (k) end -= k;


	addr = bus->addr;

	while (buf < end) {
		error = bus_val_rd(bus, addr, &val);
		if (error < 0) return error;
		n = bus->width;
		// Store in little endian order:
		while (n--) {
			*buf++ = val;
			val >>= 8;
		}
		addr += bus->width;
	}

	// Get remainder:
	if (k) {
		error = bus_val_rd(bus, addr, &val);
		while (k--) {
			*buf++ = val;
			val >>= 8;
		}
		addr += bus->width;
	}

	MUTEX_LOCK(&bus->mutex);
		bus->addr = addr; // Store incremented address for subsequent reads
	MUTEX_UNLOCK(&bus->mutex);
	return error;
}
