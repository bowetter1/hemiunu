import SwiftUI

struct GridBackground: View {
    var dotSpacing: CGFloat = 40
    var dotSize: CGFloat = 1.5
    var dotOpacity: Double = 0.2

    var body: some View {
        Canvas { context, size in
            for x in stride(from: 0, through: size.width, by: dotSpacing) {
                for y in stride(from: 0, through: size.height, by: dotSpacing) {
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(.gray.opacity(dotOpacity)))
                }
            }
        }
    }
}
