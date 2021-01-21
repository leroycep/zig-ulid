const std = @import("std");
const ulid = @import("ulid");

pub fn main() void {
    const generated_ulid = ulid.ulid();
    std.log.info("Generated ulid: {s}", .{ulid.encode(generated_ulid)});
}
