const std = @import("std");
const Config = @import("config.zig");
const c = @cImport({
    @cDefine("CL_TARGET_OPENCL_VERSION", "120");
    @cInclude("OpenCL/opencl.h");
});

const log = std.log;
const os = std.os;
const random = std.crypto.random;

const DATA_SIZE = 1024;

const KERNEL_SOURCE = @embedFile("test.cl");
var KERNEL_SOURCE_C: [*c]const u8 = KERNEL_SOURCE;

pub fn gpu(config: Config) !void {
    _ = config;
    var err: c_int = 0;

    var data: [DATA_SIZE]f32 = undefined;
    var results: [DATA_SIZE]f32 = undefined;
    var correct: u32 = 0;

    var global: usize = 0;
    var local: usize = 0;

    var device_id: c.cl_device_id = undefined;
    var context: c.cl_context = undefined;

    var commands: c.cl_command_queue = undefined;
    var program: c.cl_program = undefined;
    var kernel: c.cl_kernel = undefined;

    var input: c.cl_mem = undefined;
    var output: c.cl_mem = undefined;

    var i: usize = 0;
    const count: c_uint = DATA_SIZE;
    while (i < count) {
        data[i] = random.float(f32);
        i += 1;
    }

    err = c.clGetDeviceIDs(null, c.CL_DEVICE_TYPE_GPU, 1, &device_id, null);
    if (err != c.CL_SUCCESS) {
        log.err("failed to create a device group. {d}", .{err});
        os.exit(1);
    }

    log.info("got device id: {d}", .{device_id});

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

    kernel = c.clCreateKernel(program, "square", &err);
    if (kernel == null or err != c.CL_SUCCESS) {
        log.err("failed to create the compute kernel. {d}", .{err});
        os.exit(1);
    }

    input = c.clCreateBuffer(context, c.CL_MEM_READ_ONLY, @sizeOf(f32) * count, null, null).?;
    output = c.clCreateBuffer(context, c.CL_MEM_WRITE_ONLY, @sizeOf(f32) * count, null, null).?;
    if (input == null or output == null) {
        log.err("failed to allocate device memory. {d}", .{err});
        os.exit(1);
    }

    err = c.clEnqueueWriteBuffer(commands, input, c.CL_TRUE, 0, @sizeOf(f32) * count, &data, 0, null, null);
    if (err != c.CL_SUCCESS) {
        log.err("failed to write source array. {d}", .{err});
        os.exit(1);
    }

    err = 0;
    err = c.clSetKernelArg(kernel, 0, @sizeOf(c.cl_mem), &input);
    err |= c.clSetKernelArg(kernel, 1, @sizeOf(c.cl_mem), &output);
    err |= c.clSetKernelArg(kernel, 2, @sizeOf(c_uint), &count);
    if (err != c.CL_SUCCESS) {
        log.err("failed to set kernel arguments. {d}", .{err});
        os.exit(1);
    }

    err = c.clGetKernelWorkGroupInfo(kernel, device_id, c.CL_KERNEL_WORK_GROUP_SIZE, @sizeOf(@TypeOf(local)), &local, null);
    if (err != c.CL_SUCCESS) {
        log.err("failed to retrieve kernel work group info. {d}", .{err});
        os.exit(1);
    }

    global = count;
    err = c.clEnqueueNDRangeKernel(commands, kernel, 1, null, &global, &local, 0, null, null);
    if (err != c.CL_SUCCESS) {
        log.err("failed to execute the kernel. {d}", .{err});
        os.exit(1);
    }

    _ = c.clFinish(commands);

    err = c.clEnqueueReadBuffer(commands, output, c.CL_TRUE, 0, @sizeOf(f32) * count, &results, 0, null, null);
    if (err != c.CL_SUCCESS) {
        log.err("failed to read output array. {d}", .{err});
        os.exit(1);
    }

    correct = 0;
    i = 0;
    while (i < count) {
        if (results[i] == data[i] * data[i])
            correct += 1;
        i += 1;
    }

    log.info("computed {d}/{d} correct values.", .{ correct, count });

    _ = c.clReleaseMemObject(input);
    _ = c.clReleaseMemObject(output);
    _ = c.clReleaseProgram(program);
    _ = c.clReleaseKernel(kernel);
    _ = c.clReleaseCommandQueue(commands);
    _ = c.clReleaseContext(context);
}
