/** \file
 * 	\brief  This is the API definition for the GHDL <-> C wrapper.
 *
 * This file is called from the h2vhdl converter several times with
 * the following parametrization
 *
 * - #define RUN_TYPES : Define VHDL data type strings
 * - #define RUN_CHEAD : Define C header table
 * - None              : Define VHDL wrapper table

 * (c) 2011, 2012  Martin Strubel <hackfin@section5.ch>

 * Call API macro auxiliaries:
 */

/** \defgroup GHPIfuncs    Autowrapped functions callable from GHDL
 * 
 * This module lists the so far semi-automatically wrapped C functions
 * that can be accessed from the GHDL simulation. If you want to add more
 * functionality, edit apidef.h.
 *
 * It includes a number of type definitions for abstraction of data exchange
 * between C and GHDL.
 *
 * \attention Note that the GHDL API may change any time. In order to
 *            make adaptations to those changes least painful, it is
 *            important to make use of the type definitions and not use the
 *            raw structures directly.
 *
 * A few functions have the special suffix '_wrapped'. The reason is, that
 * GHDL strings are not null-terminated, thus those functions are wrapped
 * within a VHDL routine that appends a '\\0' byte. Those wrappers are found
 * in the lib<module>.chdl file.
 *
 * For the exact VHDL type interface, see generated libnetpp.vhdl. Currently,
 * the documentation for the autowrapped interface can only be displayed
 * in C API style.
 *
 * Basically, you can follow this rule: A C function returning a parameter
 * is also a function in VHDL. If return void_ghdl, it is a VHDL procedure.
 * For all other type definitions, omit the _ghdl suffix when using it in
 * VHDL.
 *
 * \example simnetpp.vhdl
 *
 */

#define _C1 /
#define _C2 *!--
#define _CONCAT(x, y) x##y
#define _RESOLVE(x,y) _CONCAT(x, y)
#define COMMENT _RESOLVE(_C1,_C2)


#undef APIDEF_UNINITIALIZE
#include "apimacros.h"

/** \addtogroup GHPIfuncs
 * \{ */

/* Type definitions for C<->GHDL interface.
 *
 * Note: You have to define these types in libnetpp.chdl
 *
 */

// Standard simple types:

/** A 32 bit signed integer */
DEFTYPE_EXPLICIT(integer, int32_t)
/** A GHDL interface 'fat pointer' */
DEFTYPE_EXPLICIT(string, struct fat_pointer *)
/** Pointer to constrained unsigned array */
DEFTYPE_EXPLICIT(unsigned, struct fat_pointer *)
/** Void */
DEFTYPE_EXPLICIT(void, void)

// NETPP wrapper types:
/** A netpp device handle */
DEFTYPE_HANDLE32(netpphandle_t)
/** Netpp device property token */
DEFTYPE_HANDLE32(token_t)
/** Framebuffer handle */
DEFTYPE_HANDLE32(framebuffer_t)
/** Pixel array type */
DEFTYPE_FATP(pixarray_t)
/** Single pixel type */
DEFTYPE_SLV(pixel_t, 16)
/** RAM16 data vector */
DEFTYPE_SLV(ram16_t, 16)
/* A generic handle (EXPERIMENTAL) */
DEFTYPE_EXPLICIT(handle_t, uint32_t *)

/* Note: If you add a PROTO structure, you have to explicitely define
 * the access type in libnetpp.chdl for now. */

/* A RAM buffer handle */
DEFTYPE_PROTOSTRUCT(rambuf_t, struct RamDesc)

/* A FIFO buffer handle */
DEFTYPE_PROTOSTRUCT(duplexfifo_t, struct duplexfifo_t)

DEFTYPE_SLV(fifoflag_t, 6)

/* A Bus type handle */
DEFTYPE_PROTOSTRUCT(bus_t, struct bus_t)

DEFTYPE_SLV(busflag_t, 3)

/* Pointer to constrained unsigned array */
DEFTYPE_SLV(regaddr_t, 8)
DEFTYPE_SLV(byte_t, 8)


/** Open netpp device
 * \param id    A netpp device identifier
 * \return A netpp device handle
 */
API_DEFFUNC( device_open_wrapped,     _T(netpphandle_t),
	ARG(id, string))

VHDL_COMMENT("Set integer value on netpp remote device")
VHDL_COMMENT("@param t   The property token, obtained by device_gettoken()")
VHDL_COMMENT("@param v   A 32 bit integer")
API_DEFFUNC( device_set_int,  _T(integer),
	ARG(h, netpphandle_t), ARG(t, token_t), ARG(v, integer))

API_DEFFUNC( device_set_register,  _T(integer),
	ARG(h, netpphandle_t), ARG(t, token_t), ARG(v, integer))



/** Get property token from device by name
 * \param h    The netpp device handle
 * \param id   The property name
 *
 * \return A device token
 *
 * This function will make the simulation exit if the property is not found.
 */
API_DEFFUNC( device_gettoken_wrapped, _T(token_t),
	ARG(h, netpphandle_t), ARG(id, string))

VHDL_COMMENT("Close connection to remote device")
API_DEFPROC( device_close,     _T(void),
	ARG(h, netpphandle_t))

VHDL_COMMENT("Initialize remote frame buffer device")
VHDL_COMMENT("@param dev      A netpp framebuffer capable device handle")
VHDL_COMMENT("@param w        Width of the framebuffer")
VHDL_COMMENT("@param h        Height of the frame buffer")
VHDL_COMMENT("@param buftype  One of VIDEOMODE_8BIT, VIDEOMODE_UYVY, VIDEOMODE_INDEXED")
VHDL_COMMENT("               For supported video modes, see display/videomodes.h")
API_DEFFUNC( initfb,          _T(framebuffer_t),
	ARG(dev, netpphandle_t),
	ARG(w, integer), ARG(h, integer), ARG(buftype, integer) )

