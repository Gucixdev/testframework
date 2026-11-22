const seed = process.argv[2] ? Number(process.argv[2]) : 0;
const n = process.argv[3] ? Number(process.argv[3]) : 100;
let x = (Math.imul(seed, 2654435761) + 1) >>> 0;
const rnd = () => {
  x = (x ^ (x << 13)) >>> 0;
  x = (x ^ (x >>> 17)) >>> 0;
  x = (x ^ (x << 5)) >>> 0;
  return x;
};
let s = 0;
const out = [];
for (let i = 0; i < n; i++) {
  const op = rnd() % 3, a = rnd() % 100;
  s = op === 0 ? Math.min(s + a, 100) : op === 1 ? Math.max(s - a, 0) : 0;
  out.push(`${["add", "sub", "reset"][op]} ${a} ${s}`);
}
console.log(out.join("\n"));
