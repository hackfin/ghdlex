/** Virtual Framebuffer implementation via netpp display server
 *
 * (c) 2011, Martin Strubel <hackfin@section5.ch>
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include "netpp.h"
#include "display/display.h"
#include "ghpi.h"
#include "netppwrap.h"
#include <signal.h>

#define MAX_NUM_FBS     1


typedef struct {
	unsigned long size;
	unsigned short type;
	unsigned short width, height;
	void *data;
	unsigned short bpp;
	DEVICE device;
	TOKEN token;
} FBuffer;

static
FBuffer *s_fbs[MAX_NUM_FBS] = { 0 };

void sim_releasefb(FBHANDLE handle);

FBHANDLE new_fb(void)
{
	int i;
	FBuffer *fb;

	for (i = 0; i < MAX_NUM_FBS; i++) {
		if (s_fbs[i] == 0) {
			fb = (FBuffer *) malloc(sizeof(FBuffer));
			if (!fb) return -1;
			s_fbs[i] = fb;
			return i;
		}
	}
	return -1;
}

void del_fb(FBHANDLE handle)
{
	free(s_fbs[handle]);
	s_fbs[handle] = 0;
}

void break_handler(int n)
{
	int i;
	int val = 1;
	printf("Hit Ctrl-C, cleaning up...\n");

	for (i = 0; i < MAX_NUM_FBS; i++) {
		if (GET_FB(i)) {
			printf("Terminating stream %d\n", i);
			set_property(GET_FB(i)->device, "Stream.Stop", &val, DC_COMMAND);
			sim_releasefb(i);
		}
	}
	
	exit(-1);
}


framebuffer_t_ghdl sim_initfb(DEVHANDLE dev,
	integer_ghdl w, integer_ghdl h, integer_ghdl type)
{
	unsigned long size;
	void *buf;
	short bpp = 16;
	short pixelsize;
	int error;
	int i;

	FBHANDLE handle = new_fb();
	if (handle < 0) return handle;

	FBuffer *fb = GET_FB(handle);

	DEVICE d = get_device(dev);
	
	switch (type) {
		case VIDEOMODE_8BIT: bpp = 8;
		case VIDEOMODE_INDEXED: break;
		case VIDEOMODE_UYVY: break;
		default:
			return -1;
	}

	pixelsize = (bpp + 7) / 8;
	size = w * h * pixelsize;
	buf = malloc(size);
	if (!buf) return -1;
	memset(buf, 0, size);
	fb->size = size;
	fb->data = buf;
	fb->width = w;
	fb->height = h;
	fb->type = type;
	fb->bpp = bpp;
	fb->device = d;

	error = dcProperty_ParseName(d, "Stream.Data", &fb->token);
	if (error < 0) {
		fprintf(stderr,
			"Doesn't seem to be a netpp display server we're talking to\n");
		return error;
	}

	// Configure display:
	set_property(d, "Stream.X", &w, DC_INT);
	set_property(d, "Stream.Y", &h, DC_INT);
	i = bpp; set_property(d, "Stream.BitsPerPixel", &i, DC_MODE);
	set_property(d, "Mode", &type, DC_MODE);
	i = 1; set_property(d, "Stream.Start", &i, DC_COMMAND);

	signal(SIGINT, break_handler);

	return 0;
}

void sim_setpixel(FBHANDLE handle, int x, int y, char *slv)
{
	int error;
	unsigned long offset;
	unsigned short bits, bytes;
	uint32_t val;
	FBuffer *fb = GET_FB(handle);

	bits = fb->bpp;
	bytes = (bits + 7) / 8;

	offset = y * fb->width + x;

	error = logic_to_uint(slv, bits, &val);
#ifdef DEBUG
	if (error < 0) {
		printf("Undefined pixel value at (%d, %d)\n", x, y);
		val = 0xffffffff;
	}
#endif

	switch (bytes) {
		case 2:
			( (uint16_t *) fb->data )[offset] = val;
			break;
		case 1:
			( (uint8_t *) fb->data )[offset] = val;
			break;
	}
}

void sim_releasefb(FBHANDLE handle)
{
	FBuffer *fb = GET_FB(handle);
	free(fb->data);
	del_fb(handle);
}

void sim_updatefb(FBHANDLE handle)
{
	FBuffer *fb = GET_FB(handle);
	printf("Updating buffer size %ld\n", fb->size);
	set_buffer(fb->device, fb->token, fb->data, fb->size);
}


void sim_setfb(FBHANDLE handle, struct ghdl_string *pixdata)
{
	FBuffer *fb = GET_FB(handle);
	unsigned long size;
	short pixelsize;
	uint32_t val;
	uint16_t *dst2;
	uint8_t  *dst1;
	short bpp;

	size = pixdata->bounds->len;

	if (size > fb->size) {
		size = fb->size;
		fprintf(stderr, "Warning: Size truncated\n");
	}

	char *data = pixdata->base;

	bpp = fb->bpp;
	pixelsize = (bpp + 7) / 8;

	switch (pixelsize) {
		case 2:
			dst2 = (uint16_t *) fb->data;
			while (size--) {
				logic_to_uint(data, bpp, &val);
				data += bpp;
				*dst2++ = val;
			}
			break;
		case 1:
			dst1 = (uint8_t *) fb->data;
			while (size--) {
				logic_to_uint(data, bpp, &val);
				data += bpp;
				*dst1++ = val;
			}
			break;
		default: return;
	}
}


