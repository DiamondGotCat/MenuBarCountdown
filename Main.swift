// MenuBarCountdown
// (c) 2025 DiamondGotCat
// MIT License

import SwiftUI
import AppKit
import Foundation
import Combine
import ServiceManagement
import UserNotifications

class CountdownModel: ObservableObject {
    @Published var timeString: String = "Loading..."
    @AppStorage("fetchURLString") var fetchURLString = "https://diamondgotcat.net/appledate.txt"
    @AppStorage("fetchSeconds") var fetchSeconds = "60"
    @Published var enableNotification: Bool

    private let notificationID = "CountdownFinished"
    private let testNotificationID = "CountdownTest"
    var rawDateString = ""

    private var timer: Timer?
    private var fetchTimer: Timer?
    private var targetDate: Date?
    private var url = URL(string: "https://diamondgotcat.net/appledate.txt")!

    init() {
        self.enableNotification = UserDefaults.standard.bool(forKey: "enableNotification")
        updateURL()
        fetchDate()
        startTimers()
    }

    func toggleEnableNotification(_ newValue: Bool) {
        enableNotification = newValue
        UserDefaults.standard.set(newValue, forKey: "enableNotification")

        if enableNotification {
            scheduleNotification()
            scheduleTestNotification()
        } else {
            cancelNotification()
        }
    }

    private func scheduleNotification() {
        guard enableNotification, let target = targetDate else { return }

        let center = UNUserNotificationCenter.current()

        func registerRequest() {
            center.removePendingNotificationRequests(withIdentifiers: [notificationID])

            let content = UNMutableNotificationContent()
            content.title = "Time's up!"
            content.body = "Countdown Finsihed."
            content.sound = .default

            let interval = max(target.timeIntervalSinceNow, 1)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)

            let req = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
            center.add(req)
        }

        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized:
                registerRequest()
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { ok, _ in
                    if ok { registerRequest() }
                }
            default:
                break
            }
        }
    }

    func scheduleTestNotification() {
        guard enableNotification else { return }

        let center = UNUserNotificationCenter.current()

        func registerRequest() {
            center.removePendingNotificationRequests(withIdentifiers: [testNotificationID])

            let content = UNMutableNotificationContent()
            content.title = "Hello?"
            content.body = "This is Test Notification."
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

            let req = UNNotificationRequest(identifier: testNotificationID, content: content, trigger: trigger)
            center.add(req)
        }

        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized:
                registerRequest()
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { ok, _ in
                    if ok { registerRequest() }
                }
            default:
                break
            }
        }
    }

    func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
    }

    private func updateURL() {
        if let newurl = URL(string: fetchURLString.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? fetchURLString) {
            url = newurl
        } else {
            print("Invalid URL: \(fetchURLString)")
        }
    }

    private func startTimers() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateTimeString()
        }
        fetchTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(Double(fetchSeconds)!), repeats: true) { _ in
            self.fetchDate()
        }
    }

    private func updateTimeString() {
        guard let target = targetDate else {
            timeString = "Not Available"
            return
        }

        let now = Date()
        let interval = target.timeIntervalSince(now)
        let absInterval = abs(interval)

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .abbreviated

        if interval > 0 {
            timeString = "↓ \(formatter.string(from: absInterval) ?? "Error")"
        } else if interval < 0 {
            timeString = "↑ \(formatter.string(from: absInterval) ?? "Error")"
        } else if interval == 0 {
            timeString = "= now"
        }
    }

    func fetchDate() {
        updateURL()

        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            guard error == nil, let data = data,
                  var dateString = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    self.timeString = "Failed to Fetch Date"
                }
                return
            }

            dateString = dateString
                .components(separatedBy: .newlines).joined()
                .components(separatedBy: .controlCharacters).joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)

            self.rawDateString = dateString

            print("Fetched: '\(dateString)'")

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]

            guard let date = formatter.date(from: dateString) else {
                DispatchQueue.main.async {
                    self.timeString = "Failed to Parse Date"
                }
                print("Failed to parse cleaned date string")
                return
            }

            DispatchQueue.main.async {
                self.targetDate = date
                self.updateTimeString()

                if self.enableNotification {
                    self.scheduleNotification()
                } else {
                    self.cancelNotification()
                }
            }
        }
        task.resume()
    }
}

