import AppKit
import SwiftUI
import WebKit

class SecondaryWindow: NSWindow {
    override func awakeFromNib() {
        super.awakeFromNib()
        positionTrafficLights()
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool, animate animateFlag: Bool) {
        super.setFrame(frameRect, display: flag, animate: animateFlag)
        positionTrafficLights()
    }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        positionTrafficLights()
    }

    override func makeKey() {
        super.makeKey()
        positionTrafficLights()
    }

    override func makeMain() {
        super.makeMain()
        positionTrafficLights()
    }

    private func positionTrafficLights() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.layoutIfNeeded()

            let buttons: [(NSWindow.ButtonType, CGPoint)] = [
                (.closeButton, NSPoint(x: 10, y: -5)),
                (.miniaturizeButton, NSPoint(x: 30, y: -5)),
                (.zoomButton, NSPoint(x: 50, y: -5)),
            ]

            for (buttonType, point) in buttons {
                if let button = self.standardWindowButton(buttonType) {
                    button.isHidden = false
                    button.setFrameOrigin(point)
                }
            }
        }
    }
}

class SecondaryWindowController: NSWindowController {
    convenience init(url: String) {
        let window = SecondaryWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unifiedCompact
        window.backgroundColor = .clear

        window.contentView = NSHostingView(rootView: SecondaryWindowView())

        self.init(window: window)

        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            window.delegate = appDelegate.windowDelegate
        }

        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
    }
}

struct SecondaryWindowView: View {
    var body: some View {
        DiscordWindowContent()
            .frame(minWidth: 200, minHeight: 200)
    }
}
