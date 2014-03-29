/** \file apimacros.h
 *
 * \brief Nasty macros for multiple path definition expansion between
 *        C and GHDL interface
 *
 * (c) 2011-2013, Martin Strubel <hackfin@section5.ch>
 */

#ifdef APIDEF_UNINITIALIZE
#	undef VHDL_COMMENT
#	undef _T
#	undef API_DEF
#	undef ARG
#	undef ARGO
#	undef ARGIO
#	undef ARGIOP
#	undef DEFTYPE_EXPLICIT
#	undef DEFTYPE_PROTOSTRUCT
#	undef DEFTYPE_SLV
#else

// Run the actual definition:

#define SHIFT_ARGS(x, ...) __VA_ARGS__

#if defined(RUN_TYPES)
#	define VHDL_COMMENT(x)
#	ifdef DEBUG
#	warning "Running Type generation mode"
#	endif
#	define _T(t) s_vhdl_type_##t
#	define DEFTYPE_EXPLICIT(t, def) \
	static const char _T(t)[] = #t;

#define DEFTYPE_PROTOSTRUCT(t, def) \
	static const char _T(t)[] = #t;
#	define DEFTYPE_SLV(t, s) \
	static const char _T(t)[] = #t;
#	define API_DEF(t, nm, ret, ...)
#elif defined(RUN_CHEAD)
#	ifdef DEBUG
#	warning "Running C header mode"
#	endif

// This section contains the generated Doxygen documentation

// Hack: We have to guard comments using this define, otherwise
// the documentation turns up in doc_apidef.h
#ifndef NO_MACRO_DOCS

/** \defgroup Macros       Macro documentation
 */

/** \addtogroup Macros
 * \brief Internal macros
 *
 * These macros are used in apidef.h
 *
 * \{ */


/** Add VHDL comment. This is translated into the VHDL sources
 * run through doxygen
 */
#endif // NO_MACRO_DOCS
#	define VHDL_COMMENT(x)
#	define _T(t) t##_ghdl
#ifndef NO_MACRO_DOCS
/** Creates an explicit typedef for the specified VHDL data type.
 * The VHDL data type has a '_ghdl' suffix on the C side. See also
 * \ref GHPI_Wrap
 * \param t      Type name
 * \param def    C definition
 */
#endif
#	define DEFTYPE_EXPLICIT(t, def) \
	typedef def _T(t);
#ifndef NO_MACRO_DOCS
/** Macro to define another data proxy type for both C and VHDL side
 * \param t      The VHDL data type (must be defined in libnetpp.chdl
 *               or elsewhere
 * \param def    The corresponding C data type (defined externally)
 */
#endif
#	define DEFTYPE_PROTOSTRUCT(t, def) \
	def; typedef def * _T(t);
#ifndef NO_MACRO_DOCS
/** Creates VHDL typedef for a std_logic_vector
 * \param t      Type name
 * \param s      Size of vector in bits
 */
#endif
#	define DEFTYPE_SLV(t, s) \
	typedef char _T(t)[s];
#	define API_DEF(t, nm, ret, ...) \
	ret sim_##nm(__VA_ARGS__);
#	define ARG(n, t) _T(t) n
#	define ARGO(n, t) ARG(n, t)
#	define ARGIO(n, t) ARG(n, t)
#	define ARGIOP(n, t) ARG(*n, t)


#ifndef NO_MACRO_DOCS
/** \} */
#endif

#else
#	ifdef DEBUG
#	warning "Running VHDL mode"
#	endif
#	define VHDL_COMMENT(x) { .type = TYPE_COMMENT, .name = x },
#	define _T(t) s_vhdl_type_##t
#	define DEFTYPE_EXPLICIT(t, def)
#	define DEFTYPE_PROTOSTRUCT(t, def)
#	define DEFTYPE_SLV(t, s)
#	define ARG(n, t) #n, _T(t), 0
#	define ARGO(n, t) #n, _T(t), "out"
#	define ARGIO(n, t) #n, _T(t), "inout"
#	define ARGIOP(n, t) #n, _T(t), "inout"
#	define API_DEF(t, nm, ret, ...) \
	{ .type = t, .name = #nm, .retitem = ret, \
	.parameters = { __VA_ARGS__, NULL }},

#endif

#define API_DEFFUNC(...) API_DEF(TYPE_FUNC, __VA_ARGS__)
#define API_DEFPROC(...) API_DEF(TYPE_PROC, __VA_ARGS__)


#define DEFTYPE_HANDLE32(t) DEFTYPE_EXPLICIT(t, uint32_t)
#define DEFTYPE_FATP(t)     DEFTYPE_EXPLICIT(t, struct fat_pointer *)

#	define ARG_O(n, t) _T(t) n

#endif // UNINITIALIZE
