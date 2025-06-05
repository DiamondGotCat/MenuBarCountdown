// MenuBarCountdown
// (c) 2025 DiamondGotCat
// MIT License

import AppKit
import Foundation
import Combine
import SwiftUI

class CountdownModel: ObservableObject {
    @Published var timeString: String = "Loading..."
    @AppStorage("fetchURLString") var fetchURLString = "https://diamondgotcat.net/appledate.txt"
    var rawDateString = ""
    
    private var timer: Timer?
    private var targetDate: Date?
    private var url = URL(string: "https://diamondgotcat.net/appledate.txt")!
    
    init() {
        updateURL()
        fetchDate()
        startTimers()
    }
    
    private func updateURL() {
        url = URL(string: fetchURLString)!
    }
    
    private func startTimers() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.001, repeats: true) { _ in
            self.updateTimeString()
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
        
        if interval >= 0 {
            timeString = "↓ \(formatter.string(from: absInterval) ?? "0s")"
        } else {
            timeString = "↑ \(formatter.string(from: absInterval) ?? "0s")"
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

            print("Cleaned date string: '\(dateString)'")

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
            }
        }
        task.resume()
    }
}

struct SettingsView: View {
    @AppStorage("fetchURLString") var fetchURLString: String = "https://diamondgotcat.net/appledate.txt"
    @State var temporaryFetchURLString = ""

    var body: some View {
        VStack {
            Text("Settings")
                .font(.system(size: 32))
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            Text("URL to fetch")
                .font(.system(size: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Please enter an endpoint that returns ISO 8601 formatted date data when accessed.")
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                TextField("URL...", text: $temporaryFetchURLString)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                Button("Update") {
                    fetchURLString = temporaryFetchURLString
                }
            }
        }
        .frame(minWidth: 500, minHeight: 200)
        .padding()
        .onAppear {
            temporaryFetchURLString = fetchURLString
        }
    }
}

class SettingsWindowController: NSWindowController {
    convenience init() {
        let view = SettingsView()
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

    static func showSettingsWindow() {
        if let controller = settingsController {
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            let controller = SettingsWindowController()
            settingsController = controller
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

struct ContentView: View {
    @ObservedObject var model: CountdownModel
    @AppStorage("fetchURLString") var fetchURLString: String = "https://diamondgotcat.net/appledate.txt"
    
    var body: some View {
        VStack {
            Text(model.timeString)
            Text("ISO8601: " + model.rawDateString)
            Divider()
            Text("MenuBarCountdown")
            Button("Refresh Date Infomation") {
                model.fetchDate()
            }
            .onChange(of: fetchURLString, {
                model.fetchDate()
            })
            Button("Settings...") {
                WindowManager.showSettingsWindow()
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
