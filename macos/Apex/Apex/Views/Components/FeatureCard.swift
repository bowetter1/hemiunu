import SwiftUI

struct FeatureCard: View {
    let icon: String
    let title: String
    let desc: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            Text(title)
                .font(.headline)
            Text(desc)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HStack {
        FeatureCard(icon: "sparkles", title: "AI Native", desc: "AI that sees your design")
        FeatureCard(icon: "bolt.fill", title: "Fast Deploy", desc: "Go from sketch to production")
    }
    .padding()
}
