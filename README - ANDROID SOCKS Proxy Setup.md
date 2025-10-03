# README - ANDROID SOCKS PROXY (Tun2Socks) Setup

This guide explains how to configure the Tun2Socks app on Android to connect to your Dante SOCKS5 proxy running on a 
Mac (or other Docker host). With this configuration, all traffic on the Android device can be tunneled through the SOCKS proxy.

## 1. Prerequisites
- A running **Dante SOCKS5 proxy** container (e.g., `shadybridge-dante`) on your Mac or Linux host.
- Your host machine’s **LAN IP address** (check with `ipconfig getifaddr en0` on macOS or `ip addr` on Linux).
- Tun2Socks installed from the Google Play Store (free app).
- Optional: a custom CA certificate installed and trusted on Android (see `README - ANDROID Install CA.CRT`) if your 
  proxy presents TLS certificates signed by your CA.

## 2. Open Tun2Socks and Add Proxy
1. Launch **Tun2Socks**.
2. Configure the following:
    - **Socks host:** `<YOUR_HOST_IP>`  
      (example: `192.168.1.25`)
    - **Port:** `1080`
    - **Username / Password:** leave blank (unless you configured authentication in Dante).

## 3. Enable the Proxy
1. On the main Tun2Socks screen, tap **Start Connect**.
3. Android will prompt to allow a VPN connection:
    - Tap **OK / Allow**.
4. A VPN key icon will appear in the status bar when active.

## 4. Verification
- Open Chrome or Firefox and visit [https://ifconfig.me](https://ifconfig.me).  
  The IP shown should be your Mac/ISP’s external IP, not your mobile carrier’s.
- Open a test HTTPS site you are redirecting through ShadyBridge. If you installed your CA cert, there should be no 
  TLS warnings.

## 5. Notes
- To disable the proxy, tap **Disconnect** in Tun2Socks. The VPN icon will disappear and traffic flows normally again.
- Tun2Socks proxies all traffic on the device (both Wi-Fi and cellular) while enabled.
- If you see TLS errors, make sure your CA certificate is installed and trusted on Android (see companion README).

## ⚠️ Security Reminder
- Only connect Tun2Socks to proxies you trust.
- Remove your CA certificate from Android once testing is complete to restore normal certificate security.