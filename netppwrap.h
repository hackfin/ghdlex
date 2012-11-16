/* Temporary, chaotic header */

#define FBHANDLE uint32_t
#define DEVHANDLE uint32_t

#define GET_FB(x) s_fbs[x]

struct _propertydesc;

DEVICE get_device(DEVHANDLE dev);
int set_property(DEVICE d, const char *name, void *val, int type);

int netpp_root_init(const char *name);

struct _propertydesc *property_desc_new(struct _propertydesc *template);
