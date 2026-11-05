/* Test tooling only: observe actual native backing requests, including failures. */
#ifndef SCRATCH_PROBE_HEADER
#define SCRATCH_PROBE_HEADER "scratch_cap.h"
#endif
#include SCRATCH_PROBE_HEADER
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
void* __real_realloc(void*, size_t);
void* __real_malloc(size_t);
void* __real_calloc(size_t, size_t);
void __real_free(void*);
static struct { void* pointer; size_t bytes; } allocations[64];
static size_t current, peak, ceiling;
static int calls, fail_at, violated;
static void* allocate(void* old, size_t bytes, int kind) {
    int index = -1;
    for (int i = 0; i < 64; i++) if (allocations[i].pointer == old && old) { index = i; break; }
    size_t before = index >= 0 ? allocations[index].bytes : 0;
    calls++;
    if (current - before + bytes > ceiling) violated = 1;
    if (fail_at && calls == fail_at) return NULL;
    void* pointer = kind == 0 ? __real_realloc(old, bytes) : kind == 1 ? __real_malloc(bytes) : __real_calloc(1, bytes);
    if (!pointer) return NULL;
    if (index < 0) for (int i = 0; i < 64; i++) if (!allocations[i].pointer) { index = i; break; }
    if (index < 0) abort();
    current = current - before + bytes;
    if (current > peak) peak = current;
    allocations[index].pointer = pointer; allocations[index].bytes = bytes;
    return pointer;
}
void* __wrap_realloc(void* old, size_t bytes) { return allocate(old, bytes, 0); }
void* __wrap_malloc(size_t bytes) { return allocate(NULL, bytes, 1); }
void* __wrap_calloc(size_t count, size_t bytes) {
    if (count && bytes > SIZE_MAX / count) return NULL;
    return allocate(NULL, count * bytes, 2);
}
void __wrap_free(void* pointer) {
    for (int i = 0; i < 64; i++) if (pointer && allocations[i].pointer == pointer) {
        current -= allocations[i].bytes; allocations[i].pointer = NULL; allocations[i].bytes = 0; break;
    }
    __real_free(pointer);
}
static void reset(size_t maximum, int failure) {
    if (current) abort();
    peak = 0; ceiling = maximum; calls = 0; fail_at = failure; violated = 0;
}
int main(void) {
    reset(5000000, 0);
    int64_t measured = ScratchProbe(5000000, false);
    int successful_calls = calls;
    if (measured <= 0 || (uint64_t)measured != peak || current || violated) {
        fprintf(stderr, "scratch observation mismatch: reported=%lld actual_peak=%zu current=%zu calls=%d violated=%d\n", (long long)measured, peak, current, calls, violated);
        return 1;
    }
    reset((size_t)measured, 0);
    if (ScratchProbe(measured, false) != measured || peak != (size_t)measured || current || violated) return 2;
    reset((size_t)measured - 1, 0);
    if (ScratchProbe(measured - 1, false) != -6 || current || violated || peak > ceiling) return 3;
    reset(1, 0);
    if (ScratchProbe(1, false) != -6 || calls || current || violated) return 4;
    reset(5000000, 0);
    if (ScratchProbe(5000000, true) != -8 || calls || current || violated) return 5;
    for (int i = 1; i <= successful_calls; i++) {
        reset(5000000, i);
        if (ScratchProbe(5000000, false) != -9 || current || violated) return 6;
    }
    printf("Actual native scratch backing: %lld peak bytes; exact ceiling, one-byte-below limit, precancel and all %d allocation failures passed\n", (long long)measured, successful_calls);
    return 0;
}
