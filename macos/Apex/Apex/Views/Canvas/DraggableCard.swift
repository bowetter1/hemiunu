import SwiftUI

struct DraggableCard<Content: View>: View {
    @State private var offset: CGSize
    @State private var lastOffset: CGSize
    let content: Content

    init(initialOffset: CGSize = .zero, @ViewBuilder content: () -> Content) {
        self._offset = State(initialValue: initialOffset)
        self._lastOffset = State(initialValue: initialOffset)
        self.content = content()
    }

    var body: some View {
        content
            .offset(offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
            .onHover { isHovering in
                if isHovering { NSCursor.openHand.push() }
                else { NSCursor.pop() }
            }
    }
}

#Preview {
    DraggableCard(initialOffset: .zero) {
        Text("Drag me!")
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    .frame(width: 400, height: 400)
}
