const std = @import("std");
const zdi = @import("zdi");

const Handler = struct {
    container: zdi.Container,

    pub fn init(alloc: std.mem.Allocator) !Handler {
        var ct = try zdi.Container.init(alloc);
        errdefer ct.deinit();

        var arg_iter = try ct.alloc.create(std.process.ArgIterator);
        arg_iter.* = try std.process.argsWithAllocator(alloc);
        errdefer arg_iter.deinit();
        // _ = arg_iter.skip();

        try ct.pushRef(arg_iter);
        try ct.pushRef(&alloc);

        return .{
            .container = ct,
        };
    }

    pub fn deinit(self: *Handler) void {
        self.container.find(*std.process.ArgIterator).?.deinit();
        self.container.deinit();
    }

    pub fn run(self: Handler) void {
        const fun = print; // TODO: exec one of appropriate multi-fns
        var args: std.meta.ArgsTuple(@TypeOf(fun)) = undefined;

        const @"fn" = @typeInfo(@TypeOf(fun)).@"fn";
        inline for (@"fn".params, 0..) |p, idx| {
            args[idx] = self.container.find(p.type.?).?;
        }
        @call(.auto, fun, args);
    }
};

fn print(arg_iter: *std.process.ArgIterator) void {
    while (arg_iter.next()) |arg| {
        std.log.debug("arg {s}", .{arg});
    }
}

pub fn main() !void {
    var base_alloc = std.heap.DebugAllocator(.{}).init;
    defer if (base_alloc.deinit() == .leak)
        std.log.err("Leak memory have been detected", .{});
    const alloc = base_alloc.allocator();

    var handler = try Handler.init(alloc);
    defer handler.deinit();
    handler.run();
}
