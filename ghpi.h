/** \file ghpi.h
 * GHDL VHPI C interface specifics
 *
 * (c) 2011, Martin Strubel <hackfin@section5.ch>
 *
 * Important: Note that a std_logic_vector array is passed in the
 * char * pointers, regardless of the bit order
 * (LSB to MSB) or (MSB downto LSB).
 *
 * Thus, for a MSB downto LSB array, you have to reverse the indexing!
 *
 */

#include <stdint.h>

/** char value definitions of std_logic_vector array:
 */

#define UNDEFINED 0 ///< Undefined; VHDL: 'U'
#define INVALID_X 1 ///< Invalid;   VHDL: 'X'
#define LOW       2 ///< Low;       VHDL: '0'
#define HIGH      3 ///< High;      VHDL: '1'
#define TRISTATE  4 ///< High Z;    VHDL: 'Z'

// Used for string passing. Stolen from Yanns helpful example.

/* Structure to describe array boundarys. Used by a fat_pointer */
struct int_bounds
{
	int left;
	int right;
	char dir;
	unsigned int len;
};

/* GHDL fat pointer. Fat pointers are enhanced descriptors for
 * unconstrained VHDL arrays. In this extension library, they are exclusively
 * used for strings and unconstrained SLVs.
 */
struct fat_pointer
{
	void              *base;
	struct int_bounds *bounds;
};

#define ghdl_string fat_pointer

// Generate function prototypes:
#define RUN_CHEAD
#include "apidef.h"
#undef RUN_CHEAD

// Standard simple types:


////////////////////////////////////////////////////////////////////////////
// Functions

/** \defgroup Auxiliary    Auxiliary functions for conversion, etc.
 *
 * These are internal functions to convert between GDHL data and C data
 * structures.
 *
 */

/** \addtogroup Auxiliary
 * \{ */

/** Convert std_logic_vector to unsigned short */
int logic_to_uint(const char *l, int nbits, uint32_t *val);
/** Convert std_logic_vector to unsigned short */
void uint_to_logic(char *l, int nbits, uint32_t val);
/** Convert logic to byte sequence. Matches the bit order of the
 * std_logic_vector
 */
int logic_to_bytes(char *l, int n, void *data);
/** Convert logic to 16 bit word sequence. Matches the bit order of the
 * std_logic_vector
 */
int logic_to_words(char *l, int n, void *data);
/** Convert byte sequence to logic. */
void bytes_to_logic(char *l, int n, const void *data);
/** Convert 16 bit word sequence to logic */
void words_to_logic(char *l, int n, const void *data);
/** Set all std_logic members of a std_logic_vector to 'val' */
void fill_slv(char *l, int nbits, unsigned char val);

/** \} */

/** Debugging */

void dump_bits(unsigned char c);
void hexdump(char *buf, unsigned long n);

