import SwiftUI

struct LoginView<Model : LoginModel>: View {
    @ObservedObject var loginModel: Model
    
    var body: some View {
        if loginModel.state == .LoggingIn || loginModel.state == .VerifyingEmailCode {
            Text("Logging in...")
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
        var state: LoginState = .None
        var email: String = ""
        var code: String = ""
        
        func restart() {
            
        }
        
        func codeLogin() {
            
        }
        
        func emailLogin() {
            
        }
    }
    static var previews: some View {
        LoginView(loginModel: MockLoginModel())
    }
}
