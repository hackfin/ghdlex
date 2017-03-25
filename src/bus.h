/** \file
 *
 * \brief Virtual bus structure
 *
 */

#include <stdint.h>
#include "threadaux.h"

/** \defgroup BUS      Exported virtual Bus
 *
 * These functions are typically used by a handler function like
 * device_read() or device_write() inside the netpp wrapper.
 */

/** \addtogroup BUS
 * \{
 */

#ifdef SUPPORT_LEGACY_REGISTERMAP
#define VBUS_ADDR_OFFSET 0x100 ///< Virtual bus address offset
#endif

/** The internal bus structure */
typedef
struct bus_t {
	uint32_t addr;             ///< Address
	uint32_t data;             ///< Data
	int      width;            ///< Bus width (Bytes)
	volatile char flags;       ///< RX/TX software flags
	MUTEX         mutex;       // I/O locking for concurrent threads
	uint32_t      timeout_ms;  ///< Bus timeout in ms
	unsigned char *tmpbuf;     // Buffer for I/O transaction
	uint32_t       bufsize;    // Buffer size
} Bus;

#define RX_BUSY    0x01
#define RX_PEND    0x02
#define TX_PEND    0x04
#define BUS_LE     0x10 // Little endian

#define BUS_AUXBUFSIZE 0x100

/** Bus reading function */
int bus_read(Bus *bus, unsigned char *buf, int size);

/** Bus write function */
int bus_write(Bus *bus, const unsigned char *buf, int size);

/** Bus single value read */
int bus_val_rd(Bus *bus, uint32_t addr, uint32_t *val);
/** Bus single value write */
int bus_val_wr(Bus *bus, uint32_t addr, uint32_t val);

/** \} */
