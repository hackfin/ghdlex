/** VPI netpp wrapper
 *
 * 
 * (c) 2012, <hackfin@section5.ch>
 *
 */

/** \defgroup VPIwrapper   Dynamic entity exporting
 */

/** \addtogroup VPIwrapper
 * \{ */

/** Creates a property name from a VHDL string
 * \param name        The VHDL string pointing to a name
 * \param propname    Buffer to a string
 * \param len         Length of above buffer for size check
 */
int ghdlname_to_propname(const char *name, char *propname, int len);

/** Register a Virtual RAM entity.
 * A shared netpp RAM can be read out and manipulated a RAM while emulating
 * a standard dual port RAM on the VHDL side.
 * \param entity      Pointer to a Ram descriptor structure
 * \param name        The unique property name for the entity
 */
int register_ram(void *entity, char *name);

/** \} */
