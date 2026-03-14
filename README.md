# Oxva

A native macOS Discord client with a macOS Tahoe-style Liquid Glass UI. Built with SwiftUI.

## Built on Voxa

Oxva is a fork of [Voxa](https://github.com/voxa-org/Voxa) by the Voxa contributors. The original project provided the SwiftUI WKWebView shell, plugin system, and core Discord integration. Oxva extends it with:

- **Tahoe theme** — macOS Liquid Glass surfaces using `-apple-visual-effect` on supported systems, falling back to `backdrop-filter` with directional borders, specular gradients, and inset bevel shadows
- **macOS Native theme** — HIG-accurate typography (SF Pro at correct sizes/weights), macOS cursor conventions, blue focus rings and text selection
- **Custom CSS presets** — built-in theme picker with import/export; Tahoe applied by default
- **Bug fixes** — crash on CSS paste, duplicate script injection on re-render, release channel picker never saving, hard reload silently breaking notifications and channel clicks, force unwrap crashes

## Requirements

- macOS 14 or later
- Xcode 15 or later (to build from source)

## Building from Source

```bash
git clone https://github.com/scripsweave/Oxva.git
cd Oxva
open Voxa.xcodeproj
```

Build and run the `Discord` scheme in Xcode.

## License

MIT — see [LICENSE](LICENSE).
