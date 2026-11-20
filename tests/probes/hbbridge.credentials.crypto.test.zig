// Released to Public Domain. Feasibility probe, not a credential provider.
const std = @import("std");
const Aead = std.crypto.aead.chacha_poly.XChaCha20Poly1305;

test "authenticated encryption rejects changes to data and context" {
    const plaintext = "synthetic credential: \xc3\xa7\x00value";
    const context = "hbbridge-credential-v1:sql:profile-a";
    const key = [_]u8{0x41} ** Aead.key_length;
    const nonce = [_]u8{0x29} ** Aead.nonce_length;
    var ciphertext: [plaintext.len]u8 = undefined;
    var tag: [Aead.tag_length]u8 = undefined;
    var output: [plaintext.len]u8 = undefined;

    Aead.encrypt(&ciphertext, &tag, plaintext, context, nonce, key);
    try Aead.decrypt(&output, &ciphertext, tag, context, nonce, key);
    try std.testing.expectEqualSlices(u8, plaintext, &output);

    var altered_ciphertext = ciphertext;
    altered_ciphertext[0] ^= 1;
    try std.testing.expectError(error.AuthenticationFailed, Aead.decrypt(
        &output, &altered_ciphertext, tag, context, nonce, key,
    ));
    var altered_tag = tag;
    altered_tag[0] ^= 1;
    try std.testing.expectError(error.AuthenticationFailed, Aead.decrypt(
        &output, &ciphertext, altered_tag, context, nonce, key,
    ));
    var wrong_key = key;
    wrong_key[0] ^= 1;
    try std.testing.expectError(error.AuthenticationFailed, Aead.decrypt(
        &output, &ciphertext, tag, context, nonce, wrong_key,
    ));
    var wrong_nonce = nonce;
    wrong_nonce[0] ^= 1;
    try std.testing.expectError(error.AuthenticationFailed, Aead.decrypt(
        &output, &ciphertext, tag, context, wrong_nonce, key,
    ));
    try std.testing.expectError(error.AuthenticationFailed, Aead.decrypt(
        &output, &ciphertext, tag, "hbbridge-credential-v1:sql:profile-b", nonce, key,
    ));
    std.crypto.secureZero(u8, &output);
    try std.testing.expectEqualSlices(u8, &([_]u8{0} ** plaintext.len), &output);
}

test "operating system supplies secure entropy" {
    var key: [Aead.key_length]u8 = undefined;
    var nonce: [Aead.nonce_length]u8 = undefined;
    defer std.crypto.secureZero(u8, &key);
    defer std.crypto.secureZero(u8, &nonce);
    try std.testing.io.randomSecure(&key);
    try std.testing.io.randomSecure(&nonce);
    // Entropy quality and service-account permissions need separate evaluation.
}
