import AuthenticationServices
import SwiftUI

/// Who is signed in: Sign in with Apple, with no server of ours (so far it only names the person
/// and puts their initials in the profile picture). The name and email come from Apple only the
/// first time, so they are kept here; Apple's user id says it is the same person next time.
@Observable @MainActor
final class Account {
    static let shared = Account()

    private(set) var userId: String? = UserDefaults.standard.string(forKey: "accountUser")
    private(set) var name: String? = UserDefaults.standard.string(forKey: "accountName")
    private(set) var email: String? = UserDefaults.standard.string(forKey: "accountEmail")
    var failure: String?

    #if DEBUG
    /// `-account "Willis Liao"` on launch shows a signed-in person (screenshots).
    init() {
        if let n = UserDefaults.standard.string(forKey: "account") { userId = "debug"; name = n; email = "willis@example.com" }
    }
    #endif

    var signedIn: Bool { userId != nil }

    /// "WL" for Willis Liao, the first letter for one name, nil with no name.
    var initials: String? {
        let words = (name ?? "").split(separator: " ")
        let letters = words.count > 1 ? [words.first, words.last] : [words.first]
        let text = letters.compactMap { $0?.first.map(String.init) }.joined().uppercased()
        return text.isEmpty ? nil : text
    }

    /// The button's request: what Apple should tell us.
    func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    func finish(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let c = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            failure = nil
            userId = c.user
            UserDefaults.standard.set(c.user, forKey: "accountUser")
            // Only the first sign-in carries these; later ones leave what is kept.
            if let n = c.fullName.map({ PersonNameComponentsFormatter().string(from: $0) }), !n.isEmpty { name = n; UserDefaults.standard.set(n, forKey: "accountName") }
            if let e = c.email { email = e; UserDefaults.standard.set(e, forKey: "accountEmail") }
        case .failure(let e):
            // Backing out of the sheet is not a failure.
            if (e as? ASAuthorizationError)?.code != .canceled { failure = "Couldn’t sign in. Try again." }
        }
    }

    func signOut() {
        for k in ["accountUser", "accountName", "accountEmail"] { UserDefaults.standard.removeObject(forKey: k) }
        userId = nil
        name = nil
        email = nil
    }

    /// Signs out when Apple says the person revoked WilList's access.
    func check() async {
        guard let userId else { return }
        let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: userId)
        if state == .revoked || state == .notFound { signOut() }
    }
}

/// The profile picture: the person's initials once signed in, otherwise the plain figure.
struct Avatar: View {
    @Environment(Account.self) private var account
    var size: CGFloat = 30

    var body: some View {
        if let initials = account.initials {
            Text(initials)
                .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Color.brand, in: Circle())
        } else if account.signedIn {
            Image(systemName: "person.crop.circle.fill").font(.system(size: size)).foregroundStyle(Color.brand)
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: size))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.brand)
        }
    }
}

/// Settings' first section: Sign in with Apple, or who is signed in with Sign out.
struct AccountSection: View {
    @Environment(Account.self) private var account

    var body: some View {
        Section {
            if account.signedIn {
                HStack(spacing: 12) {
                    Avatar(size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.name ?? "Signed in with Apple").font(.headline)
                        if let email = account.email { Text(email).font(.subheadline).foregroundStyle(.secondary) }
                    }
                }
                Button("Sign out", role: .destructive) { account.signOut() }
            } else {
                SignInWithAppleButton(.signIn, onRequest: account.configure, onCompletion: account.finish)
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                if let failure = account.failure { Text(failure).font(.footnote).foregroundStyle(.red) }
            }
        }
    }
}
