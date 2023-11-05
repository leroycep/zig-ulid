// MIT License
//
// Copyright (c) 2021 LeRoyce Pearson
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

const std = @import("std");
const random = std.crypto.random;

const ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
const ULID_BASE32_LEN = 26;

const ULID = @This();

value: u128,

pub fn now() @This() {
    const time_bits = @as(u48, @intCast(std.time.milliTimestamp()));
    const rand_bits = random.int(u80);

    return .{ .value = (@as(u128, time_bits) << 80) | @as(u128, rand_bits) };
}

pub const MonotonicFactory = struct {
    rng: std.rand.DefaultCsprng,

    // TODO: make these the exact size needed when issue is resolved: https://github.com/ziglang/zig/issues/7836

    // Set this to true to ensure that each value returned from `now()` is greater than the last
    last_timestamp_ms: u64 = 0,
    last_random: u128 = 0,

    pub fn init() !@This() {
        var seed: [32]u8 = undefined;
        random.bytes(&seed);
        return @This(){
            .rng = std.rand.DefaultCsprng.init(seed),
        };
    }

    pub fn now(this: *@This()) ULID {
        const time = @as(u48, @intCast(std.time.milliTimestamp()));
        if (this.last_timestamp_ms == time) {
            this.last_random += 1;
        } else {
            this.last_timestamp_ms = time;
            const rand = this.rng.random();
            this.last_random = rand.int(u80);
        }

        return ULID{ .value = (@as(u128, time) << 80) | @as(u128, this.last_random) };
    }
};

const LOOKUP = gen_lookup_table: {
    const CharType = union(enum) {
        Invalid: void,
        Ignored: void,
        Value: u5,
    };
    var lookup = [1]CharType{.Invalid} ** 256;
    for (ALPHABET, 0..) |char, idx| {
        lookup[char] = .{ .Value = idx };
        lookup[std.ascii.toLower(char)] = .{ .Value = idx };
    }

    lookup['O'] = .{ .Value = 0 };
    lookup['o'] = .{ .Value = 0 };

    lookup['I'] = .{ .Value = 1 };
    lookup['i'] = .{ .Value = 1 };
    lookup['L'] = .{ .Value = 1 };
    lookup['l'] = .{ .Value = 1 };
    lookup['-'] = .Ignored;

    break :gen_lookup_table lookup;
};

/// Convert the ULID into a byte array.
pub fn toBytes(this: @This()) [16]u8 {
    return @as([16]u8, @bitCast(std.mem.nativeToBig(u128, this.value)));
}

pub fn fromBytes(bytes: [16]u8) @This() {
    return @This(){
        .value = std.mem.bigToNative(u128, @as(u128, @bitCast(bytes))),
    };
}

pub fn encodeBase32(this: @This()) [ULID_BASE32_LEN]u8 {
    var value = this.value;

    var buffer: [ULID_BASE32_LEN]u8 = undefined;
    var i: usize = ULID_BASE32_LEN;
    while (i > 0) : (i -= 1) {
        buffer[i - 1] = ALPHABET[@as(u5, @truncate(value))];
        value >>= 5;
    }

    return buffer;
}

pub fn decodeBase32(text: []const u8) !@This() {
    if (text.len < ULID_BASE32_LEN) return error.InvalidLength;

    var value: u128 = 0;
    var chars_not_ignored: usize = 0;

    for (text) |char| {
        switch (LOOKUP[char]) {
            .Invalid => return error.InvalidCharacter,
            .Ignored => {},
            .Value => |char_val| {
                chars_not_ignored += 1;
                if (chars_not_ignored > ULID_BASE32_LEN) {
                    return error.InvalidLength;
                }

                value, const of = @shlWithOverflow(value, 5);
                if (of > 0) {
                    return error.Overflow;
                }
                value |= char_val;
            },
        }
    }

    return @This(){ .value = value };
}

pub fn cmp(a: @This(), b: @This()) std.math.Order {
    return std.math.order(a.value, b.value);
}

pub fn eq(a: @This(), b: @This()) bool {
    return cmp(a, b) == .eq;
}

test "valid" {
    const val1 = @This(){ .value = 0x41414141414141414141414141414141 };
    const enc1 = "21850M2GA1850M2GA1850M2GA1";
    try std.testing.expectEqual(val1, try decodeBase32(enc1));
    try std.testing.expectEqualStrings(enc1, &encodeBase32(val1));

    const val2 = @This(){ .value = 0x4d4e385051444a59454234335a413756 };
    const enc2 = "2D9RW50MA499CMAGHM6DD42DTP";

    var lower: [enc2.len]u8 = undefined;
    for (enc2, 0..) |char, idx| {
        lower[idx] = std.ascii.toLower(char);
    }

    try std.testing.expectEqualSlices(u8, enc2, &encodeBase32(val2));
    try std.testing.expectEqual(val2, try decodeBase32(enc2));
    try std.testing.expectEqual(val2, try decodeBase32(&lower));

    const enc3 = "2D9RW-50MA-499C-MAGH-M6DD-42DTP";
    try std.testing.expectEqual(val2, try decodeBase32(enc3));
}

test "invalid length" {
    try std.testing.expectError(error.InvalidLength, decodeBase32(""));
    try std.testing.expectError(error.InvalidLength, decodeBase32("2D9RW50MA499CMAGHM6DD42DT"));
    try std.testing.expectError(error.InvalidLength, decodeBase32("2D9RW50MA499CMAGHM6DD42DTPP"));
}

test "invalid characters" {
    try std.testing.expectError(error.InvalidCharacter, decodeBase32("2D9RW50[A499CMAGHM6DD42DTP"));
    try std.testing.expectError(error.InvalidCharacter, decodeBase32("2D9RW50MA49%CMAGHM6DD42DTP"));
}

test "overflows" {
    try std.testing.expectError(error.Overflow, decodeBase32("8ZZZZZZZZZZZZZZZZZZZZZZZZZ"));
    try std.testing.expectError(error.Overflow, decodeBase32("ZZZZZZZZZZZZZZZZZZZZZZZZZZ"));
}

test "Monotonic ULID factory: sequential output always increases" {
    var ulid_factory = try MonotonicFactory.init();
    var generated_ulids: [1024]@This() = undefined;
    for (&generated_ulids) |*ulid_to_generate| {
        ulid_to_generate.* = ulid_factory.now();
    }

    var prev_ulid = generated_ulids[0];
    for (generated_ulids[1..]) |current_ulid| {
        try std.testing.expectEqual(std.math.Order.gt, cmp(current_ulid, prev_ulid));
    }
}

test "test random values" {
    var seed: u64 = undefined;
    random.bytes(std.mem.asBytes(&seed));
    errdefer std.log.err("seed = {X}", .{seed});

    var rng = std.rand.DefaultPrng.init(seed);
    const rand = rng.random();

    const count = 500_000;
    var i: usize = 0;
    while (i < count) : (i += 1) {
        const value = ULID{
            .value = rand.int(u128),
        };
        errdefer std.log.err("value = {s}", .{value.encodeBase32()});

        try testEncodeDecode(value);
    }
}

fn testEncodeDecode(value: ULID) !void {
    const base32_encoded = value.encodeBase32();
    const base32_decoded = try ULID.decodeBase32(&base32_encoded);

    const byte_encoded = value.toBytes();
    const byte_decoded = ULID.fromBytes(byte_encoded);

    try std.testing.expect(value.eq(base32_decoded));
    try std.testing.expect(value.eq(byte_decoded));
}
