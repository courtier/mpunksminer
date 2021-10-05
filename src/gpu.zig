const std = @import("std");
const Config = @import("config.zig");
const c = @cImport({
    @cDefine("CL_TARGET_OPENCL_VERSION", "120");
    @cInclude("CL/cl.h");
});

const log = std.log;
const time = std.time;
const os = std.os;
const crypto = std.crypto;
const random = crypto.random;
const Keccak_256 = crypto.hash.sha3.Keccak_256;

export fn reportSuccess(nonce: u64) void {
    log.err("found nonce: {d}. CHECK IF THIS PRODUCES A OG PUNK BEFORE MINTING!", .{nonce});
}

//we will be using u64 instead of u88 for the gpu so pad it with extra zeroes
//32 bytes, 12 for last mined punk, 9 for addy and 11 for nonce
//64 bit nonce would be 8 bytes so we append 3 zeroes
fn prepareGPUBytesPrefix(config: Config) [32]u8 {
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

const KERNEL_SOURCE = @embedFile("miner.cl");
var KERNEL_SOURCE_C: [*c]const u8 = KERNEL_SOURCE;

pub fn gpu(config: Config, range_start_p: u64) !void {
    var err: c_int = 0;

    //setup args for miner_init
    //constant char *bytes_prefix, constant ulong *range_start,
    //global ulong *nonce_results, global uint *result_index
    var bytes_prefix: [32]u8 = prepareGPUBytesPrefix(config);
    var range_start: u64 = range_start_p;
    //length 64 was picked without reason
    var nonce_results: [64]u64 = undefined;
    //var result_index: u32 = 0;
    //_ = result_index;
    //_ = nonce_results;

    var global: usize = 0;
    var local: usize = 0;

    var device_id: c.cl_device_id = undefined;
    var context: c.cl_context = undefined;

    var commands: c.cl_command_queue = undefined;
    var program: c.cl_program = undefined;
    var kernel: c.cl_kernel = undefined;

    //both are write only
    var nonce_results_mem: c.cl_mem = undefined;
    var result_index_mem: c.cl_mem = undefined;
    //read only
    var bytes_prefix_mem: c.cl_mem = undefined;

    _ = local;
    _ = global;

    err = c.clGetDeviceIDs(null, c.CL_DEVICE_TYPE_GPU, 1, &device_id, null);
    if (err != c.CL_SUCCESS) {
        log.err("failed to create a device group. {d}", .{err});
        os.exit(1);
    }

    log.err("got device id: {d}", .{device_id});

    context = c.clCreateContext(0, 1, &device_id, null, null, &err);
    if (context == null or err != c.CL_SUCCESS) {
        log.err("failed to create a compute context. {d}", .{err});
        os.exit(1);
    }

    commands = c.clCreateCommandQueue(context, device_id, 0, &err);
    if (commands == null or err != c.CL_SUCCESS) {
        log.err("failed to create a command queue. {d}", .{err});
        os.exit(1);
    }

    program = c.clCreateProgramWithSource(context, 1, &KERNEL_SOURCE_C, null, &err);
    if (program == null or err != c.CL_SUCCESS) {
        log.err("failed to create a compute program. {d}", .{err});
        os.exit(1);
    }

    err = c.clBuildProgram(program, 0, null, null, null, null);
    if (err != c.CL_SUCCESS) {
        log.err("failed to build the program executable. {d}", .{err});
        var buf: [2048]u8 = undefined;
        var len: usize = 0;
        _ = c.clGetProgramBuildInfo(program, device_id, c.CL_PROGRAM_BUILD_LOG, 1024, &buf, &len);
        log.err("{s}", .{buf});
        os.exit(1);
    }

    log.err("program built successfully", .{});

    kernel = c.clCreateKernel(program, "miner_init", &err);
    if (kernel == null or err != c.CL_SUCCESS) {
        log.err("failed to create the compute kernel. {d}", .{err});
        os.exit(1);
    }

    nonce_results_mem = c.clCreateBuffer(context, c.CL_MEM_WRITE_ONLY, @sizeOf(u64) * 64, null, null);
    result_index_mem = c.clCreateBuffer(context, c.CL_MEM_WRITE_ONLY, @sizeOf(u32), null, null);
    bytes_prefix_mem = c.clCreateBuffer(context, c.CL_MEM_READ_ONLY, @sizeOf(c.cl_char) * 32, null, null);
    if (nonce_results_mem == null or result_index_mem == null or bytes_prefix_mem == null) {
        log.err("failed to allocate device memory. {d}", .{err});
        os.exit(1);
    }

    err = c.clEnqueueWriteBuffer(commands, bytes_prefix_mem, c.CL_TRUE, 0, @sizeOf(c.cl_char) * 32, &bytes_prefix, 0, null, null);
    if (err != c.CL_SUCCESS) {
        log.err("failed to write to bytes_prefix array. {d}", .{err});
        os.exit(1);
    }

    err = 0;
    err |= c.clSetKernelArg(kernel, 0, @sizeOf(c.cl_mem), &bytes_prefix_mem);
    err |= c.clSetKernelArg(kernel, 1, @sizeOf(c.cl_ulong), &range_start);
    err |= c.clSetKernelArg(kernel, 2, @sizeOf(c.cl_mem), &nonce_results_mem);
    err |= c.clSetKernelArg(kernel, 3, @sizeOf(c.cl_mem), &result_index_mem);
    if (err != c.CL_SUCCESS) {
        log.err("failed to set kernel arguments. {d}", .{err});
        os.exit(1);
    }

    err = c.clGetKernelWorkGroupInfo(kernel, device_id, c.CL_KERNEL_WORK_GROUP_SIZE, @sizeOf(@TypeOf(local)), &local, null);
    if (err != c.CL_SUCCESS) {
        log.err("failed to retrieve kernel work group info. {d}", .{err});
        os.exit(1);
    }

    log.info("max workers: {d}", .{local});

    while (true) {
        var before_time = time.nanoTimestamp();
        log.err("mining cycle start time: {d}", .{before_time});

        //global = local * config.gpu_work_size_max;
        global = 1;
        local = 1;
        err = c.clEnqueueNDRangeKernel(commands, kernel, 1, null, &global, &local, 0, null, null);
        if (err != c.CL_SUCCESS) {
            log.err("failed to execute the kernel. {d}", .{err});
            os.exit(1);
        }

        _ = c.clFinish(commands);

        var after_time = time.nanoTimestamp();

        err = c.clEnqueueReadBuffer(commands, nonce_results_mem, c.CL_TRUE, 0, @sizeOf(u64) * 64, &nonce_results, 0, null, null);
        if (err != c.CL_SUCCESS) {
            log.err("failed to read output array. {d}", .{err});
            os.exit(1);
        }

        log.err("finished {d} hashes", .{global});
        log.err("mining cycle end time: {d}, diff: {d}", .{ after_time, after_time - before_time });
        break;
    }

    _ = c.clReleaseMemObject(nonce_results_mem);
    _ = c.clReleaseMemObject(result_index_mem);
    _ = c.clReleaseMemObject(bytes_prefix_mem);
    _ = c.clReleaseProgram(program);
    _ = c.clReleaseKernel(kernel);
    _ = c.clReleaseCommandQueue(commands);
    _ = c.clReleaseContext(context);
}
