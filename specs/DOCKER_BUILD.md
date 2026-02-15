# SLIME v0 — Docker Package Build Specification

**Purpose:** Define the hermetic Docker container for SLIME v0  
**Target:** Production-ready sealed artifact

---

## 1. Build Requirements

### 1.1 Prerequisites

- Docker 20.10+
- AB-S Phase 7.0 compiled library (`libabs-sealed.a`)
- Rust toolchain (for building SLIME runtime)
- Git (for verification)

### 1.2 Build Environment

```bash
# Build host requirements
OS: Linux x86_64
Docker: Buildkit enabled
Build time: ~5 minutes
Final image size: <50MB
```

---

## 2. Dockerfile

```dockerfile
# SLIME v0 — Hermetic Container
# Multi-stage build for minimal final image

# ==================== Stage 1: Build ====================
FROM rust:1.75-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    musl-dev \
    openssl-dev \
    git

WORKDIR /build

# Copy AB-S sealed library
COPY lib/libabs-sealed.a /build/lib/

# Copy SLIME runtime source
COPY src/ /build/src/
COPY Cargo.toml Cargo.lock /build/

# Build SLIME runtime (static binary)
RUN cargo build --release --target x86_64-unknown-linux-musl

# Verify binary is static
RUN ldd /build/target/x86_64-unknown-linux-musl/release/slime-runtime \
    && exit 1 || exit 0

# ==================== Stage 2: Runtime ====================
FROM alpine:3.19

# Create non-root user
RUN addgroup -g 1000 slime && \
    adduser -D -u 1000 -G slime slime

WORKDIR /opt/slime

# Copy binary from builder
COPY --from=builder \
    /build/target/x86_64-unknown-linux-musl/release/slime-runtime \
    /opt/slime/bin/slime-runtime

# Copy dashboard web UI
COPY web/dashboard.html /opt/slime/web/

# Copy verification artifacts
COPY verification/ /opt/slime/verification/

# Copy minimal documentation
COPY docs/OPERATIONS.md /opt/slime/docs/

# Set ownership
RUN chown -R slime:slime /opt/slime && \
    chmod 500 /opt/slime/bin/slime-runtime

# Switch to non-root user
USER slime

# Expose ports
EXPOSE 8080/tcp
EXPOSE 8081/tcp

# Create egress socket directory
RUN mkdir -p /run/slime && chown slime:slime /run/slime

# Volume for egress socket (shared with host)
VOLUME ["/run/slime"]

# Health check
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8081/health || exit 1

# No environment variables (sealed configuration)

# Entrypoint (no shell, no PID 1 issues)
ENTRYPOINT ["/opt/slime/bin/slime-runtime"]

# No CMD (no arguments accepted)

# ==================== Metadata ====================
LABEL maintainer="SYFCORP <enterprise@syfcorp.io>"
LABEL version="v0.1.0"
LABEL description="SLIME v0 - Sealed execution environment"
LABEL ab.core.hash="07e501b05b87d1fed647e156f8b7929ab073ce7e"
LABEL canon.sealed="true"
```

---

## 3. Build Process

### 3.1 Directory Structure

```
docker-build/
├── Dockerfile
├── src/
│   ├── main.rs
│   ├── ingress/
│   ├── egress/
│   └── dashboard/
├── lib/
│   └── libabs-sealed.a        # AB-S Phase 7.0 library
├── web/
│   └── dashboard.html
├── verification/
│   ├── CANON_HASH.txt         # 07e501b0...
│   └── MANIFEST.sha256
├── docs/
│   └── OPERATIONS.md
├── Cargo.toml
└── Cargo.lock
```

### 3.2 Build Command

```bash
# Enable BuildKit
export DOCKER_BUILDKIT=1

# Build image
docker build \
  --tag syfcorp/slime-v0:latest \
  --tag syfcorp/slime-v0:v0.1.0 \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  --label "build.date=$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --label "build.commit=$(git rev-parse HEAD)" \
  .

# Verify build
docker images syfcorp/slime-v0
```

Expected output:
```
REPOSITORY          TAG       IMAGE ID       SIZE
syfcorp/slime-v0    latest    abc123...      48MB
syfcorp/slime-v0    v0.1.0    abc123...      48MB
```

