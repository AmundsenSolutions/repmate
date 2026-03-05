import SwiftUI

/// A wrapper that adds swipe-to-delete functionality to any content.
/// Shows a red circular delete button when swiped left.
/// Designed for minimal animation - instant deletion without affecting siblings.
struct SwipeToDeleteWrapper<Content: View>: View {
    let content: Content
    let onDelete: (() -> Void)?
    
    @State private var offset: CGFloat = 0
    @State private var isDeleting = false
    @GestureState private var dragOffset: CGFloat = 0
    
    private let deleteButtonWidth: CGFloat = 50
    private let deleteThreshold: CGFloat = -40
    
    init(onDelete: (() -> Void)?, @ViewBuilder content: () -> Content) {
        self.onDelete = onDelete
        self.content = content()
    }
    
    var body: some View {
        if onDelete == nil {
            // No delete action - just show content without swipe
            content
        } else {
            GeometryReader { geometry in
                ZStack(alignment: .trailing) {
                    // Delete button (revealed on swipe) - clear background
                    if offset < 0 || dragOffset < 0 {
                        HStack {
                            Spacer()
                            Button {
                                performDelete()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "trash.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 8)
                        }
                        .frame(width: deleteButtonWidth)
                        .background(Color.clear)
                    }
                    
                    // Main content
                    content
                        .offset(x: min(0, offset + dragOffset))
                        .gesture(
                            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                                .updating($dragOffset) { value, state, _ in
                                    // Only allow left swipe (negative translation)
                                    if value.translation.width < 0 {
                                        state = value.translation.width
                                    }
                                }
                                .onEnded { value in
                                    let totalOffset = offset + value.translation.width
                                    
                                    if totalOffset < deleteThreshold {
                                        // Reveal delete button with spring animation
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            offset = -deleteButtonWidth
                                        }
                                    } else {
                                        // Snap back with spring animation
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            offset = 0
                                        }
                                    }
                                }
                        )
                        .simultaneousGesture(
                            TapGesture()
                                .onEnded { _ in
                                    // Reset offset when tapping content
                                    if offset != 0 {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            offset = 0
                                        }
                                    }
                                }
                        )
                }
                .background(Color.clear)
            }
            .background(Color.clear)
            .frame(height: 36) // Match SetRowView height
            .clipped()
            .opacity(isDeleting ? 0 : 1)
            .offset(x: isDeleting ? -100 : 0) // Slide out when deleting
        }
    }
    
    private func performDelete() {
        HapticManager.shared.heavyImpact()
        
        // Slide out animation before deletion
        withAnimation(.easeOut(duration: 0.2)) {
            isDeleting = true
        }
        
        // Trigger delete after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            onDelete?()
        }
    }
}
