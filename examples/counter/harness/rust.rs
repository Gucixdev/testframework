use std::env;

fn main() {
    let a: Vec<String> = env::args().collect();
    let n: u32 = a.get(2).and_then(|v| v.parse().ok()).unwrap_or(100);
    let mut x: u32 = a.get(1).and_then(|v| v.parse::<u32>().ok()).unwrap_or(0).wrapping_mul(2654435761).wrapping_add(1);
    let mut rnd = || {
        x ^= x << 13;
        x ^= x >> 17;
        x ^= x << 5;
        x
    };
    let mut s: i64 = 0;
    for _ in 0..n {
        let op = rnd() % 3;
        let arg = rnd() % 100;
        let name = match op {
            0 => "add",
            1 => "sub",
            _ => "reset",
        };
        match op {
            0 => s = (s + arg as i64).min(100),
            1 => s = (s - arg as i64).max(0),
            _ => s = 0,
        }
        println!("{name} {arg} {s}");
    }
}
