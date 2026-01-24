import SwiftUI

struct TaskRow: View {
    let title: String
    let done: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundColor(done ? .green : .secondary)
            Text(title)
                .font(.system(size: 13))
                .strikethrough(done)
                .foregroundColor(done ? .secondary : .primary)
            Spacer()
        }
    }
}

#Preview {
    VStack {
        TaskRow(title: "Design Landing Page", done: true)
        TaskRow(title: "Add Login Form", done: false)
    }
    .padding()
}
