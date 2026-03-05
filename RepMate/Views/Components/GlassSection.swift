import SwiftUI

/// Reusable Cyber Glass style section wrapper.
struct GlassSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                content
            }
            .oledCard()
        }
    }
}
