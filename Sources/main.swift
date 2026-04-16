import Cocoa
import QuartzCore
import ApplicationServices

private enum AppStorage {
    static let rippleColorRed = "rippleColorRed"
    static let rippleColorGreen = "rippleColorGreen"
    static let rippleColorBlue = "rippleColorBlue"
    static let rippleColorAlpha = "rippleColorAlpha"
    static let hasSavedRippleColor = "hasSavedRippleColor"
    static let accessibilityPromptShown = "accessibilityPromptShown"
}

final class ClickRipplesAppDelegate: NSObject, NSApplicationDelegate {
    private var overlayController: OverlayController?
    private var statusItem: NSStatusItem?
    private let defaults = UserDefaults.standard
    private lazy var colorPanel: NSColorPanel = {
        let panel = NSColorPanel.shared
        panel.setTarget(self)
        panel.setAction(#selector(colorDidChange(_:)))
        panel.showsAlpha = true
        return panel
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureAppIcon()
        overlayController = OverlayController()
        overlayController?.updateRippleColor(loadSavedRippleColor())
        overlayController?.start()
        installStatusItem()
        overlayController?.showDemoRippleNearMouse()

        if !hasAccessibilityAccess() && !defaults.bool(forKey: AppStorage.accessibilityPromptShown) {
            promptForAccessibilityAccess()
        }
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = appIconImage()
            button.imagePosition = .imageLeading
            button.title = "ClickRipples"
        }

        let menu = NSMenu()
        menu.addItem(
            withTitle: "Show Test Ripple",
            action: #selector(showTestRipple),
            keyEquivalent: "t"
        )
        menu.addItem(
            withTitle: "Choose Ripple Color…",
            action: #selector(openColorPicker),
            keyEquivalent: "c"
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Open Accessibility Settings",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ","
        )
        menu.addItem(
            withTitle: "Show Help",
            action: #selector(showHelp),
            keyEquivalent: "h"
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Click Ripples",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )

        item.menu = menu
        statusItem = item
    }

    private func configureAppIcon() {
        if let icon = appIconImage() {
            NSApp.applicationIconImage = icon
        }
    }

    private func appIconImage() -> NSImage? {
        guard let image = Bundle.main.image(forResource: "AppIcon") else {
            return nil
        }

        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = false
        return image
    }

    private func hasAccessibilityAccess() -> Bool {
        AXIsProcessTrusted()
    }

    private func promptForAccessibilityAccess() {
        defaults.set(true, forKey: AppStorage.accessibilityPromptShown)

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.presentHelpAlert(
                title: "Enable Click Monitoring",
                message: "ClickRipples is running, but macOS may block global click detection until you allow Accessibility access. In System Settings, add or enable ClickRipples under Privacy & Security > Accessibility, then relaunch the app."
            )
        }
    }

    @objc
    private func showTestRipple() {
        overlayController?.showDemoRippleNearMouse()
    }

    @objc
    private func openColorPicker() {
        guard let overlayController else {
            return
        }

        colorPanel.color = overlayController.rippleColor
        colorPanel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    private func colorDidChange(_ sender: NSColorPanel) {
        let color = sender.color.usingColorSpace(.deviceRGB) ?? sender.color
        overlayController?.updateRippleColor(color)
        saveRippleColor(color)
    }

    @objc
    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    @objc
    private func showHelp() {
        let message: String
        if hasAccessibilityAccess() {
            message = "ClickRipples is active in the menu bar. Choose 'Show Test Ripple' to verify the overlay, then click anywhere to see live ripples."
        } else {
            message = "ClickRipples is active, but global click detection needs Accessibility permission. Open Accessibility Settings from this menu, enable ClickRipples, then relaunch it."
        }

        presentHelpAlert(title: "ClickRipples", message: message)
    }

    private func presentHelpAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func loadSavedRippleColor() -> NSColor {
        guard defaults.bool(forKey: AppStorage.hasSavedRippleColor) else {
            return .systemBlue
        }

        return NSColor(
            calibratedRed: defaults.double(forKey: AppStorage.rippleColorRed),
            green: defaults.double(forKey: AppStorage.rippleColorGreen),
            blue: defaults.double(forKey: AppStorage.rippleColorBlue),
            alpha: defaults.double(forKey: AppStorage.rippleColorAlpha)
        )
    }

    private func saveRippleColor(_ color: NSColor) {
        guard let rgbColor = color.usingColorSpace(.deviceRGB) else {
            return
        }

        defaults.set(Double(rgbColor.redComponent), forKey: AppStorage.rippleColorRed)
        defaults.set(Double(rgbColor.greenComponent), forKey: AppStorage.rippleColorGreen)
        defaults.set(Double(rgbColor.blueComponent), forKey: AppStorage.rippleColorBlue)
        defaults.set(Double(rgbColor.alphaComponent), forKey: AppStorage.rippleColorAlpha)
        defaults.set(true, forKey: AppStorage.hasSavedRippleColor)
    }

    @objc
    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = ClickRipplesAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

private final class OverlayController: NSObject {
    private var windows: [OverlayWindow] = []
    private var globalMonitor: Any?
    private var screenObserver: Any?
    private(set) var rippleColor = NSColor.systemBlue

    func start() {
        rebuildWindows()
        installEventMonitors()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildWindows()
        }
    }

    func showDemoRippleNearMouse() {
        let mousePoint = NSEvent.mouseLocation
        let demoPoint = NSPoint(x: mousePoint.x + 18, y: mousePoint.y - 18)
        showRipple(at: demoPoint)
    }

    func updateRippleColor(_ color: NSColor) {
        rippleColor = color.usingColorSpace(.deviceRGB) ?? color
        windows
            .compactMap { $0.contentView as? OverlayView }
            .forEach { $0.rippleColor = rippleColor }
    }

    deinit {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    private func installEventMonitors() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            self?.showRipple(at: NSEvent.mouseLocation)
        }
    }

