import SwiftUI

// MARK: - License Gate View

/// Shown on launch when no valid license or trial exists.
/// Matches the app's minimalist liquid glass aesthetic.
struct LicenseView: View {
    @ObservedObject var licenseManager: LicenseManager
    @Environment(\.colorScheme) var colorScheme
    
    @State private var licenseKeyInput: String = ""
    @State private var showActivation: Bool = false
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    @State private var animateIn: Bool = false
    @State private var isActivating: Bool = false
    @State private var isStartingTrial: Bool = false
    @State private var trialError: String = ""
    @State private var showTrialError: Bool = false
    
    var onLicensed: () -> Void
    
    var body: some View {
        ZStack {
            // Background — matches SetupWalkthroughView
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(white: 0.08), Color(white: 0.12)]
                    : [Color(white: 0.96), Color(white: 0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                if showActivation {
                    activationContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    welcomeContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
                
                Spacer()
            }
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 20)
        }
        .frame(minWidth: 520, minHeight: 480)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) {
                animateIn = true
            }
        }
    }
    
    // MARK: - Welcome / Choice Screen
    
    private var welcomeContent: some View {
        VStack(spacing: 32) {
            // Icon
            iconView
            
            // Title
            VStack(spacing: 10) {
                Text("VolumeGlass")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(licenseManager.hasUsedTrial
                     ? "Your trial has ended. Enter a license to continue."
                     : "Activate your license or start a free trial")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Buttons
            VStack(spacing: 14) {
                // Start Trial — only available for first-time users
                if !licenseManager.hasUsedTrial {
                    Button(action: {
                        isStartingTrial = true
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showTrialError = false
                        }
                        licenseManager.startTrial { success in
                            isStartingTrial = false
                            if success {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    onLicensed()
                                }
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    trialError = licenseManager.licenseMessage.isEmpty
                                        ? "Unable to start trial. Check your connection."
                                        : licenseManager.licenseMessage
                                    showTrialError = true
                                }
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            if isStartingTrial {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "clock")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            Text(isStartingTrial ? "Starting Trial…" : "Start 3-Day Free Trial")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isStartingTrial ? Color.accentColor.opacity(0.6) : Color.accentColor)
                                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isStartingTrial)

                    if showTrialError {
                        Text(trialError)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 280)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                
                // Activate License — becomes primary action when trial was used
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        showActivation = true
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "key")
                            .font(.system(size: 14, weight: .semibold))
                        Text("I Have a License Key")
                            .font(.system(size: 15, weight: licenseManager.hasUsedTrial ? .semibold : .medium))
                    }
                    .foregroundColor(licenseManager.hasUsedTrial ? .white : .primary)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(licenseManager.hasUsedTrial ? Color.accentColor : Color.primary.opacity(0.06))
                            .shadow(color: licenseManager.hasUsedTrial ? Color.accentColor.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
                    )
                    .overlay(
                        Group {
                            if !licenseManager.hasUsedTrial {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 0.5)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Purchase link
            Button(action: {
                if let url = URL(string: "https://volumeglass.app/") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Text("Purchase a license — $7.99")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .underline(color: .secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            
            // Quit — shown when trial was used (no free usage possible)
            if licenseManager.hasUsedTrial {
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text("Quit VolumeGlass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 50)
    }
    
    // MARK: - Activation Screen
    
    private var activationContent: some View {
        VStack(spacing: 28) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "key.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.accentColor)
            }
            
            // Title
            VStack(spacing: 8) {
                Text("Activate License")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Enter the license key from your purchase email")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // License key input
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    TextField("VG-XXXX-XXXX-XXXX-XXXX", text: $licenseKeyInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .onSubmit {
                            activateKey()
                        }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(colorScheme == .dark
                              ? Color.white.opacity(0.06)
                              : Color.black.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            showError
                                ? Color.red.opacity(0.5)
                                : Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08),
                            lineWidth: showError ? 1.5 : 0.5
                        )
                )
                .frame(maxWidth: 340)
                
                // Error message
                if showError {
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            
            // Buttons
            VStack(spacing: 12) {
                // Activate
                Button(action: activateKey) {
                    HStack(spacing: 8) {
                        if isActivating {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(isActivating ? "Validating…" : "Activate")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isActivating ? Color.accentColor.opacity(0.6) : Color.accentColor)
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isActivating)
                
                // Back
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        showActivation = false
                        showError = false
                        errorMessage = ""
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 50)
    }
    
    // MARK: - Shared Icon
    
    private var iconView: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.accentColor.opacity(0.15),
                            Color.accentColor.opacity(0.03),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 70
                    )
                )
                .frame(width: 140, height: 140)
            
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    // MARK: - Actions
    
    private func activateKey() {
        guard !isActivating else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            showError = false
        }
        
        isActivating = true
        
        licenseManager.activateLicense(key: licenseKeyInput) { success, message in
            isActivating = false
            
            if success {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    onLicensed()
                }
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    errorMessage = message
                    showError = true
                }
            }
        }
    }
}

// MARK: - Trial Expired View

/// Shown when the 3-day trial has ended.
struct TrialExpiredView: View {
    @ObservedObject var licenseManager: LicenseManager
    @Environment(\.colorScheme) var colorScheme
    
    @State private var licenseKeyInput: String = ""
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    @State private var animateIn: Bool = false
    @State private var isActivating: Bool = false
    
    var onLicensed: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(white: 0.08), Color(white: 0.12)]
                    : [Color(white: 0.96), Color(white: 0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 28) {
                Spacer()
                
                // Expired icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundColor(.orange)
                }
                
                // Title & message
                VStack(spacing: 10) {
                    Text("VolumeGlass Trial Expired")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Your trial has expired.\nPlease purchase a license to continue using VolumeGlass.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
                
                // License key input
                VStack(spacing: 12) {
                    TextField("VG-XXXX-XXXX-XXXX-XXXX", text: $licenseKeyInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(colorScheme == .dark
                                      ? Color.white.opacity(0.06)
                                      : Color.black.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    showError
                                        ? Color.red.opacity(0.5)
                                        : Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08),
                                    lineWidth: showError ? 1.5 : 0.5
                                )
                        )
                        .frame(maxWidth: 340)
                        .onSubmit { activateKey() }
                    
                    if showError {
                        Text(errorMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                
                // Buttons
                VStack(spacing: 14) {
                    // Activate
                    Button(action: activateKey) {
                        HStack(spacing: 8) {
                            if isActivating {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "key.fill")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            Text(isActivating ? "Validating…" : "Activate License")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isActivating ? Color.accentColor.opacity(0.6) : Color.accentColor)
                                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isActivating)
                    
                    // Purchase
                    Button(action: {
                        if let url = URL(string: "https://volumeglass.app/") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "cart")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Purchase — $7.99")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Quit
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Text("Quit VolumeGlass")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                
                Spacer()
            }
            .padding(.horizontal, 50)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 20)
        }
        .frame(minWidth: 520, minHeight: 500)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) {
                animateIn = true
            }
        }
    }
    
    private func activateKey() {
        guard !isActivating else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            showError = false
        }
        
        isActivating = true
        
        licenseManager.activateLicense(key: licenseKeyInput) { success, message in
            isActivating = false
            
            if success {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    onLicensed()
                }
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    errorMessage = message
                    showError = true
                }
            }
        }
    }
}

