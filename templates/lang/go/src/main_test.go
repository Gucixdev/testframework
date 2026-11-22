package main

import "testing"

func TestAdd(t *testing.T) {
	if Add(2, 3) != 5 || Add(-1, 1) != 0 {
		t.Fatal("add")
	}
}
