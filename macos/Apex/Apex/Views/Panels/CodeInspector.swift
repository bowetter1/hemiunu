import SwiftUI

enum UIElementType {
    case none, headline, button, navbar
}

struct CodeInspectorView: View {
    let element: UIElementType
    let headlineText: String
    let headlineColor: Color
    let btnColor: Color

    var codeSnippet: String {
        switch element {
        case .headline:
            return """
            // Hero Title Component
            Text("\(headlineText)")
                .font(.system(size: 56, weight: .bold))
                .foregroundColor(.\(colorName(headlineColor)))
                .multilineTextAlignment(.center)
            """
        case .button:
            return """
            // Primary Action Button
            Button(action: { startOnboarding() }) {
                Text("Get Started")
                    .padding()
                    .background(Color.\(colorName(btnColor)))
                    .clipShape(Capsule())
            }
            """
        case .navbar:
            return """
            // Navigation Bar
            HStack {
                Logo(name: "APEX")
                Spacer()
                NavLinks(["Product", "Pricing"])
                SignInButton()
            }
            .frame(height: 70)
            """
        case .none:
            return "// Select an element to inspect code"
        }
    }

    func colorName(_ color: Color) -> String {
        switch color {
        case .red: return "red"
        case .blue: return "blue"
        case .green: return "green"
        case .black: return "black"
        case .purple: return "purple"
        default: return "primary"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "terminal.fill")
                    .foregroundColor(.gray)
                Text("CODE INSPECTOR")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                Spacer()
            }

            Divider().background(Color.gray.opacity(0.2))

            ScrollView {
                Text(codeSnippet)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.green)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .frame(width: 280, height: 200)
        .background(Color.black.opacity(0.9))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    CodeInspectorView(
        element: .headline,
        headlineText: "Hello World",
        headlineColor: .blue,
        btnColor: .blue
    )
    .padding()
}
