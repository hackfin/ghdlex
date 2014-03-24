/** \file
 *
 * \brief Virtual bus structure
 *
 */

/** \defgroup BUS      Exported virtual Bus
 */

/** \addtogroup BUS
 * \{
 */

#define VBUS_ADDR_OFFSET 0x100 ///< Virtual bus address offset

/** The internal bus structure */
typedef
struct bus_t {
	uint32_t addr;             ///< Address
	uint32_t data;             ///< Data
	volatile char flags;       ///< RX/TX software flags
	MUTEX         mutex;     // I/O locking for concurrent threads
} Bus;

#define RX_BUSY 0x01
#define RX_PEND 0x02
#define TX_PEND 0x04

/** \} */
