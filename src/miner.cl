constant ulong SIXTEEN_POWERS[] = {1,
                                  16,
                                  256,
                                  4096,
                                  65536,
                                  1048576,
                                  16777216,
                                  268435456,
                                  4294967296,
                                  68719476736,
                                  1099511627776,
                                  17592186044416,
                                  281474976710656,
                                  4503599627370496,
                                  72057594037927936,
                                  1152921504606846976};

//difficulty target is <64 bits, use 64 bit int
//ulong is 64 bit
//randomize bytes, not nonce ??

kernel void miner_init(char *bytes_prefix, ulong range_start) {}
