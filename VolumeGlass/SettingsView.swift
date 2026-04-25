import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var setupState: SetupState
    @ObservedObject var licenseManager: LicenseManager
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @Environment(\.colorScheme) var colorScheme
    
    @State private var selectedTab: SettingsTab = .general
    @State private var animateIn: Bool = false
    @State private var volumeDismissBuffer: Double = 2.0
    
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case license = "License"
        case shortcuts = "Shortcuts"
        case updates = "Updates"
    }
    
    var body: some View {
        ZStack {
            // Background
            backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Tab bar
                tabBar
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                
                // Divider
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 1)
                
                // Content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        switch selectedTab {
                        case .general:
                            generalTab
                        case .license:
                            licenseTab
                        case .shortcuts:
                            shortcutsTab
                        case .updates:
                            updatesTab
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                }
            }
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 10)
        }
        .frame(width: 520, height: 600)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85).delay(0.1)) {
                animateIn = true
            }
            // Initialize local buffer for slider to avoid committing on every drag
            volumeDismissBuffer = setupState.volumeDismissTime
        }
    }
    
    // MARK: - Background
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95)
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selectedTab = tab
                    }
                }) {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .medium))
                        .foregroundColor(selectedTab == tab ? .primary : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selectedTab == tab
                                      ? Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.07)
                                      : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
    
    // MARK: - General Tab
    
    private var generalTab: some View {
        VStack(spacing: 20) {
            // Position section
            settingsSection(title: "Position", icon: "rectangle.on.rectangle") {
                VStack(spacing: 8) {
                    ForEach(VolumeBarPosition.allCases, id: \.displayName) { position in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                setupState.updatePosition(position)
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("SettingsWindowChanged"),
                                    object: nil
                                )
                            }
                        }) {
                            HStack {
                                Image(systemName: iconForPosition(position))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(setupState.selectedPosition == position ? .accentColor : .secondary)
                                    .frame(width: 24)
                                
                                Text(position.displayName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if setupState.selectedPosition == position {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(setupState.selectedPosition == position
                                          ? Color.accentColor.opacity(0.08)
                                          : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Notch display section
            settingsSection(title: "Notch Display", icon: "rectangle.topthird.inset.filled") {
                VStack(spacing: 14) {
                    // Notch-attached bar (Dynamic Island style)
                    Toggle(isOn: Binding(
                        get: { setupState.showNotchBar },
                        set: { newValue in
                            setupState.updateShowNotchBar(newValue)
                            NotificationCenter.default.post(
                                name: NSNotification.Name("SettingsWindowChanged"),
                                object: nil
                            )
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Notch volume bar")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            Text("Expands from the MacBook notch to show volume, like Dynamic Island.")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(.accentColor)

                    // Divider
                    Rectangle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 1)

                    // Floating pill
                    Toggle(isOn: Binding(
                        get: { setupState.showInNotch },
                        set: { newValue in
                            setupState.updateShowInNotch(newValue)
                            NotificationCenter.default.post(
                                name: NSNotification.Name("SettingsWindowChanged"),
                                object: nil
                            )
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Volume indicator pill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            Text("Shows a floating glassmorphism pill below the notch area when volume changes.")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(.accentColor)

                    if !hasNotchScreen {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("No notch display detected. These features require a MacBook with a notch (Pro 14\"/16\" 2021+, Air 2022+).")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 2)
                    }
                }
            }
            
            // Size section
            settingsSection(title: "Size", icon: "arrow.up.left.and.arrow.down.right") {
                VStack(spacing: 12) {
                    // Size slider
                    HStack(spacing: 12) {
                        Image(systemName: "minus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Slider(value: Binding(
                            get: { setupState.barSize },
                            set: { newValue in
                                let snapped = (newValue * 4).rounded() / 4 // snap to 0.25
                                setupState.updateSize(snapped)
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("SettingsWindowChanged"),
                                    object: nil
                                )
                            }
                        ), in: 0.5...2.0, step: 0.25)
                        .tint(.accentColor)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    
                    // Size presets
                    HStack(spacing: 6) {
                        ForEach(sizePresets, id: \.1) { name, value in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    setupState.updateSize(value)
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("SettingsWindowChanged"),
                                        object: nil
                                    )
                                }
                            }) {
                                Text(name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(abs(setupState.barSize - value) < 0.01 ? .white : .secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(abs(setupState.barSize - value) < 0.01
                                                  ? Color.accentColor
                                                  : Color.primary.opacity(0.06))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Text("Current: \(Int(setupState.barSize * 100))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            // Behavior section
            settingsSection(title: "Behavior", icon: "gearshape") {
                VStack(spacing: 10) {
                    HStack {
                        Text("Volume dismiss time")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                        Spacer()
                        Text(String(format: "%.1fs", setupState.volumeDismissTime))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    Slider(
                        value: Binding(
                            get: { volumeDismissBuffer },
                            set: { volumeDismissBuffer = $0 }
                        ),
                        in: 0.3...6.0,
                        onEditingChanged: { editing in
                            if !editing {
                                // Commit only when the user releases the slider
                                let rounded = (volumeDismissBuffer * 10).rounded() / 10.0
                                setupState.updateVolumeDismissTime(rounded)
                            }
                        }
                    )
                    .tint(.accentColor)
                }
            }

            // Appearance section
            settingsSection(title: "Appearance", icon: "paintbrush") {
                VStack(spacing: 12) {
                    // Color mode selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Volume Bar Color")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)

                        VStack(spacing: 4) {
                            ForEach(VolumeBarColorMode.allCases, id: \.self) { mode in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        setupState.updateBarColorMode(mode)
                                    }
                                }) {
                                    HStack {
                                        // Color preview circle
                                        Circle()
                                            .fill(colorPreview(for: mode))
                                            .frame(width: 16, height: 16)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
                                            )

                                        Text(mode.displayName)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.primary)

                                        Spacer()

                                        if setupState.volumeBarColorMode == mode {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(setupState.volumeBarColorMode == mode
                                                  ? Color.accentColor.opacity(0.08)
                                                  : Color.clear)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Custom color picker (only show when custom is selected)
                    if setupState.volumeBarColorMode == .custom {
                        Divider()
                            .padding(.vertical, 4)

                        HStack {
                            Text("Custom Color")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)

                            Spacer()

                            ColorPicker("", selection: Binding(
                                get: { setupState.customBarColor },
                                set: { newColor in
                                    setupState.updateCustomBarColor(newColor.toHex())
                                }
                            ))
                            .labelsHidden()
                        }
                    }
                }
            }
        }
    }

    /// Returns a preview color for the color mode selector
    private func colorPreview(for mode: VolumeBarColorMode) -> Color {
        switch mode {
        case .system:
            return colorScheme == .dark ? .white : Color(white: 0.3)
        case .white:
            return .white
        case .black:
            return .black
        case .accent:
            return .accentColor
        case .custom:
            return setupState.customBarColor
        }
    }
    
    // MARK: - License Tab
    
    private var licenseTab: some View {
        VStack(spacing: 20) {
            // Status card
            licenseStatusCard
            
            // License key display / input
            if licenseManager.licenseStatus == .active {
                activeLicenseCard
            } else {
                enterLicenseCard
            }
            
            // Actions
            licenseActions
            
            #if DEBUG
            debugSection
            #endif
        }
    }
    
    private var licenseStatusCard: some View {
        settingsSection(title: "Status", icon: "shield") {
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    // Status icon
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.12))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: statusIcon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(statusColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(statusTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(statusSubtitle)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Badge
                    Text(statusBadge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(statusColor.opacity(0.12))
                        )
                }
                
                // Trial progress bar
                if licenseManager.licenseStatus == .trial {
                    VStack(spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(Color.primary.opacity(0.06))
                                    .frame(height: 6)
                                
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(trialProgressColor)
                                    .frame(width: geo.size.width * trialProgress, height: 6)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: trialProgress)
                            }
                        }
                        .frame(height: 6)
                        
                        HStack {
                            Text("\(licenseManager.trialDaysRemaining) day\(licenseManager.trialDaysRemaining == 1 ? "" : "s") remaining")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("3 day trial")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                    }
                }
                
                // Email
                if let email = licenseManager.licenseEmail {
                    HStack(spacing: 8) {
                        Image(systemName: "envelope")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(email)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var activeLicenseCard: some View {
        settingsSection(title: "License Key", icon: "key") {
            VStack(spacing: 12) {
                // Masked key display
                if let key = licenseManager.storedLicenseKey {
                    HStack(spacing: 0) {
                        Text(maskedKey(key))
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                            .kerning(1)
                        
                        Spacer()
                        
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(key, forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 28, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.primary.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(colorScheme == .dark
                                  ? Color.white.opacity(0.04)
                                  : Color.black.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06), lineWidth: 0.5)
                    )
                }
                
                // Plan info
                if let plan = licenseManager.licensePlan {
                    HStack(spacing: 8) {
                        Image(systemName: "crown")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.accentColor)
                        Text(plan == "lifetime" ? "Lifetime License" : plan.capitalized)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
        }
    }
    
    @State private var newLicenseKey: String = ""
    @State private var isActivating: Bool = false
    @State private var activationError: String = ""
    @State private var showActivationError: Bool = false
    @State private var activationSuccess: Bool = false
    
    private var enterLicenseCard: some View {
        settingsSection(title: "License Key", icon: "key") {
            VStack(spacing: 12) {
                // Input field
                TextField("VG-XXXX-XXXX-XXXX-XXXX", text: $newLicenseKey)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(colorScheme == .dark
                                  ? Color.white.opacity(0.04)
                                  : Color.black.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                showActivationError
                                    ? Color.red.opacity(0.5)
                                    : Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06),
                                lineWidth: showActivationError ? 1.5 : 0.5
                            )
                    )
                    .onSubmit { activateLicenseFromSettings() }
                
                if showActivationError {
                    Text(activationError)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.red.opacity(0.9))
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                if activationSuccess {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        Text("License activated successfully!")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.green)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Button(action: activateLicenseFromSettings) {
                    HStack(spacing: 6) {
                        if isActivating {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        Text(isActivating ? "Validating…" : "Activate")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isActivating ? Color.accentColor.opacity(0.6) : Color.accentColor)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isActivating)
            }
        }
    }
    
    private var licenseActions: some View {
        settingsSection(title: "Actions", icon: "gear") {
            VStack(spacing: 8) {
                // Purchase button
                Button(action: {
                    if let url = URL(string: "https://volumeglass.app/") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "cart")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.accentColor)
                            .frame(width: 20)
                        
                        Text("Purchase License — $7.99")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.03))
                    )
                }
                .buttonStyle(.plain)
                
                // Support email
                Button(action: {
                    if let url = URL(string: "mailto:support@volumeglass.app") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        
                        Text("Contact Support")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("support@volumeglass.app")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.03))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Shortcuts Tab
    
    private var shortcutsTab: some View {
        VStack(spacing: 20) {
            settingsSection(title: "Keyboard Shortcuts", icon: "keyboard") {
                VStack(spacing: 2) {
                    ShortcutRecorderRow(
                        action: "Volume Up",
                        shortcut: $setupState.shortcutVolumeUp,
                        onChanged: { setupState.updateShortcutVolumeUp($0) }
                    )
                    Divider().opacity(0.4).padding(.vertical, 2)
                    ShortcutRecorderRow(
                        action: "Volume Down",
                        shortcut: $setupState.shortcutVolumeDown,
                        onChanged: { setupState.updateShortcutVolumeDown($0) }
                    )
                    Divider().opacity(0.4).padding(.vertical, 2)
                    ShortcutRecorderRow(
                        action: "Toggle Mute",
                        shortcut: $setupState.shortcutMute,
                        onChanged: { setupState.updateShortcutMute($0) }
                    )
                }
            }
            
            Button(action: {
                setupState.updateShortcutVolumeUp(.defaultVolumeUp)
                setupState.updateShortcutVolumeDown(.defaultVolumeDown)
                setupState.updateShortcutMute(.defaultMute)
            }) {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .medium))
                    Text("Reset to Defaults")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
            }
            .buttonStyle(.plain)
            
            settingsSection(title: "Media Keys", icon: "speaker.wave.3") {
                VStack(spacing: 2) {
                    shortcutRow(keys: "🔊", action: "Volume Up (media key)")
                    shortcutRow(keys: "🔉", action: "Volume Down (media key)")
                    shortcutRow(keys: "🔇", action: "Toggle Mute (media key)")
                }
            }
            
            settingsSection(title: "Gestures", icon: "hand.draw") {
                VStack(spacing: 2) {
                    shortcutRow(keys: "Double Tap", action: "Toggle Mute")
                    shortcutRow(keys: "Long Press", action: "Audio Device Menu")
                    shortcutRow(keys: "Drag", action: "Adjust Volume")
                }
            }
        }
    }
    
    // MARK: - Updates Tab

    @State private var isCheckingForUpdates = false

    private var updatesTab: some View {
        VStack(spacing: 20) {
            settingsSection(title: "App Version", icon: "info.circle") {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VolumeGlass")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Version \(updateChecker.currentVersion)")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if updateChecker.updateAvailable {
                        Text("UPDATE AVAILABLE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.12))
                            )
                    } else if updateChecker.showingUpToDate {
                        Text("UP TO DATE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.12))
                            )
                    }
                }
                .padding(.vertical, 2)
            }

            if updateChecker.updateAvailable, let latest = updateChecker.latestVersion {
                settingsSection(title: "New Version Available", icon: "arrow.down.app") {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("VolumeGlass \(latest)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)
                                if let notes = updateChecker.releaseNotes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(.secondary)
                                        .lineLimit(3)
                                }
                            }
                            Spacer()
                        }

                        Button(action: {
                            if let url = updateChecker.downloadURL {
                                AutoUpdater.shared.installUpdate(from: url)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Install Update")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.accentColor)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            settingsSection(title: "Check for Updates", icon: "arrow.clockwise") {
                Button(action: {
                    isCheckingForUpdates = true
                    Task {
                        await updateChecker.checkForUpdates()
                        updateChecker.showingUpToDate = !updateChecker.updateAvailable
                        isCheckingForUpdates = false
                    }
                }) {
                    HStack(spacing: 10) {
                        if isCheckingForUpdates {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.8)
                                .frame(width: 20)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                        }

                        Text(isCheckingForUpdates ? "Checking..." : "Check for Updates")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.03))
                    )
                }
                .buttonStyle(.plain)
                .disabled(isCheckingForUpdates)
            }
        }
    }

    // MARK: - Reusable Components
    
    private func settingsSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
            }
            
            VStack(spacing: 0) {
                content()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(colorScheme == .dark
                          ? Color.white.opacity(0.04)
                          : Color.white.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06), lineWidth: 0.5)
            )
        }
    }
    
    private func shortcutRow(keys: String, action: String) -> some View {
        HStack {
            Text(action)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(keys)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
        }
        .padding(.vertical, 6)
    }
    
    // MARK: - Helpers
    
    private var hasNotchScreen: Bool {
        NSScreen.screens.contains(where: { NotchAttachedWindow.screenHasNotch($0) })
    }

    private func iconForPosition(_ position: VolumeBarPosition) -> String {
        switch position {
        case .leftMiddleVertical: return "rectangle.lefthalf.inset.filled"
        case .bottomVertical: return "rectangle.bottomhalf.inset.filled"
        case .rightVertical: return "rectangle.righthalf.inset.filled"
        case .topHorizontal: return "rectangle.tophalf.inset.filled"
        case .bottomHorizontal: return "rectangle.bottomhalf.inset.filled"
        }
    }
    
    private var sizePresets: [(String, CGFloat)] {
        [("50%", 0.5), ("75%", 0.75), ("100%", 1.0), ("125%", 1.25), ("150%", 1.5), ("200%", 2.0)]
    }
    
    private func maskedKey(_ key: String) -> String {
        // Show first and last segments, mask the middle: VG-A1B2-****-****-G7H8
        let parts = key.split(separator: "-")
        guard parts.count >= 4 else { return key }
        let first = parts.prefix(2).joined(separator: "-")
        let last = parts.last ?? ""
        let masked = Array(repeating: "••••", count: parts.count - 3).joined(separator: "-")
        return "\(first)-\(masked)-\(last)"
    }
    
    // Status helpers
    private var statusColor: Color {
        switch licenseManager.licenseStatus {
        case .active: return .green
        case .trial: return .orange
        case .expired: return .red
        case .unlicensed: return .secondary
        }
    }
    
    private var statusIcon: String {
        switch licenseManager.licenseStatus {
        case .active: return "checkmark.seal.fill"
        case .trial: return "clock.fill"
        case .expired: return "exclamationmark.triangle.fill"
        case .unlicensed: return "xmark.seal"
        }
    }
    
    private var statusTitle: String {
        switch licenseManager.licenseStatus {
        case .active: return "License Active"
        case .trial: return "Trial Active"
        case .expired: return "Trial Expired"
        case .unlicensed: return "No License"
        }
    }
    
    private var statusSubtitle: String {
        switch licenseManager.licenseStatus {
        case .active: return licenseManager.licenseMessage.isEmpty ? "Your license is valid." : licenseManager.licenseMessage
        case .trial: return "\(licenseManager.trialDaysRemaining) day\(licenseManager.trialDaysRemaining == 1 ? "" : "s") remaining in your trial."
        case .expired: return "Your trial has ended. Activate a license to continue."
        case .unlicensed: return "Activate a license or start a trial."
        }
    }
    
    private var statusBadge: String {
        switch licenseManager.licenseStatus {
        case .active: return "ACTIVE"
        case .trial: return "TRIAL"
        case .expired: return "EXPIRED"
        case .unlicensed: return "INACTIVE"
        }
    }
    
    private var trialProgress: CGFloat {
        let total: CGFloat = 3.0
        let remaining = CGFloat(licenseManager.trialDaysRemaining)
        return max(0, min(1, remaining / total))
    }
    
    private var trialProgressColor: Color {
        let remaining = licenseManager.trialDaysRemaining
        if remaining <= 1 { return .red }
        if remaining <= 2 { return .orange }
        return .accentColor
    }
    
    // MARK: - Actions
    
    private func activateLicenseFromSettings() {
        guard !isActivating else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            showActivationError = false
            activationSuccess = false
        }
        
        isActivating = true
        
        licenseManager.activateLicense(key: newLicenseKey) { success, message in
            isActivating = false
            
            if success {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    activationSuccess = true
                    newLicenseKey = ""
                }
                // Clear success after a moment
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { activationSuccess = false }
                }
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    activationError = message
                    showActivationError = true
                }
            }
        }
    }
    
    // MARK: - Debug Section
    #if DEBUG
    
    @State private var debugInfoText: String = ""
    @State private var showDebugInfo: Bool = false
    @State private var shortTrialSeconds: String = "60"
    
    private var debugSection: some View {
        settingsSection(title: "Debug (Dev Only)", icon: "ant") {
            VStack(spacing: 10) {
                // Info dump
                Button(action: {
                    debugInfoText = licenseManager.debugInfo
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        showDebugInfo = true
                    }
                }) {
                    debugButtonRow(icon: "info.circle", label: "Show Trial Info", color: .blue)
                }
                .buttonStyle(.plain)
                
                if showDebugInfo {
                    Text(debugInfoText)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(colorScheme == .dark
                                      ? Color.white.opacity(0.03)
                                      : Color.black.opacity(0.03))
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                Divider().opacity(0.3)
                
                // Short trial
                HStack(spacing: 8) {
                    Button(action: {
                        let secs = TimeInterval(shortTrialSeconds) ?? 60
                        licenseManager.debugStartShortTrial(seconds: secs)
                    }) {
                        debugButtonRow(icon: "timer", label: "Start Short Trial", color: .orange)
                    }
                    .buttonStyle(.plain)
                    
                    TextField("sec", text: $shortTrialSeconds)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .frame(width: 50)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(colorScheme == .dark
                                      ? Color.white.opacity(0.05)
                                      : Color.black.opacity(0.04))
                        )
                    
                    Text("sec")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Force expire
                Button(action: {
                    licenseManager.debugForceExpireTrial()
                }) {
                    debugButtonRow(icon: "exclamationmark.triangle", label: "Force Expire Now", color: .red)
                }
                .buttonStyle(.plain)
                
                // Reset trial only
                Button(action: {
                    licenseManager.debugResetTrialOnly()
                    showDebugInfo = false
                }) {
                    debugButtonRow(icon: "arrow.counterclockwise", label: "Reset Trial Only", color: .purple)
                }
                .buttonStyle(.plain)
                
                // Full reset
                Button(action: {
                    licenseManager.resetAll()
                    showDebugInfo = false
                }) {
                    debugButtonRow(icon: "trash", label: "Reset Everything", color: .red)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func debugButtonRow(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.06))
        )
    }
    
    #endif
}

