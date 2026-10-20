const std = @import("std");

// Ryu emits a locale-independent shortest representation of the received f64.
// Buffers belong to C; no allocation or process/thread state crosses this ABI.
export fn HBBridgeNumberFormat(value: f64, output: [*c]u8, capacity: usize) usize {
    if (!std.math.isFinite(value) or output == null or capacity < std.fmt.float.min_buffer_size) return 0;
    const result = std.fmt.float.render(output[0..capacity], value, .{}) catch return 0;
    return result.len;
}

export fn HBBridgeNumberParse(input: [*c]const u8, length: usize, output: [*c]f64) bool {
    if (input == null or output == null or length == 0) return false;
    const value = std.fmt.parseFloat(f64, input[0..length]) catch return false;
    if (!std.math.isFinite(value)) return false;
    // Reject nonzero underflow as well as overflow. An explicit -0 stays -0.
    if (value == 0) {
        for (input[0..length]) |digit| {
            if (digit == 'e' or digit == 'E') break;
            if (digit >= '1' and digit <= '9') return false;
        }
    }
    output[0] = value;
    return true;
}

test "finite doubles format and parse without losing a bit" {
    const values = [_]f64{ 123.4567, 0.1, 1.2345678901234567, 1.0e-100, 1.0e100, std.math.floatMin(f64), std.math.floatMax(f64), @bitCast(@as(u64, 1)), -0.0 };
    for (values) |value| {
        var buffer: [64]u8 = undefined;
        var parsed: f64 = undefined;
        const length = HBBridgeNumberFormat(value, &buffer, buffer.len);
        try std.testing.expect(length != 0);
        try std.testing.expect(HBBridgeNumberParse(&buffer, length, &parsed));
        try std.testing.expectEqual(@as(u64, @bitCast(value)), @as(u64, @bitCast(parsed)));
    }
}

test "invalid, nonfinite and underflow values fail explicitly" {
    var buffer: [64]u8 = undefined;
    var parsed: f64 = undefined;
    try std.testing.expectEqual(@as(usize, 0), HBBridgeNumberFormat(std.math.inf(f64), &buffer, buffer.len));
    try std.testing.expectEqual(@as(usize, 0), HBBridgeNumberFormat(std.math.nan(f64), &buffer, buffer.len));
    try std.testing.expect(!HBBridgeNumberParse("1e999", 5, &parsed));
    try std.testing.expect(!HBBridgeNumberParse("1e-999", 6, &parsed));
    try std.testing.expect(!HBBridgeNumberParse("nan", 3, &parsed));
}
