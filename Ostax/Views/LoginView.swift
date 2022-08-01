import SwiftUI

struct LoginView<Model : LoginModel>: View {
    @ObservedObject var loginModel: Model
    
    var body: some View {
        if (loginModel.state == .LoggingInWithToken) {
            Text("Logging in...")
        } else if loginModel.state == .VerifyingEmailCode {
            Text("Verifying code...")
        } else if loginModel.state == .LoginFailed {
            Text("Login failed")
            Button("Try again") {
                loginModel.restart()
            }
        } else {
            VStack(alignment: .center) {
                Text("Welcome, stranger!")
                VStack() {
                    Text("1. Enter your email to get started")
                    
                    TextField("Email address", text: $loginModel.email)
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 150)
                        .onSubmit {
                            loginModel.emailLogin()
                        }

                }.disabled(loginModel.state != .None)
                if (loginModel.state == .EmailCodeSent) {
                    VStack {
                        Text("2. Enter the 6-digit code from email")
                        TextField("000000", text: $loginModel.code)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: loginModel.code) { newValue in
                                if (loginModel.code.count == 6) {
                                    loginModel.codeLogin()
                                }
                            }
                    }.disabled(loginModel.state == .VerifyingEmailCode)
                }
            }.frame(maxWidth: 250)
        }
    }
}


struct LoginView_Previews: PreviewProvider {
    class MockLoginModel: LoginModel {
        private func failLater() async {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            state = .LoginFailed
        }
        
        @Published var state: LoginState = .None
        @Published var email: String = ""
        @Published var code: String = ""
        
        func restart() {
            state = .None
        }
        
        func codeLogin() {
            state = .VerifyingEmailCode
            Task {
                await failLater()
            }
        }
        
        func emailLogin() {
            state = .EmailCodeSent
        }
    }
    static var previews: some View {
        LoginView(loginModel: MockLoginModel())
    }
}
