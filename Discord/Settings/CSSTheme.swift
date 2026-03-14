import Foundation

struct CSSTheme: Identifiable, Equatable {
    static func == (lhs: CSSTheme, rhs: CSSTheme) -> Bool {
        lhs.fileURL == rhs.fileURL
    }

    var id: URL { fileURL }
    var name: String
    var contents: String
    var fileURL: URL
}

var availableThemes: [CSSTheme] {
    guard let resources = Bundle.main.resourceURL else { return [] }

    let resourceContents = (try? FileManager.default.contentsOfDirectory(atPath: resources.path)) ?? []

    return resourceContents.compactMap { file -> CSSTheme? in
        guard file.hasSuffix(".css") else { return nil }

        let fileURL = resources.appending(path: file)

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir),
              !isDir.boolValue else { return nil }

        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }

        let name = String(file.dropLast(4))
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")

        return CSSTheme(name: name, contents: contents, fileURL: fileURL)
    }
    .sorted { $0.name < $1.name }
}
