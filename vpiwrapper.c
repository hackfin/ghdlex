/** \brief VPI example for access of structures via netpp
 *
 * 2012, hackfin@section5.ch
 *
 * This VPI wraps all the signals it finds on the toplevel into
 * dynamic netpp properties that can be queried and manipulated via
 * the various netpp tools.
 *
 * Important little nasty detail and feature:
 * This can only be used with a netpp version >= 0.4 which supports
 * (and is configured accordingly) dynamic properties.
 *
 * Moreover, you must have the simulator executable configured such that
 * it uses both libslave and libmysim as shared library (.so).
 * libslave.so must not have any weak symbols included for these stubs:
 *
 *  - device_read()
 *  - device_write()
 *  - local_getroot()
 *
 * This is necessary for the dynamic libraries to determine the proper root
 * node of the simulator netpp device by only calling these functions
 * from libmysim.
 *
 * This is potentially funky behaviour is due to the following reasons:
 * - Some modules may not call any netpp functionality: netpp.vpi allows
 *   access of the exported (entity) signals
 * - Some modules may already register specific properties with netpp:
 *   These are registered "on top" of the properties that netpp.vpi exports
 *   from the signals
 * - Some modules use specific VPIs with default static properties.
 *   That means, they have a set of default properties plus some dynamic
 *   properties that are depending on its configuration.
 *
 * All these modules should also be able to be called without a specific
 * VPI attached.
 *
 * Intermixing dynamic and static properties is possible from netpp 0.4
 * with the existing mechanism of class derivation. A VPI registers a
 * default static property table and adds a dynamic root node providing
 * a reference to the static properties (base class).
 *
 */

#include <stdlib.h>
#include <stdio.h>
#include "devlib_types.h"
#include "devlib_error.h"
#include "property_types.h"
#include "slave.h"
#include "dynprops.h"
#include "vpi_user.h"
#include <pthread.h>
#include "netppwrap.h"

int binstr_to_uint(const char *l, int nbits, uint32_t *val)
{
	uint32_t v = 0;
	while (nbits--) {
		v <<= 1;
		switch (*l) {
			case '1': v |= 1; break;
			case '0': break;
			default:
				fprintf(stderr, "Undefined value in %s\n", __FUNCTION__);
				*val = 0xffffffff;
				return -1;
		}
		l++;
	}
	*val = v;
	return 0;
}

void uint_to_binstr(char *l, int nbits, uint32_t val)
{
	uint32_t pos;
	
	while (nbits--) {
		pos = 1 << nbits;
		if (val & pos) {
			*l = '1';
		} else {
			*l = '0';
		}
		l++;
	}
}

int v_handler(void *p, int write, DCValue *val)
{
	s_vpi_value v;
	char str[32];
	int size;

	uint32_t uval;

	v.format = vpiBinStrVal;

	// Obtain size:
	vpi_get_value((vpiHandle) p, &v);
	size = strlen(v.value.str);


	if (write) {
		switch (val->type) {
			case DC_BOOL:
				if (val->value.i) {
					str[0] = '1';
				} else {
					str[0] = '0';
				}
				break;
			case DC_INT:
				uint_to_binstr(str, size, val->value.i);
				break;
			case DC_BUFFER:
				// TODO
				return DCERR_PROPERTY_TYPE_MATCH;
			default:
				return DCERR_PROPERTY_TYPE_MATCH;
		}
		v.value.str = str;
		vpi_put_value((vpiHandle) p, &v, NULL, vpiNoDelay);
	} else {
		binstr_to_uint(v.value.str, size, &uval);
		val->value.i = uval;
	}
	return 0;
}

PropertyDesc s_property_template = {
	.type = DC_BOOL,
	.flags = F_RW,
	.where = DC_CUSTOM,
	.access = { .custom = { v_handler, 0 } },
};

TOKEN property_from_signal(TOKEN parent, vpiHandle sig)
{
	const char *name;
	int size;
	PropertyDesc *p;
	TOKEN t;
	s_vpi_value v;

	name = vpi_get_str(vpiName, sig);
	v.format = vpiBinStrVal;
	vpi_get_value(sig, &v);
	size = strlen(v.value.str);

	p = property_desc_new(&s_property_template);
	if (!p) return TOKEN_INVALID;

	// Store vpi handle in property
	p->access.custom.p = sig;

	if (size <= 32) {
		if (size == 1)
			p->type = DC_BOOL;
		else
			p->type = DC_INT;
	} else {
		p->type = DC_BUFFER;
	}
	
	t = new_dynprop(name, p);
	dynprop_append(parent, t);
	return t;
}

int scan(struct t_cb_data *cb)
{
	const char *name;
	vpiHandle top_iter;
	vpiHandle module;
	vpiHandle sig_iter;
	vpiHandle scope;
	vpiHandle sig;

	TOKEN root;


	root = local_getroot(NULL);

	top_iter = vpi_iterate(vpiModule, NULL);
	module = vpi_scan(top_iter);
	if (module == NULL) {
		printf("Module has no nets\n");
		return -1;
	}
	scope = vpi_handle(vpiScope, module);
	if (scope) {
		sig_iter = vpi_iterate (vpiNet, scope);
		if (sig_iter) {
			while ((sig = vpi_scan (sig_iter)) != NULL) {
				name = vpi_get_str(vpiName, sig);
				property_from_signal(root, sig);
			}
		}
	}
	return 0;
}

void *netpp_thread(void *arg)
{
	int error;
	char *argv[] = {
		"", (char *) arg
	};
	error = start_server(1, argv);
	if (error < 0) return 0;
	return (void *) 1;
}

pthread_t g_thread;

int initialize(struct t_cb_data *cb)
{
	int error;
	// Init for some dynamic properties:
	netpp_root_init("VPI_GHDLwrapper");
	scan(cb);
	
	error = pthread_create(&g_thread, NULL, &netpp_thread, NULL);

	return error;
}

void my_handle_register()
{
	s_cb_data cb;

	cb.reason = cbEndOfCompile;
	cb.cb_rtn = &initialize;
	cb.user_data = 0;
	if (vpi_register_cb(&cb) == NULL)
	vpi_printf("cannot register EndOfCompile call back\n");
}

void (*vlog_startup_routines[]) () =
{
	my_handle_register,
	0
};
