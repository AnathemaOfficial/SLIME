use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::os::unix::net::UnixStream;
use std::thread;
use std::time::Duration;
use std::sync::{Mutex, OnceLock};

//
// -------------------- Types --------------------
//

#[derive(Clone, Copy)]
struct AuthorizedEffect {
    domain_id: u64,
    magnitude: u64,
    actuation_token: u128,
}

struct ActionRequest {
    domain_id: u64,
    magnitude: u64,
}

//
// -------------------- Utilities --------------------
//

fn read_http_body(mut stream: &TcpStream) -> Vec<u8> {
    let mut buf = [0u8; 8192];
    let mut out = Vec::new();

    // basic, manual HTTP read
    if let Ok(n) = stream.peek(&mut buf) {
        if n == 0 { return out; }
    }

    // read a bit
    let mut tmp = [0u8; 4096];
    if let Ok(n) = stream.read(&mut tmp) {
        out.extend_from_slice(&tmp[..n]);
    }

    out
}

fn parse_request(raw: &[u8]) -> Option<ActionRequest> {
    let text = std::str::from_utf8(raw).ok()?;

    // extremely dumb parse (dummy)
    // expects {"domain":"test","magnitude":10,"payload":""}
    let domain = if let Some(p) = text.find("\"domain\"") {
        let s = &text[p..];
        let q1 = s.find('"')?;
        let s2 = &s[q1 + 1..];
        let q2 = s2.find('"')?;
        let s3 = &s2[q2 + 1..];
        let q3 = s3.find('"')?;
        let s4 = &s3[q3 + 1..];
        let q4 = s4.find('"')?;
        &s4[..q4]
    } else {
        "test"
    };

    let magnitude = if let Some(p) = text.find("\"magnitude\":") {
        let s = &text[p + 12..];
        s.parse::<u64>().unwrap_or(0)
    } else {
        return None;
    };

    // deterministic domain_id: hash domain string to u64 (dummy)
    let domain_id = fnv1a_64(domain.as_bytes());

    Some(ActionRequest { domain_id, magnitude })
}

fn fnv1a_64(data: &[u8]) -> u64 {
    let mut hash: u64 = 0xcbf29ce484222325;
    for b in data {
        hash ^= *b as u64;
        hash = hash.wrapping_mul(0x100000001b3);
    }
    hash
}

//
// -------------------- Egress (CANON v0) --------------------
//

mod egress {
    use super::*;
    use std::io::Write;
    use std::process;

    // Canonical, non-configurable path (SLIME v0)
    const SOCKET_PATH: &str = "/run/slime/egress.sock";

    // Store a single connected stream for the process lifetime.
    // - Boot-time: connect must succeed or SLIME terminates (fail-closed hard)
    // - Runtime: write failures are dropped silently (best-effort)
    static STREAM: OnceLock<Mutex<UnixStream>> = OnceLock::new();

    pub fn init_fail_closed() {
        let s = UnixStream::connect(SOCKET_PATH).unwrap_or_else(|_| {
            // No logs, no retries: if SLIME cannot actuate, it must not run.
            process::exit(1);
        });

        let _ = STREAM.set(Mutex::new(s));
    }

    pub fn apply(effect: AuthorizedEffect) {
        let stream = STREAM.get();
        if stream.is_none() {
            // Defensive: init is a boot prerequisite. If not initialized, fail-closed.
            process::exit(1);
        }
        let mut guard = stream.unwrap().lock().unwrap();

        // Serialize exact 32 bytes (LE): u64 + u64 + u128
        let mut buf = [0u8; 32];
        buf[0..8].copy_from_slice(&effect.domain_id.to_le_bytes());
        buf[8..16].copy_from_slice(&effect.magnitude.to_le_bytes());
        buf[16..32].copy_from_slice(&effect.actuation_token.to_le_bytes());

        // Best-effort write. Any error is a silent drop (no feedback channel).
        let _ = guard.write_all(&buf);
    }
}

//
// -------------------- Ingress (Dummy HTTP) --------------------
//

mod ingress {
    use super::*;

    pub fn start() {
        let listener = TcpListener::bind("127.0.0.1:8080").unwrap();

        for conn in listener.incoming() {
            if let Ok(stream) = conn {
                handle(stream);
            }
        }
    }

    fn handle(mut stream: TcpStream) {
        // read request
        let raw = read_http_body(&stream);

        // parse
        let req = match parse_request(&raw) {
            Some(r) => r,
            None => {
                let _ = stream.write_all(b"HTTP/1.1 400 Bad Request\r\n\r\n");
                return;
            }
        };

        // decision: always AUTHORIZED for dummy
        let effect = AuthorizedEffect {
            domain_id: req.domain_id,
            magnitude: req.magnitude,
            actuation_token: 0xABCD_EF01_2345_6789_ABCD_EF01_2345_6789u128,
        };

        crate::egress::apply(effect);

        let _ = stream.write_all(b"HTTP/1.1 200 OK\r\n\r\n");
    }
}

//
// -------------------- Main --------------------
//

fn main() {
    // Canon prerequisite: actuator socket must exist and be connectable at boot.
    crate::egress::init_fail_closed();

    thread::spawn(|| ingress::start());

    loop {
        thread::sleep(Duration::from_secs(1));
    }
}
