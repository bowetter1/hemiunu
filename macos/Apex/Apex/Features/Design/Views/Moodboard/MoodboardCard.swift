import SwiftUI

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
