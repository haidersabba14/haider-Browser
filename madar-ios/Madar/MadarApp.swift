import SwiftUI
import CryptoKit
import WebKit

@main
struct MadarApp: App {
    var body: some Scene {
        WindowGroup { MadarRoot().environment(\.layoutDirection, .rightToLeft).preferredColorScheme(.light) }
    }
}

private enum Palette {
    static let background = Color(red: 0.965, green: 0.965, blue: 0.941)
    static let ink = Color(red: 0.15, green: 0.23, blue: 0.19)
    static let orange = Color(red: 0.875, green: 0.459, blue: 0.294)
}

final class LocalLock: ObservableObject {
    @Published var unlocked = false
    @Published var error = ""
    private let salt = "madar-native-2026-7d34c6e2:"
    private let expectedHash = "4fe462c1ca504e225915e4647f74cddd8de1705c2d9890692d51cd74f9208856"

    func verify(_ password: String) {
        let defaults = UserDefaults.standard
        let lockUntil = defaults.double(forKey: "madar.lockUntil")
        if Date().timeIntervalSince1970 < lockUntil {
            error = "محاولات كثيرة. انتظر دقيقة وأعد المحاولة."
            return
        }
        let hash = SHA256.hash(data: Data((salt + password).utf8)).map { String(format: "%02x", $0) }.joined()
        let received = Array(hash.utf8), expected = Array(expectedHash.utf8)
        var difference: UInt8 = 0
        for i in 0..<expected.count { difference |= received[i] ^ expected[i] }
        if difference == 0 {
            defaults.removeObject(forKey: "madar.failures")
            defaults.removeObject(forKey: "madar.lockUntil")
            error = ""
            unlocked = true
        } else {
            let failures = defaults.integer(forKey: "madar.failures") + 1
            if failures >= 5 {
                defaults.set(Date().timeIntervalSince1970 + 60, forKey: "madar.lockUntil")
                defaults.set(0, forKey: "madar.failures")
                error = "محاولات كثيرة. انتظر دقيقة وأعد المحاولة."
            } else {
                defaults.set(failures, forKey: "madar.failures")
                error = "كلمة المرور غير صحيحة. حاول مرة ثانية."
            }
        }
    }

    func lock() { unlocked = false; error = "" }
}

struct MadarRoot: View {
    @StateObject private var lock = LocalLock()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            if lock.unlocked {
                DashboardWebView(onLock: { lock.lock() })
            } else {
                LockScreen(lock: lock)
            }
            if scenePhase != .active {
                Palette.background.ignoresSafeArea()
                VStack(spacing: 15) {
                    Image(systemName: "lock.shield").font(.system(size: 36)).foregroundStyle(Palette.orange)
                    Text("مساحتك الخاصة").foregroundStyle(Palette.ink)
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { lock.lock() }
        }
    }
}

