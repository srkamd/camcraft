# 📄 ScanCraft: Easy PDF & Doc Scanner

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Google%20ML%20Kit-4285F4?style=for-the-badge&logo=google&logoColor=white" alt="Google ML Kit" />
  <img src="https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge" alt="License" />
</p>

<p align="center">
  <strong>ScanCraft</strong> is a modern, high-performance mobile document scanner and PDF utility built with Flutter and powered by Google ML Kit. It brings CamScanner-grade scanning, automatic edge detection, perspective correction, image enhancement, dual-sided ID Card merging, on-device OCR, and watermarked PDF generation directly to your smartphone.
</p>

---

## ✨ Features at a Glance

### 📸 1. Intelligent Document Scanner
* **Auto Edge Detection:** Real-time boundary recognition detects documents instantly on any surface.
* **Perspective Dewarping:** Automatically straightens skewed, angled, or tilted photos into crisp rectangular documents.
* **Magic Filters:** High-contrast color enhancement, B&W photocopy filter, and shadow removal.
* **Batch Multi-Page Scanning:** Seamlessly scan up to 20 pages in one session.

### 🪪 2. ID Card & License Mode
* Specialized dual-sided capture workflow for National ID Cards, Driver's Licenses, and Student IDs.
* Automatically aligns and composites both **Front** and **Back** sides onto a single standard A4 printable sheet.

### 🔍 3. On-Device OCR (Text Extraction)
* Extracts printed text from any document page using Google ML Kit's Latin/English text recognition models.
* 100% offline, zero-latency, and private (no data leaves the device).
* Single-tap to copy text to clipboard, share directly, or export as `.txt`.

### 📑 4. PDF Generation & Custom Watermarking
* Creates lightweight, high-resolution multi-page PDF documents.
* Add custom diagonal watermarks (e.g., *"CONFIDENTIAL"*, *"ORIGINAL"*, or author name).
* Direct one-tap sharing to WhatsApp, Google Drive, Gmail, Telegram, etc.

### 🗂️ 5. Clean Document Management
* Categorize documents with tags: `Docs`, `ID Cards`, `Notes`, `Receipts`.
* Live title-based search.
* Page management: Rotate 90°, delete individual pages, or append new pages from the Camera or Gallery.
* Local persistence to ensure scans are never lost.

---

## 🛠️ Tech Stack & Libraries

| Technology | Purpose |
|---|---|
| **Flutter & Dart** | Cross-platform framework for fast, native UI performance |
| **Google ML Kit Document Scanner** | Pre-built edge detection, perspective transform, and enhancement filters |
| **Google ML Kit Text Recognition** | Fast, on-device optical character recognition (OCR) |
| **PDF & Printing** | Multi-page PDF creation and dynamic watermarking |
| **Image** | Pixel-level canvas composition for ID Card dual-sided stitching |
| **Shared Preferences** | Local JSON document metadata storage |
| **Share Plus & OpenFilex** | Native sharing sheet and in-app file preview |

---

## 📂 Project Architecture

```text
scancraft/
├── android/                        # Android native configurations & permissions
├── lib/
│   ├── models/
│   │   └── scanned_document.dart    # ScannedDocument data model & JSON serialization
│   ├── screens/
│   │   ├── home_screen.dart            # Main dashboard, search bar & category chips
│   │   ├── document_detail_screen.dart # Multi-page viewer, rotation, PDF & OCR triggers
│   │   ├── id_card_scanner_screen.dart # 2-sided ID Card merger onto A4 canvas
│   │   └── ocr_result_screen.dart      # OCR text viewer, editor, and .txt exporter
│   ├── services/
│   │   ├── scanner_service.dart        # ML Kit Document Scanner & image persistence
│   │   ├── pdf_service.dart            # PDF generation, custom watermarking & sharing
│   │   ├── ocr_service.dart            # ML Kit text extraction engine
│   │   └── storage_service.dart        # Local storage CRUD operations
│   ├── theme/
│   │   └── app_theme.dart              # Teal/Emerald CamScanner design system
│   ├── widgets/
│   │   └── document_card.dart          # Thumbnail card with badge & quick actions
│   └── main.dart                       # App entry point
└── pubspec.yaml                        # Project dependencies & assets
```

---

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://flutter.dev/docs/get-started/install) (v3.0.0 or higher)
* Android Studio or VS Code with Flutter extension
* Android device or emulator running Android 5.0 (API level 21) or above

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/<your-username>/scancraft.git
   cd scancraft
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run on connected device/emulator:**
   ```bash
   flutter run
   ```

4. **Build Release APK:**
   ```bash
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
