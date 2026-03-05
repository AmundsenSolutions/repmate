import SwiftUI

struct OledPlusButton: View {
    var action: () -> Void
    
    // Default size 44x44 as per requirements (matches standard touch target)
    // Can be scaled if needed, but fixed size ensures consistency.
    var size: CGFloat = 44
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.cardBackground)
                
                Image(systemName: "plus")
                    .font(.system(size: size * 0.45, weight: .bold)) // ~20pt for 44px
                    .foregroundColor(Theme.Colors.accent)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OledPlusButton(action: {})
    }
}
