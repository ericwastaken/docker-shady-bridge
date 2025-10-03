# ShadyBridge — HTTPS MITM Test Harness (Dante + nginx)

ShadyBridge is a lightweight MITM test harness that lets you run any HTTPS client against a different HTTPS server 
without changing the client’s code or host configuration (beyond trusting a test CA). It combines a SOCKS5 forwarder 
(Dante), an nginx reverse‑proxy that terminates TLS with a user‑provided or locally generated test CA, and simple 
routing glue so the client thinks it’s talking to the original host while traffic is actually proxied to an arbitrary 
test host.

Use it when you need to validate client behavior (requests, headers, flows, redirects, error handling, etc.) against 
alternate backend implementations, instrumentation proxies, or test environments — without rebuilding or reconfiguring 
the client.

## Key properties
- Transparent to the HTTPS client (no client changes) as long as:
  - The client does not perform certificate pinning, and
  - The host running the client will accept and trust a test CA you install.
- Works by presenting the client with certificates signed by a local test CA; nginx then forwards/rewrites the requests 
  to the target server.
- Uses a SOCKS5 gateway so you can redirect traffic from legacy or unconfigurable clients by changing only their SOCKS proxy settings (or system proxy).
- Includes a self‑signed cert builder (scripts in this repo) to create and validate a local test CA and per‑host server certs.

## Components
- Dante (SOCKS5) — receives client traffic and forwards it into the test pipeline.
- nginx (reverse‑proxy + TLS) — terminates client TLS using certs signed by the ShadyBridge CA, and proxies the request to the chosen upstream host (optionally re‑encrypting to upstream TLS).
- ShadyBridge glue — docker‑compose topology, config templates, and helper scripts to generate per‑host certs and map incoming hostnames to arbitrary upstreams.

## Typical flow
1. ShadyBridge generates (or imports) a test CA and per‑host certs signed by that CA.
2. Client → SOCKS5 (Dante) → ShadyBridge nginx (presents test cert for requested host).
3. nginx forwards the request to the configured upstream host (plain HTTP or HTTPS).
4. Responses flow back through nginx → Dante → client; client believes it talked to the original host.

## When to use
- Functional or integration testing of HTTPS clients against alternate backends.
- Instrumentation or traffic capture where you cannot modify the client.
- Simulating different server responses or injecting faults for resilience testing.

## Limitations & warnings
- Certificate pinning: If the client pins certificates (public key or fingerprint), ShadyBridge will fail — you cannot bypass pinning.
- Trust requirement: You must install/trust ShadyBridge’s CA on the client host (or in the client’s trust store) for TLS to succeed.
- Security / legal caution: ShadyBridge performs MITM on TLS traffic. Do not use it on production networks or against third‑party systems without explicit consent. Treat CA private keys and generated certs as sensitive secrets.
- Not for production: Intended strictly for testing, QA, and local dev workflows.

## Repository layout
- compose.yml — Orchestrates the Dante SOCKS5 server and nginx reverse‑proxy on a small bridge network.
- Dockerfile-dante — Dante container image with a templated config rendered at runtime.
- Dockerfile-nginx — nginx image that serves TLS from ./certs; configs are mounted into /etc/nginx/conf.d.
- nginx.tmpl.conf — per-host nginx server template with placeholders (__SERVER_NAME__, __BACKEND_IP__) used by the generator.
- danted.conf.tmpl — Dante config template (binds to 0.0.0.0:1080 and permits a configurable CIDR).
- entrypoint-*.sh — Entry points (Dante) and helper scripts.
- certs/ — Holds CA and server cert artifacts. The builder populates: ca.key.pem, ca.crt.pem, ca.crt, server.key.pem, server.crt.pem, etc.
- x-generate-certs.sh — Self‑signed cert builder/validator using hostnames from conf.yml.
- x-docker-build.sh — Generates dns-hosts and nginx per-host configs from conf.yml, then docker compose build.
- x-show-certs.sh — Convenience script to output cert details (if present).
- [README - IOS CA Cert Install.md](./README%20-%20IOS%20CA%20Cert%20Install.md) — Step‑by‑step iOS CA installation guide.
- [README - IOS SOCKS Proxy Setup.md](./README%20-%20IOS%20SOCKS%20Proxy%20Setup.md) — iOS device SOCKS proxy setup (Shadowrocket) guide.

## Prerequisites
- Docker and Docker Compose Plugin (docker compose v2+).
- OpenSSL on the host (for the certificate builder scripts).
- A client that can send traffic through a SOCKS5 proxy (system proxy, app‑specific proxy, or iOS Shadowrocket).

## Quick start
1) Define host mappings in conf.yml (single source of truth)
- Edit conf.yml and list target hostnames with their backend IPs (first IP used). Example:
  ```yaml
  targets:
    - host: example.com
      ips:
        - 93.184.216.34
    - host: www.example.com
      ips:
        - 93.184.216.34
    - host: api.example.com
      ips:
        - 203.0.113.10
  ```