    private func rebuildWindows() {
        windows.forEach { $0.close() }
        windows = NSScreen.screens.map(OverlayWindow.init(screen:))
        windows
            .compactMap { $0.contentView as? OverlayView }
            .forEach { $0.rippleColor = rippleColor }
        windows.forEach { $0.orderFrontRegardless() }
    }

    private func showRipple(at globalPoint: NSPoint) {
        guard
            let window = windows.first(where: { NSMouseInRect(globalPoint, $0.screenFrame, false) }),
            let overlayView = window.contentView as? OverlayView
        else {
            return
        }

        let pointInScreen = NSPoint(
            x: globalPoint.x - window.screenFrame.minX,
            y: globalPoint.y - window.screenFrame.minY
        )

        overlayView.showRipple(at: pointInScreen)
    }
}

private final class OverlayWindow: NSWindow {
    let screenFrame: NSRect

    init(screen: NSScreen) {
        screenFrame = screen.frame
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        setFrame(screen.frame, display: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class OverlayView: NSView {
    var rippleColor = NSColor.systemBlue

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func showRipple(at point: NSPoint) {
        guard let hostLayer = layer else {
            return
        }

        let rippleSize: CGFloat = 36
        let rippleRect = CGRect(
            x: point.x - rippleSize / 2,
            y: point.y - rippleSize / 2,
            width: rippleSize,
            height: rippleSize
        )

        let ringLayer = CAShapeLayer()
        ringLayer.frame = rippleRect
        ringLayer.path = CGPath(ellipseIn: CGRect(origin: .zero, size: rippleRect.size), transform: nil)
        ringLayer.fillColor = rippleColor.withAlphaComponent(0.10).cgColor
        ringLayer.strokeColor = rippleColor.withAlphaComponent(0.95).cgColor
        ringLayer.lineWidth = 5
        ringLayer.opacity = 1

        hostLayer.addSublayer(ringLayer)

        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.45
        scaleAnimation.toValue = 2.0

        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 1.0
        opacityAnimation.toValue = 0

        let fadeFillAnimation = CABasicAnimation(keyPath: "fillColor")
        fadeFillAnimation.fromValue = rippleColor.withAlphaComponent(0.18).cgColor
        fadeFillAnimation.toValue = rippleColor.withAlphaComponent(0.0).cgColor

        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [scaleAnimation, opacityAnimation, fadeFillAnimation]
        animationGroup.duration = 0.42
        animationGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)
        animationGroup.fillMode = .forwards
        animationGroup.isRemovedOnCompletion = false

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ringLayer.opacity = 0
        ringLayer.fillColor = rippleColor.withAlphaComponent(0.0).cgColor
        ringLayer.transform = CATransform3DMakeScale(2.0, 2.0, 1)
        CATransaction.commit()

        ringLayer.add(animationGroup, forKey: "clickRipple")

        DispatchQueue.main.asyncAfter(deadline: .now() + animationGroup.duration) {
            ringLayer.removeFromSuperlayer()
        }
    }
}
