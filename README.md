# Zig ULID

See [ULID spec][] for more information about ULIDs.

[ulid spec]: https://github.com/ulid/spec

This implements some functions for working with ULIDs in zig. You can use it by
copying `ulid.zig` to your source code, or by adding it as a [zigmod][]
dependency:

[zigmod]: https://github.com/nektro/zigmod

```yaml
- type: git
  path: https://github.com/leroycep/zig-ulid
```

Developed with Zig version `0.8.0-dev.1028+287f640cc`.

Based on [`ulid-rs`][] by [dylanhart][].

[`ulid-rs`]: https://github.com/dylanhart/ulid-rs
[dylanhart]: https://github.com/dylanhart

-   [`now`](#fn-now-ulid)
-   [`encodeBase32`](#fn-encodeBase32ulid-26u8)
-   [`decodeBase32`](#fn-decodeBase32u8-ulid)
-   [`cmp`](#fn-cmpulid-ulid-stdmathOrder)
-   [`eq`](#fn-equlid-ulid-bool)
-   [`MonotonicFactory`](#monotonicfactory-struct)

## `fn now() ulid`

Generates a ulid using `std.time.milliTimestamp()` and the thread-local
cryptographic psuedo random number generator.

```zig
const std = @import("std");
const ulid = @import("ulid");

pub fn main() void {
    const generated_ulid = ulid.encode();
    std.log.info("Generated ulid: {s}", .{generated_ulid.encodeBase32()});
}
```

## `fn encodeBase32(ulid) [26]u8`

Converts a ulid to it's base32 encoding.

```zig
const std = @import("std");
const ulid = @import("ulid");

test "encode" {
    const value = ulid.fromBytes([1]u8{ 0x41 } ** 16);
    const encoded = ulid.encodeBase32(value);
    std.testing.expectEqualStrings("21850M2GA1850M2GA1850M2GA1", &encoded);
}
```

## `fn decodeBase32([]u8) !ulid`

Parses a base32 encoded ULID.

```zig
const std = @import("std");
const ulid = @import("ulid");

test "decode" {
    const string = "21850M2GA1850M2GA1850M2GA1";
    const decoded = try ulid.decodeBase32(string);
    std.testing.expectEqualStrings(&([1]u8{ 0x41 } ** 16), &decoded);
}
```

## `fn cmp(ulid, ulid) std.math.Order`

Compare two ULIDs.

```zig
const std = @import("std");
const ulid = @import("ulid");

pub fn main() !void {
    const value1 = try ulid.decodeBase32("01EWJ2BNFTSB4CPJP2C9291V9Q");
    const value2 = try ulid.decodeBase32("01EWJ2CXQHDBB7K18P6GZGPQ9C");
    switch (value1.cmp(value2)) {
        .lt => std.log.info("{s} < {s}", .{&value1.encodeBase32(), &value2.encodeBase32()}),
        .eq => std.log.info("{s} = {s}", .{&value1.encodeBase32(), &value2.encodeBase32()}),
        .gt => std.log.info("{s} > {s}", .{&value1.encodeBase32(), &value2.encodeBase32()}),
    }
}
```

## `fn eq(ulid, ulid) bool`

Check if two ULIDs are equal.

```zig
const std = @import("std");
const ulid = @import("ulid");

pub fn main() void {
    const value1 = ulid.decode("01EWJ2BNFTSB4CPJP2C9291V9Q");
    const value2 = ulid.decode("01EWJ2CXQHDBB7K18P6GZGPQ9C");
    if (value1.eq(value2)) {
        std.log.info("{s} = {s}", .{&value1.encodeBase32(), &value2.encodeBase32()}),
    } else {
        std.log.info("{s} =/= {s}", .{&value1.encodeBase32(), &value2.encodeBase32()}),
    }
}
```

## `MonotonicFactory` struct

Creates a ULID factory that ensures that each ulid generated is greater than the last.

```
const std = @import("std");
const ulid = @import("ulid");

test "Monotonic ULID factory: sequential output always increases" {
    var ulid_factory = try ulid.MonotonicFactory.init();
    
    var value1 = ulid_factory.now();
    var value2 = ulid_factory.now();
    
    std.testing.expect(ulid.cmp(value2, value1) == .gt);
}
```
