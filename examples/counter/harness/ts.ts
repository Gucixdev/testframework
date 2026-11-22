declare const process: { argv: string[] };

const seed: number = process.argv[2] ? Number(process.argv[2]) : 0;
const n: number = process.argv[3] ? Number(process.argv[3]) : 100;
let x: number = (Math.imul(seed, 2654435761) + 1) >>> 0;
function rnd(): number {
  x = (x ^ (x << 13)) >>> 0;
  x = (x ^ (x >>> 17)) >>> 0;
  x = (x ^ (x << 5)) >>> 0;
  return x;
}
const names: string[] = ["add", "sub", "reset"];
let s = 0;
const out: string[] = [];
for (let i = 0; i < n; i++) {
  const op: number = rnd() % 3, a: number = rnd() % 100;
  s = op === 0 ? Math.min(s + a, 100) : op === 1 ? Math.max(s - a, 0) : 0;
  out.push(`${names[op]} ${a} ${s}`);
}
console.log(out.join("\n"));
