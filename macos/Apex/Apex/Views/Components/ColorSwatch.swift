import SwiftUI

struct ColorSwatch: View {
    let color: Color
    let name: String

    var body: some View {
        VStack {
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
            Text(name)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    HStack {
        ColorSwatch(color: .blue, name: "Brand")
        ColorSwatch(color: .black, name: "Dark")
        ColorSwatch(color: .gray, name: "Surface")
    }
    .padding()
}
