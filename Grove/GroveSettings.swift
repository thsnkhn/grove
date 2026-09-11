import Combine
import ServiceManagement

@MainActor
final class GroveSettings: ObservableObject {
    @Published private(set) var enabledServices: Set<GroveService>
    @Published private(set) var launchAtLogin: Bool
    @Published private(set) var hasCompletedWelcome: Bool
    @Published private(set) var authorizingServices: Set<GroveService> = []
    @Published var errorMessage: String?

    private let eventKitStore = EventKitStore()

    let isPreview: Bool

    init(previewWelcomeCompleted: Bool? = GroveLaunchMode.isPreview ? true : nil) {
        isPreview = previewWelcomeCompleted != nil
        if let previewWelcomeCompleted {
            enabledServices = [.calendar]
            launchAtLogin = false
            hasCompletedWelcome = previewWelcomeCompleted
            return
        }
        enabledServices = GrovePreferences.enabledServices()
        launchAtLogin = SMAppService.mainApp.status == .enabled
        hasCompletedWelcome = GrovePreferences.hasCompletedWelcome()
    }

    func isEnabled(_ service: GroveService) -> Bool {
        enabledServices.contains(service)
    }

    func setEnabled(_ enabled: Bool, for service: GroveService) {
        if isPreview {
            if enabled { enabledServices.insert(service) } else { enabledServices.remove(service) }
            return
        }
        GrovePreferences.setEnabled(enabled, for: service)
        enabledServices = GrovePreferences.enabledServices()
    }

    func toggle(_ service: GroveService) {
        if isPreview {
            setEnabled(!isEnabled(service), for: service)
            return
        }
        guard !authorizingServices.contains(service) else { return }

        if isEnabled(service) {
            // EventKit grants belong to macOS. Disabling removes this service from Grove's MCP surface.
            setEnabled(false, for: service)
            return
        }

        authorizingServices.insert(service)
        Task {
            do {
                guard try await eventKitStore.authorize(service) else {
                    errorMessage = "Allow \(service.title) access in System Settings to enable it."
                    authorizingServices.remove(service)
                    return
                }
                setEnabled(true, for: service)
            } catch {
                errorMessage = error.localizedDescription
            }
            authorizingServices.remove(service)
        }
    }

    func isAuthorizing(_ service: GroveService) -> Bool {
        authorizingServices.contains(service)
    }

    func completeWelcome() {
        if !isPreview { GrovePreferences.setWelcomeCompleted(true) }
        hasCompletedWelcome = true
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        if isPreview {
            launchAtLogin = enabled
            return
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } catch {
            fputs("Grove: launch-at-login update failed: \(error.localizedDescription)\n", stderr)
        }
    }
}
