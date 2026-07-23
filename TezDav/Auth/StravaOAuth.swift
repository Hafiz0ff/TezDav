import Foundation
import Network
import SafariServices
import SwiftUI

enum StravaOAuthError: LocalizedError, Equatable {
    case invalidAuthorizationURL
    case missingCode
    case invalidState
    case accessDenied
    case invalidCallback
    case loopbackServer(String)

    var errorDescription: String? {
        switch self {
        case .invalidAuthorizationURL:
            return "Не удалось сформировать адрес авторизации Strava."
        case .missingCode:
            return "Strava не вернула код авторизации."
        case .invalidState:
            return "Ответ Strava не прошёл проверку безопасности. Попробуйте подключиться ещё раз."
        case .accessDenied:
            return "Доступ к Strava не был предоставлен."
        case .invalidCallback:
            return "Получен некорректный ответ от Strava."
        case .loopbackServer(let details):
            return "Не удалось запустить локальный OAuth callback: \(details)"
        }
    }
}

enum StravaOAuth {
    static let scopes = ["activity:read_all", "profile:read_all"]

    static func authorizationURL(
        config: StravaConfig,
        state: String,
        redirectURI: String? = nil
    ) throws -> URL {
        var components = URLComponents(string: "https://www.strava.com/oauth/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI ?? config.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: ",")),
            URLQueryItem(name: "state", value: state)
        ]

        guard let url = components?.url else {
            throw StravaOAuthError.invalidAuthorizationURL
        }
        return url
    }

    static func authorizationCode(
        from callbackURL: URL,
        expectedState: String? = nil
    ) throws -> String {
        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems

        if let expectedState {
            let returnedState = items?.first(where: { $0.name == "state" })?.value
            guard returnedState == expectedState else {
                throw StravaOAuthError.invalidState
            }
        }

        if items?.contains(where: { $0.name == "error" }) == true {
            throw StravaOAuthError.accessDenied
        }

        guard let code = items?.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw StravaOAuthError.missingCode
        }
        return code
    }
}

private final class StravaOAuthLoopbackServer {
    typealias ReadyHandler = (Result<URL, Error>) -> Void
    typealias CallbackHandler = (Result<URL, Error>) -> Void

    private let queue = DispatchQueue(label: "tj.dav.tezdav.strava-oauth-loopback")
    private var listener: NWListener?
    private var didReceiveCallback = false

