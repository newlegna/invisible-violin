#include "ViolinDSP.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>

struct ViolinDSP {
    _Atomic float target_frequency, target_amplitude;
    _Atomic double updated;
    double rate, phase, amplitude;
};
static double now_seconds(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec * 1e-9;
}
ViolinDSP *violin_create(double rate) {
    ViolinDSP *s = calloc(1, sizeof(ViolinDSP));
    if (!s) return NULL;
    s->rate = rate;

    atomic_init(&s->target_frequency, 440);
    atomic_init(&s->target_amplitude, 0);
    atomic_init(&s->updated, 0);
    return s;
}
void violin_destroy(ViolinDSP *s) { free(s); }
void violin_set(ViolinDSP *s, float frequency, float amplitude) {
    if (!isfinite(frequency) || !isfinite(amplitude)) amplitude = 0;
    atomic_store(&s->target_frequency, fmaxf(100, fminf(2000, frequency)));
    atomic_store(&s->target_amplitude, fmaxf(0, fminf(0.65, amplitude)));
    atomic_store(&s->updated, now_seconds());
}
void violin_render(ViolinDSP *s, float *out, uint32_t count) {
    double frequency = atomic_load(&s->target_frequency);
    double amplitude = atomic_load(&s->target_amplitude);
    // Stop even if camera, inference, or the main UI thread stalls.
    if (now_seconds() - atomic_load(&s->updated) > 0.25) amplitude = 0;
    double envelope = 1 - exp(-1 / (s->rate * (amplitude > s->amplitude ? 0.025 : 0.035)));

    const double weights[] = {1, 0.48, 0.32, 0.24, 0.13, 0.09, 0.055, 0.035};
    for (uint32_t i = 0; i < count; ++i) {
        s->amplitude += (amplitude - s->amplitude) * envelope;
        // Phase stays continuous, but pitch changes directly to the selected note.
        // No automatic portamento or vibrato: the displayed pitch is what sounds.
        double f = frequency;
        double value = 0;
        for (int h = 1; h <= 8; ++h)
            if (h * f < s->rate * 0.45) value += weights[h-1] * sin(h * s->phase);
        out[i] = (float)(value * s->amplitude * 0.32);
        s->phase = fmod(s->phase + 2 * M_PI * f / s->rate, 2 * M_PI);

    }
}