struct NumericTextField: NSViewRepresentable {
    @Binding var value: String

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NumericTextField

        init(_ parent: NumericTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }

            let filtered = textField.stringValue.filter { $0.isNumber || $0 == "." }

            let dotCount = filtered.filter { $0 == "." }.count
            var validString = filtered
            if dotCount > 1 {
                var firstDotFound = false
                validString = filtered.reduce(into: "") { result, char in
                    if char == "." {
                        if !firstDotFound {
                            result.append(char)
                            firstDotFound = true
                        }
                    } else {
                        result.append(char)
                    }
                }
            }

            textField.stringValue = validString
            parent.value = validString
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.stringValue = value
        textField.focusRingType = .none
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != value {
            nsView.stringValue = value
        }
    }
}

struct SettingsView: View {
    @AppStorage("fetchURLString") var fetchURLString: String = "https://diamondgotcat.net/appledate.txt"
    @State var temporaryFetchURLString = ""
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("fetchSeconds") var fetchSeconds: String = "60"
    @ObservedObject var model: CountdownModel

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if #available(macOS 13.0, *) {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } else {
                NSLog("Launch at login is only supported on macOS 13.0 or later.")
            }
        } catch {
            NSLog("Failed to change launch at login state: \(error)")
        }
    }

    var body: some View {
        VStack {
            Text("Settings")
                .font(.system(size: 32))
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack {
                Text("URL to fetch")
                    .font(.system(size: 16))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Please enter an endpoint that returns ISO 8601 formatted date data when accessed.")
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    TextField("URL", text: $temporaryFetchURLString)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Update") {
                        fetchURLString = temporaryFetchURLString
                    }
                }
            }.padding()

            Divider()

            VStack {
                Text("Data acquisition interval")
                    .font(.system(size: 16))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("This application must be restarted to take effect.")
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)
                NumericTextField(value: $fetchSeconds)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.padding()

            Divider()

            VStack {
                Text("Launch at login")
                    .font(.system(size: 16))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("macOS 13+ only.")
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Toggle("Enable", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) {
                        setLaunchAtLogin(launchAtLogin)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.padding()

            Divider()

            VStack {
                Text("Notfication")
                    .font(.system(size: 16))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("When this option is turned on, you will be notified when the countdown ends and the time is up.")
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Toggle("Enable", isOn: Binding(
                        get: { model.enableNotification },
                        set: { model.toggleEnableNotification($0) }
                    ))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Test") {
                        model.scheduleTestNotification()
                    }
                }
            }.padding()

            Spacer()
        }
        .frame(minWidth: 500, minHeight: 500)
        .padding()
        .onAppear {
            temporaryFetchURLString = fetchURLString
        }
    }
}

class SettingsWindowController: NSWindowController {
    convenience init(model: CountdownModel) {
        let view = SettingsView(model: model)
        let hostingController = NSHostingController(rootView: view)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 180),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        window.contentView = hostingController.view
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }
}

class WindowManager {
    private static var settingsController: SettingsWindowController?

    static func showSettingsWindow(model: CountdownModel) {
        if let controller = settingsController {
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            let controller = SettingsWindowController(model: model)
            settingsController = controller
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

struct ContentView: View {
    @ObservedObject var model: CountdownModel

    var body: some View {
        VStack {
            Text(model.timeString)
            Text("ISO8601: " + model.rawDateString)
            Divider()
            Text("MenuBarCountdown")
            Button("Refresh Date Information") {
                model.fetchDate()
            }
            .onChange(of: model.fetchURLString) {
                model.fetchDate()
            }
            Button("Settings...") {
                WindowManager.showSettingsWindow(model: model)
            }
            Button("Quit") {
                exit(0)
            }
        }
        .frame(width: 200)
    }
}

@main
struct CountdownMenuApp: App {
    @StateObject private var model = CountdownModel()

    var body: some Scene {
        MenuBarExtra {
            ContentView(model: model)
        } label: {
            Text(model.timeString)
        }
        .menuBarExtraStyle(.menu)
    }
}
