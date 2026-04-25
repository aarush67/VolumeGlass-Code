//
//  main.swift
//  VolumeGlassUpdater
//
//  A native update helper for VolumeGlass
//  This runs as a standalone process to update VolumeGlass while it's closed
//

import AppKit
import SwiftUI
import Combine

// MARK: - Update Step Model

enum UpdateStep: Int, CaseIterable {
    case closing = 0
    case mounting
    case removing
    case installing
    case cleaning
    case complete
    
    var title: String {
        switch self {
        case .closing: return "Closing VolumeGlass..."
        case .mounting: return "Mounting update image..."
        case .removing: return "Removing old version..."
        case .installing: return "Installing new VolumeGlass..."
        case .cleaning: return "Cleaning up..."
        case .complete: return "Update Complete!"
        }
    }
    
    var icon: String {
        switch self {
        case .closing: return "xmark.circle"
        case .mounting: return "externaldrive.badge.plus"
        case .removing: return "trash"
        case .installing: return "arrow.down.doc"
        case .cleaning: return "sparkles"
        case .complete: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Update State

class UpdateState: ObservableObject {
    @Published var currentStep: UpdateStep = .closing
    @Published var isComplete = false
    @Published var hasError = false
    @Published var errorMessage = ""
    @Published var appPath = ""
    
    static let shared = UpdateState()
}

// MARK: - Update View

struct UpdaterView: View {
    @ObservedObject var state = UpdateState.shared
    @State private var isLaunchHovering = false
    @State private var showConfetti = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header strip
                HStack(spacing: 8) {
                    if state.hasError {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.red)
                    } else if state.isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.green)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.75)
                            .frame(width: 14, height: 14)
                    }
                    Text(state.hasError ? "Update Failed" : (state.isComplete ? "Update Complete!" : "Updating VolumeGlass…"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(state.hasError ? Color.red : (state.isComplete ? Color.green : Color.primary))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .animation(.easeInOut(duration: 0.3), value: state.isComplete)
                .animation(.easeInOut(duration: 0.3), value: state.hasError)
                .onChange(of: state.isComplete) { _, complete in
                    if complete {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showConfetti = true
                        }
                    }
                }

                Divider().opacity(0.5)
                
                // Progress Steps
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(UpdateStep.allCases.filter { $0 != .complete }, id: \.rawValue) { step in
                        StepRow(
                            step: step,
                            currentStep: state.currentStep,
                            isAllComplete: state.isComplete,
                            hasError: state.hasError
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                
                // Error Message
                if state.hasError {
                    VStack(spacing: 8) {
                        Text(state.errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        Text("You can manually update by dragging VolumeGlass.app from the mounted disk image to Applications.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 16)
                }
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Action Button
                HStack {
                    Spacer()
                    
                    if state.isComplete || state.hasError {
                        Button {
                            if state.isComplete {
                                // Launch the updated VolumeGlass
                                NSWorkspace.shared.open(URL(fileURLWithPath: state.appPath))
                            }
                            // Quit the updater
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                NSApp.terminate(nil)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: state.hasError ? "xmark" : "arrow.right.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(state.hasError ? "Close" : "Launch VolumeGlass")
                            }
                            .fontWeight(.semibold)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                state.isComplete
                                    ? Color.green.opacity(isLaunchHovering ? 1.0 : 0.8)
                                    : Color.blue.opacity(isLaunchHovering ? 1.0 : 0.8)
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .onHover { h in
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                isLaunchHovering = h
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state.isComplete)
            }
            
            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Confetti View (Optimized for Performance)

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var isVisible = true
    
    var body: some View {
        GeometryReader { geo in
            if isVisible {
                Canvas { context, size in
                    for particle in particles {
                        // Simple rectangle without rotation for performance
                        let rect = CGRect(
                            x: particle.currentX - particle.size / 2,
                            y: particle.currentY - particle.size / 2,
                            width: particle.size,
                            height: particle.size * 1.5
                        )
                        context.fill(
                            RoundedRectangle(cornerRadius: 2).path(in: rect),
                            with: .color(particle.color.opacity(particle.opacity))
                        )
                    }
                }
                .onAppear {
                    createParticles(in: geo.size)
                    startAnimation()
                }
            }
        }
    }
    
    private func createParticles(in size: CGSize) {
        let colors: [Color] = [.green, .blue, .yellow, .orange, .pink, .purple, .cyan, .mint]
        let centerX = size.width / 2
        
        // 20 particles - good balance of visual effect and performance
        for i in 0..<20 {
            let spreadAngle = Double.random(in: -0.7...0.7)
            let velocity = CGFloat.random(in: 150...280)
            let targetX = centerX + cos(spreadAngle - .pi/2) * velocity
            let targetY = sin(spreadAngle - .pi/2) * velocity + CGFloat.random(in: 30...100)
            
            var particle = ConfettiParticle(
                id: i,
                x: targetX,
                startY: size.height + 10,
                endY: targetY,
                color: colors[i % colors.count],
                size: CGFloat.random(in: 5...8),
                delay: Double(i) * 0.02 // Staggered for natural look
            )
            particle.currentX = centerX + CGFloat.random(in: -15...15)
            particle.currentY = size.height + 10
            particles.append(particle)
        }
    }
    
    private func startAnimation() {
        // Batch all particles into single animation phases for better performance
        
        // Phase 1: All burst upward together (staggered by delay)
        for i in 0..<particles.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + particles[i].delay) { [self] in
                guard i < particles.count else { return }
                withAnimation(.easeOut(duration: 0.6)) {
                    particles[i].currentY = particles[i].endY
                    particles[i].currentX = particles[i].x
                }
            }
        }
        
        // Phase 2: All fall and fade together
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [self] in
            withAnimation(.easeIn(duration: 0.6)) {
                for i in 0..<particles.count {
                    particles[i].currentY = 350
                    particles[i].opacity = 0
                }
            }
        }
        
        // Cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            isVisible = false
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id: Int
    let x: CGFloat
    let startY: CGFloat
    let endY: CGFloat
    let color: Color
    let size: CGFloat
    let delay: Double
    var currentX: CGFloat = 0
    var currentY: CGFloat = 0
    var opacity: Double = 1
}

struct StepRow: View {
    let step: UpdateStep
    let currentStep: UpdateStep
    let isAllComplete: Bool
    let hasError: Bool
    
    private var isComplete: Bool {
        // When all done, all steps are complete
        if isAllComplete { return true }
        return step.rawValue < currentStep.rawValue
    }
    
    private var isCurrent: Bool {
        // When all done, no step is "current"
        if isAllComplete { return false }
        return step.rawValue == currentStep.rawValue
    }
    
    private var isPending: Bool {
        // When all done, no step is pending
        if isAllComplete { return false }
        return step.rawValue > currentStep.rawValue
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                } else if isCurrent {
                    if hasError {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.red)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.8)
                            .transition(.opacity)
                    }
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .transition(.opacity)
                }
            }
            .frame(width: 20, height: 20)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isComplete)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCurrent)
            
