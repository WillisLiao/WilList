// WilList for iPhone and iPad: the web app in app/, bundled and shown in a web view.
// Files are served from the app bundle under willist://app/ (ES modules need a real
// origin, which file:// URLs don't give), the planner's data is mirrored to a file so
// iOS clearing website data can never lose it, and downloads go to the share sheet.

import SwiftUI
import WebKit
import UniformTypeIdentifiers

@main
struct WilListApp: App {
    var body: some Scene {
        WindowGroup {
            PlannerView().ignoresSafeArea()
        }
    }
}

struct PlannerView: UIViewRepresentable {
    func makeCoordinator() -> Bridge { Bridge() }

    func makeUIView(context: Context) -> WKWebView {
        let bridge = context.coordinator
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.setURLSchemeHandler(bridge, forURLScheme: Bridge.scheme)
        let scripts = config.userContentController
        scripts.addUserScript(WKUserScript(source: bridge.restoreScript(), injectionTime: .atDocumentStart, forMainFrameOnly: true))
        scripts.add(bridge, name: "save")
        scripts.add(bridge, name: "share")

        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = bridge
        web.uiDelegate = bridge
        web.isOpaque = false
        web.backgroundColor = .systemBackground
        web.scrollView.backgroundColor = .systemBackground
        web.scrollView.contentInsetAdjustmentBehavior = .never // the page pads itself with env(safe-area-inset-*)
        web.allowsLinkPreview = false
        web.isInspectable = true // Safari → Develop, for debugging on a device
        web.load(URLRequest(url: URL(string: "\(Bridge.scheme)://app/index.html")!))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}
}

final class Bridge: NSObject, WKURLSchemeHandler, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    static let scheme = "willist"
    private let root = Bundle.main.resourceURL!.appendingPathComponent("app", isDirectory: true).standardizedFileURL
    private let saveQueue = DispatchQueue(label: "willist.save")

    // MARK: serving the bundled web app

    private static let mime: [String: String] = [
        "html": "text/html", "js": "text/javascript", "mjs": "text/javascript", "css": "text/css",
        "json": "application/json", "webmanifest": "application/manifest+json", "svg": "image/svg+xml",
        "png": "image/png", "woff2": "font/woff2", "txt": "text/plain",
    ]

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else { return }
        let path = url.path.isEmpty || url.path == "/" ? "index.html" : String(url.path.dropFirst())
        let file = root.appendingPathComponent(path).standardizedFileURL
        guard file.path.hasPrefix(root.path + "/"), let data = try? Data(contentsOf: file) else {
            task.didReceive(HTTPURLResponse(url: url, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: nil)!)
            task.didFinish()
            return
        }
        let type = Self.mime[file.pathExtension.lowercased()] ?? "application/octet-stream"
        task.didReceive(HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                        headerFields: ["Content-Type": type, "Content-Length": String(data.count), "Cache-Control": "no-cache"])!)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}

    // MARK: keeping the planner's data safe

    private var stateFile: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("willist.v1.json")
    }

    // Runs before the app's own code: puts the saved copy back if website data was cleared,
    // then mirrors every save of the planner to native code.
    func restoreScript() -> String {
        let saved = (try? String(contentsOf: stateFile, encoding: .utf8))
            .flatMap { try? JSONEncoder().encode($0) }
            .flatMap { String(data: $0, encoding: .utf8) } ?? "null"
        return """
        (() => {
          const KEY = 'willist.v1';
          const saved = \(saved);
          try { if (saved && !localStorage.getItem(KEY)) localStorage.setItem(KEY, saved); } catch {}
          const setItem = Storage.prototype.setItem;
          Storage.prototype.setItem = function (k, v) {
            setItem.call(this, k, v);
            if (this === localStorage && k === KEY) window.webkit.messageHandlers.save.postMessage(String(v));
          };
        })();
        """
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "save":
            guard let text = message.body as? String else { return }
            let file = stateFile
            saveQueue.async { try? Data(text.utf8).write(to: file, options: .atomic) }
        case "share":
            guard let body = message.body as? [String: Any], let name = body["filename"] as? String,
                  let text = body["text"] as? String else { return }
            share(name: name, text: text, from: message.webView)
        default:
            break
        }
    }

    // Backups and calendar files: save, AirDrop or open in Calendar from the share sheet.
    private func share(name: String, text: String, from web: WKWebView?) {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent((name as NSString).lastPathComponent)
        guard (try? Data(text.utf8).write(to: file, options: .atomic)) != nil,
              let host = web?.window?.rootViewController else { return }
        let sheet = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        if let pop = sheet.popoverPresentationController, let web {
            pop.sourceView = web
            pop.sourceRect = CGRect(x: web.bounds.midX, y: web.bounds.midY, width: 1, height: 1)
            pop.permittedArrowDirections = []
        }
        (host.presentedViewController ?? host).present(sheet, animated: true)
    }

    // MARK: links to other sites open in Safari

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url, let scheme = url.scheme?.lowercased() else { return decisionHandler(.cancel) }
        if scheme == Self.scheme || scheme == "about" || scheme == "blob" || scheme == "data" { return decisionHandler(.allow) }
        UIApplication.shared.open(url)
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url { UIApplication.shared.open(url) }
        return nil
    }

    // If iOS ends the web content process (memory pressure), bring the planner back.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}
