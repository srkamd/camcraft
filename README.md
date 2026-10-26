# 📄 ScanCraft: Easy PDF & Doc Scanner

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Google%20ML%20Kit-4285F4?style=for-the-badge&logo=google&logoColor=white" alt="Google ML Kit" />
  <img src="https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge" alt="License" />
</p>

<p align="center">
  <strong>ScanCraft</strong> is a comprehensive, production-grade mobile document scanner, PDF utility, and productivity suite built with Flutter and Google ML Kit. It delivers CamScanner Pro features: auto edge detection, perspective correction, image filters, dual-sided ID Card merging, intelligent high-accuracy OCR, digital signatures, AES-128 PDF password protection, PDF compression presets, multi-document merging, built-in QR/Barcode scanner, and biometric app lock.
</p>

---

## ✨ Features at a Glance

### 📸 1. Intelligent Document Scanner
* **Auto Edge Detection:** Real-time boundary recognition detects documents instantly on any surface.
* **Perspective Dewarping:** Converts tilted/angled photos into flat, deskewed rectangular scans.
* **Magic Filters:** High-contrast color enhancement, B&W photocopy filter, and shadow removal.
* **Batch Scanning:** Scan up to 20 pages seamlessly in a single workflow.

### 🪪 2. ID Card & License Mode
* Specialized dual-sided capture workflow for National ID Cards, Driver's Licenses, and Student IDs.
* Automatically aligns and composites both **Front** and **Back** sides onto a single standard A4 printable sheet.

### ✍️ 3. Digital Signature (E-Sign)
* Smooth in-app signature drawing pad with customizable ink colors (Black, Navy Blue, Emerald Green, Crimson Red).
* One-tap stamping and permanent burning of transparent signatures onto any document page.

### 🔍 4. Optimized High-Accuracy OCR (Text Extraction)
* Pre-processed computer vision pipeline (Grayscale normalization + Contrast boost) feeding Google ML Kit text models for 99% character accuracy.
* 100% offline and private.
* Copy text, share instantly, or export as `.txt`.

### 🔒 5. PDF Security & AES-128 Password Protection
* Lock sensitive documents with AES-128 user & owner passwords.
* Add custom diagonal watermarks (e.g., *"CONFIDENTIAL"*, *"ORIGINAL"*).

### 🗜️ 6. Smart PDF Compressor
* Choose from 3 compression presets before export:
  - **Standard (Recommended):** Reduces file size by ~65% while keeping text crystal clear.
  - **Compact:** Ultra-compressed for instant WhatsApp and email sharing (~85% smaller).
  - **Original:** Full-resolution HD archive quality.

### 🔀 7. Multi-Document PDF Merger
* Select 2 or more scanned documents with checkboxes and merge all pages into a single unified master document.

### 📷 8. QR Code & Barcode Scanner
* Scan any QR code or barcode from camera or gallery.
* Direct URL launching, text copying, and saving decoded results as document notes.

### 🛡️ 9. Biometric App Lock
* Protect confidential scans with device Fingerprint or Face ID authentication via Android BiometricPrompt.

---

## 🛠️ Tech Stack & Architecture

| Technology | Purpose |
|---|---|
| **Flutter & Dart** | Cross-platform framework for fast, native UI performance |
| **Google ML Kit Document Scanner** | Machine learning document boundary detection and auto-crop |
| **Google ML Kit Text Recognition** | On-device OCR text extraction engine |
| **Google ML Kit Barcode Scanning** | High-speed QR code and 1D/2D barcode reader |
| **PDF & Printing** | Multi-page PDF generation, AES-128 encryption & watermarking |
| **Signature** | Custom drawing canvas for digitizing signatures |
| **Local Auth** | Android BiometricPrompt fingerprint and face security |
| **Image** | Pixel-level canvas composition, resizing, and contrast pre-processing |
| **Shared Preferences** | Local persistence for metadata, documents, and settings |

---

## 📂 Project Structure

```text
scancraft/
├── android/                        # Native Android configuration, biometric permissions
├── lib/
│   ├── models/
│   │   └── scanned_document.dart    # Document data model & JSON serialization
│   ├── screens/
│   │   ├── home_screen.dart            # Dashboard, search, tags, multi-select merge & app lock
│   │   ├── document_detail_screen.dart # Multi-page viewer, rotation, PDF options & E-Sign
│   │   ├── id_card_scanner_screen.dart # 2-sided ID Card merger onto A4 canvas
│   │   ├── signature_screen.dart       # Digital signature canvas & ink picker
│   │   ├── qr_scanner_screen.dart      # QR code & Barcode scanner tool
│   │   └── ocr_result_screen.dart      # OCR text viewer, editor & .txt exporter
│   ├── services/
│   │   ├── scanner_service.dart        # ML Kit Document Scanner wrapper
│   │   ├── pdf_service.dart            # Multi-page PDF, encryption & compression presets
│   │   ├── ocr_service.dart            # Image pre-processing & text extraction engine
│   │   ├── barcode_service.dart        # Barcode & QR code detection engine
│   │   ├── security_service.dart       # Biometric authentication & app lock manager
│   │   └── storage_service.dart        # Local JSON persistence CRUD
│   ├── theme/
│   │   └── app_theme.dart              # Teal/Emerald CamScanner design system
│   ├── widgets/
│   │   └── document_card.dart          # Thumbnail card with badges & context actions
│   └── main.dart                       # App entry point
└── pubspec.yaml                        # Project dependencies
```

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (>= 3.0.0)
* Android Studio or VS Code with Flutter extension
* Android device or emulator (Android 5.0+, API 21+)

### Installation & Run

```bash
# Clone the repository
git clone https://github.com/srkamd/scancraft.git
cd scancraft

# Install dependencies
flutter pub get

# Run on device
flutter run

# Build Release APK
flutter build apk --release
```

*The generated APK will be located at: `build/app/outputs/flutter-apk/app-release.apk`*

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  Built with ❤️ using <strong>Flutter</strong> & <strong>Google ML Kit</strong>
</p>
