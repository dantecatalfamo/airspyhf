const std = @import("std");

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

    const version = getVersion(b) catch unreachable;

    const shared_lib = b.addSharedLibrary(.{
        .name = "libairspyhf",
        .target = target,
        .optimize = optimize,
        .version = version,
    });

    const static_lib = b.addStaticLibrary(.{
        .name = "libairspyhf",
        .target = target,
        .optimize = optimize,
        .version = version,
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

    b.installFile("tools/52-airspyhf.rules", "etc/udev/rules.d/52-airspyhf.rules");
}

pub fn getVersion(b: *std.Build) !std.SemanticVersion {
    const contents = try std.fs.cwd().readFileAlloc(b.allocator, "libairspyhf/src/airspyhf.h", 1024 * 1024 * 10);
    defer b.allocator.free(contents);
    var lines = std.mem.split(u8, contents, "\n");
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "#define AIRSPYHF_VERSION")) {
            var quotes = std.mem.split(u8, line, "\"");
            _ = quotes.first();
            if (quotes.next()) |version| {
                return std.SemanticVersion.parse(version);
            }
        }
    }
    return error.MissingVersion;
}
