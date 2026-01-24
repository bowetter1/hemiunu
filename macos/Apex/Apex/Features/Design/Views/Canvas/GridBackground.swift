import SwiftUI

struct InfiniteGrid: View {
    var dotSpacing: CGFloat = 50
    var dotSize: CGFloat = 2
    var dotOpacity: Double = 0.3

    var body: some View {
        Canvas { context, size in
            for x in stride(from: 0, through: size.width, by: dotSpacing) {
                for y in stride(from: 0, through: size.height, by: dotSpacing) {
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(.black.opacity(dotOpacity)))
                }
            }
        }
        .frame(width: 10000, height: 10000)
        .background(Color.gray.opacity(0.1))
    }
}

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

#Preview {
    GridBackground()
        .frame(width: 400, height: 400)
}
