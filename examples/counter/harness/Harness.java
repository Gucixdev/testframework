public class Harness {
    public static void main(String[] args) {
        long seed = args.length > 0 ? Long.parseLong(args[0]) : 0;
        int n = args.length > 1 ? Integer.parseInt(args[1]) : 100;
        long[] x = {(seed * 2654435761L + 1) & 0xFFFFFFFFL};
        String[] names = {"add", "sub", "reset"};
        long s = 0;
        StringBuilder out = new StringBuilder();
        for (int i = 0; i < n; i++) {
            int op = (int) (rnd(x) % 3);
            long a = rnd(x) % 100;
            s = op == 0 ? Math.min(s + a, 100) : op == 1 ? Math.max(s - a, 0) : 0;
            out.append(names[op]).append(' ').append(a).append(' ').append(s).append('\n');
        }
        System.out.print(out);
    }

    static long rnd(long[] x) {
        long v = x[0];
        v ^= (v << 13) & 0xFFFFFFFFL;
        v ^= v >>> 17;
        v ^= (v << 5) & 0xFFFFFFFFL;
        x[0] = v;
        return v;
    }
}
