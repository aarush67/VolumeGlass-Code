# VolumeGlass 🎵

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13.0+-blue.svg" alt="macOS 13.0+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange.svg" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/SwiftUI-Latest-purple.svg" alt="SwiftUI">
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="MIT License">
</p>

**A beautiful, iOS-style volume control overlay for macOS** with glass morphism design, real-time audio monitoring, and intuitive gesture controls. Replace the default system volume indicator with an elegant, customizable alternative.

---

## ✨ Key Features

### 🎚️ Volume Control
- **Drag-to-Adjust** - Smooth, responsive volume slider with pixel-perfect control
- **Auto-Mute at Zero** - Dragging to 0% automatically mutes audio using the same mute API
- **Real-Time Feedback** - Shows current volume percentage with live visual updates
- **Haptic Feedback** - Tactile responses at 25%, 50%, 75%, and 100% volume milestones
- **Smooth Animations** - Liquid glass effect with spring physics and easing

### 🎯 Quick Actions Menu
- **One-Tap Mute** - Instant mute/unmute with visual indicator
- **Volume Presets** - Quick buttons for 25%, 50%, 75%, and 100%
- **Device Switcher** - Switch audio outputs without leaving the app
- **Status Display** - See current device name and volume percentage

### 🔌 Audio Device Management
- **Multi-Device Support** - Switch between speakers, headphones, AirPods, displays, etc.
- **Long-Press Device Menu** - Hold on the bar to open device selection
- **Device Memory** - Remembers your last selected output
- **Real-Time Detection** - Automatically updates when devices connect/disconnect

### ⌨️ Complete Keyboard Control
- **Arrow Keys** - Press `↑` and `↓` to adjust volume
- **Keyboard Shortcuts** - `Cmd+Shift+↑` / `↓` for volume, `Cmd+Shift+M` for mute
- **Media Keys** - Works with F11/F12 and hardware media buttons
- **Global Monitoring** - Works even when VolumeGlass is in background

### 🎨 Highly Customizable
**5 Position Options:**
- Left Middle (Vertical) - Classic left-side positioning
- Right Middle (Vertical) - Right-side alternative
- Top Center (Horizontal) - Wide layout at top of screen
- Bottom Center (Horizontal) - Positioned above dock with 100+ point clearance
- Center Screen (Floating) - Central overlay for emphasis

**Additional Customization:**
- Size Scaling (50% - 150%)
- Automatic dark/light mode adaptation
- Glass morphism transparency effects
- Persistent settings between sessions

### 🎯 Gesture Controls
- **Drag** - Smooth volume adjustment
- **Double-Tap** - Quick mute/unmute
- **Long-Press** - Open device selection menu
- **Hover** - Bar appears on cursor approach

### ♿ Accessibility & Quality
- **VoiceOver Support** - Full screen reader compatibility
- **Keyboard-Only Navigation** - Complete control without mouse
- **High Contrast** - Works in accessibility contrast modes
- **Persistent Settings** - All preferences saved automatically

---

## 📥 Installation

### Method 1: From DMG (Recommended)

