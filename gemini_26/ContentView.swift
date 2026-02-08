import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Apex26Theme.deepBackground.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Välkommen till Apex26")
                    .font(.system(.largeTitle, design: .serif))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .editorialShadow()

                Text("Projektet är nu körbart.")
                    .foregroundStyle(.secondary)

                Button {
                    // Demo action
                } label: {
                    Text("Kom igång")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Apex26Theme.accent)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .editorialShadow()
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .glassSurface()
            .padding()
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
