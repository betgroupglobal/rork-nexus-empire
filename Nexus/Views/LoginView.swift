import SwiftUI

struct LoginView: View {
    @Bindable var authVM: AuthViewModel
    @State private var isRegistering: Bool = false
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var name: String = ""
    @State private var confirmPassword: String = ""
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case name, email, password, confirm
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: geo.size.height * 0.12)

                    headerSection

                    Spacer()
                        .frame(height: 40)

                    formSection

                    Spacer()
                        .frame(height: 24)

                    actionButton

                    Spacer()
                        .frame(height: 16)

                    toggleModeButton

                    Spacer()
                        .frame(height: 20)

                    demoModeButton

                    Spacer()
                        .frame(height: 12)

                    devLoginButton

                    Spacer()
                        .frame(height: geo.size.height * 0.1)
                }
                .padding(.horizontal, 28)
                .frame(minHeight: geo.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.14),
                    Color(red: 0.08, green: 0.12, blue: 0.24),
                    Color(red: 0.04, green: 0.06, blue: 0.14),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .onChange(of: isRegistering) { _, _ in
            authVM.errorMessage = nil
        }
    }

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.blue.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 50
                        )
                    )
                    .frame(width: 90, height: 90)

                Image(systemName: "shield.checkered")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(.white)
            }

            Text("Nexus")
                .font(.system(size: 34, weight: .bold, design: .default))
                .foregroundStyle(.white)

            Text(isRegistering ? "Create your account" : "Sign in to your empire")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var formSection: some View {
        VStack(spacing: 14) {
            if isRegistering {
                AuthTextField(
                    icon: "person",
                    placeholder: "Full Name",
                    text: $name,
                    focused: $focusedField,
                    field: .name
                )
                .textContentType(.name)
                .submitLabel(.next)
                .onSubmit { focusedField = .email }
            }

            AuthTextField(
                icon: "envelope",
                placeholder: "Email",
                text: $email,
                focused: $focusedField,
                field: .email
            )
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.next)
            .onSubmit { focusedField = .password }

            AuthSecureField(
                icon: "lock",
                placeholder: "Password",
                text: $password,
                focused: $focusedField,
                field: .password
            )
            .textContentType(isRegistering ? .newPassword : .password)
            .submitLabel(isRegistering ? .next : .go)
            .onSubmit {
                if isRegistering {
                    focusedField = .confirm
                } else {
                    submit()
                }
            }

            if isRegistering {
                AuthSecureField(
                    icon: "lock.shield",
                    placeholder: "Confirm Password",
                    text: $confirmPassword,
                    focused: $focusedField,
                    field: .confirm
                )
                .textContentType(.newPassword)
                .submitLabel(.go)
                .onSubmit { submit() }
            }

            if let error = authVM.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                }
                .foregroundStyle(.red)
                .padding(.top, 4)
            }
        }
    }

    private var actionButton: some View {
        Button {
            submit()
        } label: {
            Group {
                if authVM.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(isRegistering ? "Create Account" : "Sign In")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(.rect(cornerRadius: 14))
        }
        .disabled(!isFormValid || authVM.isLoading)
        .opacity(isFormValid ? 1 : 0.5)
        .sensoryFeedback(.impact(flexibility: .solid), trigger: authVM.isAuthenticated)
    }

    private var toggleModeButton: some View {
        Button {
            withAnimation(.snappy) {
                isRegistering.toggle()
                confirmPassword = ""
            }
        } label: {
            HStack(spacing: 4) {
                Text(isRegistering ? "Already have an account?" : "Don't have an account?")
                    .foregroundStyle(.white.opacity(0.5))
                Text(isRegistering ? "Sign In" : "Create One")
                    .foregroundStyle(.blue)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
        }
    }

    private var demoModeButton: some View {
        Button {
            authVM.loginDemo()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.circle.fill")
                    .font(.subheadline)
                Text("Enter Demo Mode")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(.white.opacity(0.7))
            .background(Color.white.opacity(0.08))
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    private var devLoginButton: some View {
        Button {
            email = "dev@nexus.test"
            password = "devdev123"
            name = "Dev User"
            if isRegistering {
                confirmPassword = "devdev123"
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "hammer.fill")
                    .font(.caption2)
                Text("Fill Dev Credentials")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.white.opacity(0.3))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            .clipShape(.rect(cornerRadius: 8))
        }
    }

    private var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 6
        if isRegistering {
            return !name.isEmpty && emailValid && passwordValid && password == confirmPassword
        }
        return emailValid && passwordValid
    }

    private func submit() {
        guard isFormValid else { return }
        focusedField = nil
        Task {
            if isRegistering {
                await authVM.register(name: name, email: email, password: password)
            } else {
                await authVM.login(email: email, password: password)
            }
        }
    }
}

private struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var focused: FocusState<LoginView.Field?>.Binding
    let field: LoginView.Field

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 20)
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.3)))
                .foregroundStyle(.white)
                .focused(focused, equals: field)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color.white.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(focused.wrappedValue == field ? 0.2 : 0.06), lineWidth: 1)
        )
    }
}

private struct AuthSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var focused: FocusState<LoginView.Field?>.Binding
    let field: LoginView.Field
    @State private var showPassword: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 20)
            Group {
                if showPassword {
                    TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.3)))
                } else {
                    SecureField("", text: $text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.3)))
                }
            }
            .foregroundStyle(.white)
            .focused(focused, equals: field)

            Button {
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color.white.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(focused.wrappedValue == field ? 0.2 : 0.06), lineWidth: 1)
        )
    }
}
