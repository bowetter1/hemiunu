import SwiftUI

// MARK: - Generation Cards

struct GeneratingCard: View {
    @State private var dotCount = 0

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 28, height: 28)
                .background(Color.blue.opacity(0.15))
                .cornerRadius(6)

            Text("Generating\(String(repeating: ".", count: dotCount))")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)

        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                dotCount = (dotCount + 1) % 4
            }
        }
    }
}

struct GenerationResultCard: View {
    let result: GenerateSiteResponse
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
                    .frame(width: 28, height: 28)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(6)

                Text("Generated!")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(10)

            // List created pages
            VStack(alignment: .leading, spacing: 4) {
                ForEach(result.pagesCreated, id: \.self) { page in
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text(page)
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

struct ErrorCard: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14))
                .foregroundColor(.red)
                .frame(width: 28, height: 28)
                .background(Color.red.opacity(0.15))
                .cornerRadius(6)

            Text(message)
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .lineLimit(2)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}
