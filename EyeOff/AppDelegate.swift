
import Cocoa
import UserNotifications
import ServiceManagement


class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    // var currentInterval: TimeInterval = 20 * 60 // production
    var currentInterval: TimeInterval = 20 // 🧪 for quick testing

    var isOverlayVisible = false
    var overlayWindow: NSWindow?
    var countdownTimer: Timer?
    var remainingSeconds: Int = 20
    var countdownLabel: NSTextField?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        requestNotificationPermission()
        startReminderTimer()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "👁️"

        let menu = NSMenu()
        
        let intervalMenu = NSMenu()
        [10, 20, 30].forEach { min in
            let item = NSMenuItem(title: "\(min) minutes", action: #selector(changeInterval(_:)), keyEquivalent: "")
            item.representedObject = min
            item.state = (Int(currentInterval / 60) == min) ? .on : .off
            intervalMenu.addItem(item)
        }

        let intervalItem = NSMenuItem(title: "Set Reminder Interval", action: nil, keyEquivalent: "")
        menu.setSubmenu(intervalMenu, for: intervalItem)
        menu.addItem(intervalItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Notification Settings", action: #selector(openNotificationSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About EyesOff", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
    }
    

    @objc func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "EyesOff (20-20-20)"
        alert.informativeText = """
        Version 1.0.0

        👁 EyesOff reminds you to follow the 20-20-20 rule:
        Every 20 minutes, look at something 20 feet away for 20 seconds.

        📌 Customizable interval. Blurs screen gently.

        🔗 GitHub: github.com/lavisar
        🧑‍💻 Developed by Lavisar
        """
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc func changeInterval(_ sender: NSMenuItem) {
        guard let minutes = sender.representedObject as? Int else { return }
        currentInterval = TimeInterval(minutes * 60)
        restartTimer()

        sender.menu?.items.forEach { $0.state = .off }
        sender.state = .on
    }

    func restartTimer() {
        timer?.invalidate()
        startReminderTimer()
    }

    func startReminderTimer() {
        print("📅 Timer started with interval: \(currentInterval)")
        timer = Timer.scheduledTimer(withTimeInterval: currentInterval, repeats: true) { [weak self] _ in
                print("🔔 Timer fired")
                self?.showReminder()
            }
    }
    
    

    @objc func showReminder() {
        let screenFrame = NSScreen.main?.frame ?? .zero
        let panel = NSPanel(
            contentRect: CGRect(x: screenFrame.midX - 200, y: screenFrame.midY - 150, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        panel.title = "👁️ EyesOff Break Time"
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.center()
        panel.makeKeyAndOrderFront(nil)

        let contentView = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // Message Label
        let label = NSTextField(labelWithString: """
        🧘 Time to rest your eyes!

        ⏳ Please look 20 feet away and relax for \(remainingSeconds)s.

        💡 Blink slowly. Breathe deeply.
        """)
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        label.backgroundColor = .clear
        label.isBordered = false
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)

        // OK Button
        let okButton = NSButton(title: "Got it!", target: panel, action: #selector(panel.close))
        okButton.bezelStyle = .rounded
        okButton.font = .systemFont(ofSize: 16)
        okButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(okButton)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -20),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            okButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20),
            okButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        ])

        panel.contentView = contentView
    }

    @objc func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if !granted {
                print("❗ Notification permission not granted.")
            }
        }
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }

    @objc func skipOverlay(_ sender: NSButton) {
        sender.isEnabled = false
        dismissOverlayIfNeeded()
    }

    func dismissOverlayIfNeeded() {
        DispatchQueue.main.async {
            guard self.isOverlayVisible else { return }

            if let timer = self.countdownTimer {
                timer.invalidate()
                self.countdownTimer = nil
            }

            if let contentView = self.overlayWindow?.contentView {
                for subview in contentView.subviews {
                    subview.layer?.removeAllAnimations()
                }
            }

            self.isOverlayVisible = false
            self.overlayWindow?.orderOut(nil)
            self.overlayWindow?.close()
            self.overlayWindow = nil
            self.countdownLabel = nil
        }
    }

    func startCountdown() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }

                self.remainingSeconds -= 1

                if let label = self.countdownLabel, self.remainingSeconds > 0 {
                    label.stringValue = "⏳ \(self.remainingSeconds)s"
                } else {
                    self.dismissOverlayIfNeeded()
                }
            }
        }
    }

}