/*!
 * \mainpage GHDLex documentation
 * \version 0.05develop
 * \author Martin Strubel
 * \date 03/2014
 *
 * \section Intro     Introduction
 *
 * This code collection is an attempt to gather a few useful routines
 * into a pool of reusable functionality. It is FAR from being a real
 * library, but technically, we treat it as one.
 *
 * The main purpose is to enable GHDL to communicate easily with external
 * applications in both directions, for example, to read in real data samples
 * or output processing results to a existing and proven software driver.
 * 
 * This 'library' makes heavy use again of the netpp library. The reason is
 * that netpp already provides an efficient framework for test benching via
 * scripts as well as many I/O features spread across the network.
 * So you can easily realize a distributed processing and simulation solution
 * without having to move hardware around or even restructure your entire
 * lab. So for example, you could grab the current measurement samples from
 * the LHC lab, the SETI project and the CERN and run it through your VHDL RTL
 * description :-)
 *
 * Also, it offers a certain level of abstraction which makes it easy
 * to swap software components or VHDL entities.
 *
 * \section Start      Getting started
 * 
 * Currently, ghdlex operates in the following variants:
 *   -# Quick and dirty enhancement of existing test benches using the
 *     \c --vpi option
 *   -# Simple usage of "virtual entity" implementations that automatically
 *     initialize the netpp interface
 *   -# Explicit linkage and calling of "ghpi wrappers" (\ref GHDLIntf)
 *
 * The first method is the simplest, you just add netpp property
 * functionality to an existing test bench. The \c netpp.vpi shared library
 * module scans the top level signals of the test bench and exports them
 * as dynamic properties.
 *
 * The second method is almost as simple. Typically, you add a virtualized
 * entity to your design or you just flip a configuration statement to
 * use the simulation architecture of an entity. For example, you instance
 * the VFIFO entity in your design and a separate netpp thread is
 * automatically started when you run the simulation.
 *
 * The third method is the direct access to netpp. This can be tricky, as
 * netpp can have the role of a master, of a slave, or both.
 * For example, the simulation would be a master in case it drives a virtual
 * frame buffer and requires no more interaction. Typically it acts as a
 * slave when it uses the VFIFO only. 
 * You'll have to somewhat dig into the netpp internals. Quite a few netpp data
 * structures can be accessed from VHDL. This method requires you to become
 * familiar with the \subpage GHPI_Wrap module.
 *
 * \subsection VirtualEntities Virtual Entities
 *
 * There are only a few default virtual entities that come with ghdlex:
 *
 *  - VFIFO:       A multiply instanceable virtual FIFO
 *  - DualPort16:  Dual port RAM simulation
 *  - VirtualBus:  A simple virtual bus master for testing slave devices
 *  - VirtualFIFO: A FIFO buffer (standalone, one instance): DEPRECATED!
 *
 * They all depend on netpp, so they call netpp_init() at start up of
 * the simulation.
 *
 * Previously, some of those modules did require to load the netpp.vpi
 * module on top. This is no longer necessary, as soon as they call
 * netpp_init(), the netpp API is initialized. If not, your simulation
 * will stop with a Null pointer exception and write a warning about
 * using netpp.vpi.
 *
 * It is not a problem to load the netpp.vpi on top of an already
 * initialized netpp server, but you will also get a warning on the
 * console. Future versions may run an extra server on a separate port.
 *
 * The VFIFO is normally the first thing to implement for testing
 * a hardware and software design in cooperation. From the host side, it
 * works like a typical FIFO adapter that is accessed through USB or
 * a serial interface.
 *
 * For example to access the virtual FIFO on the simulation, start
 * 'simboard'. This will, among other things, output something like:
 *
 * \code
Reserved FIFO ':simboard:nfifo(0):fifo:' with word size 1, size 0x400
Initialize FIFO with word width of 8 bits
Initialize FIFO with word width of 8 bits
ProbeServer listening on UDP Port 7208...
Listening on UDP Port 2008...
Listening on TCP Port 2008...
\endcode
 * Then run the python script test.py from another console:
 *
 * \code
python test.py
\endcode
 *
 * You will now see a simple loop back of the bytes sent from the
 * Python script.
 *
 * From the slave side, there are a few example implementations for:
 *  - A virtual frame buffer that can be filled by your VGA timing generator
 *  - An interface to measurement devices to read a waveform from a
 *    scope using the TMC protocol
 *
 * If you wish to used more FIFOs and other virtual entities in your design,
 * you might rather use the VFIFO instead. See also \ref VPIwrapper.
 * 
 * \section GHDLIntf   GHDL interfacing
 *
 * \subsection GHPI The VHPI interface (GHPI)
 *
 * As mentioned, there is no official 'API' for GHDL. There are implementations
 * that seem to conform to the public VHPI specifications, this library
 * is not yet making use of the VHPI interface. Instead, it is using
 * potentially dangerous methods to access the GHDL internal structures
 * directly.
 *
 * So, even if there is no official "clean" way to do it, we should at least
 * keep the potential changes in one place and automate wrapping and data
 * type exchange as far as possible. Therefore you are encouraged to use
 * meta types so that you will not have to change your test bench simulation
 * code all over if the API changes.
 *
 * For a short comparison between C and VHDL/Ada (the latter being the
 * actual heart of GHDL), we can definitely reassert that there are many
 * more data type variants in VHDL than in C. This can make the interfacing
 * complex. So far, we have only covered a few data types:
 *
 * - unsigned/std_logic_vector (constrained and unconstrained)
 * - string (unconstrained)
 * - integer
 * - Some specific handles for interfacing with external units
 *
 * All currently covered types are found in the typedef section of the
 * \ref GHPI_Wrap module.
 *
 * The following modules provide the API for the GHPI extension:
 * - \subpage GHPI_Wrap    
 * - \subpage GHPI_Netpp
 * - \subpage GHPI_Pipe  
 *
 * From the C API side:
 * - \subpage Auxiliary
 * - \subpage FIFO
 *
 *
 * \subsection VPI The VPI interface
 *
 * The VPI interface originates from the Verilog world and allows simple
 * signal manipulation from external processes as well.
 * GHDL implements only a small subset of VPI, however this is sufficient
 * for interactive manipulation of signals. The difference from GHDLs
 * VHPI implementation is, that there is support for loading of VPI
 * extensions (which are simply shared libraries with a specific API).
 * The ghdlex VPI wrapper for netpp exports top level signals to netpp
 * properties which can be manipulated remotely through a C interface
 * or Python scripts.
 * See \ref VPIwrapper for details.
 *
 * Note that this way of pin manipulation is <b>not real time</b> in
 * terms of simulation. The "now" on the software side is not defined
 * on the simulation side. Therefore you could miss a signal, when it
 * is pulsed from the software side too fast. However, this can be a good
 * test for your design, although we would recommend to use the VPI
 * interface only for rather static signals. If you try to mimick a
 * clock signal, it will likely go wrong.
 *
 * \section Functionality
 *
 * \subsection FuncSlave      Generic data I/O with external applications
 *
 * In this case, a GHDL simulation acts as slave (or server).
 * For data I/O with external programs, there are two examples
 * (see example/ folder):
 *
 * - pipe.vhdl : Simple file based I/O using named Unix pipes
 * - fifo.vhdl : A thread based software FIFO implementation, that
 *                  can be compiled to accept data over the network from
 *                  a netpp client (virtual driver)
 *
 * \subsection FuncMaster     Data output to various devices
 *
 * In the following examples, GHDL is used as a master (or client),
 * talking to external devices.
 *
 * - netpp.vhdl: A simple example for setting a register value on a
 *                  remote device.
 * - fb.vhdl:    Demonstrates a YUV format display output to a remote
 *                  framebuffer (the netpp display server)
 *
 * These examples can easily be modified to write directly to local devices
 * instead of going through remote handlers.
 *
 * \section VPIwrapper Automated netpp interfacing through VPI
 *
 * The VPIwrapper for netpp can be added to any existing test bench and
 * does the following:
 * - Look for signals in the top level module
 * - Create and export dynamic properties within netpp according to these
 *   signals
 * - Make the signals directly accessible trough netpp
 *
 * As an example, a testbench is loaded with the netpp.vpi module:
 *
 * \code ./simx --vpi=netpp.vpi \endcode
 *
 * and responds with:
 * \code
loading VPI module 'netpp.vpi'
VPI module loaded!
Reserved RAM ':simram:ram0:' with word size 0x1000(8192 bytes)
ProbeServer listening on UDP Port 7208...
Registered RAM property with name ':simram:ram0:'
Listening on UDP Port 2008...
Reserved RAM ':simram:ram1:' with word size 0x1000(8192 bytes)
Listening on TCP Port 2008...
Registered RAM property with name ':simram:ram1:'
\endcode
 * 
 * From the client side, the top level properties of this module can be
 * accessed as follows:
 * \code netpp localhost \endcode
 * \code
Child: [80000001] 'clk'
Child: [80000002] 'we'
...
Child: [00000002] 'Enable'
Child: [00000005] 'Irq'
Child: [00000007] 'Reset'
Child: [00000008] 'Throttle'
Child: [00000009] 'Timeout'
Child: [00000003] 'Fifo'
\endcode
 *
 * The properties shown with capitals are static and inherited from a
 * default GHDL wrapper device. This does not necessarily have to be the
 * case. It is up to the netpp device implementation, what properties
 * it exhibits or what device description it inherits from.
 *
 * Instances of virtual entities are displayed in the VHDL path name
 * notation, like
\code
:simram:ram0:\endcode
 *
 * Accessing these properties from Python raises a little issue with the
 * Python name space rules, as member names of that sort are not allowed.
 * Therefore, you have to get the property token by using the getattr()
 * function, like
 *
\code
ram0 = getattr(root_node, ":simram:ram0:") \endcode

 *
 * Manipulating a pin means, setting a netpp property:
 * \code netpp localhost we 1 # Set 'we' to HIGH \endcode
 *
 * Note that this manipulation can interfere with internal stimuli.
 * If you change signals like the 'clk' signal which is typically
 * generated inside the VHDL test bench, randomly inexplicable behaviour
 * can occur.
 *
 * \subsection RealTime  Timing versus Real Time
 *
 * As the simulation always runs slower than the real world, you have to
 * introduce some timing tricks to make software cooperate properly with the
 * simulation. For example, when using a VFIFO, the software has to use
 * greater timeouts to wait for the simulation to finish.
 *
 * On the other hand, you might not want to run the simulation at full speed
 * when it is not interacting with the software. For this case, the VFIFO
 * entity has a throttle pin. If '1', the Virtual FIFO will sleep the
 * specified SLEEP_CYCLES when there is no activity.
 *
 * That way, a simulation time scale can somewhat be controlled such that
 * it looks like "real time" (with respect to a scale).
 *
 * Some other entities that may not be contained in the free ghdlex
 * distribution use the global_throttle signal. The user has to assign
 * this signal himself on the top level implementation.
 * The example board.vhdl demonstrates how the global_throttle signal
 * is controlled from outside via netpp via a property definition.
 *
 * When using the netpp.vpi module, you can manipulate this signal
 * automatically from the netpp side by its name in the hierarchy.
 *
 * Also, there might be a global_dbgclk signal for some debugger entities.
 * Make sure this signal is driven from the top level simulation, otherwise
 * your units may not act. For most of these debugger units, there is
 * a USE_GLOBAL_CLK generic flag that is false by default, i.e. you will
 * have to use a clock specification. For detailed information, please
 * refer to the specific debug module section.
 *
 * \subsection Extending Extending Autowrapping
 *
 * Because a lot of manual coding needs to be done in order to wrap
 * a C routine by a VHDL call, some highly experimental tricks to abuse
 * the C preprocessor are used. Basically, a .chdl file will be turned into
 * a .vhdl file. See Makefile for specific rules.
 * This allows to resolve #define and #include statements and makes
 * the API definition somewhat easier, since all can be generated from one
 * header file.
 *
 * The important files:
 * - apidef.h: The API definition
 * - libnetpp.chdl: The C template for the autowrapped netpp library package
 *
 * If you wish to add another virtual entity, you will have to touch 
 * these files. Typically, the steps are:
 *
 * -# Add another access data type (see handle_t in \c libnetpp.chdl)
 * -# Add another #DEFTYPE_PROTOSTRUCT entry in \c apidef.h
 * -# Implement netpp side handlers for the defined data structure
 *    (see also netppwrap.h)
 * -# Define the property template for this entity: Add a property in
 *    ghdlsim.xml, and provide it with a named, unique 'id' attribute.
 * -# For registering the new virtual entity with netpp, see
 *    register_fifo() for example. The template token is retrieved via
 *    the external corresponding token variable initialized in the generated
 *    file proplist.c. It has the form g_t_<id>.
 *
 *
 * Files for hackers - please only extend, don't change:
 *
 * - apimacros.h: The dirty stuff under the hood
 * - h2vhdl.c: The vhdl package generator
 *
 * \section Restrictions Restrictions or bugs
 *
 *
 * \bug ghdlex is not endian safe! For all buffer properties, it is assumed
 *      that the host the simulation is running on has the same endianness
 *      as the client (tested is little endian only). Endian safety is only
 *      given with netpp integers and of course byte wide buffers.
 *
 * \bug Not all top level signals can be exported to netpp.
 *
 * \bug GHDL is not fully thread safe. You might need a modified version,
 *      if manipulation through netpp.vpi causes weird behaviour.
 *
 * \example board.vhdl
 * \example netpp.vhdl
 * \example pipe.vhdl
 * \example fb.vhdl
 * \example dpram16.vhdl
 * \example vfifo.vhdl
 *
*
 *
 */