            Text(step.title)
                .font(.system(size: 13, weight: isComplete ? .medium : (isCurrent ? .semibold : .regular)))
                .foregroundColor(isPending ? Color.secondary : (isComplete ? Color.green : Color.white))
            
            Spacer()
        }
        .padding(.vertical, 8)
        .opacity(isPending ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isComplete)
        .animation(.easeInOut(duration: 0.2), value: isCurrent)
    }
}

// MARK: - Window Controller

class UpdaterWindowController: NSObject {
    var window: NSWindow?
    
    func showWindow() {
        let contentView = UpdaterView()
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 400)
        
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        window?.backgroundColor = .clear
        window?.isOpaque = false
        window?.hasShadow = true
        window?.isMovableByWindowBackground = true
        window?.contentView = hostingView
        window?.center()
        window?.level = .modalPanel
        window?.makeKeyAndOrderFront(nil)
        
        // Resize to fit content
        if let cv = window?.contentView {
            let fittingSize = cv.fittingSize
            window?.setContentSize(fittingSize)
            window?.center()
        }
    }
}

// MARK: - Update Logic

class Updater {
    let dmgPath: String
    let appPath: String
    let oldPID: Int32
    let state = UpdateState.shared
    
    init(dmgPath: String, appPath: String, oldPID: Int32) {
        self.dmgPath = dmgPath
        self.appPath = appPath
        self.oldPID = oldPID
        state.appPath = appPath
    }
    
