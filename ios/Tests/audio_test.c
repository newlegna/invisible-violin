#include "ViolinDSP.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <unistd.h>
static double measured_pitch(float *samples, int count, double rate) {
    double first = -1, last = 0;
    int crossings = 0;
    for (int i=1; i<count; ++i) {
        assert(isfinite(samples[i]) && fabs(samples[i]) < 1);
        if (samples[i-1] <= 0 && samples[i] > 0) {
            double crossing = i-1 + (-samples[i-1])/(samples[i]-samples[i-1]);
            if (first < 0) first = crossing;
            last = crossing;
            crossings++;
        }
    }
    assert(crossings > 3);
    return (crossings-1)*rate/(last-first);
}
int main(void) {
    const int midi[] = {55,57,59,60,62,64,65,67,69,71,72,74,76,77,79,81,83};
    float samples[9600];
    for (int r=0; r<2; ++r) {
        double rate = r ? 44100 : 48000;
        ViolinDSP *s = violin_create(rate);
        assert(s);
        violin_render(s,samples,9600);
        for (int i=0; i<9600; ++i) assert(samples[i] == 0);
        for (int n=0; n<17; ++n) {
            double frequency = 440 * pow(2,(midi[n]-69)/12.0);
            violin_set(s,frequency,0.65);
            violin_render(s,samples,9600);
            assert(fabs(measured_pitch(samples+500,9100,rate)-frequency) < 0.12);
        }
        // A large downward change must immediately settle at D4, with no glide.
        violin_set(s,293.664768,0.65);
        violin_render(s,samples,2000);
        assert(fabs(measured_pitch(samples,2000,rate)-293.664768) < 0.12);
        usleep(300000);
        for (int i=0; i<3; ++i) violin_render(s,samples,9600);
        assert(fabs(samples[9599]) < 0.00001);
        violin_destroy(s);
    }
    puts("Audio checks passed: 17 measured natural-note pitches at 44.1/48 kHz, direct pitch changes, bounded output, silence, and stale-input fadeout.");
}
