/* LD_PRELOAD fault injector: the INJECT_N-th call (counting malloc, calloc, realloc, mmap together) fails with
 * ENOMEM; every later call works again. INJECT_N=0 injects nothing. Build: cc -shared -fPIC -o inject.so inject.c -ldl */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>

static long calls, target = -1;

static int fail_now(void)
{
    if (target < 0) { const char *e = getenv("INJECT_N"); if (!e) { ++calls; return 0; } /* environ not set up yet, or not asked */ target = atol(e); }
    ++calls;
    return target > 0 && calls == target;
}

/* INJECT_REPORT=FILE: write the number of injectable calls the run made, so a driver knows how far to sweep */
__attribute__((destructor)) static void report(void)
{
    const char *f = getenv("INJECT_REPORT");
    FILE *o = f ? fopen(f, "w") : 0;
    if (o) { fprintf(o, "%ld\n", calls); fclose(o); }
}
#define REAL(name) static __typeof__(&name) real; if (!real) real = dlsym(RTLD_NEXT, #name)

void *malloc(size_t n) { REAL(malloc); int f = fail_now(); if (f) { errno = ENOMEM; return 0; } return real(n); }
void *realloc(void *p, size_t n) { REAL(realloc); int f = fail_now(); if (f) { errno = ENOMEM; return 0; } return real(p, n); }
void *mmap(void *a, size_t n, int pr, int fl, int fd, off_t o)
{ REAL(mmap); int f = fail_now(); if (f) { errno = ENOMEM; return MAP_FAILED; } return real(a, n, pr, fl, fd, o); }
