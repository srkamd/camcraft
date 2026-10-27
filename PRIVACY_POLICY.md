# Privacy Policy for CamCraft: PDF & Doc Scanner

**Last Updated:** October 27, 2026  
**Effective Date:** October 27, 2026  
**Developer:** Shahrukh Ahmad (`srkamd`)  
**Application ID:** `com.srkamd.camcraft`  

---

## 1. Overview & Commitment to Privacy
CamCraft ("we", "our", or "the App") is developed as a privacy-first mobile document scanner and PDF utility. We believe that your personal, legal, financial, and business documents belong solely to you. 

CamCraft operates with an **on-device architecture**. All image processing, edge detection, perspective correction, optical character recognition (OCR), and PDF compilation happen locally on your device hardware using Google ML Kit. **We do not operate backend servers that upload, store, or inspect your scanned documents.**

---

## 2. Information We Collect and Process

### A. Camera and Photo Media
- **Purpose:** To allow you to take photos of paper documents, books, receipts, and identity cards, or import existing photos from your device gallery to generate PDF files.
- **Handling:** Images captured or imported into CamCraft are saved solely to your device's private local application storage. They are never transmitted to external cloud servers.

### B. Biometric Data (Fingerprint / Face Unlock)
- **Purpose:** If you choose to enable the optional App Lock feature, CamCraft interfaces with Android's standard BiometricPrompt API (`androidx.biometric`).
- **Handling:** CamCraft never collects, stores, or accesses your raw biometric templates. Verification is performed entirely within the Android Operating System's Secure Enclave / Hardware-backed Keystore.

### C. Device & Diagnostics Data
- We do not require account registration or login. You can use all core features anonymously without providing your name, phone number, or email address.

---

## 3. Third-Party Services & Libraries

CamCraft integrates industry-standard SDKs that may process minimal diagnostic or ad-serving information in accordance with their respective privacy policies:

1. **Google ML Kit (Document Scanner, OCR, Barcode Scanning):**
   - Provided by Google LLC.
   - Processing is executed locally on-device.
   - [Google ML Kit Terms & Privacy](https://developers.google.com/ml-kit/terms)

2. **Google AdMob (Advertising & Monetization):**
   - We may display advertisements provided by Google AdMob. AdMob may collect and process device identifiers (such as Android Advertising ID), non-personal usage data, and IP addresses to serve personalized or non-personalized ads.
   - [Google Privacy & Terms for Advertising](https://policies.google.com/technologies/ads)

---

## 4. Data Retention and Deletion
- All scanned documents, extracted text, and generated PDF files remain on your phone until you explicitly delete them inside the App or uninstall the App.
- Uninstalling the App immediately erases all locally saved document databases and caches.

---

## 5. Children's Privacy
CamCraft is not directed at children under the age of 13. We do not knowingly collect personal identifiable information from children.

---

## 6. Security
We value your trust in providing us with your documents for on-device processing. We implement modern Android security standards, including Scoped Storage, AES encryption for password-protected PDFs, and hardware-backed biometric verification.

---

## 7. Changes to This Privacy Policy
We may update our Privacy Policy from time to time. Any changes will be posted on this page with an updated effective date.

---

## 8. Contact Us
If you have any questions or feedback regarding this Privacy Policy, please contact:
- **Developer:** Shahrukh Ahmad
- **GitHub Repository:** [https://github.com/srkamd/scancraft](https://github.com/srkamd/scancraft)
- **Contact Email:** `srkamd.dev@gmail.com`
