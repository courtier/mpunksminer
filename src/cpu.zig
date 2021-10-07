const clap = @import("clap/clap.zig");
const gpu = @import("gpu.zig");
const Config = @import("config.zig");
const std = @import("std");
const fmt = std.fmt;
const crypto = std.crypto;
const time = std.time;
const os = std.os;
const process = std.process;
const debug = std.debug;
const io = std.io;
const log = std.log;
const atomic = std.atomic;
const math = std.math;
const random = std.crypto.random;
const Thread = std.Thread;
const Atomic = atomic.Atomic;
const ArrayList = std.ArrayList;
const Keccak_256 = crypto.hash.sha3.Keccak_256;

var config: Config = Config{};

var gpa_allocator = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = &gpa_allocator.allocator;

const MAX_POWER_I = 16;
const SIXTEEN_POWERS: [MAX_POWER_I]u64 = blk: {
    var buf: [MAX_POWER_I]u64 = undefined;
    var i: usize = 0;
    while (i < MAX_POWER_I) {
        buf[i] = pow(16, i);
        i += 1;
    }
    break :blk buf;
};

//take the sha3.zig and modify that too, surely i could speed it up
//also make it return binary perhaps

fn calculateBytesPrefix() [32]u8 {
    var buff: [32]u8 = undefined;
    var last = config.last_mined;
    var addy = config.address;
    var i: usize = 11;
    while (i > 0) {
        buff[i] = @truncate(u8, last);
        last >>= 8;
        i -= 1;
    }
    buff[i] = @truncate(u8, last);
    i = 20;
    while (i > 12) {
        buff[i] = @truncate(u8, addy);
        addy >>= 8;
        i -= 1;
    }
    buff[i] = @truncate(u8, addy);
    buff[21] = '0';
    buff[22] = '0';
    buff[23] = '0';
    return buff;
}

//maybe remove the @truncate and replace with shift
//use u64?
fn encodeNonceOnly(nn: u64) [32]u8 {
    var buff: [32]u8 = config.bytes_prefix;
    var nonce = nn;
    var i: usize = 31;
    while (i > 24) {
        buff[i] = @truncate(u8, nonce);
        nonce >>= 8;
        i -= 1;
    }
    buff[i] = @truncate(u8, nonce);
    return buff;
}

fn bytesToInt(bytes: [11]u8) u64 {
    var res: u64 = 0;
    var power: usize = 22;
    var i: usize = 0;
    if (bytes[10] != '0' or bytes[9] != '0' or bytes[8] != '0')
        return math.maxInt(u64);
    while (i < 11) {
        power -= 1;
        res += (bytes[i] >> 4) * SIXTEEN_POWERS[power];
        power -= 1;
        res += (bytes[i] & 15) * SIXTEEN_POWERS[power];
        i += 1;
    }
    return res;
}

fn pow(nt: u64, pt: u64) u88 {
    var res: u64 = 1;
    var p = pt;
    var n = nt;
    while (true) {
        if (p & 1 != 0)
            res *= n;
        p >>= 1;
        if (p == 0)
            break;
        n *= n;
    }
    return res;
}

fn isNonceValid(nonce: u64) bool {
    var pack = encodeNonceOnly(nonce);
    var h: [Keccak_256.digest_length]u8 = undefined;
    Keccak_256.hash(pack[0..], &h, .{});
    var n = bytesToInt(h[21..].*);
    return n < config.gpu_difficulty_target;
}

fn miner(range_start: u64, range_end: u64) !void {
    log.err("miner thread id: {d} - amount: {d} - start: {d}", .{ Thread.getCurrentId(), range_end - range_start, range_start });
    var n = range_start;
    while (n < range_end) {
        if (isNonceValid(n))
            log.err("found nonce: {d}. CHECK IF THIS PRODUCES A OG PUNK BEFORE MINTING!", .{n});
        n += 1;
    }
}

pub fn cpuThreads(tc: usize) !void {
    var i: usize = 0;
    var count: usize = tc;
    var threads: []Thread = try gpa.alloc(Thread, count);
    defer gpa.free(threads);
    var start: u64 = random.int(u64);
    var before_time = time.nanoTimestamp();
    log.err("mining cycle start time: {d}", .{before_time});
    while (i < count) {
        var thread = try Thread.spawn(.{}, miner, .{ start, start + config.test_range_increment });
        threads[i] = thread;
        start += config.test_range_increment + 1;
        i += 1;
    }
    i = 0;
    while (i < count) {
        threads[i].join();
        i += 1;
    }
    var after_time = time.nanoTimestamp();
    log.err("mining cycle end time: {d}, diff: {d}", .{ after_time, after_time - before_time });
}
