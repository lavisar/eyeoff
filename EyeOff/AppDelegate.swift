import Cocoa
import UserNotifications
import ServiceManagement


class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var workTimer: Timer?
    var countdownTimer: Timer?
    var remainingSeconds = 20
    var currentInterval: TimeInterval = 20 // 20 minutes
    
    var isBreakAlertRunning = false
    
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
                self.startWorkTimer() // Restart 20 minutes
            }
        }
    }

    func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = "EyesOff Reminder"
        content.body = "Take a 20-second eye break! Look 20 feet away."

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    func showBreakAlert() {
        if isBreakAlertRunning {
            return
        }
        
        isBreakAlertRunning = true
        
        let alert = NSAlert()
        alert.messageText = "👁️ EyesOff Break Time!"
        alert.informativeText = """
        🧘 Time to rest your eyes!

        ⏳ Look 20 feet away for 20 seconds.
        💡 Blink slowly. Breathe deeply.
        """
        alert.alertStyle = .informational
        

        alert.addButton(withTitle: "Got it!")
        
        //? Cancel any previous scheduled alerts
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(showAlertModal(_:)), object: nil)
        
        self.perform(#selector(showAlertModal(_:)), with: alert, afterDelay: 0.1)
    }


    @objc func showAlertModal(_ alert: NSAlert) {
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            isBreakAlertRunning = false
        }
    }

    func playAlertSound() {
        let currentSound = getSelectedSound()
        NSSound(named: NSSound.Name(currentSound))?.play()
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
        startWorkTimer()
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "EyesOff (20-20-20)"
        alert.informativeText = """
        Version 1.0.0

        \u{1F441} EyesOff reminds you to follow the 20-20-20 rule:
        Every 20 minutes, look at something 20 feet away for 20 seconds.

        \u{1F517} GitHub: github.com/lavisar/eyeoff
        \u{1F9D1}\u{200D}\u{1F4BB} Developed by Lavisar
        """
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
}
