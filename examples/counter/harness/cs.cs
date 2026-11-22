using System;
using System.Text;

class Harness
{
    static uint x;
    static uint Rnd() { x ^= x << 13; x ^= x >> 17; x ^= x << 5; return x; }

    static void Main(string[] args)
    {
        uint seed = args.Length > 0 ? uint.Parse(args[0]) : 0;
        int n = args.Length > 1 ? int.Parse(args[1]) : 100;
        unchecked { x = seed * 2654435761u + 1; }
        string[] names = { "add", "sub", "reset" };
        long s = 0;
        var o = new StringBuilder();
        for (int i = 0; i < n; i++)
        {
            uint op = Rnd() % 3, a = Rnd() % 100;
            s = op == 0 ? Math.Min(s + a, 100) : op == 1 ? Math.Max(s - a, 0) : 0;
            o.Append(names[op]).Append(' ').Append(a).Append(' ').Append(s).Append('\n');
        }
        Console.Out.Write(o.ToString());
    }
}