- All hostnames will resolve (via dnsmasq) to the internal NGINX IP (172.30.0.3). NGINX will proxy each hostname to its configured backend IP over HTTPS.
- A single SAN certificate will be created that includes all hostnames from conf.yml.

2) Generate configs and certificates; build images
- Run:
  ```bash
  ./x-docker-build.sh
  ```
- Behavior:
  - Generates ./dnsmasq.d/dns-hosts with a single line mapping all hosts to 172.30.0.3 (the nginx container).
  - Generates per-host NGINX server configs in ./conf-nginx/ based on conf.yml.
  - Creates/validates the CA and server certificate covering all hostnames from conf.yml.
  - Builds the Docker images.

3) Start services
- Start:
  ```bash
  docker compose up -d
  ```

4) Point your client at the SOCKS5 proxy
- SOCKS5 endpoint: host running Docker, port 1080 (mapped from the Dante container).
- Ensure your client traffic uses the SOCKS5 proxy. Inside the stack, Dante resolves hostnames via the dnsmasq sidecar, which can override specific hosts to point to nginx (172.30.0.3).
- For iOS, use the Shadowrocket setup guide below.

5) Install and trust the test CA on the client
- For iOS: see [README - IOS CA Cert Install.md](./README%20-%20IOS%20CA%20Cert%20Install.md).
- For desktop/macOS browsers and tools, import ./certs/ca.crt (PEM) into the system or app trust store.

## How it works in this repo
- Networking: docker compose creates a small bridge network (172.30.0.0/29). nginx is assigned 172.30.0.3, dnsmasq 172.30.0.2.
- Routing: Dante queries the in-stack dnsmasq, which can override configured hostnames in dnsmasq.d/dns-hosts to point at nginx (172.30.0.3) for TLS termination.
- TLS: nginx serves server.crt.pem/server.key.pem that cover all hostnames listed in dnsmasq.d/dns-hosts and will be trusted by clients that install ca.crt.
- Upstream: Each generated nginx server config proxies to the backend IP specified for that hostname in dnsmasq.d/dns-hosts (proxy_ssl_server_name on; proxy_ssl_verify off by default).

## Environment variables
- DANTED_EXTERNAL — Optional. Interface name for Dante to use as its external interface. Defaults to the container’s default route interface (usually eth0).
- DANTED_USER — Optional. Runtime user for Dante (defaults to nobody).
- ALLOW_FROM — Optional. CIDR allowed to connect to Dante (defaults to 0.0.0.0/0). Tighten this for LAN‑only access.

## Client setup guides (iOS)
- CA installation: [README - IOS CA Cert Install.md](./README%20-%20IOS%20CA%20Cert%20Install.md)
- SOCKS proxy on iOS (Shadowrocket): [README - IOS SOCKS Proxy Setup.md](./README%20-%20IOS%20SOCKS%20Proxy%20Setup.md)

## Common scenarios
- A/B backend testing: Map target hostnames to different backend IPs in dnsmasq.d/dns-hosts.
- Traffic capture/instrumentation: Point hostnames to an instrumentation proxy upstream; keep ShadyBridge as the TLS edge for clients while sending to that proxy.
- Failure injection: Change the backend IP in dnsmasq.d/dns-hosts to a host that returns crafted errors/timeouts, or add nginx rules to inject faults.

## Troubleshooting
- Client shows TLS errors:
  - Ensure the client trusts ./certs/ca.crt. On iOS, follow the CA install guide and enable full trust for root certificates.
  - Verify server.crt.pem SANs include the hostname(s) you’re testing. Re‑run ./x-generate-certs.sh after updating dnsmasq.d/dns-hosts.
- Cannot connect through SOCKS:
  - Confirm Dante is listening on 0.0.0.0:1080 (docker ps; docker logs socks-dante).
  - Check ALLOW_FROM is set correctly; by default it is 0.0.0.0/0. Tighten only if you understand your network.
- Upstream handshake fails or loops:
  - Check that the backend IP configured for that hostname in dnsmasq.d/dns-hosts points to the intended upstream server and is reachable from the nginx container.
  - If your upstream uses HTTPS with required verification, consider setting proxy_ssl_verify on and mounting appropriate CA bundles into the nginx container.
- Name mismatch upstream:
  - nginx forwards SNI to the upstream (proxy_ssl_server_name on), which helps if upstream expects a particular hostname. If your upstream needs a specific Host header, you can adjust proxy_set_header Host in nginx.tmpl.conf.

## Security notes
- Treat files under ./certs as secrets, especially ca.key.pem and server.key.pem.
- Never use this setup on untrusted networks without strong controls. Remove CA trust from devices after testing.
- Do not attempt to circumvent certificate pinning.

## Cleanup
- Stop services: docker compose down
- Remove generated certs (if you need a fresh CA/certs): rm -rf certs/*
- Remove images: docker image rm <image_ids> (optional)

## References
- iOS CA installation: [README - IOS CA Cert Install.md](./README%20-%20IOS%20CA%20Cert%20Install.md)
- iOS SOCKS proxy (Shadowrocket) setup: [README - IOS SOCKS Proxy Setup.md](./README%20-%20IOS%20SOCKS%20Proxy%20Setup.md)
