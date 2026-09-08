import Combine
import Foundation
#if canImport(Sparkle)
import Sparkle
#endif

@MainActor
final class GroveUpdater: NSObject, ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var updateAvailable = false

    #if canImport(Sparkle)
    private var controller: SPUStandardUpdaterController?

    #endif

    override init() {
        super.init()
        #if canImport(Sparkle)
        guard !GroveLaunchMode.isHeadless else { return }
        let controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self
        )
        self.controller = controller
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$automaticallyChecksForUpdates)
        #endif
    }

    func checkForUpdates() {
        #if canImport(Sparkle)
        controller?.checkForUpdates(nil)
        #endif
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        #if canImport(Sparkle)
        controller?.updater.automaticallyChecksForUpdates = enabled
        #endif
    }
}

#if canImport(Sparkle)
// Sparkle calls its UI delegate on the main thread; its Objective-C protocol lacks actor annotations.
extension GroveUpdater: @preconcurrency SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        false
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
        updateAvailable = !state.userInitiated
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        updateAvailable = false
    }

    func standardUserDriverWillFinishUpdateSession() {
        updateAvailable = false
    }
}
#endif
