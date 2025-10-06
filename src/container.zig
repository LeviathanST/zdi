const std = @import("std");
const testing = std.testing;

/// A container contains all dependencies
pub const Container = struct {
    refs: []Ref = &.{},
    alloc: std.mem.Allocator,
    _arena: *std.heap.ArenaAllocator,

    pub fn init(alloc: std.mem.Allocator) !Container {
        var aa = try alloc.create(std.heap.ArenaAllocator);
        aa.* = std.heap.ArenaAllocator.init(alloc);

        return .{
            .alloc = aa.allocator(),
            ._arena = aa,
        };
    }

    pub fn deinit(self: *Container) void {
        // TODO: call dependencies's `deinit()` if needed

        const alloc = self._arena.child_allocator;
        self.alloc.free(self.refs);
        self._arena.deinit();
        alloc.destroy(self._arena);
    }

    /// Find a value of `T` type in the container
    pub fn find(self: Container, comptime T: type) ?T {
        const typeInfo = @typeInfo(T);
        const Type = if (typeInfo == .pointer) std.meta.Child(T) else T;

        for (self.refs) |ref|
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
            };

        return null;
    }

    /// Append a ref into the container
    /// Currently, this function only run on runtime.
    /// TODO: make it comptime
    pub fn pushRef(self: *Container, value: anytype) !void {
        std.log.debug("[ ] {s}\r\n", .{@typeName(@TypeOf(value))});
        std.debug.assert(@typeInfo(@TypeOf(value)) == .pointer); // `value` must be a pointer

        var new_refs = try self.alloc.alloc(Ref, self.refs.len + 1);
        for (self.refs, 0..) |ref, i|
            new_refs[i] = ref;

        // append the new value
        new_refs[self.refs.len] = .from(value);

        self.alloc.free(self.refs);
        self.refs = new_refs;
        std.log.debug("\x1b[2K\x1b[1A\x1b[2K- Done\r\n", .{});
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
        return .{
            .tid = .from(ptr_info.child),
            .ptr = value,
            .is_const = ptr_info.is_const,
        };
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
