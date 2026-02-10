import SwiftUI

/// Glass popover shown when user clicks an element in the preview.
/// Two modes: action picker → inline text input.
struct ElementPopover: View {
    let element: ClickedElement
    let onSubmit: (String) -> Void
    let onDismiss: () -> Void

    @State private var mode: Mode = .actions
    @State private var inputText: String = ""
    @FocusState private var inputFocused: Bool

    private enum Mode {
        case actions
        case editText
        case describe
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.001)
                .onTapGesture { onDismiss() }

            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().opacity(0.5)

                switch mode {
                case .actions:
                    actionButtons
                case .editText, .describe:
                    inputField
                }
            }
            .frame(width: 300)
            .glassEffect(.regular, in: .rect(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
            .position(x: element.screenX, y: element.screenY - 20)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: iconForTag(element.tag))
                .font(.system(size: 11))
                .foregroundStyle(.blue)

            Text(element.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Text(element.selector)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 0) {
            actionButton(icon: "pencil", label: "Edit text") {
                inputText = element.text
                mode = .editText
                inputFocused = true
            }
            actionButton(icon: "text.bubble", label: "Describe change…") {
                inputText = ""
                mode = .describe
                inputFocused = true
            }
        }
        .padding(.vertical, 4)
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Input Field

    private var inputField: some View {
        HStack(spacing: 6) {
            TextField(placeholder, text: $inputText, axis: .vertical)
                .font(.system(size: 12))
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($inputFocused)
                .onSubmit { submit() }

            Button(action: submit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(inputText.isEmpty ? Color(nsColor: .tertiaryLabelColor) : Color.blue)
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty)
        }
        .padding(10)
    }

    private var placeholder: String {
        mode == .editText ? "Edit text…" : "Describe the change…"
    }

    private func submit() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        let instruction: String
        switch mode {
        case .editText:
            instruction = "Change the text of `\(element.selector)` to: \"\(text)\""
        case .describe:
            instruction = "For `\(element.selector)` (\(element.tag.lowercased())): \(text)"
        case .actions:
            return
        }
        onSubmit(instruction)
    }

    // MARK: - Helpers

    private func iconForTag(_ tag: String) -> String {
        switch tag.lowercased() {
        case "h1", "h2", "h3": "textformat.size"
        case "p": "text.alignleft"
        case "button", "a": "cursorarrow.click"
        case "img": "photo"
        case "section": "rectangle.3.group"
        case "nav": "menubar.rectangle"
        case "footer": "dock.rectangle"
        default: "square.dashed"
        }
    }
}