// MARK: - Shortcut Recorder Row

struct ShortcutRecorderRow: View {
    let action: String
    @Binding var shortcut: ShortcutKey
    let onChanged: (ShortcutKey) -> Void
    @State private var isRecording = false
    @State private var keyMonitor: Any?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            Text(action)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)

            Spacer()

            if isRecording {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 5, height: 5)
                    Text("Press shortcut…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.red.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
                .onTapGesture { stopRecording() }
            } else {
                Button(action: startRecording) {
                    Text(shortcut.displayString)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard self.isRecording else { return event }
            if event.keyCode == 53 { // Escape — cancel
                self.stopRecording()
                return nil
            }
            let filtered = event.modifierFlags.intersection([.command, .shift, .option, .control])
            guard !filtered.isEmpty else { return event } // require at least one modifier
            let newShortcut = ShortcutKey(keyCode: event.keyCode, modifiers: filtered.rawValue)
            self.shortcut = newShortcut
            self.onChanged(newShortcut)
            self.stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}

// MARK: - Settings Window Controller

class SettingsWindowController {
    static let shared = SettingsWindowController()
    
    private var window: NSWindow?
    
    func showSettings(setupState: SetupState) {
        // If window already exists, bring to front
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = SettingsView(
            setupState: setupState,
            licenseManager: LicenseManager.shared
        )
        
        let hostingView = NSHostingView(rootView: settingsView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.title = "VolumeGlass Settings"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.center()
        window.isMovableByWindowBackground = true
        window.setFrameAutosaveName("VolumeGlassSettings")
        
        // Set the correct appearance
        window.backgroundColor = NSColor(white: NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? 0.1 : 0.95, alpha: 1)
        
        self.window = window
        
        // Show the window
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Watch for close to go back to accessory
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.window = nil
            // Go back to accessory mode if volume monitoring is active
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if UserDefaults.standard.bool(forKey: "isSetupComplete") {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }
}
