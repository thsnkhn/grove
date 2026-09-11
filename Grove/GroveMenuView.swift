import AppKit
import SwiftUI

struct GroveMenuView: View {
    @ObservedObject var settings: GroveSettings
    @ObservedObject var updater: GroveUpdater
    @ObservedObject var agentManager: GroveAgentManager
    @State private var showsSettings = false
    @State private var hasAppeared = false

    init(
        settings: GroveSettings,
        updater: GroveUpdater,
        agentManager: GroveAgentManager,
        showsSettings: Bool = false
    ) {
        self.settings = settings
        self.updater = updater
        self.agentManager = agentManager
        _showsSettings = State(initialValue: showsSettings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !settings.hasCompletedWelcome {
                GroveAgentSetupView(agentManager: agentManager, isWelcome: true) {
                    settings.completeWelcome()
                    showsSettings = false
                }
            } else if showsSettings {
                settingsHeader
                GroveAgentSetupView(agentManager: agentManager, isWelcome: false)
                Divider()
                options
            } else {
                mainHeader
                serviceList
            }
        }
        .padding(16)
        .frame(width: 304)
        .onAppear(perform: load)
        .alert(
            "Grove",
            isPresented: Binding(
                get: { agentManager.errorMessage != nil || settings.errorMessage != nil },
                set: {
                    if !$0 {
                        agentManager.errorMessage = nil
                        settings.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                agentManager.errorMessage = nil
                settings.errorMessage = nil
            }
        } message: {
            Text(agentManager.errorMessage ?? settings.errorMessage ?? "Try again.")
        }
    }

    private var mainHeader: some View {
        HStack {
            Text("Grove")
                .font(.system(size: 15, weight: .semibold))

            Spacer()

            Button {
                showsSettings = true
                agentManager.refresh()
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Settings")
            .accessibilityLabel("Settings")
        }
    }

    private var settingsHeader: some View {
        HStack(spacing: 8) {
            Button {
                showsSettings = false
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Back to Grove")
            .accessibilityLabel("Back to Grove")

            Text("Settings")
                .font(.system(size: 15, weight: .semibold))

            Spacer()
        }
    }

    private var serviceList: some View {
        LazyVStack(spacing: 0) {
            ForEach(GroveService.allCases) { service in
                let isEnabled = settings.isEnabled(service)
                ServiceRow(
                    title: service.title,
                    symbolName: isEnabled
                        ? service.filledSymbolName
                        : service.outlineSymbolName,
                    status: settings.isAuthorizing(service) ? "…" : (isEnabled ? "On" : "Off"),
                    color: color(for: service),
                    isEnabled: isEnabled
                ) {
                    settings.toggle(service)
                }
            }

            ForEach(ComingSoonTool.all) { tool in
                ServiceRow(
                    title: tool.title,
                    symbolName: tool.symbolName,
                    status: "Soon",
                    color: .secondary,
                    isEnabled: false,
                    action: nil
                )
            }
        }
    }

    private var options: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Launch at Login")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Toggle("", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .accessibilityLabel("Launch at Login")
            }
            .frame(height: 32)

            Divider()
                .opacity(0.65)

            #if canImport(Sparkle)
            optionButton(updater.updateAvailable ? "Update Available…" : "Check for Updates…") {
                updater.checkForUpdates()
            }
            .disabled(!updater.canCheckForUpdates)
            #endif

            Divider()
                .opacity(0.65)

            optionButton("Quit Grove", role: .destructive) {
                if !settings.isPreview { NSApplication.shared.terminate(nil) }
            }
        }
    }

    private func optionButton(
        _ title: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func color(for service: GroveService) -> Color {
        switch service {
        case .calendar: return Color(nsColor: .systemRed)
        case .reminders: return Color(nsColor: .systemBlue)
        }
    }

    private func load() {
        guard !hasAppeared else { return }
        hasAppeared = true
        agentManager.refresh()
    }
}

private struct GroveAgentSetupView: View {
    @ObservedObject var agentManager: GroveAgentManager
    let isWelcome: Bool
    var onContinue: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: isWelcome ? 4 : 0) {
                if isWelcome {
                    Text("Welcome to Grove")
                        .font(.system(size: 15, weight: .semibold))
                }

                Text("Connect Grove to an installed agent.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            if agentManager.agents.isEmpty {
                Text("No supported agents found. See the README for manual setup.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 8) {
                    ForEach(agentManager.agents) { agent in
                        GroveAgentRow(agent: agent, agentManager: agentManager)
                    }
                }
            }

            if isWelcome, let onContinue {
                HStack {
                    Spacer()
                    if #available(macOS 26.0, *) {
                        Button("Continue", action: onContinue)
                            .buttonStyle(.glassProminent)
                            .controlSize(.small)
                    } else {
                        Button("Continue", action: onContinue)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }
            }
        }
    }
}

