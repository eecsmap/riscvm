long fib(long n) {
    long a = 0;
    long b = 1;
    while (n-- > 0) {
        long temp = a;
        a = b;
        b = temp + a;
    }
    return a;
}
