import SwiftUI
import WebKit
import UnixDomainSocket

struct DiscordWindowContent: View {
    @AppStorage("discordReleaseChannel") private var discordReleaseChannel: String = "stable"

    @State var webViewReference: WKWebView?

    var body: some View {
        ZStack(alignment: .topLeading) {
            ZStack {
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)

                WebView(
                    initialURL: DiscordReleaseChannel(rawValue: discordReleaseChannel)?.url ?? DiscordReleaseChannel.stable.url,
                    webViewReference: $webViewReference
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: webViewReference) {
                    Vars.webViewReference = webViewReference
                }
            }

            DraggableView()
                .frame(height: 48)
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    DiscordWindowContent()
}
