import SwiftUI
import DiscordRPCBridge
import Foundation
import UserNotifications
import OSLog
@preconcurrency import WebKit

// MARK: - Constants

/// CSS for accent color customization
var hexAccentColor: String? {
    if let accentColor = NSColor.controlAccentColor.usingColorSpace(.sRGB) {
        let red = Int(accentColor.redComponent * 255)
        let green = Int(accentColor.greenComponent * 255)
        let blue = Int(accentColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    return nil
}

/// Non-dynamic default CSS applied to the webview.
let rootCSS = """
:root {
    --background-accent: rgba(0, 0, 0, 0.5) !important;
    --background-floating: transparent !important;
    --background-message-highlight: transparent !important;
    --background-message-highlight-hover: transparent !important;
    --background-message-hover: transparent !important;
    --background-mobile-primary: transparent !important;
    --background-mobile-secondary: transparent !important;
    --background-modifier-accent: transparent !important;
    --background-modifier-active: transparent !important;
    --background-modifier-hover: transparent !important;
    --background-modifier-selected: transparent !important;
    --background-nested-floating: transparent !important;
    --background-primary: transparent !important;
    --background-secondary: transparent !important;
    --background-secondary-alt: transparent !important;
    --background-tertiary: transparent !important;
    --bg-overlay-3: transparent !important;
    --channeltextarea-background: transparent !important;
}
"""

struct SuffixedCSSStyle: Codable {
    let prefix: String
    let styles: [String: String]
}

/// CSS Styles that are sent to a script to automatically be suffixed and updated dynamically.
/// You may explicitly add suffixes if necessary (e.g. if there are multiple objects that share the same prefix)
var suffixedCSSStyles: [String: [String: String]] = [
    "guilds": [
        "margin-top": "48px"
    ],
    "scroller": [
        "padding-top": "0",
        "mask-image": "linear-gradient(to bottom, black calc(100% - 36px), transparent 100%)",
    ],
    "themed_fc4f04": [
        "background-color": "transparent"
    ],
    "themed__9293f": [
        "background-color": "transparent"
    ],
    "button_df39bd": [
        "background-color": "rgba(0, 0, 0, 0.15)"
    ],
    "chatContent": [
        "background-color": "transparent",
        "background": "transparent"
    ],
    "chat": [
        "background": "transparent"
    ],
    "quickswitcher": [
        "background-color": "transparent",
        "-webkit-backdrop-filter": "blur(5px)"
    ],
    "content": [
        "background": "none"
    ],
    "container": [
        "background-color": "transparent"
    ],
    "mainCard": [
        "background-color": "rgba(0, 0, 0, 0.15)"
    ],
    "listItem_c96c45:has(div[aria-label='Download Apps'])": [
        "display": "none"
    ],
    "children_fc4f04:after": [
        "background": "0",
        "width": "0"
    ],
    "expandedFolderBackground": [
        "background": "var(--activity-card-background)"
    ],
    "folder": [
        "background": "var(--activity-card-background)"
    ],
    "floating": [
        "background": "var(--activity-card-background)"
    ],
    "content_f75fb0:before": [
        "display": "none"
    ],
    "outer": [
        "background-color": "transparent"
    ]
]

// MARK: - Plugin and CSS Loader

/// Loads all scripts, plugins, and CSS into the provided WebView.
/// Called on initial setup and after every hard reload.
func loadPluginsAndCSS(webView: WKWebView) {
    let fullSystemAccent = UserDefaults.standard.object(forKey: "discordUsesSystemAccent") as? Bool ?? true
    let sidebarDividerSystemAccent = UserDefaults.standard.object(forKey: "discordSidebarDividerUsesSystemAccent") as? Bool ?? true

    let dynamicRootCSS = """
    /* CSS variables that require reinitialisation on view reload */
    \({
        guard let accent = hexAccentColor,
            fullSystemAccent == true else {
            return ""
        }

        return """
        :root {
        /* brand */
            --bg-brand: \(accent) !important;
            \({ () -> String in
                var values = [String]()
                for i in stride(from: 5, through: 95, by: 5) {
                    let hexAlpha = String(format: "%02X", Int(round((Double(i) / 100.0) * 255)))
                    values.append("--brand-\(String(format: "%02d", i))a: \(accent)\(hexAlpha);")
                }
                return values.joined(separator: "\n")
            }())
            --brand-260: \(accent)1A !important;
            --brand-500: \(accent) !important;
            --brand-560: \(accent)26 !important; /* filled button hover */
            --brand-600: \(accent)30 !important; /* filled button clicked */

        /* foregrounds */
            --mention-foreground: \(accent) !important;
            --mention-background: \(accent)26 !important;
            --control-brand-foreground: \(accent)32 !important;
            --control-brand-foreground-new: \(accent)30 !important;
        }
        """
    }())
    """

    // Build local style map with the dynamic guildSeparator entry — avoid mutating global
    var localStyles = suffixedCSSStyles
    localStyles["guildSeparator"] = [
        "background-color": {
            guard let accent = hexAccentColor,
                  sidebarDividerSystemAccent == true else {
                return """
                color-mix(/* --background-modifier-accent */
                    in oklab,
                    hsl(var(--primary-500-hsl) / 0.48) 100%,
                    hsl(var(--theme-base-color-hsl, 0 0% 0%) / 0.48) var(--theme-base-color-amount, 0%)
                )
                """
            }

            return accent
        }()]

    // Inject default CSS
    webView.configuration.userContentController.addUserScript(
        WKUserScript(
            source: """
            const defaultStyle = document.createElement('style');
            defaultStyle.id = 'voxaStyle';
            defaultStyle.textContent = `\(rootCSS + "\n\n" + dynamicRootCSS)`;
            document.head.appendChild(defaultStyle);

            const customStyle = document.createElement('style');
            customStyle.id = 'voxaCustomStyle';
            customStyle.textContent = "";
            document.head.appendChild(customStyle);
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
    )

    let prefixStyles = localStyles.map { SuffixedCSSStyle(prefix: $0.key, styles: $0.value) }

    guard let styleData: Data = {
        do {
            return try JSONEncoder().encode(prefixStyles)
        } catch {
            print("Error encoding CSS styles to JSON: \(error)")
            return nil
        }
    }(), let styles = String(data: styleData, encoding: .utf8) else {
        print("Error converting style data to JSON string")
        return
    }

    webView.configuration.userContentController.addUserScript(
        WKUserScript(
            source: """
            (function() {
              const prefixes = \(styles);
              if (!prefixes.length) {
                console.log("No prefixes provided.");
                return;
              }

              // Each prefix maps to a Set of matching classes
              const classSets = prefixes.map(() => new Set());

              function processElementClasses(element) {
                element.classList.forEach(cls => {
                  prefixes.forEach((prefixConfig, index) => {
                    const { prefix, styles } = prefixConfig;
                    if (cls.startsWith(prefix + '_') || cls === prefix) {
                      classSets[index].add(cls);
                      applyImportantStyles(element, styles);
                    }
                  });
                });
              }

              function applyImportantStyles(element, styles) {
                for (const [prop, val] of Object.entries(styles)) {
                  element.style.setProperty(prop, val, 'important');
                }
              }

              function buildPrefixCSS(prefixConfigs) {
                let cssOutput = '';
                for (const { prefix, styles } of prefixConfigs) {
                  const hasSpace = prefix.includes(' ');
                  const placeholder = hasSpace ? prefix : `${prefix}_placeholder`;
                  cssOutput += `.${placeholder} {\n`;
                  for (const [prop, val] of Object.entries(styles)) {
                    cssOutput += `  ${prop}: ${val} !important;\n`;
                  }
                  cssOutput += `}\n\n`;
                }
                return cssOutput;
              }

              // Initial pass over all elements
              document.querySelectorAll('*').forEach(processElementClasses);

              // Monitor DOM changes
              const observer = new MutationObserver(mutations => {
                mutations.forEach(mutation => {
                  if (mutation.type === 'childList') {
                    mutation.addedNodes.forEach(node => {
                      if (node.nodeType === Node.ELEMENT_NODE) {
                        processElementClasses(node);
                        node.querySelectorAll('*').forEach(processElementClasses);
                      }
                    });
                  } else if (mutation.type === 'attributes' && mutation.attributeName === 'class') {
                    processElementClasses(mutation.target);
                  }
                });
              });

              observer.observe(document.body, { childList: true, attributes: true, subtree: true });

              // Expose CSS viewer for debugging
              window.showParsedCSS = () => console.log(`Generated CSS from JSON:\n${buildPrefixCSS(prefixes)}`);
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
    )

    // Channel Click Handler Script
    webView.configuration.userContentController.addUserScript(
        WKUserScript(
            source: """
            (function () {
                document.addEventListener('click', function(e) {
                    const channel = e.target.closest('.blobContainer_a5ad63');
                    if (channel) {
                        window.webkit.messageHandlers.channelClick.postMessage({type: 'channel'});
                        return;
                    }

                    const link = e.target.closest('.link_c91bad');
                    if (link) {
                        e.preventDefault();
                        let href = link.getAttribute('href') || link.href || '/channels/@me';
                        if (href.startsWith('/')) {
                            href = 'https://discord.com' + href;
                        }
                        window.webkit.messageHandlers.channelClick.postMessage({type: 'user', url: href});
                        return;
                    }

                    const serverIcon = e.target.closest('.wrapper_f90abb');
                    if (serverIcon) {
                        window.webkit.messageHandlers.channelClick.postMessage({type: 'server'});
                    }
                });
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
    )

    // Notification Handling Script
    webView.configuration.userContentController.addUserScript(
        WKUserScript(
            source: """
            (function () {
                const Original = window.Notification;
                let perm = "default";
                const map = new Map();

                Object.defineProperty(Notification, "permission", {
                    get: () => perm,
                    configurable: true,
                });

                class OxvaNotification extends Original {
                    constructor(title, options = {}) {
                        const id = crypto.randomUUID().toUpperCase();
                        super(title, options);
                        this.notificationId = id;
                        map.set(id, this);
                        window.webkit?.messageHandlers?.notify?.postMessage({
                            title,
                            options,
                            notificationId: id,
                        });

                        this.onshow = null;
                        setTimeout(() => {
                            this.dispatchEvent(new Event("show"));
                            if (typeof this._onshow === "function") this._onshow();
                        }, 0);
                    }

                    close() {
                        if (this.notificationId) {
                            window.webkit?.messageHandlers?.closeNotification?.postMessage({
                                id: this.notificationId,
                            });
                        }
                        super.close();
                    }

                    set onshow(h) { this._onshow = h; }
                    get onshow() { return this._onshow; }

                    set onerror(h) { this._onerror = h; }
                    get onerror() { return this._onerror; }

                    handleError(e) {
                        if (typeof this._onerror === "function") this._onerror(e);
                    }
                }

                window.Notification = OxvaNotification;

                Notification.requestPermission = function (cb) {
                    return new Promise((resolve) => {
                        window.webkit?.messageHandlers?.notificationPermission?.postMessage({});
                        window.notificationPermissionCallback = resolve;
                    }).then((res) => {
                        if (typeof cb === "function") cb(res);
                        return res;
                    });
                };

                window.addEventListener("nativePermissionResponse", (e) => {
                    if (window.notificationPermissionCallback) {
                        perm = e.detail.permission || "default";
                        window.notificationPermissionCallback(perm);
                        window.notificationPermissionCallback = null;
                    }
                });

                window.addEventListener("notificationError", (e) => {
                    const { notificationId, error } = e.detail;
                    const n = map.get(notificationId);
                    if (n) {
                        n.handleError(error);
                        map.delete(notificationId);
                    }
                });

                window.addEventListener("notificationSuccess", (e) => {
                    const { notificationId } = e.detail;
                    const n = map.get(notificationId);
                    if (n) {
                        console.log(`Notification successfully added: ${notificationId}`);
                        map.delete(notificationId);
                    }
                });
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    )

    // Inject SVG filter definitions used by liquid-glass.css
    webView.configuration.userContentController.addUserScript(
        WKUserScript(
            source: """
            (function() {
                if (document.getElementById('voxa-svg-filters')) return;
                const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
                svg.id = 'voxa-svg-filters';
                svg.setAttribute('aria-hidden', 'true');
                svg.style.cssText = 'position:absolute;width:0;height:0;overflow:hidden;pointer-events:none;';
                svg.innerHTML = `<defs>
                  <!-- Organic displacement for background panels (sidebar, user bar).
                       Scale kept low (6) so text above is unaffected. -->
                  <filter id="voxa-glass-panel" x="-5%" y="-5%" width="110%" height="110%"
                          color-interpolation-filters="sRGB">
                    <feTurbulence type="fractalNoise" baseFrequency="0.008 0.008"
                                  numOctaves="2" seed="92" result="noise"/>
                    <feGaussianBlur in="noise" stdDeviation="2" result="blurredNoise"/>
                    <feDisplacementMap in="SourceGraphic" in2="blurredNoise"
                                      scale="35" xChannelSelector="R" yChannelSelector="G"/>
                  </filter>
                </defs>`;
                document.body.appendChild(svg);
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
    )

    // Load active plugins
    activePlugins.forEach { plugin in
        webView.configuration.userContentController.addUserScript(
            WKUserScript(
                source: plugin.contents,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )
    }
}

// MARK: - WebView Representable

struct WebView: NSViewRepresentable {
    var initialURL: URL
    @Binding var webViewReference: WKWebView?
    private let rpcBridge = DiscordRPCBridge()

    init(initialURL: URL, webViewReference: Binding<WKWebView?> = .constant(nil)) {
        self.initialURL = initialURL
        self._webViewReference = webViewReference
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        // MARK: WebView Configuration

        let config = WKWebViewConfiguration()

        config.applicationNameForUserAgent = "Version/17.2.1 Safari/605.1.15"

        // Enable media capture
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true

        // If macOS 14 or higher, enable fullscreen
        if #available(macOS 14.0, *) {
            config.preferences.isElementFullscreenEnabled = true
        }

        // Additional media constraints
        config.preferences.setValue(true, forKey: "mediaDevicesEnabled")
        config.preferences.setValue(true, forKey: "mediaStreamEnabled")
        config.preferences.setValue(true, forKey: "peerConnectionEnabled")
        config.preferences.setValue(true, forKey: "screenCaptureEnabled")
        config.preferences.setValue(true, forKey: "useSystemAppearance")

        // Always enable the Web Inspector (accessible via Debug menu)
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        // Edit CSP to allow for 3rd party scripts and stylesheets to be loaded
        config.setValue(
            "default-src * 'unsafe-inline' 'unsafe-eval'; script-src * 'unsafe-inline' 'unsafe-eval'; connect-src * 'unsafe-inline'; img-src * data: blob: 'unsafe-inline'; frame-src *; style-src * 'unsafe-inline';",
            forKey: "overrideContentSecurityPolicy"
        )

        // MARK: WebView Initialisation

        let webView = WKWebView(frame: .zero, configuration: config)
        Task { @MainActor in webViewReference = webView }

        // Store a weak reference in Coordinator to break potential cycles
        context.coordinator.webView = webView

        // Configure webview delegates
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator

        // Make background transparent
        webView.underPageBackgroundColor = .clear

        // Add message handlers
        // If these are added to, ensure you remove the handlers as well in `Coordinator` `deinit`
        webView.configuration.userContentController.add(context.coordinator, name: "channelClick")
        webView.configuration.userContentController.add(context.coordinator, name: "notify")
        webView.configuration.userContentController.add(context.coordinator, name: "notificationPermission")

        rpcBridge.startBridge(for: webView)

        loadPluginsAndCSS(webView: webView)
        webView.load(URLRequest(url: initialURL))

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    // MARK: - Coordinator

    class Coordinator: NSObject, WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate {
        weak var webView: WKWebView?
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        deinit {
            // avoid memory leaks
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "channelClick")
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "notify")
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "notificationPermission")
        }

        // MARK: - WKWebView Delegate Methods

        @available(macOS 12.0, *)
        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            print("Requesting permission for media type:", type)
            decisionHandler(.grant)
        }

        func webView(
            _ webView: WKWebView,
            runOpenPanelWith parameters: WKOpenPanelParameters,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping ([URL]?) -> Void
        ) {
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = true
            openPanel.canChooseDirectories = false
            openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection

            openPanel.begin { response in
                if response == .OK {
                    completionHandler(openPanel.urls)
                } else {
                    completionHandler(nil)
                }
            }
        }

        func webView(
            _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let url = navigationAction.request.url,
               navigationAction.navigationType == .linkActivated,
               let host = url.host,
               !host.hasSuffix("discord.com"),
               !host.hasSuffix("discordapp.com")
            {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {}

        // MARK: - Script Message Handling

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "channelClick":
                guard
                    let body = message.body as? [String: Any],
                    let type = body["type"] as? String,
                    type == "user",
                    let urlString = body["url"] as? String,
                    let url = URL(string: urlString)
                else { return }
                NSWorkspace.shared.open(url)

            case "notify":
                guard
                    let body = message.body as? [String: Any],
                    let title = body["title"] as? String,
                    let options = body["options"] as? [String: Any],
                    let notificationId = body["notificationId"] as? String
                else {
                    print("Received malformed notify message.")
                    return
                }

                let notification = UNMutableNotificationContent()
                notification.title = title
                notification.body = options["body"] as? String ?? ""

                if let soundName = options["sound"] as? String {
                    notification.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
                } else {
                    notification.sound = .default
                }

                let request = UNNotificationRequest(
                    identifier: notificationId,
                    content: notification,
                    trigger: nil
                )

                UNUserNotificationCenter.current().add(request) { error in
                    guard error == nil else {
                        let error = error!
                        print("Error adding notification: \(error.localizedDescription)")

                        Task { @MainActor in
                            do {
                                try await self.webView?.callAsyncJavaScript(
                                    """
                                    window.dispatchEvent(
                                        new CustomEvent('notificationError', {
                                            detail: { notificationId, error }
                                        })
                                    );
                                    """,
                                    arguments: ["notificationId": notificationId, "error": error.localizedDescription],
                                    in: nil,
                                    in: .page
                                )
                            } catch {
                                print("Error dispatching notificationError: \(error.localizedDescription)")
                            }
                        }
                        return
                    }

                    Task { @MainActor in
                        do {
                            try await self.webView?.callAsyncJavaScript(
                                """
                                window.dispatchEvent(
                                    new CustomEvent('notificationSuccess', {
                                        detail: { notificationId }
                                    })
                                );
                                """,
                                arguments: ["notificationId": notificationId],
                                in: nil,
                                in: .page
                            )
                        } catch {
                            print("Error dispatching notificationSuccess: \(error.localizedDescription)")
                        }
                    }
                }

            case "notificationPermission":
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    let permission = granted ? "granted" : "denied"

                    Task { @MainActor in
                        do {
                            try await self.webView?.callAsyncJavaScript(
                                """
                                window.dispatchEvent(
                                    new CustomEvent('nativePermissionResponse', {
                                        detail: { permission }
                                    })
                                );
                                """,
                                arguments: ["permission": permission],
                                in: nil,
                                in: .page
                            )
                        } catch {
                            print("Error dispatching nativePermissionResponse: \(error.localizedDescription)")
                        }
                    }
                }

            default:
                print("Unimplemented message: \(message.name)")
            }
        }
    }
}

/// Performs a hard reload of the WebView by clearing all scripts and reloading the initial URL.
/// All scripts (CSS, channel click, notifications, plugins) are re-added via loadPluginsAndCSS.
func hardReloadWebView(webView: WKWebView) {
    webView.configuration.userContentController.removeAllUserScripts()
    loadPluginsAndCSS(webView: webView)
    let releaseChannel = UserDefaults.standard.string(forKey: "discordReleaseChannel") ?? ""
    let url = DiscordReleaseChannel(rawValue: releaseChannel)?.url ?? DiscordReleaseChannel.stable.url
    webView.load(URLRequest(url: url))
}
