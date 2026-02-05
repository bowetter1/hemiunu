import SwiftUI

struct CommandBar: View {
    @Binding var text: String
    var placeholder: String = "Ask AI to do something..."
    var onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: "sparkles")
                .foregroundColor(.blue)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .onSubmit(onSubmit)

            if !text.isEmpty {
                Button(action: onSubmit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .frame(width: 500, height: 50)
        .background(Theme.Colors.glassFill)
        .clipShape(Capsule())
    }
}

#Preview {
    CommandBar(text: .constant(""), onSubmit: {})
        .padding()
}
