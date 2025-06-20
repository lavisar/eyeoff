import Cocoa
import UserNotifications
import ServiceManagement


class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var workTimer: Timer?
    var countdownTimer: Timer?
    var remainingSeconds = 20
    var currentInterval: TimeInterval = 20 // 20 minutes
    
    var soundMenu: NSMenu!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        requestNotificationPermission()
        startWorkTimer()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "\u{1F441}\u{FE0F}"

        let menu = NSMenu()
        soundMenu = NSMenu()
        let sounds = getSystemSoundNames()
        let currentSound = getSelectedSound()

        for sound in sounds {
            let menuItem = NSMenuItem()
            let button = NSButton(radioButtonWithTitle: sound, target: self, action: #selector(selectSoundRadio(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(rawValue: sound)
            button.state = (sound == currentSound) ? .on : .off
            menuItem.view = button
            soundMenu.addItem(menuItem)
        }


        //? Sound customize
        let soundMenuItem = NSMenuItem(title: "Select Sound", action: nil, keyEquivalent: "")
        menu.setSubmenu(soundMenu, for: soundMenuItem)
        menu.addItem(soundMenuItem)
        
        //? Run on login
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLoginItem(_:)), keyEquivalent: "")
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)

        //? Noti setting
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Notification Settings", action: #selector(openNotificationSettings), keyEquivalent: ""))
        
        //? App info
        menu.addItem(NSMenuItem(title: "About EyesOff", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                print("✅ App registered for launch at login")
            } else {
                try SMAppService.mainApp.unregister()
                print("❌ App unregistered from launch at login")
            }
        } catch {
            print("⚠️ Failed to toggle launch at login: \(error)")
        }
    }


    func startWorkTimer() {
        workTimer?.invalidate()
        workTimer = Timer.scheduledTimer(withTimeInterval: currentInterval, repeats: true) { [weak self] _ in
            self?.triggerBreakReminder()
        }
    }

    func triggerBreakReminder() {
        DispatchQueue.main.async {
            self.remainingSeconds = 20
            self.showBreakAlert()
            self.playAlertSound()
            self.sendNotification()
            self.startCountdownToDismissAlert()
        }
    }

    func startCountdownToDismissAlert() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            self.remainingSeconds -= 1
            if self.remainingSeconds <= 0 {
                timer.invalidate()
                self.dismissActiveAlert()
                self.startWorkTimer() // Restart 20 minutes
            }
        }
    }

    var activePanel: NSPanel?

    func showBreakAlert() {
        let screenFrame = NSScreen.main?.frame ?? .zero
        let panel = NSPanel(
            contentRect: CGRect(x: screenFrame.midX - 200, y: screenFrame.midY - 150, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "\u{1F441}\u{FE0F} EyesOff Break Time"
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.center()

        let contentView = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let label = NSTextField(labelWithString: "\u{1F9D8} Time to rest your eyes!\n\n\u{23F3} Please look 20 feet away and relax for 20 seconds.\n\n\u{1F4A1} Blink slowly. Breathe deeply.")
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        label.backgroundColor = .clear
        label.isBordered = false
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)

        let okButton = NSButton(title: "Got it!", target: self, action: #selector(dismissAlertManually))
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
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        activePanel = panel
    }

    func playAlertSound() {
        let currentSound = getSelectedSound()
        NSSound(named: NSSound.Name(currentSound))?.play()
    }

    func sendNotification() {
        let content = UNMutableNotificationContent()
        
        content.title = "EyesOff Reminder"
        content.body = "Take a 20-second eye break! Look 20 feet away."
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "\(getSelectedSound()).aiff"))


        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if !granted {
                print("\u{2757} Notification permission not granted.")
            }
        }
    }
        
    // Custom sound
    func getSystemSoundNames() -> [String] {
        let soundFolder = "/System/Library/Sounds"
        let fileManager = FileManager.default
        guard let items = try? fileManager.contentsOfDirectory(atPath: soundFolder) else { return [] }
        return items
            .filter { $0.hasSuffix(".aiff") }
            .map { $0.replacingOccurrences(of: ".aiff", with: "") }
    }

    func saveSelectedSound(_ name: String) {
        UserDefaults.standard.set(name, forKey: "SelectedSound")
    }

    func getSelectedSound() -> String {
        return UserDefaults.standard.string(forKey: "SelectedSound") ?? "Submarine"
    }

    func playSoundSelectSound() {
        let soundName = getSelectedSound()
        NSSound(named: NSSound.Name(soundName))?.play()
    }
    
    @objc func toggleLoginItem(_ sender: NSMenuItem) {
        let enable = sender.state == .off
        toggleLaunchAtLogin(enable)
        sender.state = enable ? .on : .off
    }
    
    @objc func selectSoundRadio(_ sender: NSButton) {
        guard let sound = sender.identifier?.rawValue else { return }
        saveSelectedSound(sound)
        playSoundSelectSound()

        for item in soundMenu.items {
            if let btn = item.view as? NSButton {
                btn.state = (btn == sender) ? .on : .off
            }
        }
    }
    
    @objc func selectSound(_ sender: NSMenuItem) {
        guard let selected = sender.representedObject as? String else { return }
        saveSelectedSound(selected)
        playSoundSelectSound()

        sender.menu?.items.forEach { $0.state = .off }
        sender.state = .on

    }
    
    @objc func openNotificationSettings() {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                NSWorkspace.shared.open(url)
            }
        }

    @objc func dismissAlertManually() {
        countdownTimer?.invalidate()
        dismissActiveAlert()
        startWorkTimer()
    }

    func dismissActiveAlert() {
        activePanel?.orderOut(nil)
        activePanel?.close()
        activePanel = nil
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "EyesOff (20-20-20)"
        alert.informativeText = """
        Version 1.0.0

        \u{1F441} EyesOff reminds you to follow the 20-20-20 rule:
        Every 20 minutes, look at something 20 feet away for 20 seconds.

        \u{1F4CC} Customizable interval. Blurs screen gently.
        \u{1F517} GitHub: github.com/lavisar
        \u{1F9D1}\u{200D}\u{1F4BB} Developed by Lavisar
        """
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
}
