import AppKit
import SwiftUI

struct GroveMenuView: View {
    @ObservedObject var settings: GroveSettings
    @ObservedObject var updater: GroveUpdater
    @ObservedObject var agentManager: GroveAgentManager
    @State private var showsDetails = false
    @State private var hasAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsHeader

            if showsDetails {
                detailContent
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if settings.hasCompletedWelcome {
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

    private var settingsHeader: some View {
        Button {
            guard settings.hasCompletedWelcome else { return }
            withAnimation(.snappy(duration: 0.25, extraBounce: 0)) {
                showsDetails.toggle()
            }
            if showsDetails {
                agentManager.refresh()
            }
        } label: {
            HStack {
                Text("Grove")
                    .font(.system(size: 15, weight: .semibold))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(showsDetails ? 90 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(showsDetails ? "Hide Grove options" : "Show Grove options")
        .accessibilityLabel("Grove options")
        .accessibilityValue(
            settings.hasCompletedWelcome
                ? (showsDetails ? "Expanded" : "Collapsed")
                : "Setup required"
        )
    }

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroveAgentSetupView(agentManager: agentManager) {
                settings.completeWelcome()
                withAnimation(.snappy(duration: 0.25, extraBounce: 0)) {
                    showsDetails = false
                }
            }

            if settings.hasCompletedWelcome {
                Divider()
                    .opacity(0.65)

                options
            }
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
                    .font(.system(size: 14))
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
                NSApplication.shared.terminate(nil)
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
                    .font(.system(size: 14))
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
        showsDetails = !settings.hasCompletedWelcome
        agentManager.refresh()
    }
}

private struct GroveAgentSetupView: View {
    @ObservedObject var agentManager: GroveAgentManager
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to Grove")
                    .font(.system(size: 15, weight: .semibold))

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

            HStack {
                Spacer()
                Button("Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
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
                            ? Color(red: 0.96, green: 0.96, blue: 0.97)
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
