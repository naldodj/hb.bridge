const std = @import("std");

const Aead = std.crypto.aead.chacha_poly.XChaCha20Poly1305;
const Base64 = std.base64.standard;
const envelope_prefix = "enc:v1:";
const encryption_prefix = "enc:";
const max_password_bytes = 4096;
const max_aad_bytes = 8192;
const envelope_overhead = Aead.nonce_length + Aead.tag_length;
const max_payload_bytes = max_password_bytes + envelope_overhead;
const max_envelope_bytes = envelope_prefix.len + Base64.Encoder.calcSize(max_payload_bytes);

const Status = enum(i32) {
    ok = 0,
    invalid_input = 1,
    invalid_envelope = 2,
    unsupported_version = 3,
    authentication_failed = 4,
    entropy_unavailable = 5,
};

fn FillRandom(bytes: []u8) std.Io.RandomSecureError!void {
    var entropy = std.Io.Threaded.init(std.heap.page_allocator, .{});
    defer entropy.deinit();
    try entropy.io().randomSecure(bytes);
}

fn PasswordValid(password: []const u8) bool {
    return password.len != 0 and std.unicode.utf8ValidateSlice(password) and
        std.mem.indexOfAny(u8, password, "\x00\r\n") == null;
}

fn CheckEnvelopeVersion(envelope: []const u8) Status {
    if (std.mem.startsWith(u8, envelope, envelope_prefix)) return .ok;
    if (!std.mem.startsWith(u8, envelope, encryption_prefix)) return .invalid_envelope;

    const suffix = envelope[encryption_prefix.len..];
    const version_end = std.mem.indexOfScalar(u8, suffix, ':') orelse return .invalid_envelope;
    const version = suffix[0..version_end];
    if (version.len < 2 or version[0] != 'v') return .invalid_envelope;
    for (version[1..]) |digit| {
        if (!std.ascii.isDigit(digit)) return .invalid_envelope;
    }
    return .unsupported_version;
}

// The C adapter owns the caller buffers. Failed encryption/decryption publishes
// no output and leaves the caller's output buffer untouched.
export fn HBBridgeCredentialRandomKey(key: [*c]u8, key_len: usize) i32 {
    if (key == null or key_len != Aead.key_length) return @intFromEnum(Status.invalid_input);
    const bytes = key[0..Aead.key_length];
    FillRandom(bytes) catch {
        std.crypto.secureZero(u8, bytes);
        return @intFromEnum(Status.entropy_unavailable);
    };
    return @intFromEnum(Status.ok);
}

export fn HBBridgeCredentialV1Encrypt(
    key: [*c]const u8,
    key_len: usize,
    input: [*c]const u8,
    input_len: usize,
    aad: [*c]const u8,
    aad_len: usize,
    output: [*c]u8,
    capacity: usize,
    written: [*c]usize,
) i32 {
    if (written == null) return @intFromEnum(Status.invalid_input);
    written[0] = 0;

    if (key == null or key_len != Aead.key_length or
        input == null or input_len == 0 or input_len > max_password_bytes or
        aad == null or aad_len == 0 or aad_len > max_aad_bytes or output == null)
    {
        return @intFromEnum(Status.invalid_input);
    }

    const password = input[0..input_len];
    const payload_len = password.len + envelope_overhead;
    const envelope_len = envelope_prefix.len + Base64.Encoder.calcSize(payload_len);
    if (capacity < envelope_len or !PasswordValid(password)) return @intFromEnum(Status.invalid_input);

    var payload_buffer: [max_payload_bytes]u8 = undefined;
    const payload = payload_buffer[0..payload_len];
    const nonce = payload[0..Aead.nonce_length];
    const ciphertext_end = payload_len - Aead.tag_length;
    const ciphertext = payload[Aead.nonce_length..ciphertext_end];
    const tag = payload[ciphertext_end..][0..Aead.tag_length];
    FillRandom(nonce) catch return @intFromEnum(Status.entropy_unavailable);
    Aead.encrypt(ciphertext, tag, password, aad[0..aad_len], nonce.*, key[0..Aead.key_length].*);

    @memcpy(output[0..envelope_prefix.len], envelope_prefix);
    _ = Base64.Encoder.encode(output[envelope_prefix.len..envelope_len], payload);
    written[0] = envelope_len;
    return @intFromEnum(Status.ok);
}

