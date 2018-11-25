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
#include "slave.h"
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

char g_initialized = 0;

static int g_is_dynamic = 0;

// External token in prop list:
extern TOKEN g_t_ghdlex_fifo;
extern TOKEN g_t_ghdlex_bus;
extern TOKEN g_t_ghdlex_ram;
// extern TOKEN g_t_pty;

struct local_config {
	int port;
};

#ifdef __WIN32__
#define THREAD_RETURN DWORD
#define THREAD_DECO   WINAPI
#else
#define THREAD_RETURN void *
#define THREAD_DECO
#endif

////////////////////////////////////////////////////////////////////////////
// PROTOS

// handler.c:

int handle_rambuf(void *p, int write, DCValue *val);
void init_registermap(void);

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
	.access = { .custom = { handle_rambuf, 0 } },
};

DEVICE get_device(DEVHANDLE dev)
{
	return s_devices[dev];
}

TOKEN local_getroot(DEVICE d)
{
	int index = 0;
	if (!g_initialized) {
		fprintf(stderr, "netpp not initialized. Use --vpi=netpp.vpi\n");
		return TOKEN_INVALID;
	}

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

int sim_device_set_register(DEVHANDLE handle, TOKEN t, int v)
{
	int error;
	DEVICE d = GET_DEV(handle);
	DCValue val;
	val.value.i = v;
	val.type = DC_REGISTER;

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
	USLEEP(cycles);
}

static uint32_t s_prev = 0;

void sim_throttle(byte_t_ghdl activity, integer_ghdl cycles)
{
	uint32_t val;

	logic_to_uint(activity, sizeof(byte_t_ghdl), &val);

	if (val == s_prev) {
		USLEEP(cycles);
	} else {
		s_prev = val;
	}
}

int ghdlname_to_propname(const char *name, char *propname, int len)
{
	strncpy(propname, name, len-1);
	propname[len-1] = '\0';
	return 0;
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

PropertyDesc *property_string_new(int size)
{
	PropertyDesc *p;
	p = (PropertyDesc*) malloc(sizeof(PropertyDesc) + size);
	if (p) {
		p->type = DC_STRING;
		p->flags = F_RO;
		p->where = DC_STATIC;
		p->access.s_string = (char *) &p[1];
	}
	return p;
}

static
TOKEN create_property_descriptor(const PropertyDesc *template, void *entity,
	const char *name)
{
	PropertyDesc *p;

	p = property_desc_new(template);
	if (!p) return TOKEN_INVALID;
	if (p->type == DC_STRUCT) {
		p->where = DC_CUSTOM;
	}

	p->access.custom.p = entity; // Story entity handle in custom pointer
	if (template->type != DC_STRUCT && !template->access.custom.handler) {
		netpp_log(DCLOG_ERROR, "custom handler for '%s' is NULL!\n", template->name);
	}

	return new_dynprop(name, p);
}

/** Clone a dynamic property from a simple standalone template without
 * hierarchy.
 */
static
TOKEN property_from_template(TOKEN parent, void *entity, const char *name,
	PropertyDesc *tdesc)
{
	TOKEN t;

	t = create_property_descriptor(tdesc, entity, name);

	if (t != TOKEN_INVALID) dynprop_append(parent, t);
	return t;
}

/** Recursively construct dynamic property from property template:
 * The 'template' must be part of the device property hierarchy,
 * because all its children will be cloned as well
 */
static
TOKEN property_from_entity(TOKEN parent, void *entity, 
	TOKEN template, const char *name)
{
	TOKEN t, walk;
	PropertyDesc *p;
	const PropertyDesc *child;
	const PropertyDesc *tdesc = getProperty_ByToken(template);


	t = create_property_descriptor(tdesc, entity, name);

	if (t != TOKEN_INVALID) {
		dynprop_append(parent, t);
		// and create its children:
		// Select first child from template:
		walk = property_select(0, template, template);
		while (walk != TOKEN_INVALID) {
			child = getProperty_ByToken(walk);
			property_from_entity(t, entity, walk, child->name);
			// Get successor:
			walk = property_select(0, template, walk);
		}
	}
	return t;
}

int register_fifo(void *entity, char *name)
{
	TOKEN t;
	TOKEN root;
	root = local_getroot(NULL);
	if (root == TOKEN_INVALID) return -1;
	printf("Registering FIFO..\n");
	// Retrieve descriptor for FIFO token (defined externally)
	t = property_from_entity(root, entity, g_t_ghdlex_fifo, name);

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
	if (root == TOKEN_INVALID) return -1;
	// Clone a property instance from the buffer template:
	// t = property_from_template(root, entity, name, &s_buffer_template);

	t = property_from_entity(root, entity, g_t_ghdlex_ram, name);

	if (t == TOKEN_INVALID) {
		printf("Unable to register ram, out of properties?\n");
		return -1;
	}
	printf("Registered RAM property with name '%s'\n", name);
	return 0;
}

int register_bus(void *entity, char *name)
{
	TOKEN t;
	TOKEN root;
	root = local_getroot(NULL);
	if (root == TOKEN_INVALID) return -1;
	// Clone a property instance from the buffer template:
	t = property_from_entity(root, entity, g_t_ghdlex_bus, name);
	if (t == TOKEN_INVALID) {
		printf("Unable to register bus, out of properties?\n");
		return -1;
	}
	printf("Registered BUS property with name '%s'\n", name);
	return 0;
}

#if 0
int register_pty(void *entity, char *name)
{
	PropertyDesc *pname;
	TOKEN t;
	TOKEN root;
	int size = strlen(name) + 1;
	
	pname = property_string_new(size);
	if (!pname) {
		return 0;
	}
	strcpy(pname->access.s_string, name);

	root = local_getroot(NULL);
	if (root == TOKEN_INVALID) return -1;
	// Clone a property instance from the buffer template:
	t = property_from_entity(root, entity, g_t_pty, name);

	if (t == TOKEN_INVALID) {
		printf("Unable to register PTY, out of properties?\n");
		return -1;
	}
	printf("Registered PTY property with name '%s'\n", name);
	return 0;
}
#endif


extern DeviceDesc g_devices[];
extern int g_ndevices;

int netpp_is_initialized(void)
{
	return g_initialized;
}

int netpp_root_init(const char *name)
{
	int error;

	TOKEN t;
	if (g_initialized) {
//		fprintf(stderr, "Root node already initialized, ignoring root %s\n",
//			name);
		return 1;
	}
	register_proplist(g_devices, g_ndevices);

	g_is_dynamic = 1;

	error = dynprop_init(80);
	if (error < 0) return error;

	t = new_dynprop(name, &s_rootprop);
	if (t == TOKEN_INVALID) return -1;
	g_initialized = 1;
	return 0;
}

static
THREAD_RETURN THREAD_DECO netpp_thread(void *arg)
{
	int error;
	struct local_config *cfg = (struct local_config *) arg;
	char *argv[4];
	char portstr[32];
	argv[0] = "sim";

#ifdef SUPPORT_LEGACY_REGISTERMAP
	init_registermap();
#endif

	if (cfg) {
		snprintf(portstr, sizeof(portstr)-1, "--port=%d", cfg->port);
		argv[1] = portstr;
		argv[2] = "--hide";
		argv[3] = NULL;
		error = start_server(3, argv);
	} else {
		argv[0] = NULL;
		error = start_server(1, argv);
	}

	if (error < 0) {
		printf("Failed to start server\n");
		return 0;
	}

	return (THREAD_RETURN) 1;
}


int create_thread(const char *name, struct local_config *cfg)
{
	int error;

#ifdef __WIN32__
	HANDLE g_thread;
#else
	pthread_t g_thread;
#endif


#ifdef __WIN32__
	DWORD thid;
	g_thread = CreateThread(NULL, 0x20000, netpp_thread, (PVOID) cfg,
		0, &thid);
	if (!g_thread) {
		error = -1;
		printf("Failed to create thread\n");
	}
#else
	error = pthread_create(&g_thread, NULL, &netpp_thread, cfg);
#endif
	if (error < 0) return error;
	return 0;
}

static struct local_config cfg;

int netpp_server_init(const char *name, int port)
{
	int error;

	if (port == 0) {
		return create_thread(name, NULL);
	} else {
		cfg.port = port;
		return create_thread(name, (void *) &cfg);
	}
}

integer_ghdl sim_netpp_init_wrapped(struct ghdl_string *name, int port)
{
	// we're allowed to live on the stack, cuz we're only used during
	// configuration

#ifndef CONFIG_NETPP_EARLY_INIT
	int error;
	error = netpp_root_init(name->base);
	if (error < 0) return error;
#else
	fprintf(stderr, "Ignoring device name '%s' in this implementation\n",
		name->base);
#endif
	return netpp_server_init(name->base, port);
}

