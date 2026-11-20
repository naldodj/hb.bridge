const std = @import("std");

comptime {
    _ = @import("hbbridge.number.zig");
    _ = @import("hbbridge.credentials.zig");
}

export fn HBBridgeZigDispatch(json_ptr: [*c]const u8) [*c]const u8 {
    _ = json_ptr;
    return "{\"success\": true, \"message\": \"hbBridge Zig Engine Active\"}";
}
