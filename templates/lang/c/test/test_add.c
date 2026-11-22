#include <stdio.h>
#include "../src/add.h"

int main(void) {
	if (add(2, 3) != 5 || add(-1, 1) != 0) { puts("FAIL add"); return 1; }
	puts("ok   add");
	return 0;
}
