/** \file netpp.c
 *
 * Simple interface to a netpp device from the simulator (VHDL code)
 *
 * Warning: Very GHDL specific and possibly non-portable
 * (Tested on 64 bit Intel only)
 *
 */

#include <stdlib.h>
#include <stdio.h>
#include "netpp.h"
#include "property_types.h"
#include "property_protocol.h"
#include "dynprops.h"
#include "fifo.h"
#include "ghpi.h"
#include "netppwrap.h"

#define MAX_NUM_DEVICES 8

#define GET_DEV(x) s_devices[x]

static
DEVICE s_devices[MAX_NUM_DEVICES] = {
	0, 0, 0, 0, 0, 0, 0, 0
};

static int g_is_dynamic = 0;

// External token in prop list:
extern TOKEN g_t_fifo;

////////////////////////////////////////////////////////////////////////////
// PROTOS

int buffer_handler(void *p, int write, DCValue *val);

// Templates:

PropertyDesc s_rootprop = {
	.type = DC_ROOT,
	.flags = F_RO | F_LINK /* Derived ! */,
	.access = { .base = 0 }
};


////////////////////////////////////////////////////////////////////////////

/** A buffer Property Description template */
PropertyDesc s_buffer_template = {
	.type = DC_BUFFER,
	.flags = F_RW,
	.where = DC_CUSTOM,
	.access = { .custom = { buffer_handler, 0 } },
};

DEVICE get_device(DEVHANDLE dev)
{
	return s_devices[dev];
}

TOKEN local_getroot(DEVICE d)
{
	int index = 0;
	if (g_is_dynamic) return DYNAMIC_PROPERTY | DEVICE_TOKEN(index);
	return DEVICE_TOKEN(index);
}

void handleError(int error)
{
	const char *s;
	s = dcGetErrorString(error);

	fprintf(stderr, "netpp error: %s\n", s);
}

int set_property(DEVICE d, const char *name, void *val, int type)
{
	int error;
	DCValue v;
	TOKEN t;

	error = dcProperty_ParseName(d, name, &t);
	if (error < 0) return error;

	v.value.i = *( (int *) val);
	v.type = type;

	return dcDevice_SetProperty(d, t, &v);
}

netpphandle_t_ghdl sim_device_open_wrapped(struct ghdl_string *id)
{
	DEVICE d;
	int error;
	int i;
	char *port = id->base;

	error = dcDeviceOpen(port, &d);
	if (error < 0) return error;

	for (i = 0; i < MAX_NUM_DEVICES; i++) {
		if (GET_DEV(i) == 0) {
			GET_DEV(i) = d;
			return i;
		}
	}
	return -1;
}

void sim_device_close(DEVHANDLE handle)
{
	DEVICE d = GET_DEV(handle);
	dcDeviceClose(d);
	GET_DEV(handle) = 0;
}

TOKEN sim_device_gettoken_wrapped(DEVHANDLE handle, struct ghdl_string *id)
{
	DEVICE d = GET_DEV(handle);
	TOKEN t;
	int error;

	error = dcProperty_ParseName(d, id->base, &t);
	if (error < 0) {
		fprintf(stderr, "Fatal: ");
		handleError(error);
		exit(-1);
	}
	return t;
}

int sim_device_set_int(DEVHANDLE handle, TOKEN t, int v)
{
	int error;
	DEVICE d = GET_DEV(handle);
	DCValue val;
	val.value.i = v;
	val.type = DC_INT;

	error = dcDevice_SetProperty(d, t, &val);
	if (error < 0) handleError(error);
	return error;
	
}

int set_buffer(DEVICE d, TOKEN t, void  *buf, int len)
{
	int error;
	DCValue val;
	val.value.p = buf;
	val.len = len;
	val.type = DC_BUFFER;

	error = dcDevice_SetProperty(d, t, &val);
	if (error < 0) handleError(error);
	return error;
}

void sim_usleep(integer_ghdl cycles)
{
	usleep(cycles);
}

int ghdlname_to_propname(const char *name, char *propname, int len)
{
	strncpy(propname, name, len-1);
	propname[len-1] = '\0';
}

// No longer used, we don't compress the names down anymore, to keep
// the VHDL hierarchy sane.