    func start(onReady: @escaping ReadyHandler, onCallback: @escaping CallbackHandler) throws {
        let listener = try NWListener(using: .tcp, on: .any)
        self.listener = listener

        listener.stateUpdateHandler = { [weak self, weak listener] state in
            guard let self else { return }

            switch state {
            case .ready:
                guard
                    let port = listener?.port,
                    let redirectURL = URL(string: "http://localhost:\(port.rawValue)/auth/callback")
                else {
                    onReady(.failure(StravaOAuthError.invalidAuthorizationURL))
                    return
                }
                onReady(.success(redirectURL))
            case .failed(let error):
                onReady(.failure(StravaOAuthError.loopbackServer(error.localizedDescription)))
                self.stop()
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.receiveRequest(from: connection, accumulatedData: Data(), onCallback: onCallback)
        }
        listener.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func receiveRequest(
        from connection: NWConnection,
        accumulatedData: Data,
        onCallback: @escaping CallbackHandler
    ) {
        connection.start(queue: queue)
        receiveMore(
            from: connection,
            accumulatedData: accumulatedData,
            onCallback: onCallback
        )
    }

    private func receiveMore(
        from connection: NWConnection,
        accumulatedData: Data,
        onCallback: @escaping CallbackHandler
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] content, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }

            var requestData = accumulatedData
            if let content {
                requestData.append(content)
            }

            if requestData.range(of: Data("\r\n\r\n".utf8)) != nil {
                self.process(requestData, from: connection, onCallback: onCallback)
            } else if let error {
                connection.cancel()
                onCallback(.failure(StravaOAuthError.loopbackServer(error.localizedDescription)))
            } else if isComplete || requestData.count >= 65_536 {
                connection.cancel()
                onCallback(.failure(StravaOAuthError.invalidCallback))
            } else {
                self.receiveMore(
                    from: connection,
                    accumulatedData: requestData,
                    onCallback: onCallback
                )
            }
        }
    }

    private func process(
        _ requestData: Data,
        from connection: NWConnection,
        onCallback: @escaping CallbackHandler
    ) {
        guard
            let request = String(data: requestData, encoding: .utf8),
            let requestLine = request.components(separatedBy: "\r\n").first
        else {
            sendResponse(status: "400 Bad Request", body: "Invalid OAuth callback.", over: connection)
            return
        }

        let parts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count == 3, parts[0] == "GET" else {
            sendResponse(status: "405 Method Not Allowed", body: "Only GET is supported.", over: connection)
            return
        }

        let target = parts[1]
        let callbackURL = target.hasPrefix("http")
            ? URL(string: target)
            : URL(string: "http://localhost\(target)")

        guard let callbackURL, callbackURL.path == "/auth/callback" else {
            sendResponse(status: "404 Not Found", body: "Not found.", over: connection)
            return
        }

        guard !didReceiveCallback else {
            sendResponse(status: "409 Conflict", body: "OAuth callback already received.", over: connection)
            return
        }
        didReceiveCallback = true

        sendResponse(
            status: "200 OK",
            body: "Authorization complete. You can return to TezDav.",
            over: connection
        )
        onCallback(.success(callbackURL))
    }

    private func sendResponse(
        status: String,
        body: String,
        over connection: NWConnection
    ) {
        let bodyData = Data(body.utf8)
        let headers = """
        HTTP/1.1 \(status)\r
        Content-Type: text/plain; charset=utf-8\r
        Content-Length: \(bodyData.count)\r
        Cache-Control: no-store\r
        Connection: close\r
        \r
        """
        var response = Data(headers.utf8)
        response.append(bodyData)

        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

@MainActor
final class StravaOAuthCoordinator: NSObject, ObservableObject, SFSafariViewControllerDelegate {
    static let shared = StravaOAuthCoordinator()

    @Published private(set) var isAuthenticating = false
    @Published private(set) var isConnected = false
    @Published var errorMessage: String?

    private let config: StravaConfig
    private let tokenStore: TokenStore
    private var loopbackServer: StravaOAuthLoopbackServer?
    private var expectedState: String?
    private var browser: SFSafariViewController?
    private var isExchangingToken = false

    init(
        config: StravaConfig = .fromBundle(),
        tokenStore: TokenStore = KeychainTokenStore()
    ) {
        self.config = config
        self.tokenStore = tokenStore
        super.init()
    }

    func start() {
        guard !isAuthenticating else { return }
        guard config.isConfigured else {
            fail(with: "Параметры Strava не настроены в Info.plist.")
            return
        }

        errorMessage = nil
        isAuthenticating = true
        isExchangingToken = false

        let state = UUID().uuidString
        expectedState = state

        let server = StravaOAuthLoopbackServer()
        loopbackServer = server

        do {
            try server.start(
                onReady: { [weak self] result in
                    Task { @MainActor in
                        self?.handleServerReady(result, state: state)
                    }
                },
                onCallback: { [weak self] result in
                    Task { @MainActor in
                        self?.handleCallback(result)
                    }
                }
            )
        } catch {
            fail(with: error.localizedDescription)
        }
    }

    func clearError() {
        errorMessage = nil
    }

    nonisolated func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        Task { @MainActor [weak self] in
            guard let self, !self.isExchangingToken else { return }
            self.cancel()
        }
    }

    private func handleServerReady(_ result: Result<URL, Error>, state: String) {
        guard isAuthenticating, expectedState == state else { return }

        switch result {
        case .success(let redirectURL):
            do {
                let authorizationURL = try StravaOAuth.authorizationURL(
                    config: config,
                    state: state,
                    redirectURI: redirectURL.absoluteString
                )
                presentBrowser(at: authorizationURL)
            } catch {
                fail(with: error.localizedDescription)
            }
        case .failure(let error):
            fail(with: error.localizedDescription)
        }
    }

    private func handleCallback(_ result: Result<URL, Error>) {
        guard isAuthenticating, !isExchangingToken else { return }

        switch result {
        case .success(let callbackURL):
            guard let expectedState else {
                fail(with: StravaOAuthError.invalidState.localizedDescription)
                return
            }

            do {
                let code = try StravaOAuth.authorizationCode(
                    from: callbackURL,
                    expectedState: expectedState
                )
                isExchangingToken = true
                stopBrowserAndServer()
                exchangeCode(code)
            } catch {
                fail(with: error.localizedDescription)
            }
        case .failure(let error):
            fail(with: error.localizedDescription)
        }
    }

    private func exchangeCode(_ code: String) {
        Task {
            do {
                let refresher = StravaTokenRefresher(config: config)
                let token = try await refresher.exchangeCode(code)
                try tokenStore.saveToken(token)

                isConnected = true
                isAuthenticating = false
                isExchangingToken = false
                expectedState = nil
            } catch {
                fail(with: "Strava не приняла код авторизации: \(error.localizedDescription)")
            }
        }
    }

    private func presentBrowser(at url: URL) {
        guard let presenter = Self.topViewController() else {
            fail(with: "Не найден экран для открытия Strava.")
            return
        }

        let browser = SFSafariViewController(url: url)
        browser.delegate = self
        browser.dismissButtonStyle = .cancel
        self.browser = browser
        presenter.present(browser, animated: true)
    }

    private func cancel() {
        stopBrowserAndServer()
        expectedState = nil
        isAuthenticating = false
        isExchangingToken = false
    }

    private func fail(with message: String) {
        stopBrowserAndServer()
        expectedState = nil
        isAuthenticating = false
        isExchangingToken = false
        errorMessage = message
    }

    private func stopBrowserAndServer() {
        loopbackServer?.stop()
        loopbackServer = nil

        browser?.dismiss(animated: true)
        browser = nil
    }

    private static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController

        return topViewController(from: root)
    }

    private static func topViewController(from root: UIViewController?) -> UIViewController? {
        if let presented = root?.presentedViewController {
            return topViewController(from: presented)
        }
        if let navigation = root as? UINavigationController {
            return topViewController(from: navigation.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topViewController(from: tab.selectedViewController)
        }
        return root
    }
}
