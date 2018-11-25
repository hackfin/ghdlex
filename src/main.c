/** \file
 *
 * Main program launcher to start GHDL simulation from
 *
 */
#include <stdio.h>
#include <libgen.h>
#include "ghpi.h"

int ghdl_main(int argc, char **argv);

int main(int argc, char **argv)
{
	int error;
	const char *name;

#ifdef CONFIG_NETPP_EARLY_INIT
	name = basename(argv[0]);
	
	error = netpp_root_init(name);
#endif
	if (error >= 0) {
		error = ghdl_main(argc, argv);
	}
	return error;
}
