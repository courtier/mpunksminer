last_mined: u96 = 2475882076944016005221515264,
//me : 0x725aEF067EeE7B1eB7B06A7404b7b65afa04193B
//test : 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
address: u72 = @truncate(u72, @intCast(u160, 0x725aEF067EeE7B1eB7B06A7404b7b65afa04193B)),

difficulty_target: u88 = 5731203885580,
range_increment: u88 = 10000000,
bytes_prefix: [32]u8 = undefined,

gpu_difficulty_target: u64 = 5731203885580,
//TODO add option to both automatically determine this and override it manually
gpu_work_size_max: usize = 100000,
