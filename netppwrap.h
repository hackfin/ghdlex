/** \file
 * \brief netpp wrapper functions
 *
 * Functions to register a virtual entity with the netpp VPI handler.
 *
 * (c) 2012, <hackfin@section5.ch>
 *
 */

/** \defgroup VPIwrapper   Dynamic entity exporting
 *
 * \example vpiwrapper.c
 */

/** \addtogroup VPIwrapper
 * \{ */


/** Netpp root node initialization. Call before registering any
 * properties.
 *
 * \param name      Name of root node (device name, really)
 */
int netpp_root_init(const char *name);

/** Creates a property name from a VHDL string
 * \param name        The VHDL string pointing to a name
 * \param propname    Buffer to a string
 * \param len         Length of above buffer for size check
 *
 * \warning This function may change the behaviour, i.e. the property
 *          name translation.
 */
int ghdlname_to_propname(const char *name, char *propname, int len);

/** Register a Virtual RAM entity.
 * A shared netpp RAM can be read out and manipulated a RAM while emulating
 * a standard dual port RAM on the VHDL side.
 * \param entity      Pointer to a Ram descriptor structure
 * \param name        The unique property name for the entity
 */
int register_ram(void *entity, char *name);

/** Register a Virtual FIFO entity.
 * \param entity      Pointer to a FIFO descriptor structure
 * \param name        The unique property name for the entity
 */
int register_fifo(void *entity, char *name);

/** \} */
#define FBHANDLE uint32_t
#define DEVHANDLE uint32_t

#define GET_FB(x) s_fbs[x]

struct _propertydesc;

DEVICE get_device(DEVHANDLE dev);
int set_property(DEVICE d, const char *name, void *val, int type);


struct _propertydesc *property_desc_new(struct _propertydesc *template);
