//! This exmaple describe how to use `zdi` to implement
//! a CLI tool.
const std = @import("std");
const zdi = @import("zdi");

const Handler = struct {
    container: *zdi.Container,

    const Command = enum {
        say,
        hello,

        pub fn fromString(str: []const u8) !Command {
            const command = std.meta.stringToEnum(Command, str);
            if (command == null) return error.CommandNotFound;
            return command.?;
        }
    };

    pub fn init(alloc: std.mem.Allocator) !Handler {
        // init the container
        var ct = try zdi.Container.init(alloc);
        errdefer ct.deinit();

        // TODO: auto create?
        const arg_iter = try ct.alloc.create(std.process.ArgIterator);
        arg_iter.* = try std.process.argsWithAllocator(alloc);

        // push some needed dependencies
        try ct.pushRef(arg_iter);
        try ct.pushRef(&ct.alloc);

        return .{
            .container = ct,
        };
    }

    pub fn deinit(self: *Handler) void {
        self.container.deinit();
    }

    fn cmd(self: Handler, comptime fun: anytype) !void {
        // init a tuple to contains required paramaters of the executed function
        var args: std.meta.ArgsTuple(@TypeOf(fun)) = undefined;

        // get required paramaters info of the executed function
        const @"fn" = @typeInfo(@TypeOf(fun)).@"fn";
        inline for (@"fn".params, 0..) |p, idx| {
            args[idx] = self.container.find(p.type.?).?;
        }
        try @call(.auto, fun, args);
    }

    pub fn run(self: *Handler) !void {
        // TODO: exec one of appropriate multi-fns
        var arg_iter = self.container.find(*std.process.ArgIterator).?;
        _ = arg_iter.skip();
        const command_str = arg_iter.next() orelse {
            std.log.err("Missing command.", .{});
            return;
        };
        const command = Command.fromString(command_str) catch {
            std.log.err("Command `{s}` not found.", .{command_str});
            return;
        };

        try switch (command) {
            inline else => |c| self.cmd(@field(Handler, @tagName(c))),
        };
    }

    fn say(alloc: std.mem.Allocator, arg_iter: *std.process.ArgIterator) !void {
        var list: std.ArrayList(u8) = .{};
        defer list.deinit(alloc);

        while (arg_iter.next()) |items| {
            list.appendSlice(alloc, items) catch @panic("OOM");
            list.append(alloc, ' ') catch @panic("OOM");
        }

        std.log.debug("{s}", .{list.items[0..]});
    }

    pub fn hello() !void {
        std.log.debug("print", .{});
    }
};

pub fn main() !void {
    var base_alloc = std.heap.DebugAllocator(.{}).init;
    defer if (base_alloc.deinit() == .leak)
        std.log.err("Leak memory have been detected", .{});
    const alloc = base_alloc.allocator();

    var handler = try Handler.init(alloc);
    defer handler.deinit();

    try handler.run();
}
