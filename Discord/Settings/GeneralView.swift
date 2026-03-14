import SwiftUI

struct GeneralView: View {
    @AppStorage("discordUsesSystemAccent") private var fullSystemAccent: Bool = true
    @AppStorage("discordSidebarDividerUsesSystemAccent") private var sidebarDividerSystemAccent: Bool = true
    @AppStorage("discordReleaseChannel") private var discordReleaseChannel: String = "stable"
    @State private var discordReleaseChannelSelection: DiscordReleaseChannel = .stable

    var body: some View {
        ScrollView {
            Form {
                HStack {
                    Text("Join The Discord")
                    Spacer()
                    Button("Join Discord") {
                        let link = URL(string: "https://discord.gg/Dps8HnDBpw")!
                        Vars.webViewReference?.load(URLRequest(url: link))
                    }
                }

                HStack {
                    Text("Support Us On GitHub")
                    Spacer()
                    Button("Go To Voxa's GitHub") {
                        NSWorkspace.shared.open(URL(string: "https://github.com/plyght/Voxa")!)
                    }
                }

                Toggle(isOn: $fullSystemAccent) {
                    Text("Voxa matches system accent color")
                    Text("Modifying this setting will reload Voxa.")
                        .foregroundStyle(.placeholder)
                }
                .onChange(of: fullSystemAccent) {
                    if let webView = Vars.webViewReference { hardReloadWebView(webView: webView) }
                }

                Toggle(isOn: $sidebarDividerSystemAccent) {
                    Text("Sidebar divider matches system accent color")
                    Text("Modifying this setting will reload Voxa.")
                        .foregroundStyle(.placeholder)
                }
                .onChange(of: sidebarDividerSystemAccent) {
                    if let webView = Vars.webViewReference { hardReloadWebView(webView: webView) }
                }

                Picker(selection: $discordReleaseChannelSelection, content: {
                    ForEach(DiscordReleaseChannel.allCases, id: \.self) {
                        Text($0.description)
                    }
                }, label: {
                    Text("Discord Release Channel")
                    Text("Modifying this setting will reload Voxa.")
                        .foregroundStyle(.placeholder)
                })
                .onChange(of: discordReleaseChannelSelection) {
                    discordReleaseChannel = discordReleaseChannelSelection.rawValue
                    if let webView = Vars.webViewReference { hardReloadWebView(webView: webView) }
                }
            }
            .formStyle(.grouped)
        }
        .onAppear {
            discordReleaseChannelSelection = DiscordReleaseChannel(rawValue: discordReleaseChannel) ?? .stable
        }
    }
}

#Preview {
    GeneralView()
}
