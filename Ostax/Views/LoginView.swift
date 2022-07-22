import SwiftUI

struct LoginView: View {
    var loginModel: LoginModel
    @State var emailValue = ""
    @State var sendingEmail = false
    @State var codeValue = ""
    @State var sendingCode = false
    
    var body: some View {
        if (loginModel.state == .LoggingIn) {
            Text("Logging in...")
        } else {
            VStack(alignment: .center) {
                Text("Welcome, stranger!")
                VStack() {
                    Text("1. Enter your email to get started")
                    
                    TextField("Email address", text: $emailValue)
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 150)
                        .onSubmit {
                            loginModel.emailLogin(email: emailValue)
                            sendingEmail = true
                        }

                }.disabled(sendingEmail)
                if (sendingEmail) {
                    VStack {
                        Text("2. Enter the 6-digit code from email")
                        TextField("000000", text: $codeValue)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: codeValue) { newValue in
                                if (codeValue.count == 6) {
                                    loginModel.codeLogin(email: emailValue, code: codeValue)
                                    sendingCode = true
                                }
                            }
                    }.disabled(sendingCode)
                }
                if (sendingCode) {
                    VStack {
                        Text("3. Wait a minute...")
                    }
                }
            }.frame(maxWidth: 250)
        }
    }
}


struct LoginView_Previews: PreviewProvider {
    class MockLoginModel: LoginModel {
        var state: LoginState = .None
        func codeLogin(email: String, code: String) {
            
        }
        
        func emailLogin(email: String) {
            
        }
    }
    static var previews: some View {
        LoginView(loginModel: MockLoginModel())
    }
}
