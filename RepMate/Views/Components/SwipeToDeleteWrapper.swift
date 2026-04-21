import SwiftUI

/// Adds swipe-to-delete gesture to list items.
struct SwipeToDeleteWrapper<Content: View>: View {
    let content: Content
    let onDelete: (() -> Void)?
    
    @State private var offset: CGFloat = 0
    @State private var previousOffset: CGFloat = 0
    @State private var isDeleting = false
    
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
            ZStack(alignment: .trailing) {
                // Delete button background
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
                .opacity(offset < 0 ? 1 : 0)
                
                // Main content
                content
                    .background(Color.white.opacity(0.001))
                    .offset(x: offset)
                    .gesture(
                        DragGesture(minimumDistance: 15, coordinateSpace: .local)
                            .onChanged { value in
                                let newOffset = previousOffset + value.translation.width
                                // Allow interactive dragging, constrained to 0
                                withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.9)) {
                                    offset = min(0, max(-deleteButtonWidth * 1.5, newOffset))
                                }
                            }
                            .onEnded { value in
                                let finalOffset = previousOffset + value.translation.width
                                
                                if finalOffset < deleteThreshold {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        offset = -deleteButtonWidth
                                        previousOffset = -deleteButtonWidth
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        offset = 0
                                        previousOffset = 0
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded { _ in
                                if offset != 0 {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        offset = 0
                                        previousOffset = 0
                                    }
                                }
                            }
                    )
            }
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
