#ifndef ViolinDSP_h
#define ViolinDSP_h
#include <stdint.h>
typedef struct ViolinDSP ViolinDSP;
ViolinDSP *violin_create(double sample_rate);
void violin_destroy(ViolinDSP *dsp);
void violin_set(ViolinDSP *dsp, float frequency, float amplitude);
void violin_render(ViolinDSP *dsp, float *output, uint32_t count);
#endif
