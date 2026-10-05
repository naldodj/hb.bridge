const std = @import("std");

export fn hbbridge_zig_dispatch(json_ptr: [*c]const u8) [*c]const u8 {
    _ = json_ptr;
    return "{\"success\": true, \"message\": \"hbBridge Zig Engine Active\"}";
}
