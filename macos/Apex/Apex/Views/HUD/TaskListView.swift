import SwiftUI

struct TaskListView: View {
    @ObservedObject var client: ApexClient

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI AGENT")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            if client.logs.isEmpty {
                Text("No activity yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(client.logs.suffix(5)) { log in
                    LogRow(log: log)
                }
            }

            if let question = client.pendingQuestion {
                Divider()
                QuestionView(question: question) { answer in
                    Task {
                        if let sprintId = client.currentSprint?.id {
                            try? await client.answerQuestion(
                                sprintId: sprintId,
                                questionId: question.id,
                                answer: answer
                            )
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 280)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.2), lineWidth: 1))
    }
}

struct LogRow: View {
    let log: LogEntry

    var icon: String {
        switch log.logType {
        case .info: return "info.circle"
        case .phase: return "flag"
        case .workerStart: return "play.circle"
        case .workerDone: return "checkmark.circle"
        case .toolCall: return "wrench"
        case .toolResult: return "doc.text"
        case .thinking: return "brain"
        case .parallelStart: return "arrow.triangle.branch"
        case .parallelDone: return "arrow.triangle.merge"
        case .error: return "exclamationmark.triangle"
        case .success: return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch log.logType {
        case .info: return .secondary
        case .phase: return .blue
        case .workerStart: return .cyan
        case .workerDone: return .green
        case .toolCall: return .orange
        case .toolResult: return .purple
        case .thinking: return .cyan
        case .parallelStart: return .yellow
        case .parallelDone: return .yellow
        case .error: return .red
        case .success: return .green
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            Text(log.message)
                .font(.system(size: 12))
                .lineLimit(2)
                .foregroundColor(.primary)
            Spacer()
        }
    }
}

struct QuestionView: View {
    let question: AIQuestion
    let onAnswer: (String) -> Void

    @State private var customAnswer = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.question)
                .font(.system(size: 13, weight: .medium))

            if let options = question.options {
                ForEach(options, id: \.self) { option in
                    Button(action: { onAnswer(option) }) {
                        Text(option)
                            .font(.system(size: 12))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                TextField("Custom answer...", text: $customAnswer)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                Button("Send") {
                    onAnswer(customAnswer)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    TaskListView(client: ApexClient())
        .padding()
}
