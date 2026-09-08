import AppKit
import Darwin
import SwiftUI

enum GroveLaunchMode {
    static var argument: String? {
        CommandLine.arguments.dropFirst().first
    }

    static var isHeadless: Bool {
        argument != nil
    }
}

@MainActor
final class GroveAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if GroveLaunchMode.isHeadless {
            NSApp.setActivationPolicy(.prohibited)
            Task { await runHeadlessCommand() }
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        GroveProcessRegistry.terminateServers()
        return .terminateNow
    }

    private func runHeadlessCommand() async {
        do {
            switch GroveLaunchMode.argument {
            case "--mcp":
                let store = EventKitStore()
                let services = GrovePreferences.enabledServices()
                try await GroveServer(store: store, enabledServices: services).run()
            case "authorize":
                print(try await EventKitStore().authorize())
            case "doctor":
                print(EventKitStore().doctor())
            case "--help", "-h":
                printHelp()
            case "--version", "-v":
                print(Grove.version)
            default:
                throw GroveError.invalidArgument("Unknown command. Run `Grove --help` for usage.")
            }
        } catch {
            FileHandle.standardError.write(Data("Grove: \(error.localizedDescription)\n".utf8))
            Darwin.exit(1)
        }

        NSApp.terminate(nil)
    }

    private func printHelp() {
        print("""
        Grove \(Grove.version)

        Native Mac tools for AI assistants.

        Usage:
          Grove                 Open the Grove menu bar app.
          Grove --mcp           Start the MCP server over stdio.
          Grove authorize       Request Calendar and Reminders access.
          Grove doctor          Show local permission and runtime status.
          Grove --help          Show this help.
          Grove --version       Show the version.
        """)
    }
}

@main
struct GroveApp: App {
    @NSApplicationDelegateAdaptor(GroveAppDelegate.self) private var appDelegate
    @StateObject private var settings = GroveSettings()

    var body: some Scene {
        MenuBarExtra("Grove", systemImage: "tree.fill") {
            GroveMenuView(settings: settings)
        }
        .menuBarExtraStyle(.window)
    }
}

enum Grove {
    static let version = "0.1.0"
}