VHDL_COMMENT("Set pixel on remote frame buffer")
VHDL_COMMENT(" @param x      X coordinate")
VHDL_COMMENT(" @param y      Y coordinate")
VHDL_COMMENT(" @param pixel  Pixel value")
API_DEFPROC( setpixel,        _T(void),
	ARG(fb, framebuffer_t),
		ARG(x, integer), ARG(y, integer), ARG(pixel, pixel_t) )

VHDL_COMMENT("Write entire remote frame buffer")
VHDL_COMMENT("@param data   Pointer to VHDL frame buffer type")
API_DEFPROC( setfb,           _T(void),
	ARG(fb, framebuffer_t), ARG(data, pixarray_t))

VHDL_COMMENT("Send update event to framebuffer")
API_DEFPROC( updatefb,        _T(void),
	ARG(fb, framebuffer_t))

VHDL_COMMENT("Release remote framebuffer")
API_DEFPROC( releasefb,       _T(void),
	ARG(fb, framebuffer_t))

VHDL_COMMENT("Read from dummy register map. At the moment only 8 bit wide")
VHDL_COMMENT("@param addr  Register map address")
VHDL_COMMENT("@param data  Register map data")
API_DEFPROC( regmap_read, _T(void), ARG(addr, regaddr_t), ARGO(data, unsigned))

VHDL_COMMENT("Write to dummy register map. At the moment only 8 bit wide")
VHDL_COMMENT("@param addr  Register map address")
VHDL_COMMENT("@param data  Register map data")
API_DEFPROC( regmap_write, _T(void), ARG(addr, regaddr_t), ARG(data, unsigned))

VHDL_COMMENT("Sleep for 'cycles' microseconds")
VHDL_COMMENT("@param cycles sleep time in us")
API_DEFPROC( usleep,       _T(void), ARG(cycles, integer))

VHDL_COMMENT("Throttle simulation")
VHDL_COMMENT("@param activity When toggled, do not sleep")
VHDL_COMMENT("@param cycles   sleep time in us")
API_DEFPROC( throttle,     _T(void), ARG(activity, byte_t),
             ARG(cycles, integer) )

/* New FIFO API */

/* Wrapped function, see fifo_new in libnetpp.chdl */
API_DEFFUNC( fifo_new_wrapped, _T(duplexfifo_t),
	ARG(name, string),
	ARG(size, integer),
	ARG(wordsize, integer)
	)

API_DEFPROC( fifo_rxtx, _T(void), ARGIOP(df, duplexfifo_t),
	ARGIO(data, unsigned),
	ARGIO(flags, fifoflag_t)
	)

VHDL_COMMENT("Delete FIFO")
API_DEFPROC( fifo_del,        _T(void), ARGIOP(fifo, duplexfifo_t))

/* Virtual Bus API */

/* Wrapped function, see bus_new in libnetpp.chdl */
API_DEFFUNC( bus_new_wrapped, _T(bus_t),
	ARG(name, string),
	ARG(width, integer)
	)


VHDL_COMMENT("Virtual Bus I/O")
VHDL_COMMENT("@param vbus     Bus handle")
VHDL_COMMENT("@param addr     Address bus")
VHDL_COMMENT("@param data     Data bus")
VHDL_COMMENT("@param flags    Bus flags")
API_DEFPROC( bus_rxtx, _T(void), ARGIOP(vbus, bus_t),
	ARGIO(addr, unsigned),
	ARGIO(data, unsigned),
	ARGIO(flags, busflag_t)
	)

VHDL_COMMENT("Delete Bus")
API_DEFPROC( bus_del,        _T(void), ARGIOP(vbus, bus_t))

/* RAM stuff */

/* Allocate new RAM buffer, wrapper */
API_DEFFUNC( ram_new_wrapped, _T(rambuf_t),
	ARG(name, string),
	ARG(size, integer))

VHDL_COMMENT("Write to RAM buffer")
VHDL_COMMENT("@param addr  word address")
VHDL_COMMENT("@param data  input data")
API_DEFPROC( ram_write,       _T(void), ARGIOP(ram, rambuf_t),
	ARGIO(addr, unsigned), ARGO(data, ram16_t))

VHDL_COMMENT("Read from RAM buffer")
VHDL_COMMENT("@param addr  word address")
VHDL_COMMENT("@param data  output data")
API_DEFPROC( ram_read,        _T(void), ARGIOP(ram, rambuf_t),
	ARGIO(addr, unsigned), ARG(data, ram16_t))

VHDL_COMMENT("Delete and free RAM buffer")
API_DEFPROC( ram_del,         _T(void), ARGIOP(ram, rambuf_t))

/** Explicit netpp initialization. Apply this when not using --vpi=netpp.vpi
 */
VHDL_COMMENT("Initialize netpp root node")
API_DEFFUNC( netpp_init_wrapped, _T(integer),
	ARG(name, string) )

/** \} */

/* Test functions only */
API_DEFFUNC( get_ptr,       _T(handle_t), ARG(dev, netpphandle_t))

API_DEFPROC( set_ptr,       _T(void), ARGIO(h, handle_t))


// Call API macro auxiliaries:
// Call them again to clean up what they defined:
#define APIDEF_UNINITIALIZE
#include "apimacros.h"
