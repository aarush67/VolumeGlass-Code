# VolumeGlass

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13.0+-blue.svg" alt="macOS 13.0+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange.svg" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/SwiftUI-Latest-purple.svg" alt="SwiftUI">
  <img src="https://img.shields.io/badge/license-CC%20BY--NC--ND%204.0-lightgrey.svg" alt="License">
</p>

**A beautiful, iOS-style volume control overlay for macOS** with glass morphism design, real-time audio monitoring, and intuitive gesture controls. Replaces the default system volume indicator with an elegant, customizable alternative.

---

## Key Features

### Volume Control
- **Drag-to-Adjust** - Smooth, responsive volume slider with pixel-perfect control
- **Auto-Mute at Zero** - Dragging to 0% automatically mutes audio
- **Real-Time Feedback** - Shows current volume percentage with live visual updates
- **Haptic Feedback** - Tactile responses at 25%, 50%, 75%, and 100% milestones
- **Smooth Animations** - Liquid glass effect with spring physics

### Quick Actions Menu
- **One-Tap Mute** - Instant mute/unmute with visual indicator
- **Volume Presets** - Quick buttons for 25%, 50%, 75%, and 100%
- **Device Switcher** - Switch audio outputs without leaving the app

### Audio Device Management
- **Multi-Device Support** - Switch between speakers, headphones, AirPods, displays, etc.
- **Long-Press Device Menu** - Hold on the bar to open device selection
- **Real-Time Detection** - Automatically updates when devices connect/disconnect

### Keyboard & Media Keys
- Arrow keys, `Cmd+Shift+Up/Down` for volume, `Cmd+Shift+M` for mute
- F11/F12 and hardware media buttons supported
- Works even when VolumeGlass is in the background

### Customization
- 5 position options: Left, Right, Top, Bottom, Center
- Size scaling from 50% to 150%
- Automatic dark/light mode adaptation
- Persistent settings between sessions

### Accessibility
- Full VoiceOver support
- Keyboard-only navigation
- High contrast mode compatibility

---

## Installation

1. Download the latest [VolumeGlass.dmg](https://github.com/aarush67/VolumeGlass-Code/releases/latest/download/VolumeGlass.dmg)
2. Open the DMG and drag VolumeGlass to your Applications folder
3. Launch VolumeGlass
4. Grant Accessibility permissions when prompted (required for keyboard/media key support)
5. Follow the setup walkthrough to choose your position and size

---

## Build from Source

**Requirements:** macOS 13.0+, Xcode 15.0+, Swift 5.9+

```bash
git clone https://github.com/aarush67/VolumeGlass-Code.git
cd VolumeGlass-Code
open VolumeGlass.xcodeproj
# Press Cmd+R to build and run
```

---

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Volume Up | `Up Arrow` or `Cmd+Shift+Up` |
| Volume Down | `Down Arrow` or `Cmd+Shift+Down` |
| Toggle Mute | `Cmd+Shift+M` |
| Hardware Keys | F11 / F12 or media buttons |

---

## Troubleshooting

**Volume bar not showing** — Move your cursor close to the bar's position. If it still doesn't appear, check Accessibility permissions in System Settings → Privacy & Security → Accessibility.

**Keyboard shortcuts not working** — Accessibility permission is required. Go to System Settings → Privacy & Security → Accessibility and make sure VolumeGlass is enabled.

**Settings not saving** — Close the app fully and reopen. Check that your disk has available storage.

**Permission dialog keeps reappearing** — Go to System Settings → Privacy & Security → Accessibility, remove VolumeGlass from the list, restart the app, and grant permission again.

---

## License

Copyright (c) 2025 Aarush Prakash

This project is licensed under [CC BY-NC-ND 4.0](https://creativecommons.org/licenses/by-nc-nd/4.0/). You may view and share the code with attribution, but you may not use it in other projects, modify it, or use it commercially.

---

## Support & Feedback

- **Bug reports / feature requests:** [GitHub Issues](https://github.com/aarush67/VolumeGlass-Code/issues)
- **Website:** [volumeglass.app](https://volumeglass.app)

---

<p align="center">
  <a href="https://github.com/aarush67/VolumeGlass-Code">Star on GitHub</a>
  ·
  <a href="https://github.com/aarush67/VolumeGlass-Code/issues">Report Issues</a>
</p>
