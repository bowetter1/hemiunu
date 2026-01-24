import SwiftUI

struct DesignSystemPanel: View {
    @Binding var primaryColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "paintpalette.fill")
                Text("DESIGN SYSTEM")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ColorSwatch(color: primaryColor, name: "Brand")
                ColorSwatch(color: .black, name: "Dark")
                ColorSwatch(color: Color(nsColor: .systemGray), name: "Surface")
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10)
    }
}

#Preview {
    DesignSystemPanel(primaryColor: .constant(.blue))
        .padding()
        .background(Color.gray.opacity(0.1))
}
