// Released to Public Domain. Synthetic ABI probe; not a credential provider.
const std = @import("std");
const Aead = std.crypto.aead.chacha_poly.XChaCha20Poly1305;

export fn HBBridgeCredentialProbe(data: [*]const u8, length: usize) bool {
    const allocator = std.heap.page_allocator;
    const input = data[0..length];
    const context = "synthetic-abi-probe";
    var entropy = std.Io.Threaded.init(allocator, .{});
    defer entropy.deinit();
    const io = entropy.io();
    var key: [Aead.key_length]u8 = undefined;
    defer std.crypto.secureZero(u8, &key);
    var nonce: [Aead.nonce_length]u8 = undefined;
    io.randomSecure(&key) catch return false;
    io.randomSecure(&nonce) catch return false;

    const ciphertext = allocator.alloc(u8, length) catch return false;
    defer allocator.free(ciphertext);
    const output = allocator.alloc(u8, length) catch return false;
    defer allocator.free(output);
    defer std.crypto.secureZero(u8, output);
    var tag: [Aead.tag_length]u8 = undefined;

    Aead.encrypt(ciphertext, &tag, input, context, nonce, key);
    Aead.decrypt(output, ciphertext, tag, context, nonce, key) catch return false;
    if (!std.mem.eql(u8, input, output)) return false;
    tag[0] ^= 1;
    Aead.decrypt(output, ciphertext, tag, context, nonce, key) catch |err| {
        return err == error.AuthenticationFailed;
    };
    return false;
}