#if 0
int ghdlname_to_propname(const char *name, char *propname, int len)
{
	char c;
	
	const char *word = 0, *at = 0;

	enum {
		S_NEUTRAL,
		S_DOT,
		S_WORD,
	} state = S_NEUTRAL;

	while ((c = *name++)) {
		switch (state) {
			case S_NEUTRAL:
				switch (c) {
					case ':': state = S_DOT; break;
				}
				break;
			case S_DOT:
				word = name - 1;
				state = S_WORD;
				break;
			case S_WORD:
				switch (c) {
					case '@': at = name - 1; state = S_NEUTRAL; break;
					case ':': at = name - 1; state = S_DOT; break;
				}
		}
	}
	len--;
	if (at && word) {
		while (len-- && word != at) {
			*propname++ = *word++;
		}
		*propname = '\0';
		return 0;
	}
	return -1;
}
#endif

PropertyDesc *property_desc_new(PropertyDesc *template)
{
	PropertyDesc *p;
	p = (PropertyDesc*) malloc(sizeof(PropertyDesc));
	if (p) {
		*p = *template;
	}
	return p;
}

/** Clone a dynamic property from a simple standalone template without
 * hierarchy.
 */
TOKEN property_from_template(TOKEN parent, void *entity, const char *name,
	PropertyDesc *template)
{
	TOKEN t;
	PropertyDesc *p;

	p = property_desc_new(template);
	if (!p) return TOKEN_INVALID;
	p->access.custom.p = entity; // Story entity handle in custom pointer

	t = new_dynprop(name, p);
	if (t != TOKEN_INVALID) dynprop_append(parent, t);
	return t;
}

/** Recursively construct dynamic property from property template:
 * The 'template' must be part of the device property hierarchy,
 * because all its children will be cloned as well
 */
TOKEN property_from_entity(TOKEN parent, void *entity, 
	TOKEN template, const char *name)
{
	TOKEN t, walk;
	PropertyDesc *p, *child;
	PropertyDesc *tdesc = getProperty_ByToken(template);

	p = property_desc_new(tdesc);
	if (!p) return TOKEN_INVALID;
	p->access.custom.p = entity; // Story entity handle in custom pointer

	t = new_dynprop(name, p);
	// iterate children:

	if (t != TOKEN_INVALID) {
		dynprop_append(parent, t);
		// and create its children:
		// Select first child from template:
		walk = property_select(template, template);
		while (walk != TOKEN_INVALID) {
			child = getProperty_ByToken(walk);
			property_from_entity(t, entity, walk, child->name);
			// Get successor:
			walk = property_select(template, walk);
		}
	}
	return t;
}

int register_fifo(void *entity, char *name)
{
	TOKEN t;
	TOKEN root;
	root = local_getroot(NULL);
	printf("Registering FIFO..\n");
	// Retrieve descriptor for FIFO token (defined externally)
	t = property_from_entity(root, entity, g_t_fifo, name);
	if (t == TOKEN_INVALID) {
		printf("Unable to register FIFO, out of properties?\n");
		return -1;
	}
	printf("Registered FIFO property with name '%s'\n", name);
	return 0;
}

int register_ram(void *entity, char *name)
{
	TOKEN t;
	TOKEN root;
	root = local_getroot(NULL);
	// Clone a property instance from the buffer template:
	t = property_from_template(root, entity, name, &s_buffer_template);
	if (t == TOKEN_INVALID) {
		printf("Unable to register ram, out of properties?\n");
		return -1;
	}
	printf("Registered RAM property with name '%s'\n", name);
	return 0;
}

char g_initialized = 0;

extern DeviceDesc g_devices[];
extern int g_ndevices;

int netpp_root_init(const char *name)
{
	TOKEN t;
	if (g_initialized) {
		fprintf(stderr, "netpp already initialized, ignoring root %s\n", name);
		return 1;
	}
	register_proplist(g_devices, g_ndevices);

	g_is_dynamic = 1;

	dynprop_init(80);

	t = new_dynprop(name, &s_rootprop);
	if (t == TOKEN_INVALID) return -1;
	g_initialized = 1;
	return 0;
}