private struct GroveAgentRow: View {
    let agent: GroveAgent
    @ObservedObject var agentManager: GroveAgentManager

    var body: some View {
        HStack(spacing: 8) {
            Text(agent.title)
                .font(.system(size: 13))

            Spacer(minLength: 8)

            if agent.supportsMCPCommands {
                Button(agent.mcpInstalled ? "Uninstall" : "Install") {
                    agentManager.toggleMCP(for: agent)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(agentManager.isBusy(agent))
            } else {
                Button("README") {
                    agentManager.openREADME(for: agent)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

private struct ServiceRow: View {
    let title: String
    let symbolName: String
    let status: String
    let color: Color
    let isEnabled: Bool
    let action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isEnabled
                            ? Color(nsColor: .controlBackgroundColor)
                            : Color(nsColor: .tertiarySystemFill))

                    Image(systemName: symbolName)
                        .font(.system(size: 14, weight: .medium))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(isEnabled ? color : Color(nsColor: .secondaryLabelColor))
                }
                .frame(width: 26, height: 26)

                Text(title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(action == nil
                        ? Color(nsColor: .tertiaryLabelColor)
                        : .primary)

                Spacer(minLength: 8)

                Text(status)
                    .font(.system(size: 12))
                    .foregroundStyle(action == nil
                        ? Color(nsColor: .tertiaryLabelColor)
                        : .secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityLabel("\(title), \(status)")
    }
}

private struct ComingSoonTool: Identifiable {
    let title: String
    let symbolName: String

    var id: String { title }

    static let all = [
        ComingSoonTool(title: "Mail", symbolName: "envelope"),
        ComingSoonTool(title: "Notes", symbolName: "note.text"),
        ComingSoonTool(title: "Messages", symbolName: "message"),
        ComingSoonTool(title: "Contacts", symbolName: "person.2")
    ]
}

#if DEBUG
private struct GroveMenuPreview: View {
    @StateObject private var settings: GroveSettings
    @StateObject private var updater = GroveUpdater(isPreview: true)
    @StateObject private var agentManager = GroveAgentManager(isPreview: true)
    let showsSettings: Bool

    init(welcome: Bool = false, showsSettings: Bool = false) {
        _settings = StateObject(wrappedValue: GroveSettings(previewWelcomeCompleted: !welcome))
        self.showsSettings = showsSettings
    }

    var body: some View {
        GroveMenuView(
            settings: settings,
            updater: updater,
            agentManager: agentManager,
            showsSettings: showsSettings
        )
        .background(.regularMaterial)
    }
}

#Preview("Welcome", traits: .fixedLayout(width: 304, height: 300)) {
    GroveMenuPreview(welcome: true)
}

#Preview("Main", traits: .fixedLayout(width: 304, height: 260)) {
    GroveMenuPreview()
}

#Preview("Settings", traits: .fixedLayout(width: 304, height: 410)) {
    GroveMenuPreview(showsSettings: true)
}

#Preview("Main — Dark", traits: .fixedLayout(width: 304, height: 260)) {
    GroveMenuPreview().preferredColorScheme(.dark)
}
#endif