    func run() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performUpdate()
        }
    }
    
    private func setStep(_ step: UpdateStep) {
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.state.currentStep = step
            }
        }
        // Small delay for visual feedback between steps
        Thread.sleep(forTimeInterval: 0.15)
    }
    
    private func setError(_ message: String) {
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.state.hasError = true
                self.state.errorMessage = message
            }
        }
    }
    
    private func setComplete() {
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                self.state.currentStep = .complete
                self.state.isComplete = true
            }
            // Auto-launch and quit after 10 seconds if user doesn't click the button
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                if self.state.isComplete {
                    NSWorkspace.shared.open(URL(fileURLWithPath: self.state.appPath))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NSApp.terminate(nil)
                    }
                }
            }
        }
    }
    
    private func performUpdate() {
        // Step 1: Close old app
        setStep(.closing)
        
        // Kill the old process
        kill(oldPID, SIGKILL)
        
        // Wait for it to die
        for _ in 0..<20 {
            if kill(oldPID, 0) != 0 {
                break
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        Thread.sleep(forTimeInterval: 0.8)
        
        // Step 2: Mount DMG
        setStep(.mounting)
        
        let mountProcess = Process()
        mountProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        mountProcess.arguments = ["attach", dmgPath, "-nobrowse", "-mountpoint", "/Volumes/VolumeGlassUpdate"]
        
        do {
            try mountProcess.run()
            mountProcess.waitUntilExit()
        } catch {
            setError("Failed to mount update image")
            return
        }
        
        // Check if mount succeeded
        let appInDMG = "/Volumes/VolumeGlassUpdate/VolumeGlass.app"
        if !FileManager.default.fileExists(atPath: appInDMG) {
            setError("Could not find VolumeGlass.app in update image")
            return
        }
        
        // Step 3: Remove old app
        setStep(.removing)
        
        do {
            if FileManager.default.fileExists(atPath: appPath) {
                try FileManager.default.removeItem(atPath: appPath)
            }
        } catch {
            // Try with admin privileges using osascript
            let script = "do shell script \"rm -rf '\(appPath)'\" with administrator privileges"
            let appleScript = NSAppleScript(source: script)
            var errorDict: NSDictionary?
            appleScript?.executeAndReturnError(&errorDict)
            
            if FileManager.default.fileExists(atPath: appPath) {
                setError("Could not remove old version. Please delete VolumeGlass.app manually.")
                // Open Applications folder to help user
                NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications"))
                NSWorkspace.shared.open(URL(fileURLWithPath: "/Volumes/VolumeGlassUpdate"))
                return
            }
        }
        
        // Step 4: Install new app
        setStep(.installing)
        
        do {
            try FileManager.default.copyItem(atPath: appInDMG, toPath: appPath)
        } catch {
            setError("Failed to install new version: \(error.localizedDescription)")
            return
        }
        
        // Remove quarantine attribute
        let xattrProcess = Process()
        xattrProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        xattrProcess.arguments = ["-rd", "com.apple.quarantine", appPath]
        try? xattrProcess.run()
        xattrProcess.waitUntilExit()
        
        // Step 5: Cleanup
        setStep(.cleaning)
        
        let unmountProcess = Process()
        unmountProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        unmountProcess.arguments = ["detach", "/Volumes/VolumeGlassUpdate", "-quiet"]
        try? unmountProcess.run()
        unmountProcess.waitUntilExit()
        
        try? FileManager.default.removeItem(atPath: dmgPath)
        
        // Small delay before showing complete
        Thread.sleep(forTimeInterval: 0.4)
        
        // Complete!
        setComplete()
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: UpdaterWindowController?
    var updater: Updater?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Parse command line arguments
        let args = CommandLine.arguments
        
        guard args.count >= 4 else {
            print("Usage: VolumeGlassUpdater <dmg_path> <app_path> <old_pid>")
            NSApp.terminate(nil)
            return
        }
        
        let dmgPath = args[1]
        let appPath = args[2]
        let oldPID = Int32(args[3]) ?? 0
        
        // Show the window
        windowController = UpdaterWindowController()
        windowController?.showWindow()
        
        // Start the update
        updater = Updater(dmgPath: dmgPath, appPath: appPath, oldPID: oldPID)
        updater?.run()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()

