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
const ULID_LEN = 26;

pub fn ulid() [16]u8 {
    const time_bits = @intCast(u48, std.time.milliTimestamp());
    const rand_bits = random.int(u80);

    const value = (@as(u128, time_bits) << 80) | @as(u128, rand_bits);
    const big_endian_ulid = std.mem.nativeToBig(u128, value);
    return @bitCast([16]u8, big_endian_ulid);
}

pub const MonotonicFactory = struct {
    rng: std.rand.DefaultCsprng,

    // TODO: make these the exact size needed when issue is resolved: https://github.com/ziglang/zig/issues/7836

    // Set this to true to ensure that each value returned from ulidNow is greater than the last
    last_timestamp_ms: u64 = 0,
    last_random: u128 = 0,

    pub fn init() !@This() {
        var seed: [32]u8 = undefined;
        random.bytes(&seed);
        return @This(){
            .rng = std.rand.DefaultCsprng.init(seed),
        };
    }

    pub fn ulidNow(this: *@This()) [16]u8 {
        const time = @intCast(u48, std.time.milliTimestamp());
        if (this.last_timestamp_ms == time) {
            this.last_random += 1;
        } else {
            this.last_timestamp_ms = time;
            this.last_random = this.rng.random.int(u80);
        }

        const ulid_int = (@as(u128, time) << 80) | @as(u128, this.last_random);
        const ulid_int_big = std.mem.nativeToBig(u128, ulid_int);
        return @bitCast([16]u8, ulid_int_big);
    }
};

const LOOKUP = gen_lookup_table: {
    const CharType = union(enum) {
        Invalid: void,
        Ignored: void,
        Value: u5,
    };
    var lookup = [1]CharType{.Invalid} ** 256;
    for (ALPHABET) |char, idx| {
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

pub fn encodeTo(buffer: []u8, valueIn: [16]u8) !void {
    if (buffer.len < ULID_LEN) return error.BufferToSmall;

    var value = std.mem.bigToNative(u128, @bitCast(u128, valueIn));

    var i: usize = ULID_LEN;
    while (i > 0) : (i -= 1) {
        buffer[i - 1] = ALPHABET[@truncate(u5, value)];
        value >>= 5;
    }
}

pub fn encode(value: [16]u8) [ULID_LEN]u8 {
    var buffer: [ULID_LEN]u8 = undefined;
    encodeTo(&buffer, value) catch |err| switch (err) {
        error.BufferToSmall => unreachable,
    };
    return buffer;
}

pub fn decode(text: []const u8) ![16]u8 {
    if (text.len < ULID_LEN) return error.InvalidLength;

    var value: u128 = 0;
    var chars_not_ignored: usize = 0;

    for (text) |char| {
        switch (LOOKUP[char]) {
            .Invalid => return error.InvalidCharacter,
            .Ignored => {},
            .Value => |char_val| {
                chars_not_ignored += 1;
                if (chars_not_ignored > ULID_LEN) {
                    return error.InvalidLength;
                }

                if (@shlWithOverflow(u128, value, 5, &value)) {
                    return error.Overflow;
                }
                value |= char_val;
            },
        }
    }

    const big_endian_ulid = std.mem.nativeToBig(u128, value);
    return @bitCast([16]u8, big_endian_ulid);
}

pub fn cmp(a: [16]u8, b: [16]u8) std.math.Order {
    for (a) |a_val, idx| {
        if (a_val == b[idx]) {
            continue;
        } else if (a_val > b[idx]) {
            return .gt;
        } else {
            return .lt;
        }
    }
    return .eq;
}

pub fn eq(a: [16]u8, b: [16]u8) bool {
    return cmp(a, b) == .eq;
}

test "valid" {
    const val1 = [16]u8{
        0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
    };
    const enc1 = "21850M2GA1850M2GA1850M2GA1";
    try std.testing.expectEqual(val1, try decode(enc1));
    try std.testing.expectEqualSlices(u8, enc1, &encode(val1));

    const val2 = [16]u8{ 0x4d, 0x4e, 0x38, 0x50, 0x51, 0x44, 0x4a, 0x59, 0x45, 0x42, 0x34, 0x33, 0x5a, 0x41, 0x37, 0x56 };
    const enc2 = "2D9RW50MA499CMAGHM6DD42DTP";

    var lower: [enc2.len]u8 = undefined;
    for (enc2) |char, idx| {
        lower[idx] = std.ascii.toLower(char);
    }

    try std.testing.expectEqualSlices(u8, enc2, &encode(val2));
    try std.testing.expectEqual(val2, try decode(enc2));
    try std.testing.expectEqual(val2, try decode(&lower));

    const enc3 = "2D9RW-50MA-499C-MAGH-M6DD-42DTP";
    try std.testing.expectEqual(val2, try decode(enc3));
}

test "invalid length" {
    try std.testing.expectError(error.InvalidLength, decode(""));
    try std.testing.expectError(error.InvalidLength, decode("2D9RW50MA499CMAGHM6DD42DT"));
    try std.testing.expectError(error.InvalidLength, decode("2D9RW50MA499CMAGHM6DD42DTPP"));
}

test "invalid characters" {
    try std.testing.expectError(error.InvalidCharacter, decode("2D9RW50[A499CMAGHM6DD42DTP"));
    try std.testing.expectError(error.InvalidCharacter, decode("2D9RW50MA49%CMAGHM6DD42DTP"));
}

test "overflows" {
    try std.testing.expectError(error.Overflow, decode("8ZZZZZZZZZZZZZZZZZZZZZZZZZ"));
    try std.testing.expectError(error.Overflow, decode("ZZZZZZZZZZZZZZZZZZZZZZZZZZ"));
}

test "compare ulids" {}

test "Monotonic ULID factory: sequential output always increases" {
    var ulid_factory = try MonotonicFactory.init();
    var generated_ulids: [1024][16]u8 = undefined;
    for (generated_ulids) |*ulid_to_generate| {
        ulid_to_generate.* = ulid_factory.ulidNow();
    }

    var prev_ulid = generated_ulids[0];
    for (generated_ulids[1..]) |current_ulid| {
        try std.testing.expectEqual(std.math.Order.gt, cmp(current_ulid, prev_ulid));
    }
}
