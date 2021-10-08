const clap = @import("clap/clap.zig");
const gpu = @import("gpu.zig");
const cpu = @import("cpu.zig");
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

const SIXTEEN_POWERS: [22]u88 = blk: {
    var buf: [22]u88 = undefined;
    var i: usize = 0;
    while (i < 22) {
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
    return buff;
}

//maybe remove the @truncate and replace with shift
//use u64?
fn encodeNonceOnly(nn: u88) [32]u8 {
    var buff: [32]u8 = config.bytes_prefix;
    var nonce = nn;
    var i: usize = 31;
    while (i > 21) {
        buff[i] = @truncate(u8, nonce);
        nonce >>= 8;
        i -= 1;
    }
    buff[i] = @truncate(u8, nonce);
    return buff;
}

fn bytesToInt(bytes: [11]u8) u88 {
    var res: u88 = 0;
    var power: usize = 22;
    var i: usize = 0;
    while (i < 11) {
        power -= 1;
        res += (bytes[i] >> 4) * SIXTEEN_POWERS[power];
        power -= 1;
        res += (bytes[i] & 15) * SIXTEEN_POWERS[power];
        i += 1;
    }
    return res;
}

fn pow(nt: u88, pt: u88) u88 {
    var res: u88 = 1;
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

fn isNonceValid(nonce: u88) bool {
    var pack = encodeNonceOnly(nonce);
    var h: [Keccak_256.digest_length]u8 = undefined;
    Keccak_256.hash(pack[0..], &h, .{});
    var n = bytesToInt(h[21..].*);
    return n < config.difficulty_target;
}

fn miner(range_start: u88, range_end: u88) !void {
    log.err("miner thread id: {d} - amount: {d} - start: {d}", .{ Thread.getCurrentId(), range_end - range_start, range_start });
    var n = range_start;
    while (n < range_end) {
        if (isNonceValid(n))
            log.err("found nonce: {d}. CHECK IF THIS PRODUCES A OG PUNK BEFORE MINTING!", .{n});
        n += 1;
    }
}

fn cpuThreads(tc: usize) !void {
    var i: usize = 0;
    var count: usize = tc;
    var threads: []Thread = try gpa.alloc(Thread, count);
    defer gpa.free(threads);
    var start: u88 = random.int(u88);
    var before_time = time.nanoTimestamp();
    log.err("mining cycle start time: {d}", .{before_time});
    while (i < count) {
        var thread = try Thread.spawn(.{}, miner, .{ start, start + config.range_increment });
        threads[i] = thread;
        start += config.range_increment;
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

pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("-h, --help                 Display help.") catch unreachable,
        clap.parseParam("-g, --gpu                  Use GPU, default is CPU.") catch unreachable,
        //todo add option to use a set amount of devices, or even pick which device(s)
        clap.parseParam("-m, --multi                Use all OpenCL GPUs available.") catch unreachable,
        clap.parseParam("-t, --threads <NUM>        Amount of threads.") catch unreachable,
        clap.parseParam("-w, --wallet <STR>         ETH wallet address.") catch unreachable,
        clap.parseParam("-l, --lastmined <NUM>      Last mined punk.") catch unreachable,
        clap.parseParam("-d, --difficulty <NUM>     Difficulty target.") catch unreachable,
        clap.parseParam("-i, --increment <NUM>      # of hashes per cpu thread.") catch unreachable,
        //todo add option to change gpu work amount
        clap.parseParam("--test                     Run in test mode.") catch unreachable,
    };

    var args = try clap.parse(clap.Help, &params, .{});
    defer args.deinit();

    const stdout = std.io.getStdOut().writer();

    if (args.flag("--help")) {
        try clap.help(stdout, params[0..]);
        return;
    }

    log.err("THIS MINER DOES NOT CHECK FOR OG PUNK COLLISION, YOU MUST DO THIS BY HAND BEFORE MINTING OTHERWISE YOU MIGHT LOSE YOUR PUNK FOREVER!!!!!", .{});

    if (args.option("--lastmined")) |l|
        config.last_mined = try fmt.parseInt(u96, l, 10);
    if (args.option("--wallet")) |w| {
        if (w[0] == '0' and w[1] == 'x') {
            config.address = @truncate(u72, try fmt.parseInt(u160, w[2..], 16));
        } else {
            config.address = @truncate(u72, try fmt.parseInt(u160, w, 16));
        }
    }
    if (args.option("--difficulty")) |d|
        config.difficulty_target = try fmt.parseInt(u88, d, 10);
    if (args.option("--increment")) |i|
        config.range_increment = try fmt.parseInt(u88, i, 10);

    if (args.flag("--gpu")) {
        try gpu.gpu(config);
    } else if (args.flag("--multi")) {
        try gpu.multidevice(config);
    } else if (args.flag("--test")) {
        //while(true)
        //    try cpu.cpuThreads(4);
        try cpu.cpuThreads(1, config);
        //random
        config.address = @truncate(u72, @intCast(u160, 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4));
        config.bytes_prefix = calculateBytesPrefix();
        _ = isNonceValid(0);
    } else {
        var thread_count: usize = 0;
        if (args.option("--threads")) |n|
            thread_count = try fmt.parseInt(usize, n, 10);
        config.bytes_prefix = calculateBytesPrefix();
        var cpu_count = try Thread.getCpuCount();
        if (thread_count == 0) {
            thread_count = cpu_count;
        } else if (thread_count != cpu_count) {
            log.err("threads ({d}) do not match cpu cores ({d}), performance might be suboptimal", .{ thread_count, cpu_count });
        }
        while (true) {
            try cpuThreads(thread_count);
        }
    }
}
