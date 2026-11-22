#!/usr/bin/env bash
# the same harness in bash: 64-bit arithmetic, masked to 32 bits like the others
seed=${1:-0} n=${2:-100}
x=$(( (seed * 2654435761 + 1) & 0xFFFFFFFF ))
rnd() { x=$(( x ^ ((x << 13) & 0xFFFFFFFF) )); x=$(( x ^ (x >> 17) )); x=$(( x ^ ((x << 5) & 0xFFFFFFFF) )); }
s=0
names=(add sub reset)
for (( i = 0; i < n; i++ )); do
	rnd; op=$(( x % 3 )); rnd; a=$(( x % 100 ))
	case $op in
		0) s=$(( s + a > 100 ? 100 : s + a )) ;;
		1) s=$(( s - a < 0 ? 0 : s - a )) ;;
		*) s=0 ;;
	esac
	echo "${names[op]} $a $s"
done
