import SwiftUI
import WebKit

struct PluginsView: View {
    @State private var plugins: [Plugin] = []
    @State private var active: [Plugin] = []
    @State private var pluginsChanged: Bool = false

    var body: some View {
        Form {
            ForEach(plugins) { plugin in
                PluginListItem(
                    plugin: plugin,
                    active: $active,
                    pluginsChanged: $pluginsChanged
                )
            }
        }
        .formStyle(.grouped)
        .onAppear {
            plugins = availablePlugins
            active = activePlugins
        }

        if pluginsChanged {
            Form {
                HStack {
                    Text("Refresh Voxa to Apply Changes")
                    Spacer()
                    Button("Refresh") {
                        if let webView = Vars.webViewReference { hardReloadWebView(webView: webView) }
                        withAnimation { pluginsChanged = false }
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}

struct PluginListItem: View {
    let plugin: Plugin
    @Binding var active: [Plugin]
    @Binding var pluginsChanged: Bool

    var body: some View {
        Toggle(
            isOn: Binding(
                get: { active.contains(plugin) },
                set: { isActive in
                    if isActive {
                        active.append(plugin)
                    } else {
                        active.removeAll(where: { $0 == plugin })
                    }
                    activePlugins = active
                    withAnimation { pluginsChanged = true }
                }
            )
        ) {
            Section {
                HStack {
                    Text(plugin.name)
                        .foregroundStyle(.primary)

                    if let url = plugin.url {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Image(systemName: "globe")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } footer: {
                Text(plugin.author)
                    .foregroundStyle(.secondary)
                Text(plugin.description)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

#Preview {
    PluginsView()
}
