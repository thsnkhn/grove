import Combine
import ServiceManagement

@MainActor
final class GroveSettings: ObservableObject {
    @Published private(set) var enabledServices: Set<GroveService>
    @Published private(set) var launchAtLogin: Bool

    init() {
        enabledServices = GrovePreferences.enabledServices()
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func isEnabled(_ service: GroveService) -> Bool {
        enabledServices.contains(service)
    }

    func setEnabled(_ enabled: Bool, for service: GroveService) {
        GrovePreferences.setEnabled(enabled, for: service)
        enabledServices = GrovePreferences.enabledServices()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
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
