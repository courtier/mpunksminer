const std = @import("std");
const Mutex = std.Thread.Mutex;

last_mined: u96 = 2475882076944016005221515264,
//me : 0x725aEF067EeE7B1eB7B06A7404b7b65afa04193B
//test : 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
address: u72 = @truncate(u72, @intCast(u160, 0x725aEF067EeE7B1eB7B06A7404b7b65afa04193B)),

difficulty_target: u88 = 5731203885580,
range_increment: u88 = 10000000,
bytes_prefix: [32]u8 = undefined,

test_range_increment: u64 = 10000000,

//test nonce: 11111115731203885580
gpu_difficulty_target: u64 = 5731203885580,
//TODO add option to both automatically determine this and override it manually
gpu_work_size_max: usize = 100,

//todo these will segfault once they are used, figure out a way to initialize them at runtime
last_mined_mutex: Mutex = Mutex{},
difficulty_target_mutex: Mutex = Mutex{},

const Self = @This();

pub fn updateDifficultyTarget(self: *Self, target: u64) void {
    const held = self.difficulty_target_mutex.acquire();
    defer held.release();
    self.difficulty_target = target;
    self.gpu_difficulty_target = target;
}

pub fn getDifficultyTarget(self: *Self) u64 {
    const held = self.difficulty_target_mutex.acquire();
    defer held.release();
    return self.gpu_difficulty_target;
}

pub fn updateLastMined(self: *Self, mined: u96) void {
    const held = self.last_mined_mutex.acquire();
    defer held.release();
    self.last_mined = mined;
}
pub fn getLastMined(self: *Self) u96 {
    const held = self.last_mined_mutex.acquire();
    defer held.release();
    return self.last_mined;
}