1. **Download** the latest [VolumeGlass.dmg](https://github.com/yourusername/VolumeGlass/releases)
2. **Open** the DMG file
3. **Drag** VolumeGlass to your Applications folder
4. **Launch** from Applications or Spotlight (Cmd+Space + "VolumeGlass")

### Method 2: First Launch Setup

After launching VolumeGlass for the first time:

**Step 1: Security Warning (if shown)**
- Go to **System Settings → Privacy & Security**
- Scroll down and find VolumeGlass
- Click **"Open Anyway"**
- (This appears because the app isn't notarized - we don't have a paid Apple Developer Account)

**Step 2: Grant Accessibility Permissions**
- VolumeGlass will request accessibility access
- Click **"Open System Settings"** in the dialog
- Or manually go to **System Settings → Privacy & Security → Accessibility**
- Add VolumeGlass to the list
- **Why?** This allows the app to detect keyboard shortcuts and media keys

**Step 3: Setup Walkthrough**
- Choose your preferred position (Left, Right, Top, Bottom, or Center)
- Adjust size scaling (50%-150%)
- Click "Complete Setup"
- Done! ✅

### Method 3: Build from Source

**Requirements:**
- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.9+

**Build Steps:**
```bash
# Clone the repository
git clone https://github.com/yourusername/VolumeGlass.git
cd VolumeGlass-Code

# Open in Xcode
open VolumeGlass.xcodeproj

# Build and Run
# Press Cmd+R or go to Product → Run
```

---

## 🎮 Usage Guide

### Basic Volume Control

#### Using the Slider
1. **Move your cursor** near the volume bar position
2. Bar appears automatically with current volume
3. **Drag vertically** (left/right mode) or **horizontally** (up/down mode) to adjust
4. **Feel haptic feedback** at each 25% increment (25%, 50%, 75%, 100%)
5. **Release** when you reach desired volume

#### Dragging to Mute
- **Drag all the way to 0%** → Audio automatically mutes (same as mute button)
- **Drag above 0% while muted** → Audio automatically unmutes
- This uses the system mute API, not just volume setting

#### Quick Mute
- **Double-tap** the volume bar for instant mute/unmute toggle
- **Or** click the Mute button in Quick Actions menu

### Quick Actions Menu

**To open:**
1. Click the **"⋯" (ellipsis) button** on the volume bar
2. Menu slides in with options

**Available options:**
- **Volume Display** - Current volume % with icon
- **Mute/Unmute** - Toggle button (shows current state)
- **Audio Output** - Open device switcher
- **Volume Presets** - Quick buttons for 25%, 50%, 75%, 100%

### Switching Audio Devices

**Option 1: Long-Press**
1. **Long-press** (hold ~0.8 seconds) on the volume bar
2. Device menu slides in from the side
3. **Tap any device** to switch instantly
4. Changes take effect immediately

**Option 2: Quick Actions Menu**
1. Click **"⋯"** to open menu
2. Click **"Audio Output"**
3. Select device from list

**Option 3: System Settings**
- Volume bar respects system audio settings
- Manual changes sync automatically

---

## ⌨️ Keyboard Shortcuts

| Action | Shortcut | Notes |
|--------|----------|-------|
| Volume Up | `↑` Arrow Up | Works with or without modifiers |
| Volume Down | `↓` Arrow Down | Works with or without modifiers |
| Volume Up | `Cmd+Shift+↑` | Alternative keyboard shortcut |
| Volume Down | `Cmd+Shift+↓` | Alternative keyboard shortcut |
| Toggle Mute | `Cmd+Shift+M` | Mute/Unmute toggle |
| Hardware Keys | F11/F12 or media buttons | If available on your Mac |

**Notes:**
- All shortcuts work even when VolumeGlass is in background
- Supports both global and local keyboard monitoring
- Plain arrow keys work without requiring modifiers
- Media buttons automatically detected and routed

---

## ⚙️ Settings & Customization

### Position Options

| Position | Layout | Best For | Details |
|----------|--------|----------|---------|
| **Left Middle** | Vertical | Compact setup | Left side, centered vertically |
| **Right Middle** | Vertical | Right-handed users | Right side, centered vertically |
| **Top Center** | Horizontal | Ultrawide monitors | Wide layout, easy to see |
| **Bottom Center** | Horizontal | Easy access | Above dock, plenty of clearance |
| **Center Screen** | Floating | Focus | Center overlay, most visible |

### Size Scaling

Adjust the bar size from **50% to 150%**:
- **50%** - Subtle, minimal visual presence, unobtrusive
- **100%** - Default, balanced sizing, recommended
- **150%** - Large, easy to target, prominent

### Theme & Appearance

- **Light Mode** - Bright glass effect, optimal for light backgrounds
- **Dark Mode** - Dark glass effect, optimal for dark backgrounds
- **Adaptive** - Automatically switches based on system appearance
- **All-day** - No manual switching needed

### Settings Storage

All preferences are automatically saved:
- ✅ Selected position and size
- ✅ Last used audio device
- ✅ Window visibility states
- ✅ Menu preferences
- ✅ All other customizations

**Changes take effect immediately** - no restart needed!

---

## 🐛 Troubleshooting

### Volume Bar Not Showing

**Problem:** The volume bar doesn't appear when you move your cursor.

**Solutions:**
1. **Move your cursor** - The bar appears on cursor movement or volume change
2. **Adjust volume** - Use keyboard shortcuts to trigger it: `↑` or `↓`
3. **Check accessibility** - System Settings → Privacy & Security → Accessibility
4. **Verify VolumeGlass is listed** - If not, add it and restart app
5. **Restart the app** - Close completely and reopen

### Keyboard Shortcuts Not Working

**Problem:** Arrow keys or Cmd+Shift shortcuts don't control volume.

**Solutions:**
1. **Grant accessibility access** - Go to System Settings → Privacy & Security → Accessibility
2. **Add VolumeGlass if missing** - Click `+` and select VolumeGlass
3. **Restart the app** - Close and reopen after granting permission
4. **Check for conflicts** - Other apps might be intercepting shortcuts
5. **Try plain arrow keys** - These should work even without modifiers
6. **Restart macOS** - Sometimes permissions need system restart to take effect

### Audio Device Won't Switch

**Problem:** Selecting a device in the menu doesn't switch audio output.

**Solutions:**
1. **Verify device connection** - Ensure the device is actually connected
2. **Refresh device list** - Long-press bar or click "Audio Output" to reload
3. **Check macOS settings** - Verify device in System Settings → Sound
4. **Wait a moment** - Sometimes takes a second for system to recognize
5. **Restart audio service** - Close VolumeGlass and reopen
6. **Restart macOS** - Some audio changes require system restart

### Dragging to Zero Doesn't Mute

**Problem:** Dragging slider to 0% doesn't automatically mute audio.

**Solutions:**
1. **Drag all the way down** - Make sure you reach the very bottom (0%)
2. **Check mute status** - Look at Quick Actions menu to verify mute state
3. **Verify permissions** - Accessibility access is required for mute control
4. **Restart app** - Close and reopen VolumeGlass
5. **Check system audio** - Verify in System Settings → Sound

### Settings Not Saving

**Problem:** Settings revert to defaults after restart.

**Solutions:**
1. **Check disk space** - Ensure your drive has available storage
2. **Restart app** - Close completely and reopen
3. **Verify permissions** - App needs write access to user directory
4. **Reset and reinstall** - Remove from Applications and download fresh copy
5. **Check System Settings** - Accessibility permissions still granted

### Accessibility Permission Request Keeps Appearing

**Problem:** Permission dialog appears repeatedly even after granting access.

**Solutions:**
1. **Go to System Settings** → Privacy & Security → Accessibility
2. **Find VolumeGlass in the list** - Should be there if you granted permission
3. **Remove it** - Click `−` button next to VolumeGlass
4. **Restart the app** - VolumeGlass will request permission again
5. **Grant it again** - Click "OK" in the permission dialog
6. **Restart macOS** - Sometimes permissions need full system restart

---

## 🔧 Technical Details

### System Architecture

- **SwiftUI** - Modern declarative UI framework
- **Combine** - Reactive data binding and state management
- **Core Audio** - Low-level audio device management
- **AppKit** - System-level window and overlay management
- **EventKit** - Global keyboard event monitoring

### Core Components

```
VolumeGlass/
├── VolumeGlassApp.swift          # App entry point, lifecycle management
├── VolumeMonitor.swift            # Volume & device monitoring core
├── VolumeControlView.swift        # Main UI layout and menus
├── VolumeIndicatorView.swift      # Volume slider bar component
├── DeviceSelectionMenu.swift      # Audio device picker menu
├── AudioDeviceManager.swift       # Audio device API wrapper
├── SetupState.swift               # Settings persistence & state
├── SetupWalkthroughView.swift     # First-launch setup UI
├── VolumeOverlayWindow.swift      # Overlay window management
└── Assets.xcassets/               # Icons, colors, resources
```

### Audio APIs

- **Core Audio Framework** - Audio device enumeration and management
- **AudioObjectSetPropertyData** - Volume and mute control
- **AudioDevice Classes** - Device selection and configuration
- **Aggregate Devices** - Multi-channel audio support

### Keyboard Monitoring

- **Global Event Monitor** - System-wide keyboard event capture
- **Local Event Monitor** - Fallback for accessory mode apps
- **Media Key Handling** - Hardware volume button integration
- **NSEvent.systemDefined** - Media key event parsing

### State Management

- **@ObservedObject** - Real-time volume and device changes
- **@State** - Local UI state (menus, visibility)
- **UserDefaults** - Persistent settings storage
- **NotificationCenter** - Inter-component communication

---

## 🎨 Design Philosophy

VolumeGlass embodies iOS design principles applied to macOS:

- **Clarity** - Clear, intuitive controls that are obvious to use
- **Deference** - Blends with the system, doesn't compete for attention
- **Depth** - Glass morphism with real transparency and blur
- **Responsiveness** - Instant feedback to every user action
- **Haptics** - Tactile feedback for key interactions
- **Accessibility** - Works perfectly for all users, including those with disabilities

---

## 📝 Version History

### Version 1.0.0 - Initial Release
- ✅ Volume slider with drag control
- ✅ Auto-mute when dragging to 0%
- ✅ Quick actions menu
- ✅ Audio device switcher
- ✅ 5 customizable positions
- ✅ Size scaling (50%-150%)
- ✅ Full keyboard shortcut support (plain arrows + Cmd+Shift)
- ✅ Media key integration
- ✅ Haptic feedback system
- ✅ Settings persistence
- ✅ Full accessibility support
- ✅ Glass morphism design
- ✅ Dark/Light mode adaptation
- ✅ Real-time volume monitoring
- ✅ Mute state detection

---

## 🤝 Contributing

Contributions are welcome and appreciated! Here's how to contribute:

1. **Fork** the repository on GitHub
2. **Create** a feature branch: `git checkout -b feature/your-feature`
3. **Make** your changes and test thoroughly
4. **Commit** with clear messages: `git commit -m 'Add feature: description'`
5. **Push** to your branch: `git push origin feature/your-feature`
6. **Open** a Pull Request with description of changes

### Code Style
- Follow Swift naming conventions
- Use meaningful variable names
- Add comments for complex logic
- Test on multiple macOS versions

---

## 📄 License

VolumeGlass is released under the **MIT License**.

See the [LICENSE](LICENSE) file for complete details.

```
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
```

---

## 🙏 Acknowledgments

- **macOS Community** - Excellent resources and documentation
- **Audio Framework** - Core Audio for system integration
- **SwiftUI Community** - Examples and best practices
- **Design Inspiration** - iOS 7+ glass morphism design language

---

## 📞 Support & Feedback

Have questions, found a bug, or have a feature request?

### Report Issues
- **GitHub Issues** - [Create an issue](https://github.com/yourusername/VolumeGlass/issues)
- Include macOS version, steps to reproduce, and screenshots if applicable

### Get Help
- **Troubleshooting Guide** - See section above for common issues
- **Email** - [your-email@example.com](mailto:your-email@example.com)
- **Twitter/X** - [@YourHandle](https://twitter.com)

### Feature Requests
- Open a GitHub Discussion or Issue
- Describe what you'd like to see
- Explain your use case

---

## 🚀 Roadmap

Future enhancements planned for VolumeGlass:

- [ ] Custom color themes and skins
- [ ] Per-app volume control
- [ ] Volume history and statistics
- [ ] Launch at login option
- [ ] Mini music player integration
- [ ] Customizable keyboard shortcuts
- [ ] Multiple monitor optimization
- [ ] Menubar mode variant
- [ ] Advanced EQ controls
- [ ] Device-specific settings

---

## 💡 Tips & Tricks

### Hidden Features
- **Quick Presets** - Buttons in menu for instant volume levels
- **Double-Tap Mute** - Tap bar twice for quick mute
- **Anywhere Shortcuts** - Keyboard shortcuts work even when minimized
- **Auto Device Switch** - Remember your favorite devices

### Best Practices
1. **Grant Accessibility Early** - Do this on first launch for best experience
2. **Choose Your Position** - Pick the one that doesn't interfere with your workflow
3. **Use Keyboard Shortcuts** - Faster than menu for quick volume changes
4. **Customize Size** - Make it smaller if it blocks your view too much
5. **Use Presets** - Set common volumes you use frequently

### Performance Tips
- VolumeGlass uses minimal resources (< 20MB RAM typically)
- Runs efficiently in background
- Doesn't affect system audio quality
- Fast startup time

---

<p align="center">
  <br/>
  <strong>Made with ❤️ for macOS users</strong>
  <br/>
  <a href="https://github.com/yourusername/VolumeGlass">⭐ Star on GitHub</a>
  ·
  <a href="https://github.com/yourusername/VolumeGlass/issues">📝 Report Issues</a>
  ·
  <a href="https://github.com/yourusername/VolumeGlass/discussions">💬 Discussions</a>
  <br/><br/>
  <em>Enjoy a beautiful way to control your Mac's volume!</em>
</p>