// MARK: - Trial Expired Popup View (shown while app is running)

/// Compact popup that appears when the trial expires mid-session.
/// Flat, minimal style matching the rest of the app — no gradients.
struct TrialExpiredPopupView: View {
    @ObservedObject var licenseManager: LicenseManager
    @Environment(\.colorScheme) var colorScheme
    
    @State private var licenseKeyInput: String = ""
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    @State private var animateIn: Bool = false
    @State private var isActivating: Bool = false
    
    var onLicensed: () -> Void
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95)
    }
    
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer().frame(height: 8)
                
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 72, height: 72)
                    
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundColor(.orange)
                }
                
                // Title & subtitle
                VStack(spacing: 8) {
                    Text("VolumeGlass Trial Expired")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Please purchase a license to continue using VolumeGlass.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
                
                // License key input
                VStack(spacing: 10) {
                    TextField("VG-XXXX-XXXX-XXXX-XXXX", text: $licenseKeyInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(colorScheme == .dark
                                      ? Color.white.opacity(0.05)
                                      : Color.black.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    showError
                                        ? Color.red.opacity(0.5)
                                        : Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.07),
                                    lineWidth: showError ? 1.5 : 0.5
                                )
                        )
                        .frame(maxWidth: 320)
                        .onSubmit { activateKey() }
                    
                    if showError {
                        Text(errorMessage)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                
                // Buttons
                VStack(spacing: 10) {
                    // Activate
                    Button(action: activateKey) {
                        HStack(spacing: 8) {
                            if isActivating {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "key.fill")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            Text(isActivating ? "Validating…" : "Activate License")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: 260)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isActivating ? Color.accentColor.opacity(0.6) : Color.accentColor)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isActivating)
                    
                    // Purchase
                    Button(action: {
                        if let url = URL(string: "https://volumeglass.app/") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "cart")
                                .font(.system(size: 13, weight: .medium))
                            Text("Purchase — $7.99")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: 260)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.07), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Quit
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Text("Quit VolumeGlass")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
                
                Spacer().frame(height: 8)
            }
            .padding(.horizontal, 36)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 12)
        }
        .frame(width: 420, height: 460)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85).delay(0.15)) {
                animateIn = true
            }
        }
    }
    
    private func activateKey() {
        guard !isActivating else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            showError = false
        }
        
        isActivating = true
        
        licenseManager.activateLicense(key: licenseKeyInput) { success, message in
            isActivating = false
            
            if success {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    onLicensed()
                }
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    errorMessage = message
                    showError = true
                }
            }
        }
    }
}

