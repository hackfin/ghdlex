/** Example implementation of direct variable access via the netpp
 * property mechanisms.
 */

/** Define this, when you wish to use the derived class
 *  with experimental code. */

#define EXPERIMENTAL

#ifdef EXPERIMENTAL
#	define DEVICE_INDEX 1
#else
#	define DEVICE_INDEX 0
#endif

#define BUFSIZE    0x200
#define STRINGSIZE 64

void init_registermap(void);

extern int g_timeout;
