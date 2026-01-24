import SwiftUI

struct FileExplorerView: View {
    var files: [FileItem] = FileItem.sampleFiles

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                Text("PROJECT FILES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.bottom, 5)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(files) { file in
                    FileRow(
                        name: file.name,
                        icon: file.icon,
                        color: file.color,
                        indent: file.indent
                    )
                }
            }
        }
        .padding()
        .frame(width: 220, height: 300)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10)
    }
}

struct FileItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let indent: CGFloat

    static let sampleFiles: [FileItem] = [
        FileItem(name: "src", icon: "folder.fill", color: .blue, indent: 0),
        FileItem(name: "components", icon: "folder.fill", color: .blue, indent: 15),
        FileItem(name: "Navbar.tsx", icon: "swift", color: .orange, indent: 30),
        FileItem(name: "Hero.tsx", icon: "swift", color: .orange, indent: 30),
        FileItem(name: "Button.tsx", icon: "swift", color: .orange, indent: 30),
        FileItem(name: "App.tsx", icon: "swift", color: .orange, indent: 15),
        FileItem(name: "global.css", icon: "number", color: .purple, indent: 15),
        FileItem(name: "package.json", icon: "doc.plaintext.fill", color: .gray, indent: 0),
    ]
}

#Preview {
    FileExplorerView()
        .padding()
        .background(Color.gray.opacity(0.1))
}
