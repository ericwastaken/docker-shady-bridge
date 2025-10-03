# README - IOS SOCKS PROXY (Shadowrocket) Setup

This guide explains how to configure the **Shadowrocket** app on iOS to connect to your Dante SOCKS5 proxy running on 
a Mac (or other Docker host). With this configuration, all app traffic on the iOS device will be tunneled through the 
SOCKS proxy.

## 1. Prerequisites
- A running **Dante SOCKS5 proxy** container (e.g., `socks-dante`) on your Mac.
- Your Mac’s **LAN IP address** (check with `ipconfig getifaddr en0` on macOS).
- Shadowrocket installed from the iOS App Store (paid app).
- Optional: a custom CA certificate installed and trusted on iOS (see `README - IOS Install CA.CRT`) if your proxy 
  presents TLS certificates signed by your CA.

## 2. Open Shadowrocket and Add Proxy
1. Launch **Shadowrocket**.
2. Tap the **`+`** icon in the top-right corner to add a new server.
3. Configure the following:
    - **Type:** SOCKS5
    - **Host:** `<YOUR_MAC_IP>`  
      (example: `192.168.1.25`)
    - **Port:** `1080`
    - **Username / Password:** leave blank (unless you configured authentication in Dante).
    - **Remarks:** optional label, e.g., `Dante Proxy`.

4. Tap **Done** to save.

## 3. Enable the Proxy
1. On the Shadowrocket main screen, tap the **toggle switch** at the top.
2. iOS will prompt to install a VPN configuration the first time:
    - Tap **Allow**.
    - Enter your device passcode or confirm with Face ID/Touch ID.
3. The **VPN key icon** should appear in the status bar when active.

## 4. Verification
- Open Safari and visit [https://ifconfig.me](https://ifconfig.me).  
  The IP shown should be your Mac/ISP’s external IP, not your mobile carrier’s.
- Open https://yourhost.yourdomain.com  
  It should connect successfully through Dante. If you installed your CA cert, there should be no TLS warnings.

## 5. Notes
- To **disable the proxy**, toggle Shadowrocket off. The VPN icon disappears and traffic flows normally.
- You can add rules in Shadowrocket to proxy only certain domains or apps. For full-device proxying, leave the default 
  “Global” mode.
- If you see TLS errors, ensure your CA certificate is trusted in iOS (see companion README).
- Shadowrocket tunnels all app traffic (Wi-Fi and cellular) while enabled.

## ⚠️ Security Reminder
- Only connect Shadowrocket to proxies you trust.
- Remove your CA certificate from iOS once testing is complete to restore normal certificate security.