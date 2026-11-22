#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

static uint32_t x;
static uint32_t rnd(void) { x ^= x << 13; x ^= x >> 17; x ^= x << 5; return x; }

int main(int argc, char **argv) {
	int n = argc > 2 ? atoi(argv[2]) : 100;
	x = argc > 1 ? (uint32_t)atoi(argv[1]) * 2654435761u + 1 : 1;
	long s = 0;
	for (int i = 0; i < n; i++) {
		unsigned op = rnd() % 3, a = rnd() % 100;
		const char *name = op == 0 ? "add" : op == 1 ? "sub" : "reset";
		if (op == 0) { s += a; if (s > 100) s = 100; }
		else if (op == 1) { s -= a; if (s < 0) s = 0; }
		else s = 0;
		printf("%s %u %ld\n", name, a, s);
	}
	return 0;
}