// MARK: - Trial Expired Window Controller

class TrialExpiredWindowController {
    static let shared = TrialExpiredWindowController()
    
    private var window: NSPanel?
    private var closeObserver: NSObjectProtocol?
    
    var isShowing: Bool {
        window?.isVisible == true
    }
    
    func showExpiredPopup() {
        // If already showing, bring to front
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let popupView = TrialExpiredPopupView(
            licenseManager: LicenseManager.shared
        ) {
            // On licensed — dismiss and resume
            TrialExpiredWindowController.shared.dismiss()
        }
        
        let hostingView = NSHostingView(rootView: popupView)
        
        // No .closable — user must Activate or Quit, can't just dismiss
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 460),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.title = "VolumeGlass"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.center()
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        panel.backgroundColor = NSColor(white: isDark ? 0.1 : 0.95, alpha: 1)
        
        self.window = panel
        
        // Show
        NSApp.setActivationPolicy(.regular)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Safety net: if the panel somehow closes without activation, quit
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            guard self?.window != nil else { return }
            // Panel closed without a successful license activation — quit
            NSApplication.shared.terminate(nil)
        }
    }
    
    func dismiss() {
        // Remove close observer FIRST so closing the window won't trigger quit
        if let observer = closeObserver {
            NotificationCenter.default.removeObserver(observer)
            closeObserver = nil
        }
        
        window?.close()
        window = nil
        
        // Notify the app to restart volume monitoring now that the license is valid
        NotificationCenter.default.post(name: NSNotification.Name("TrialExpiredLicenseActivated"), object: nil)
        
        // Go back to accessory mode
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if UserDefaults.standard.bool(forKey: "isSetupComplete") {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}
