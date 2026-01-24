import SwiftUI

struct FileRow: View {
    let name: String
    let icon: String
    let color: Color
    let indent: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            Text(name)
                .font(.system(size: 13))
                .foregroundColor(.primary)
        }
        .padding(.leading, indent)
    }
}

#Preview {
    VStack(alignment: .leading) {
        FileRow(name: "src", icon: "folder.fill", color: .blue, indent: 0)
        FileRow(name: "App.tsx", icon: "swift", color: .orange, indent: 15)
    }
    .padding()
}
