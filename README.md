# 📄 ScanCraft: Easy PDF & Doc Scanner

A full-fledged, high-performance mobile document scanner and PDF utility built with Flutter and Google ML Kit.

---

## 🌟 Key Features

### 1. 📷 Smart Document Scanner
- **Auto Edge Detection:** Automatically finds and crops document boundaries in real time.
- **Perspective Dewarping:** Converts tilted/angled photos into flat, deskewed rectangular scans.
- **Magic Color & B&W Filters:** Eliminates shadows and yellows, producing crystal-clear high-contrast scans.
- **Multi-page Batch Scanning:** Scan up to 20 pages in a single workflow.

### 2. 🪪 ID Card & License Mode
- Capture **Front Side** and **Back Side** of ID cards, Driver's Licenses, or Student IDs.
- Automatically composites and aligns both sides onto a single printable A4 page.

### 3. 🔤 Optical Character Recognition (OCR)
- On-device Latin/English text extraction powered by **Google ML Kit Text Recognition**.
- Copy extracted text, share it instantly, or export as `.txt`.

### 4. 📑 PDF Generator & Watermarking
- Generates high-resolution multi-page PDF files.
- Add custom diagonal watermarks (e.g., *"CONFIDENTIAL"*, *"ORIGINAL"*).
- Instant share to WhatsApp, Drive, Gmail, or any installed app.

### 5. 🗂️ Document Management
- Organize by categories: `Docs`, `ID Cards`, `Notes`, `Receipts`.
- Search documents by title.
- Reorder, rotate, or delete individual pages.
- Local persistence via `SharedPreferences`.

---

## 🚀 How to Run the App

### Option A: Running from VS Code
1. Open the project folder:
   `C:\Users\srkamd\.gemini\antigravity\scratch\scancraft`
2. Open terminal and run:
   ```bash
   flutter pub get
   flutter run
   ```
   Or press `F5` to start debugging on your connected Android phone or Emulator.

### Option B: Running from Android Studio
1. Open Android Studio.
2. Click **Open** and select:
   `C:\Users\srkamd\.gemini\antigravity\scratch\scancraft`
3. Click the green **Run (▶)** button on the top toolbar.

---

## 📂 Project Architecture

```
scancraft/
├── android/                   # Native Android config & permissions
├── lib/
│   ├── models/
│   │   └── scanned_document.dart    # Data model & serialization
│   ├── screens/
│   │   ├── home_screen.dart            # Dashboard, search & filters
│   │   ├── document_detail_screen.dart # Multi-page viewer & page actions
│   │   ├── id_card_scanner_screen.dart # Dual-sided ID card merger
│   │   └── ocr_result_screen.dart      # Extracted text viewer
│   ├── services/
│   │   ├── scanner_service.dart        # ML Kit Document Scanner wrapper
│   │   ├── pdf_service.dart            # PDF generator & watermarking
│   │   ├── ocr_service.dart            # ML Kit OCR text extractor
│   │   └── storage_service.dart        # Local persistence engine
│   ├── theme/
│   │   └── app_theme.dart              # Teal/Emerald CamScanner design system
│   ├── widgets/
│   │   └── document_card.dart          # Grid document card with options
│   └── main.dart                       # App entry point
└── pubspec.yaml                        # Dependencies & configuration
```
