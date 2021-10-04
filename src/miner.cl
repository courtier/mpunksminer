// difficulty target is <64 bits, use 64 bit int
// ulong is 64 bit
// randomize bytes, not nonce ??

inline void encode_nonce(char *bytes, ulong nonce) {
  // 8 bytes
  bytes[31] = nonce & 255;
  bytes[30] = (nonce >> 8) & 255;
  bytes[29] = (nonce >> 16) & 255;
  bytes[28] = (nonce >> 24) & 255;
  bytes[27] = (nonce >> 32) & 255;
  bytes[26] = (nonce >> 40) & 255;
  bytes[25] = (nonce >> 48) & 255;
  bytes[24] = (nonce >> 56) & 255;
}

kernel void miner_init(global ulong *nonces, constant char *bytes_prefix,
                       global ulong *nonce_result, global uint *result_index,
                       constant ulong *range_start) {
  uint worker_id = (ulong)get_global_id(0);
  ulong nonce = *range_start + worker_id;
  char local_bytes[32];
  for (uint i = 0; i < 24; i++) {
      local_bytes[i] = bytes_prefix[i];
  }
  encode_nonce(local_bytes, nonce);
  
  // TODO
  bool valid_nonce = true;
  if (valid_nonce) {
    atomic_inc(result_index);
    nonce_result[*result_index] = nonce;
  }
}
