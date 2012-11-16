/** Dynamic property table building from iteration capable structure */

#include "property_types.h"
#include "dynprops.h"

typedef struct {
	int (*descent)(void **node);
	int (*next)(void **node);
	int (*property_from_node)(void *node, DynPropertyDesc *p);
	unsigned char *buffer;
	unsigned int len;
	unsigned int size;
} Iterator;

int build_proplist(Iterator *it, void **node)
{
	DynPropertyDesc *p;
	void *n = *node;

	if (n == 0) return 0;

	if (it->len + sizeof(*p) >= it->size) {
		printf("Out of memory\n");
		return ERR_MALLOC;
	}

	ret = it->property_from_node(n, &buffer[len]);
	if (ret < 0) return ret;
	


}

#if TEST

	set_rootprop(rootname, p);


int build_props(char *rootname, int n, DynPropertyDesc **props);
{
	DynPropertyDesc *p;
	int n;
	int i;



	


	*props = p;
	return 0;
}

int main(int argc, char **argv)
{

}

#endif
