# Moosjan Invoice

A sales invoice manager built with Flutter for **Moosjan Dairy Feeds**. Create, manage, preview, and share professional PDF invoices for dairy feed sales — fully offline, with a local SQLite database.

## Features

- Create and edit sales invoices with multiple line items
- Manage a product catalog (add, edit, delete products with prices)
- Live invoice preview with automatic total calculations
- Generate and share PDF invoices
- Local SQLite storage — works fully offline
- Invoice gallery to browse, search, and reopen past invoices
- Customer details (name, phone, location) on every invoice
- Custom branding with app icon and themed UI

## Tech Stack

- **Flutter** (Dart SDK ^3.11.0)
- **sqflite** — local SQLite database
- **pdf** & **printing** — PDF generation and preview
- **share_plus** — share invoices
- **intl** — number/date formatting
- **path_provider** — file system access

## Project Structure

```
lib/
├── main.dart
├── app_theme.dart
├── database/
│   └── db_helper.dart
├── models/
│   └── invoice.dart
├── screens/
│   ├── gallery_screen.dart
│   ├── invoice_form_screen.dart
│   ├── invoice_preview_screen.dart
│   └── manage_products_screen.dart
├── services/
│   └── pdf_service.dart
└── widgets/
    └── invoice_card.dart
```

## Getting Started

### Prerequisites

- Flutter SDK (Dart `^3.11.0`)
- Android Studio / Xcode (for platform builds)

### Install & Run

```bash
flutter pub get
flutter run
```

### Build a Release APK

```bash
flutter build apk --release
```

The release APK is output to `build/app/outputs/flutter-apk/`.

### Install on a Connected Device (ADB)

```bash
adb install -r build/app/outputs/flutter-apk/MoosJan_inv.apk
adb shell monkey -p com.moosjan.moosjan_invoice -c android.intent.category.LAUNCHER 1
```

## Configuration

App icon assets are configured in `pubspec.yaml` under `flutter_launcher_icons`. To regenerate launcher icons after replacing the source PNGs:

```bash
flutter pub run flutter_launcher_icons
```

## License

Private project. All rights reserved.