---

## 4. Image Verification

### 4.1 Inspect Image

```bash
# Check image metadata
docker inspect syfcorp/slime-v0:latest | jq '.[0].Config.Labels'
```

Expected labels:
```json
{
  "version": "v0.1.0",
  "ab.core.hash": "07e501b05b87d1fed647e156f8b7929ab073ce7e",
  "canon.sealed": "true"
}
```

### 4.2 Run Verification Tests

```bash
# Test 1: Image starts successfully
docker run --rm syfcorp/slime-v0:latest &
sleep 3
curl http://localhost:8081/health

# Test 2: No shell access
docker exec slime-v0 /bin/sh
# Should fail (no shell in image)

# Test 3: Binary is static
docker run --rm syfcorp/slime-v0:latest ldd /opt/slime/bin/slime-runtime
# Should output: "not a dynamic executable"

# Test 4: Runs as non-root
docker run --rm syfcorp/slime-v0:latest id
# Should output: uid=1000(slime) gid=1000(slime)
```

---

## 5. Image Signing and Distribution

### 5.1 Sign Image

```bash
# Generate signing key (one-time)
docker trust key generate syfcorp

# Sign and push
docker trust sign syfcorp/slime-v0:v0.1.0
docker push syfcorp/slime-v0:v0.1.0
docker push syfcorp/slime-v0:latest
```

### 5.2 Generate SHA256 Manifest

```bash
# Get image digest
docker inspect --format='{{index .RepoDigests 0}}' syfcorp/slime-v0:v0.1.0

# Output example:
# syfcorp/slime-v0@sha256:abc123def456...

# Save to manifest
docker inspect syfcorp/slime-v0:v0.1.0 | \
  jq -r '.[0].RepoDigests[0]' > DOCKER_MANIFEST.sha256
```

---

## 6. Runtime Configuration

### 6.1 Fixed Endpoints

SLIME v0 has **no configuration**. All endpoints are hardcoded:

**Ingress:**
- HTTP server on port `8080`
- Endpoint: `POST /action`

**Dashboard:**
- HTTP server on port `8081`
- Read-only web interface and metrics API

**Egress:**
- Unix domain socket at `/run/slime/egress.sock`
- Created by SLIME on startup
- Permissions: `0600` (owner `slime`, group `slime`)

**No environment variables are read.**  
**No configuration files are parsed.**

### 6.2 Port Mapping

```bash
# Ingress (required)
-p 8080:8080

# Dashboard (optional, recommended)
-p 8081:8081
```

### 6.3 Volume Mount for Egress

**Required volume:** `/run/slime`

This exposes the egress socket to the host, allowing actuator bridges to connect.

```bash
-v /run/slime:/run/slime
```

---

## 7. Production Deployment Example

### 7.1 Docker Compose

```yaml
version: '3.8'

services:
  slime:
    image: syfcorp/slime-v0:v0.1.0
    container_name: slime-v0
    restart: unless-stopped
    
    ports:
      - "8080:8080"  # Ingress
      - "8081:8081"  # Dashboard
    
    volumes:
      - /run/slime:/run/slime  # Egress socket
    
    networks:
      - slime-net
    
    healthcheck:
      test: ["CMD", "wget", "--spider", "http://localhost:8081/health"]
      interval: 10s
      timeout: 3s
      retries: 3
    
    # Security hardening
    read_only: true
    tmpfs:
      - /run/slime:mode=0755
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL

  actuator:
    image: your-actuator-bridge:latest
    container_name: actuator-bridge
    restart: unless-stopped
    
    volumes:
      - /run/slime:/run/slime  # Connect to egress socket
    
    networks:
      - slime-net
    
    depends_on:
      - slime

networks:
  slime-net:
    driver: bridge
```

Deploy:
```bash
docker-compose up -d
docker-compose ps
docker-compose logs -f slime
```

---

## 8. Image Update Policy

### 8.1 Versioning

SLIME uses semantic versioning:
- `v0.1.0` - Initial release
- `v0.1.1` - Patch (bug fixes only, no feature changes)
- `v0.2.0` - Minor (reserved for future, v0 is frozen)

