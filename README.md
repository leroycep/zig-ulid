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

Based on [`ulid-rs`][] by [dylanhart][].

[`ulid-rs`]: https://github.com/dylanhart/ulid-rs
[dylanhart]: https://github.com/dylanhart

-   [`ulid`](#fn-ulid-16u8)
-   [`encode`](#fn-encode-16u8-26u8)
-   [`encodeTo`](#fn-encodeTo-u8-16u8-void)
-   [`decode`](#fn-decode-16u8-26u8)
-   [`cmp`](#fn-cmp-16u8-16u8-cmp)
-   [`eq`](#fn-eq-16u8-16u8-bool)
-   [`MonotonicFactory`](#monotonicfactory-struct)

## `fn ulid() [16]u8`

Generates a binary ulid using `std.time.milliTimestamp()` and the thread-local
cryptographic psuedo random number generator.

```zig
const std = @import("std");
const ulid = @import("ulid");

pub fn main() void {
    const generated_ulid = ulid.ulid();
    std.log.info("Generated ulid: {s}", .{ulid.encode(generated_ulid)});
}
```

## `fn encode([16]u8) [26]u8`

Converts a binary ulid to it's base32 encoding.

```zig
const std = @import("std");
const ulid = @import("ulid");

test "encode" {
    const value = [1]u8{ 0x41 } ** 16;
    const encoded = ulid.encode(value);
    std.testing.expectEqualSlices(u8, "21850M2GA1850M2GA1850M2GA1", &encoded);
}
```

## `fn encodeTo([]u8, [16]u8)`

Encodes the given ULID into the buffer.

```zig
const std = @import("std");
const ulid = @import("ulid");

test "encode" {
    const value = [1]u8{ 0x41 } ** 16;
    const encoded: [26]u8 = undefined;
    ulid.encodeTo(&encoded, value) catch |err| switch(err){
        error.BufferToSmall => unreachable,
    };
    std.testing.expectEqualSlices(u8, "21850M2GA1850M2GA1850M2GA1", &encoded);
}
```

## `fn decode([26]u8) ![16]u8`

Parses a base32 encoded ULID into raw bytes.

```zig
const std = @import("std");
const ulid = @import("ulid");

test "decode" {
    const string = "21850M2GA1850M2GA1850M2GA1";
    const decoded = try ulid.decode(string);
    std.testing.expectEqualSlices(u8, &([1]u8{ 0x41 } ** 16), &decoded);
}
```

## `fn cmp([16]u8, [16]u8) Cmp`

Compare two ULIDs.

```zig
const std = @import("std");
const ulid = @import("ulid");

pub fn main() void {
    const value1 = ulid.decode("01EWJ2BNFTSB4CPJP2C9291V9Q");
    const value2 = ulid.decode("01EWJ2CXQHDBB7K18P6GZGPQ9C");
    switch (ulid.cmp(value1, value2)) {
        .lt => std.log.info("{s} < {s}", .{&ulid.encode(value1), &ulid.encode(value2)}),
        .eq => std.log.info("{s} = {s}", .{&ulid.encode(value1), &ulid.encode(value2)}),
        .gt => std.log.info("{s} > {s}", .{&ulid.encode(value1), &ulid.encode(value2)}),
    }
}
```

## `fn eq([16]u8, [16]u8) bool`

Check if two ULIDs are equal.

```zig
const std = @import("std");
const ulid = @import("ulid");

pub fn main() void {
    const value1 = ulid.decode("01EWJ2BNFTSB4CPJP2C9291V9Q");
    const value2 = ulid.decode("01EWJ2CXQHDBB7K18P6GZGPQ9C");
    if (ulid.eq(value1, value2)) {
        std.log.info("{s} = {s}", .{&ulid.encode(value1), &ulid.encode(value2)}),
    } else {
        std.log.info("{s} =/= {s}", .{&ulid.encode(value1), &ulid.encode(value2)}),
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
    
    var value1 = ulid_factory.ulidNow();
    var value2 = ulid_factory.ulidNow();
    
    std.testing.expect(ulid.cmp(value2, value1) == .gt);
}
```
