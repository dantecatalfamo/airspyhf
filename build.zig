const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const shared_lib = b.addSharedLibrary(.{
        .name = "libairspyhf",
        .target = target,
        .optimize = optimize,
    });

    const static_lib = b.addStaticLibrary(.{
        .name = "libairspyhf",
        .target = target,
        .optimize = optimize,
    });

    inline for (.{ shared_lib, static_lib }) |lib| {
        lib.linkLibC();
        lib.linkSystemLibrary("libusb-1.0");
        lib.addCSourceFiles(&libairspyhfSource, &.{});

        b.installArtifact(lib);
    }

    inline for (programs) |program| {
        const exe = b.addExecutable(.{
            .name = "airspyhf_" ++ program,
            .target = target,
            .optimize = optimize,
        });

        exe.linkLibC();
        exe.linkSystemLibrary("libusb-1.0");
        exe.linkLibrary(static_lib);
        exe.addSystemIncludePath(.{ .path = "libairspyhf/src" });
        exe.addCSourceFiles(&.{"tools/src/airspyhf_" ++ program ++ ".c"}, &.{});

        b.installArtifact(exe);
    }

    inline for (header_files) |header_file| {
        const header = b.addInstallHeaderFile("libairspyhf/src/" ++ header_file, "libairspyhf/" ++ header_file);
        b.getInstallStep().dependOn(&header.step);
    }
}

const libairspyhfSource = [_][]const u8 {
    "libairspyhf/src/airspyhf.c",
    "libairspyhf/src/iqbalancer.c",
};

const header_files = [_][]const u8 {
    "airspyhf.h",
    "airspyhf_commands.h",
    "iqbalancer.h",
};

const programs = [_][]const u8 {
    "calibrate",
    "gpio",
    "info",
    "lib_version",
    "rx",
};