struct LockScreen: View {
    @ObservedObject var lock: LocalLock
    @State private var password = ""
    @State private var reveal = false
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis").font(.system(size: 25, weight: .medium))
                        .foregroundStyle(.white).frame(width: 44, height: 46)
                        .background(Palette.orange, in: RoundedRectangle(cornerRadius: 13))
                        .rotationEffect(.degrees(-5))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("مدار").font(.system(size: 30, weight: .semibold))
                        Text("M A D A R").font(.system(size: 8, weight: .medium))
                    }
                }.padding(.bottom, 65)
                HStack(spacing: 8) {
                    Circle().fill(Palette.orange).frame(width: 6, height: 6)
                    Text("مساحتك الخاصة").font(.system(size: 12)).foregroundStyle(.secondary)
                }.padding(.bottom, 19)
                Text("كل تطبيقاتك.\nفي مدار واحد.")
                    .font(.system(size: 39, weight: .semibold)).lineSpacing(10)
                    .fixedSize(horizontal: false, vertical: true)
                Text("نظرة أوضح لأداء تطبيقاتك، من أول تحميل إلى آخر إنجاز.")
                    .font(.system(size: 14)).lineSpacing(7).foregroundStyle(.secondary)
                    .padding(.top, 18).padding(.bottom, 35)
                Text("كلمة المرور").font(.system(size: 12, weight: .medium)).padding(.bottom, 10)
                HStack {
                    Group {
                        if reveal { TextField("كلمة المرور", text: $password) }
                        else { SecureField("كلمة المرور", text: $password) }
                    }
                    .environment(\.layoutDirection, .leftToRight)
                    .textContentType(.password).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .focused($focused).submitLabel(.go).onSubmit(submit)
                    Button { reveal.toggle() } label: {
                        Image(systemName: reveal ? "eye.slash" : "eye").foregroundStyle(.secondary)
                    }.accessibilityLabel(reveal ? "إخفاء كلمة المرور" : "إظهار كلمة المرور")
                }
                .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.1)))
                Text(lock.error).font(.system(size: 11)).foregroundStyle(.red)
                    .frame(minHeight: 30, alignment: .leading).accessibilityAddTraits(.updatesFrequently)
                Button(action: submit) {
                    HStack {
                        Text("الدخول إلى لوحة التحكم").font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.left")
                    }.padding(17).foregroundStyle(.white)
                        .background(Palette.orange, in: RoundedRectangle(cornerRadius: 10))
                }.disabled(password.isEmpty)
                HStack(spacing: 7) {
                    Image(systemName: "lock.shield").font(.system(size: 12))
                    Text("مساحة محمية. الدخول لك فقط.").font(.system(size: 11))
                }.foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 19)
                Text("بيانات GitHub الفعلية · مساحة خاصة")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity).padding(.top, 50)
            }
            .foregroundStyle(Palette.ink).padding(.horizontal, 30).padding(.top, 35).padding(.bottom, 25)
            .frame(maxWidth: 450).frame(maxWidth: .infinity)
        }.scrollDismissesKeyboard(.interactively)
    }

    private func submit() {
        lock.verify(password)
        if lock.unlocked { password = ""; focused = false }
    }
}

struct DashboardWebView: UIViewRepresentable {
    let onLock: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onLock: onLock) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: "lock")
        configuration.userContentController.add(context.coordinator, name: "exportReport")
        configuration.userContentController.add(context.coordinator, name: "preferences")
        if let saved = UserDefaults.standard.string(forKey: "madar.preferences"),
           let savedData = saved.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: savedData) as? [String: Any],
           let encoded = try? JSONSerialization.data(withJSONObject: object),
           let json = String(data: encoded, encoding: .utf8) {
            configuration.userContentController.addUserScript(WKUserScript(source: "window.MADAR_SAVED_PREFERENCES = \(json);", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        if let dataURL = Bundle.main.url(forResource: "data", withExtension: "json", subdirectory: "web"),
           let data = try? String(contentsOf: dataURL, encoding: .utf8) {
            configuration.userContentController.addUserScript(WKUserScript(source: "window.NATIVE_MADAR_METADATA = \(data);", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = UIColor(red: 0.965, green: 0.965, blue: 0.941, alpha: 1)
        view.scrollView.backgroundColor = view.backgroundColor
        if let url = Bundle.main.url(forResource: "dashboard", withExtension: "html", subdirectory: "web") {
            view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) { }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "lock")
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "exportReport")
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "preferences")
        uiView.stopLoading()
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let onLock: () -> Void
        init(onLock: @escaping () -> Void) { self.onLock = onLock }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame else { return }
            if message.name == "lock" { onLock(); return }
            if message.name == "preferences", let text = message.body as? String,
               text.utf8.count <= 100000, let data = text.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data)) is [String: Any] {
                UserDefaults.standard.set(text, forKey: "madar.preferences")
                return
            }
            guard message.name == "exportReport", let body = message.body as? [String: Any],
                  let csv = body["csv"] as? String, let filename = body["filename"] as? String,
                  filename.hasPrefix("madar-"), ["csv", "json", "txt", "md", "html", "tsv"].contains(URL(fileURLWithPath: filename).pathExtension.lowercased()),
                  !filename.contains("/"), !filename.contains("..") else { return }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            do { try csv.write(to: url, atomically: true, encoding: .utf8) }
            catch { return }
            guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                  let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else { return }
            var presenter = root
            while let next = presenter.presentedViewController { presenter = next }
            let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            sheet.popoverPresentationController?.sourceView = presenter.view
            sheet.popoverPresentationController?.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
            presenter.present(sheet, animated: true)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
            if url.isFileURL { decisionHandler(.allow); return }
            if navigationAction.navigationType == .linkActivated, ["https", "http"].contains(url.scheme ?? "") {
                UIApplication.shared.open(url)
            }
            decisionHandler(.cancel)
        }
    }
}
