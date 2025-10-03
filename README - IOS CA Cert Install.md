# README - IOS Install CA.CRT

This guide explains how to install and trust a custom Certificate Authority (CA) on iOS so that HTTPS connections to your proxy or test backend succeed without TLS errors.

## 1. Prepare the CA Certificate
- Make sure you have your CA certificate in **PEM/CRT format** (e.g. `ca.crt.pem`).
- Rename it to `ca.crt` for simplicity.
- Note that the generate certs scripts in this repo should have already done this for you.

## 2. Transfer to the Device
You can get the certificate file onto your iPhone/iPad using one of the following:
- **WEB / HTTP**: open a browser and navigate to `http://<host>:8080`. A page will provide a link to download the CA
  certificate.
- **AirDrop** the `ca.crt` file from your Mac.
- **Email** the file to yourself and open it in the Mail app.
- **Host it temporarily** on your local web server and download via Safari.

When you open the file, iOS will say **“Profile Downloaded.”**

## 3. Install the Profile
1. On your iPhone, go to:  
   **Settings → General → VPN & Device Management**  
   (On some iOS versions this may be **Profiles & Device Management**).
2. Under **Downloaded Profile**, select your CA certificate.
3. Tap **Install** and enter your device passcode.
4. Confirm the installation.

## 4. Trust the Root CA
1. Go to:  
   **Settings → General → About → Certificate Trust Settings**
2. Find your newly installed CA under *Enable Full Trust for Root Certificates*.
3. Turn the toggle **ON** to fully trust this CA.
4. Confirm.

## 5. Verify
- Connect to your proxy and visit an HTTPS URL in Safari.
- You should **no longer see TLS errors**.
- Apps that use iOS’s system TLS (including curl without `--insecure`) should now trust your proxy certificates.

## ⚠️ Notes
- Only install and trust CAs you control. Trusting a malicious CA compromises device security.
- After testing, **remove the CA**:  
  **Settings → General → VPN & Device Management → Profiles → Remove Profile**.