import SwiftUI

struct ContentView: View {
    @State private var authService = AuthService()

    var body: some View {
        Group {
            if authService.isAuthenticated {
                HomeView(authService: authService)
            } else {
                #if DEBUG
                DevSignInView(authService: authService)
                #else
                SignInView(authService: authService)
                #endif
            }
        }
    }
}

#Preview {
    ContentView()
}