### 8.2 Update Procedure

**SLIME v0 instances are not updated in-place.**

To deploy new version:
```bash
# 1. Pull new image
docker pull syfcorp/slime-v0:v0.1.1

# 2. Stop old container
docker stop slime-v0

# 3. Remove old container
docker rm slime-v0

# 4. Start new container
docker run -d \
  --name slime-v0 \
  -p 8080:8080 \
  -p 8081:8081 \
  -e SLIME_EGRESS_URL=http://actuator:9000/execute \
  syfcorp/slime-v0:v0.1.1
```

**No state migration needed (stateless).**

---

## 9. Security Hardening

### 9.1 Read-Only Filesystem

```bash
docker run -d \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=10M \
  syfcorp/slime-v0:latest
```

### 9.2 Resource Limits

```bash
docker run -d \
  --memory=256M \
  --memory-swap=256M \
  --cpu-shares=512 \
  --pids-limit=50 \
  syfcorp/slime-v0:latest
```

### 9.3 Network Isolation

```bash
# Create isolated network
docker network create --driver bridge slime-isolated

# Run SLIME in isolated network
docker run -d \
  --network slime-isolated \
  --network-alias slime \
  syfcorp/slime-v0:latest

# Only allow specific upstream system access
docker run -d \
  --network slime-isolated \
  your-upstream-system
```

---

## 10. Build Artifacts Checklist

After build, verify these artifacts exist:

- [ ] Docker image: `syfcorp/slime-v0:v0.1.0`
- [ ] Docker image: `syfcorp/slime-v0:latest`
- [ ] Image digest: `DOCKER_MANIFEST.sha256`
- [ ] Image size: <50MB
- [ ] Labels: version, ab.core.hash, canon.sealed
- [ ] Health check: functional
- [ ] Static binary: verified
- [ ] Non-root user: verified
- [ ] No shell: verified
- [ ] Signature: applied

---

## 11. Distribution Channels

### 11.1 Docker Hub

```bash
# Push to Docker Hub
docker push syfcorp/slime-v0:v0.1.0
docker push syfcorp/slime-v0:latest
```

### 11.2 Private Registry

```bash
# Tag for private registry
docker tag syfcorp/slime-v0:v0.1.0 registry.company.com/slime-v0:v0.1.0

# Push to private registry
docker push registry.company.com/slime-v0:v0.1.0
```

### 11.3 Archive Export

```bash
# Save image as tar archive for airgapped deployment
docker save syfcorp/slime-v0:v0.1.0 | gzip > slime-v0-v0.1.0.tar.gz

# Load on airgapped system
gunzip < slime-v0-v0.1.0.tar.gz | docker load
```

---

## 12. Testing the Built Image

### 12.1 Smoke Test Suite

```bash
#!/bin/bash
# smoke-test.sh

set -e

echo "=== SLIME v0 Smoke Test ==="

# Start SLIME
docker run -d --name slime-test \
  -p 8080:8080 \
  -p 8081:8081 \
  -e SLIME_EGRESS_URL=http://mock-egress:9000 \
  syfcorp/slime-v0:latest

sleep 3

# Test 1: Health check
echo "Test 1: Health check"
curl -f http://localhost:8081/health || exit 1

# Test 2: Version endpoint
echo "Test 2: Version endpoint"
curl -f http://localhost:8081/version | grep "07e501b0" || exit 1

# Test 3: Action endpoint (format validation)
echo "Test 3: Action endpoint"
curl -X POST http://localhost:8080/action \
  -H "Content-Type: application/json" \
  -d '{"domain":"test","magnitude":10,"payload":"dGVzdA=="}' || exit 1

# Test 4: Dashboard accessible
echo "Test 4: Dashboard"
curl -f http://localhost:8081/ || exit 1

# Test 5: Metrics endpoint
echo "Test 5: Metrics"
curl -f http://localhost:8081/metrics || exit 1

# Cleanup
docker stop slime-test
docker rm slime-test

echo "=== All tests passed ==="
```

Run tests:
```bash
chmod +x smoke-test.sh
./smoke-test.sh
```

---

**END — DOCKER PACKAGING SPECIFICATION**

The Docker image is now ready for enterprise deployment.
