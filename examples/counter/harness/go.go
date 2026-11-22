package main

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
)

func main() {
	n := 100
	var x uint32 = 1
	if len(os.Args) > 1 {
		v, _ := strconv.ParseUint(os.Args[1], 10, 32)
		x = uint32(v)*2654435761 + 1
	}
	if len(os.Args) > 2 {
		n, _ = strconv.Atoi(os.Args[2])
	}
	rnd := func() uint32 { x ^= x << 13; x ^= x >> 17; x ^= x << 5; return x }
	w := bufio.NewWriter(os.Stdout)
	defer w.Flush()
	s := int64(0)
	for i := 0; i < n; i++ {
		op, a := rnd()%3, rnd()%100
		name := [3]string{"add", "sub", "reset"}[op]
		switch op {
		case 0:
			s = min(s+int64(a), 100)
		case 1:
			s = max(s-int64(a), 0)
		default:
			s = 0
		}
		fmt.Fprintf(w, "%s %d %d\n", name, a, s)
	}
}
