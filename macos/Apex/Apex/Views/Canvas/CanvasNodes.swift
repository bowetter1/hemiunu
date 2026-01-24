import SwiftUI

struct NoteNode: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .padding()
            .frame(width: 150, height: 150)
            .background(color.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 5)
    }
}

struct ImageNode: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 100))
            .frame(width: 200, height: 200)
            .background(Color.gray.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 5)
    }
}

struct MockupNode: View {
    let title: String
    let content: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
            Text(content)
                .font(.system(size: 13))
        }
        .padding(15)
        .frame(width: 180, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

struct ImageMockupNode: View {
    var body: some View {
        VStack {
            Image(systemName: "photo.fill")
                .font(.largeTitle)
                .foregroundColor(.gray.opacity(0.3))
        }
        .frame(width: 200, height: 150)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
}

struct MoodboardCard: View {
    let imageURL: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MOODBOARD")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            AsyncImage(url: URL(string: imageURL)) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 200, height: 140)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 200, height: 140)
                        .overlay(ProgressView())
                }
            }

            Text(caption)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10)
    }
}

#Preview {
    VStack(spacing: 20) {
        NoteNode(text: "A sample note", color: .yellow)
        MockupNode(title: "Feature", content: "Some description", color: .blue)
    }
    .padding()
}
