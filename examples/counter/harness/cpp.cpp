#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <algorithm>

int main(int argc, char **argv) {
	int n = argc > 2 ? std::atoi(argv[2]) : 100;
	uint32_t x = argc > 1 ? static_cast<uint32_t>(std::atoi(argv[1])) * 2654435761u + 1 : 1;
	auto rnd = [&x] { x ^= x << 13; x ^= x >> 17; x ^= x << 5; return x; };
	long s = 0;
	const char *names[] = {"add", "sub", "reset"};
	for (int i = 0; i < n; i++) {
		unsigned op = rnd() % 3, a = rnd() % 100;
		if (op == 0) s = std::min(s + static_cast<long>(a), 100L);
		else if (op == 1) s = std::max(s - static_cast<long>(a), 0L);
		else s = 0;
		std::printf("%s %u %ld\n", names[op], a, s);
	}
}
