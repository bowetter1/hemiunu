import SwiftUI
import WebKit

struct WebViewNode: NSViewRepresentable {
    let htmlContent: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(htmlContent, baseURL: nil)
    }
}

struct Line {
    var points: [CGPoint]
}

struct DrawingLayer: View {
    @State private var lines: [Line] = []
    @State private var isDrawingMode = false

    var body: some View {
        ZStack {
            if isDrawingMode {
                Color.black.opacity(0.01)

                Canvas { context, size in
                    for line in lines {
                        var path = Path()
                        path.addLines(line.points)
                        context.stroke(path, with: .color(.blue), lineWidth: 3)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newPoint = value.location
                            if value.translation == .zero {
                                lines.append(Line(points: [newPoint]))
                            } else {
                                guard !lines.isEmpty else { return }
                                lines[lines.count - 1].points.append(newPoint)
                            }
                        }
                )
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: { isDrawingMode.toggle() }) {
                        Image(systemName: isDrawingMode ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle")
                            .font(.title)
                            .foregroundColor(isDrawingMode ? .blue : .gray)
                            .padding(8)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
                Spacer()
            }
        }
    }
}

#Preview {
    DrawingLayer()
        .frame(width: 400, height: 400)
}
