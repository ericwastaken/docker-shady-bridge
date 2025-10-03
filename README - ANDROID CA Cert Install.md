# README - ANDROID Install CA.CRT

This guide explains how to install and trust a custom Certificate Authority (CA) on Android so that HTTPS connections 
to your proxy or test backend succeed without TLS errors.

## 1. Prepare the CA Certificate
- Make sure you have your CA certificate in **PEM/CRT format** (e.g. `ca.crt` or `ca.pem`).
- If you have a `.pem` file, you can usually just rename it to `ca.crt` — it's the same format.
- Keep the private key (`ca.key`) offline and secret; you only install the public `ca.crt` on the device.
- Note: the generate-certs scripts in this repo likely already produced `certs/ca.crt`.

## 2. Transfer to the Device
You can get the certificate file onto your Android device using one of the following:
- **WEB / HTTP**: open a browser and navigate to `http://<host>:8080`. A page will provide a link to download the CA 
  certificate.
- **USB / MTP**: copy `ca.crt` into `Download/` on the device.
- **Email**: email the file to yourself and open it in the Mail app on the device.
- **Local web server**: host `http://<host>/ca.crt` temporarily and download it via Chrome.
- **ADB (developer)**:

```
adb push ca.crt /sdcard/Download/ca.crt
```

When the file is on the device, note where you saved it (e.g., Downloads).

## 3. Install the CA Certificate
1. Open **Settings** on the Android device.
2. Go to **Security** (may be named "Security & privacy", "Lock screen & security", or "Biometrics & security").
3. Tap **Encryption & credentials** or **Install from storage / Install a certificate** (text varies by vendor and Android version).
4. Choose **CA certificate** (or **Trusted credentials → Install from storage**).
5. Select the `ca.crt` file you copied (likely in Downloads).
6. Give the certificate a name (e.g., "ShadyBridge Test CA") and confirm.
7. If prompted for your screen lock PIN/passcode, enter it to allow the install.

## 4. Verify
- Open **Settings → Security → Trusted credentials**.
- Switch to the **User** tab (or look under User credentials). You should see your CA listed.
- Connect your client/proxy as needed and visit an HTTPS site through it.
- If the app uses the system trust store and does not reject user CAs, TLS errors should no longer appear.

## 5. Remove the CA (cleanup after testing)
1. Go to **Settings → Security → Trusted credentials** (or **Encryption & credentials**).
2. Open the **User** tab and locate the CA you installed.
3. Tap it and choose **Remove** or **Uninstall**.
4. Reboot to ensure trust removal is applied everywhere.

## ⚠️ Notes
- Android 7+ (Nougat) and later: Apps targeting API level 24+ typically do not trust user-installed CAs by default. 
  Many modern apps (including Chrome/WebView, or apps with certificate pinning) ignore user CAs unless they opt in via 
  a network security configuration. Installing a user CA may not be sufficient for those apps.
- Emulators: Android emulators (AVD) are handy for testing because you can add the CA to the system store (or push 
  into `/system/etc/security/cacerts/` on rooted/emulator images) so Chrome/WebView accepts it.
- Rooted devices: If you control a rooted device, you can install the CA into the system store (not covered here) so 
  all apps, including Chrome, will trust it.
- Security: Only install CAs you control. Trusting a malicious CA compromises device security. Remove the CA after testing.
