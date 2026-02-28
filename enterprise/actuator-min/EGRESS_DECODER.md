# Egress Decoder Reference

This document describes how to interpret the 32-byte egress payload.

## Byte Layout (Little Endian)


[0..8] domain_id u64 LE
[8..16] magnitude u64 LE
[16..32] actuation_token u128 LE


## Decoding Example (Rust)

```rust
let mut buf = [0u8; 32];
stream.read_exact(&mut buf)?;

let domain_id = u64::from_le_bytes(buf[0..8].try_into()?);
let magnitude = u64::from_le_bytes(buf[8..16].try_into()?);
let token = u128::from_le_bytes(buf[16..32].try_into()?);# Egress Decoder Reference

This document describes how to interpret the 32-byte egress payload.

## Byte Layout (Little Endian)

Decoding Example (Python)
domain_id, magnitude, low, high = struct.unpack("<QQQQ", data)
token = (high << 64) | low
Invariant

Every authorized action produces exactly one 32-byte message.
Impossible actions produce no message.


---
