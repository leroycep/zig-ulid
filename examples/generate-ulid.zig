const std = @import("std");
const ulid = @import("ulid");

pub fn main() void {
    const generated_ulid = ulid.now();
    std.log.info("Generated ulid: {s}", .{generated_ulid.encodeBase32()});
}
