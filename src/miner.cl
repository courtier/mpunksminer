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

// we are assuming bytes len = 32 and out len = 32
// https://github.com/ethereum/solidity/blob/develop/libsolutil/Keccak256.cpp
constant uchar RHO[24] = {1,  3,  6,  10, 15, 21, 28, 36, 45, 55, 2,  14,
                          27, 41, 56, 8,  25, 43, 62, 18, 39, 61, 20, 44};
constant uchar PI[24] = {10, 7,  11, 17, 18, 3, 5,  16, 8,  21, 24, 4,
                         15, 23, 19, 13, 12, 2, 20, 14, 22, 9,  6,  1};
// i think this can be converted to 32 bit to have better performance
// see: https://gist.github.com/chrisveness/433ba370cb78f9aef50d2d17ba940091
constant ulong RC[24] = {1ULL,
                         0x8082ULL,
                         0x800000000000808aULL,
                         0x8000000080008000ULL,
                         0x808bULL,
                         0x80000001ULL,
                         0x8000000080008081ULL,
                         0x8000000000008009ULL,
                         0x8aULL,
                         0x88ULL,
                         0x80008009ULL,
                         0x8000000aULL,
                         0x8000808bULL,
                         0x800000000000008bULL,
                         0x8000000000008089ULL,
                         0x8000000000008003ULL,
                         0x8000000000008002ULL,
                         0x8000000000000080ULL,
                         0x800aULL,
                         0x800000008000000aULL,
                         0x8000000080008081ULL,
                         0x8000000000008080ULL,
                         0x80000001ULL,
                         0x8000000080008008ULL};
#define rol(x, s) (((x) << s) | ((x) >> (64 - s)))
#define REPEAT6(e) e e e e e e
#define REPEAT24(e) REPEAT6(e e e e)
#define REPEAT5(e) e e e e e
#define FOR5(type, v, s, e)                                                    \
  v = 0;                                                                       \
  REPEAT5(e; v = (type)(v + s);)

inline void keccakf(void *state) {
  ulong *a = (ulong *)state;
  ulong b[5] = {0};

  for (int i = 0; i < 24; i++) {
    uchar x, y;
    // Theta
    FOR5(uchar, x, 1, b[x] = 0; FOR5(uchar, y, 5, b[x] ^= a[x + y];))
    FOR5(
        uchar, x, 1,
        FOR5(uchar, y, 5, a[y + x] ^= b[(x + 4) % 5] ^ rol(b[(x + 1) % 5], 1);))
    // Rho and pi
    ulong t = a[1];
    x = 0;
    REPEAT24(b[0] = a[PI[x]]; a[PI[x]] = rol(t, RHO[x]); t = b[0]; x++;)
    // Chi
    FOR5(uchar, y, 5,
         FOR5(uchar, x, 1, b[x] = a[y + x];)
             FOR5(uchar, x, 1,
                  a[y + x] = b[x] ^ ((~b[(x + 1) % 5]) & b[(x + 2) % 5]);))
    // Iota
    a[0] ^= RC[i];
  }
}

#define _(S)                                                                   \
  do {                                                                         \
    S                                                                          \
  } while (0)
#define FOR(i, ST, L, S) _(for (size_t i = 0; i < L; i += ST) { S; })
#define mkapply_ds(NAME, S)                                                    \
  static inline void NAME(uchar *dst, uchar const *src, size_t len) {          \
    FOR(i, 1, len, S);                                                         \
  }
#define mkapply_sd(NAME, S)                                                    \
  static inline void NAME(uchar const *src, uchar *dst, size_t len) {          \
    FOR(i, 1, len, S);                                                         \
  }

mkapply_ds(xorin, dst[i] ^= src[i]); // xorin
mkapply_sd(setout, dst[i] = src[i]); // setout

#define P keccakf
#define Plen 200

// Fold P*F over the full blocks of an input.
#define foldP(I, L, F)                                                         \
  while (L >= rate) {                                                          \
    F(a, I, rate);                                                             \
    P(a);                                                                      \
    I += rate;                                                                 \
    L -= rate;                                                                 \
  }

