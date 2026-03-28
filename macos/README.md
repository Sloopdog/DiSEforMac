# DiSE macOS App

This folder contains a native macOS configurator for the `DiSE` speed editor hardware.

It replaces the Windows-only WPF programmer in `src/SpeedEditorProg` with a SwiftUI app that:

- connects to the DiSE custom HID interface on macOS
- reads and writes the device configuration
- saves and loads `.DiSE` settings files compatible with the upstream Windows tool
- persists settings to device flash

## Build

From this folder:

```bash
swift build
```

To produce a local `.app` bundle:

```bash
./build-macos-app.sh
```

The resulting app bundle is written to:

```text
macos/build/DiSE Programmer.app
```

## Notes

- The app targets the DiSE custom HID interface with vendor ID `1155`, product ID `22334`, usage page `0xFFA0`, usage `1`.
- If Gatekeeper warns on first launch, use right-click -> Open for the unsigned local build, or codesign it with your own certificate.
