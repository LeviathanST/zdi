// TODO: describe about CI concepts
const std = @import("std");
const testing = std.testing;

/// A container contains all dependencies
pub const Container = struct {
    refs: std.ArrayList(Ref),
    alloc: std.mem.Allocator,
    _arena: *std.heap.ArenaAllocator,

    pub fn init(alloc: std.mem.Allocator) !*Container {
        var aa = try alloc.create(std.heap.ArenaAllocator);
        errdefer alloc.destroy(aa);
        aa.* = std.heap.ArenaAllocator.init(alloc);

        const allocator = aa.allocator();
        const self = try allocator.create(Container);
        errdefer allocator.destroy(self);

        self.* = .{
            .refs = try .initCapacity(alloc, 64),
            .alloc = allocator,
            ._arena = aa,
        };

        return self;
    }

    /// Automatically call `deinit()` from dependencies
    /// if its exsists.
    pub fn deinit(self: *Container) void {
        for (self.refs.items) |*ref| {
            if (ref.deinit_fn) |deinit_fn| deinit_fn(ref);
        }

        const alloc = self._arena.child_allocator;
        self.refs.deinit(alloc);
        // NOTE: When the arena is deinit, the container is also deinit too Then,
        //       we cant free arena via `alloc.destroy(self._arena)` so
        //       need to store the arena ptr and deinit later.
        const arena_ptr = self._arena;
        arena_ptr.deinit();
        alloc.destroy(arena_ptr);
    }

    /// Find a value of `T` type in the container
    pub fn find(self: Container, comptime T: type) ?T {
        const typeInfo = @typeInfo(T);
        const Type = if (typeInfo == .pointer) std.meta.Child(T) else T;

        for (self.refs.items) |ref| {
            // check the appropriate type
            if (ref.match(Type)) {
                // if `T` is a pointer, check if it can
                // be mutable or not.
                if (typeInfo == .pointer) {
                    if (ref.is_const and !typeInfo.pointer.is_const)
                        @panic("Cannot get a mutable pointer from an immutable pointer");

                    return @ptrCast(@alignCast(@constCast(ref.ptr)));
                }

                return @as(*Type, @ptrCast(@alignCast(@constCast(ref.ptr)))).*;
            }
        }

        return null;
    }

    /// Append a ref into the container
    /// Currently, this function only run on runtime.
    pub fn pushRef(self: *Container, value: anytype) !void {
        std.log.debug("\x1b[1;32mAppend:\x1b[0m {s}\r\n", .{@typeName(@TypeOf(value))});
        errdefer std.log.debug("\x1b[2K\x1b[1A- Error occured\r\n", .{});
        std.debug.assert(@typeInfo(@TypeOf(value)) == .pointer); // `value` must be a pointer

        try self.refs.append(self.alloc, .from(value));
        std.log.debug("\x1b[2K\x1b[1A- Done\r\n", .{});
    }

    test "find & pushRef" {
        const alloc = testing.allocator;
        const Test = struct {
            hehe: []const u8,
        };

        const test_var: Test = .{ .hehe = "hoho" };
        var container = try Container.init(alloc);
        defer container.deinit();

        try container.pushRef(&test_var);

        const get_test = container.find(Test).?;
        try testing.expectEqualStrings(get_test.hehe, "hoho");
    }
};

/// A type-erased component in container
pub const Ref = struct {
    tid: TypeId,
    ptr: *const anyopaque,
    is_const: bool,
    deinit_fn: ?*const fn (*Ref) void,

    const TypeId = struct {
        name: []const u8,

        pub fn from(comptime T: type) TypeId {
            return .{ .name = @typeName(T) };
        }
    };

    pub fn match(self: Ref, comptime T: type) bool {
        return std.mem.eql(u8, self.tid.name, @typeName(T));
    }

    pub fn from(value: anytype) Ref {
        const ptr_info = @typeInfo(@TypeOf(value)).pointer;
        const OriginType = ptr_info.child;

        var self: Ref = .{
            .tid = .from(OriginType),
            .ptr = value,
            .is_const = ptr_info.is_const,
            .deinit_fn = null,
        };

        if (std.meta.hasMethod(OriginType, "deinit")) {
            const H = struct {
                pub fn deinit(ref: *Ref) void {
                    OriginType.deinit(@ptrCast(@alignCast(@constCast(ref.ptr))));
                }
            };
            self.deinit_fn = H.deinit;
        }

        return self;
    }

    test "match" {
        const Test1 = struct {};
        const Test2 = struct {};

        const test1: Test1 = .{};
        const test2: Test2 = .{};

        const ref1: Ref = .from(&test1);
        const ref2: Ref = .from(&test2);

        try std.testing.expect(ref1.match(Test1));
        try std.testing.expect(ref2.match(Test2));

        try std.testing.expect(!ref2.match(Test1));
        try std.testing.expect(!ref1.match(Test2));
    }
};