export fn HBBridgeCredentialV1Decrypt(
    key: [*c]const u8,
    key_len: usize,
    input: [*c]const u8,
    input_len: usize,
    aad: [*c]const u8,
    aad_len: usize,
    output: [*c]u8,
    capacity: usize,
    written: [*c]usize,
) i32 {
    if (written == null) return @intFromEnum(Status.invalid_input);
    written[0] = 0;

    if (key == null or key_len != Aead.key_length or input == null or
        aad == null or aad_len == 0 or aad_len > max_aad_bytes or output == null)
    {
        return @intFromEnum(Status.invalid_input);
    }
    if (input_len == 0 or input_len > max_envelope_bytes) return @intFromEnum(Status.invalid_envelope);

    const envelope = input[0..input_len];
    const version_status = CheckEnvelopeVersion(envelope);
    if (version_status != .ok) return @intFromEnum(version_status);

    const encoded = envelope[envelope_prefix.len..];
    const payload_len = Base64.Decoder.calcSizeForSlice(encoded) catch return @intFromEnum(Status.invalid_envelope);
    if (payload_len <= envelope_overhead or payload_len > max_payload_bytes) {
        return @intFromEnum(Status.invalid_envelope);
    }

    var payload_buffer: [max_payload_bytes]u8 = undefined;
    const payload = payload_buffer[0..payload_len];
    Base64.Decoder.decode(payload, encoded) catch return @intFromEnum(Status.invalid_envelope);
    const ciphertext_end = payload_len - Aead.tag_length;
    const ciphertext = payload[Aead.nonce_length..ciphertext_end];
    if (capacity < ciphertext.len) return @intFromEnum(Status.invalid_input);

    var plaintext_buffer: [max_password_bytes]u8 = undefined;
    const plaintext = plaintext_buffer[0..ciphertext.len];
    defer std.crypto.secureZero(u8, plaintext);

    const nonce = payload[0..Aead.nonce_length];
    const tag = payload[ciphertext_end..][0..Aead.tag_length];
    Aead.decrypt(plaintext, ciphertext, tag.*, aad[0..aad_len], nonce.*, key[0..Aead.key_length].*) catch
        return @intFromEnum(Status.authentication_failed);
    if (!PasswordValid(plaintext)) return @intFromEnum(Status.invalid_envelope);

    @memcpy(output[0..plaintext.len], plaintext);
    written[0] = plaintext.len;
    return @intFromEnum(Status.ok);
}

test "credential envelope preserves UTF-8 and rejects tampering without publishing output" {
    var key: [Aead.key_length]u8 = undefined;
    defer std.crypto.secureZero(u8, &key);
    const ok = @intFromEnum(Status.ok);
    try std.testing.expectEqual(ok, HBBridgeCredentialRandomKey(&key, key.len));

    const password = " caf\xc3\xa9;} ";
    const aad = "synthetic credential context";
    var envelope: [max_envelope_bytes]u8 = undefined;
    var envelope_len: usize = undefined;
    try std.testing.expectEqual(ok, HBBridgeCredentialV1Encrypt(
        &key,
        key.len,
        password.ptr,
        password.len,
        aad.ptr,
        aad.len,
        &envelope,
        envelope.len,
        &envelope_len,
    ));

    var output: [password.len]u8 = undefined;
    defer std.crypto.secureZero(u8, &output);
    var output_len: usize = undefined;
    try std.testing.expectEqual(ok, HBBridgeCredentialV1Decrypt(
        &key,
        key.len,
        &envelope,
        envelope_len,
        aad.ptr,
        aad.len,
        &output,
        output.len,
        &output_len,
    ));
    try std.testing.expectEqualSlices(u8, password, output[0..output_len]);

    // A valid Base64 mutation reaches authentication without changing the
    // encoded length or padding.
    const mutation_index = envelope_prefix.len + 8;
    envelope[mutation_index] = if (envelope[mutation_index] == 'A') 'B' else 'A';
    @memset(&output, 0x5a);
    try std.testing.expectEqual(@intFromEnum(Status.authentication_failed), HBBridgeCredentialV1Decrypt(
        &key,
        key.len,
        &envelope,
        envelope_len,
        aad.ptr,
        aad.len,
        &output,
        output.len,
        &output_len,
    ));
    try std.testing.expectEqual(@as(usize, 0), output_len);
    try std.testing.expectEqualSlices(u8, &([_]u8{0x5a} ** password.len), &output);
}

test "credential envelope rejects noncanonical Base64 and unsupported versions" {
    var key: [Aead.key_length]u8 = undefined;
    defer std.crypto.secureZero(u8, &key);
    const ok = @intFromEnum(Status.ok);
    try std.testing.expectEqual(ok, HBBridgeCredentialRandomKey(&key, key.len));

    const password = "a";
    const aad = "synthetic credential context";
    var envelope: [max_envelope_bytes]u8 = undefined;
    var envelope_len: usize = undefined;
    try std.testing.expectEqual(ok, HBBridgeCredentialV1Encrypt(
        &key,
        key.len,
        password.ptr,
        password.len,
        aad.ptr,
        aad.len,
        &envelope,
        envelope.len,
        &envelope_len,
    ));

    var output: [password.len]u8 = undefined;
    var output_len: usize = undefined;
    const invalid_envelope = @intFromEnum(Status.invalid_envelope);

    // A 41-byte payload has one pad character. Set a zero padding bit in its
    // last sextet while leaving the encoded bytes otherwise unchanged.
    try std.testing.expectEqual(@as(u8, '='), envelope[envelope_len - 1]);
    const alphabet = std.base64.standard_alphabet_chars;
    const index = std.mem.indexOfScalar(u8, &alphabet, envelope[envelope_len - 2]).?;
    envelope[envelope_len - 2] = alphabet[index | 1];
    try std.testing.expectEqual(invalid_envelope, HBBridgeCredentialV1Decrypt(
        &key,
        key.len,
        &envelope,
        envelope_len,
        aad.ptr,
        aad.len,
        &output,
        output.len,
        &output_len,
    ));
    try std.testing.expectEqual(@as(usize, 0), output_len);

    envelope[5] = '2';
    try std.testing.expectEqual(@intFromEnum(Status.unsupported_version), HBBridgeCredentialV1Decrypt(
        &key,
        key.len,
        &envelope,
        envelope_len,
        aad.ptr,
        aad.len,
        &output,
        output.len,
        &output_len,
    ));
    try std.testing.expectEqual(@as(usize, 0), output_len);
}
