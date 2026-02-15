#!/usr/bin/env python3
"""
SLIME v0 — Example Actuator Bridge
Connects to /run/slime/egress.sock and processes authorized effects.
"""

import socket
import struct
import sys

SOCKET_PATH = '/run/slime/egress.sock'

def actuate(domain_id, magnitude, token):
    """
    Perform mechanical actuation based on authorized effect.
    
    This is where your application-specific logic goes.
    Examples:
    - Call external APIs
    - Control hardware
    - Update databases
    - Send notifications
    """
    print(f"[ACTUATE] domain={domain_id}, magnitude={magnitude}, token={token:032x}")
    
    # TODO: Implement your actuation logic here
    # Domain-specific mapping from domain_id to actual operations
    
    pass

def main():
    print(f"Connecting to SLIME egress socket: {SOCKET_PATH}")
    
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.connect(SOCKET_PATH)
        print("Connected to SLIME egress")
    except Exception as e:
        print(f"ERROR: Failed to connect to SLIME egress: {e}", file=sys.stderr)
        sys.exit(1)
    
    try:
        while True:
            # Read exactly 32 bytes (AuthorizedEffect structure)
            data = sock.recv(32)
            
            if len(data) == 0:
                print("Socket closed by SLIME")
                break
            
            if len(data) != 32:
                print(f"WARNING: Received incomplete effect ({len(data)} bytes), skipping")
                continue
            
            # Unpack AuthorizedEffect (little-endian)
            # - domain_id: 8 bytes (u64)
            # - magnitude: 8 bytes (u64)
            # - actuation_token: 16 bytes (u128)
            domain_id, magnitude, token_low, token_high = struct.unpack('<QQQQ', data)
            token = (token_high << 64) | token_low
            
            # Perform actuation
            actuate(domain_id, magnitude, token)
    
    except KeyboardInterrupt:
        print("\nShutting down actuator bridge")
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        sock.close()

if __name__ == '__main__':
    main()
