import SwiftUI
import WebKit
import UniformTypeIdentifiers

struct CustomCSSView: View {
    @AppStorage("customCSS") private var customCSS: String = ""

    @State private var themes: [CSSTheme] = []
    @State private var selectedThemeID: URL? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Picker("Preset", selection: $selectedThemeID) {
                    Text("None").tag(Optional<URL>.none)
                    if !themes.isEmpty {
                        Divider()
                        ForEach(themes) { theme in
                            Text(theme.name).tag(Optional(theme.fileURL))
                        }
                    }
                }
                .frame(maxWidth: 200)
                .onChange(of: selectedThemeID) {
                    guard let id = selectedThemeID,
                          let theme = themes.first(where: { $0.fileURL == id }) else { return }
                    customCSS = theme.contents
                    applyCSS()
                }

                Spacer()

                Button("Import…", action: importFromFile)
                Button("Export…", action: exportToFile)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            TextEditor(text: $customCSS)
                .font(.system(.body, design: .monospaced))
                .onChange(of: customCSS) {
                    applyCSS()
                }
        }
        .onAppear {
            themes = availableThemes
            if customCSS.isEmpty,
               let tahoe = themes.first(where: { $0.fileURL.deletingPathExtension().lastPathComponent == "tahoe" }) {
                selectedThemeID = tahoe.fileURL
                customCSS = tahoe.contents
                applyCSS()
            } else {
                selectedThemeID = themes.first(where: { $0.contents == customCSS })?.fileURL
            }
        }
    }

    private func applyCSS() {
        guard let webView = Vars.webViewReference,
              let jsonData = try? JSONEncoder().encode(customCSS),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        webView.evaluateJavaScript(
            "document.getElementById('voxaCustomStyle').textContent = \(jsonString);"
        )
    }

    private func importFromFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "css") ?? .plainText]
        panel.title = "Import CSS File"

        guard panel.runModal() == .OK,
              let url = panel.url,
              let contents = try? String(contentsOf: url, encoding: .utf8) else { return }

        customCSS = contents
        selectedThemeID = nil
        applyCSS()
    }

    private func exportToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "css") ?? .plainText]
        panel.nameFieldStringValue = "custom.css"
        panel.title = "Export CSS File"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? customCSS.write(to: url, atomically: true, encoding: .utf8)
    }
}
