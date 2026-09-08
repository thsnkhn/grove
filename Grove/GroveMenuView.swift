import AppKit
import SwiftUI

struct GroveMenuView: View {
    @ObservedObject var settings: GroveSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Grove")
                    .font(.headline)

                Spacer(minLength: 0)

                Circle()
                    .fill(settings.enabledServices.isEmpty ? Color.secondary : Color.green)
                    .frame(width: 7, height: 7)
                    .accessibilityLabel(settings.enabledServices.isEmpty ? "MCP disabled" : "MCP enabled")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)

            Divider()

            VStack(spacing: 2) {
                ForEach(GroveService.allCases) { service in
                    Toggle(isOn: binding(for: service)) {
                        Label(service.title, systemImage: service.symbolName)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }

                Toggle(isOn: loginBinding) {
                    Text("Launch at Login")
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .padding(.vertical, 5)

            Divider()

            Button {
                // TODO: Replace the release-page handoff with an appcast-backed updater.
                guard let url = URL(string: "https://github.com/thsnkhn/grove/releases/latest") else { return }
                NSWorkspace.shared.open(url)
            } label: {
                Label("Check for Updates…", systemImage: "sparkles")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit Grove", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .frame(width: 260)
        .padding(.vertical, 5)
    }

    private func binding(for service: GroveService) -> Binding<Bool> {
        Binding(
            get: { settings.isEnabled(service) },
            set: { settings.setEnabled($0, for: service) }
        )
    }

    private var loginBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtLogin },
            set: { settings.setLaunchAtLogin($0) }
        )
    }
}