inline void hash(uchar *out, size_t outlen, uchar const *in, size_t inlen,
                 size_t rate, uchar delim) {
  uchar a[Plen] = {0};
  // Absorb input.
  foldP(in, inlen, xorin);
  // Xor in the DS and pad frame.
  a[inlen] ^= delim;
  a[rate - 1] ^= 0x80;
  // Xor in the last block.
  xorin(a, in, inlen);
  // Apply P
  P(a);
  // Squeeze output.
  foldP(out, outlen, setout);
  setout(a, out, outlen);
  // dont think this particularly does anything
  // memset(a, 0, 200);
}

kernel void miner_init(global uchar *bytes_prefix, const ulong range_start,
                       const ulong difficulty_target,
                       global ulong *nonce_results, global uint *result_index) {
  ulong worker_id = (ulong)get_global_id(0);
  if (range_start >= ULONG_MAX - worker_id)
    return;
  ulong nonce = range_start + worker_id;
  // ulong nonce = 4416973503411977525;
  uchar local_bytes[32];
  uint i;
  for (i = 0; i < 24; i++) {
    local_bytes[i] = bytes_prefix[i];
  }
  local_bytes[31] = nonce & 255;
  local_bytes[30] = (nonce >> 8) & 255;
  local_bytes[29] = (nonce >> 16) & 255;
  local_bytes[28] = (nonce >> 24) & 255;
  local_bytes[27] = (nonce >> 32) & 255;
  local_bytes[26] = (nonce >> 40) & 255;
  local_bytes[25] = (nonce >> 48) & 255;
  local_bytes[24] = (nonce >> 56) & 255;
  /*for (i = 0; i < 32; i++) {
    printf("%d-", local_bytes[i]);
  }
  printf("\n");*/
  // hash to decimal then cast to ulong by doing (number & 0xFFFFFFFF)
  // what did i mean by this?
  // TODO
  // uchar test[4] = "test";
  uchar hash_bytes[32];
  hash(hash_bytes, 32, local_bytes, 32, 200 - (256 / 4), 0x01);
  /*uchar charset[16] = "0123456789abcdef";
  char buf[66];
  uint buf_i = 0;
  for (i = 0; i < 32; i++) {
    buf[buf_i] = charset[hash_bytes[i] >> 4];
    buf_i += 1;
    buf[buf_i] = charset[hash_bytes[i] & 15];
    buf_i += 1;
  }
  buf[buf_i] = 0;
  buf[64] = '\0';
  for (i = 0; i < 65; i++) {
    printf("%c", buf[i]);
  }
  printf("\n");*/
  // hex is 4 bits, we have 256 bit hash
  // we want 64 bit integer 16 hex digits
  // we will have to truncate from 128 bit to 88
  // if it overflows ulong that means its greather than
  // difficulty_target so we just return false
  ulong result = 0;
  uint power = 22;
  ulong tmp;
  i = 21;
  // 0x10000000000000000
  while (i < 32) {
    // if (result + ((hash_bytes[i] >> 4) * SIXTEEN_POWERS[power]) <
    //     difficulty_target) {
    // if (result + ((hash_bytes[i] >> 4) * SIXTEEN_POWERS[power++]) >
    // (0x10000000000000000-1)) {
    if (power > 15 && ((hash_bytes[i] >> 4) != 0 || (hash_bytes[i] & 15) != 0))
      return;
    tmp = (hash_bytes[i] >> 4) * SIXTEEN_POWERS[power--];
    if (result > ULONG_MAX - tmp) {
      return;
    }
    result += tmp;
    // } else
    //   return;
    // if (result + ((hash_bytes[i] & 4) * SIXTEEN_POWERS[power]) <
    //     difficulty_target) {
    tmp = (hash_bytes[i] & 15) * SIXTEEN_POWERS[power];
    if (result > ULONG_MAX - tmp) {
      return;
    }
    result += tmp;
    if (power > 0)
      power--;
    // } else
    //   return;
    i++;
  }
  //  printf("result: %d\n", result);
  // printf("%d\n", result);
  // if result overflows it goes into negatives
  // is this platform dependent? should i be relying on this?
  // probbably not.
  if (result < difficulty_target) {
    atomic_inc(result_index);
    nonce_results[*result_index] = nonce;
  }
}
