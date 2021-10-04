// difficulty target is <64 bits, use 64 bit int
// ulong is 64 bit
// nonce is 8 bytes
// randomize bytes, not nonce ??

kernel void miner_init(constant char *bytes_prefix, constant ulong *range_start,
                       global ulong *nonce_results, global uint *result_index) {
  uint worker_id = (ulong)get_global_id(0);
  ulong nonce = (*range_start) + worker_id;
  char local_bytes[32];
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
  // hash to decimal then cast to ulong by doing (number & 0xFFFFFFFF)
  // TODO
  bool valid_nonce = true;
  if (valid_nonce) {
    atomic_inc(result_index);
    nonce_results[*result_index] = nonce;
  }
}
