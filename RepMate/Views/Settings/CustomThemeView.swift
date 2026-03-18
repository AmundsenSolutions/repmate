import SwiftUI

struct CustomThemeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: AppDataStore // For preview data if needed
    @EnvironmentObject var themeManager: ThemeManager
    
    // Local State for color manipulation
    @State private var hue: Double = 0.5
    @State private var previewColor: Color = .blue
    
    var body: some View {
        ZStack {
            // 1. Background (Heavy Blur over everything)
            Color.black.ignoresSafeArea()
            
            // Background ambient glow matching the selected color
            previewColor
                .opacity(0.15)
                .blur(radius: 100)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Header
                Text("Create Custom Theme")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                // 2. Live Preview Card (Mini HomeView)
                VStack(spacing: 16) {
                    // Mini Protein Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("🔥 12 day streak")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(previewColor.opacity(0.2))
                                .cornerRadius(4)
                            Spacer()
                        }
                        
                        Text("Today's Protein")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        HStack(alignment: .firstTextBaseline) {
                            Text("185")
                                .font(.system(size: 40, weight: .regular, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: previewColor.opacity(0.8), radius: 8)
                            
                            Text("g")
                                .font(.system(size: 20, weight: .medium, design: .rounded))
                                .foregroundColor(previewColor)
                        }
                    }
                    .padding(16)
                    .background(
                        ZStack {
                            Rectangle().fill(.ultraThinMaterial).opacity(0.9)
                            LinearGradient(colors: [previewColor.opacity(0.1), .clear], startPoint: .top, endPoint: .bottom)
                        }
                    )
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(colors: [previewColor.opacity(0.6), previewColor.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: previewColor.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    // Mini "Start Workout" Button
                    HStack {
                        Text("Start Workout")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(12)
                    .background(
                        ZStack {
                            Capsule().fill(.ultraThinMaterial)
                            Capsule().fill(previewColor.opacity(0.2))
                        }
                    )
                    .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                }
                .padding(24)
                .background(.ultraThinMaterial) // Frame for the preview area
                .cornerRadius(24)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .padding(.horizontal, 24)
                
                // 3. Controls
                VStack(spacing: 24) {
                    Text("Select Accent Color")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    // Custom Hue Slider
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Gradient Bar
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hue: 0.0, saturation: 1, brightness: 1),
                                    Color(hue: 0.1, saturation: 1, brightness: 1),
                                    Color(hue: 0.2, saturation: 1, brightness: 1),
                                    Color(hue: 0.3, saturation: 1, brightness: 1),
                                    Color(hue: 0.4, saturation: 1, brightness: 1),
                                    Color(hue: 0.5, saturation: 1, brightness: 1),
                                    Color(hue: 0.6, saturation: 1, brightness: 1),
                                    Color(hue: 0.7, saturation: 1, brightness: 1),
                                    Color(hue: 0.8, saturation: 1, brightness: 1),
                                    Color(hue: 0.9, saturation: 1, brightness: 1),
                                    Color(hue: 1.0, saturation: 1, brightness: 1)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(height: 20)
                            .cornerRadius(10)
                            
                            // Glowing Knob
                            Circle()
                                .fill(previewColor)
                                .frame(width: 32, height: 32)
                                .shadow(color: previewColor, radius: 10)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .offset(x: CGFloat(hue) * (geo.size.width - 32))
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let width = geo.size.width - 32
                                            var newHue = value.location.x / width
                                            newHue = max(0, min(1, newHue))
                                            self.hue = Double(newHue)
                                            updateColor()
                                        }
                                )
                        }
                    }
                    .frame(height: 32)
                    .padding(.horizontal, 32)
                }
                
                Spacer()
                
                // 4. Actions
                HStack(spacing: 16) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                    }
                    
                    Button {
                        saveTheme()
                    } label: {
                        Text("Save Theme")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                            .background(
                                ZStack {
                                    Rectangle().fill(.ultraThinMaterial)
                                    previewColor.opacity(0.6)
                                }
                            )
                            .cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.3), lineWidth: 1))
                            .shadow(color: previewColor.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            // Initialize with current custom color or active accent
            if themeManager.activeTheme == .custom {
                // If already custom, try to match hue (approximate)
                // Since extraction is hard, we just default to existing customColor
                previewColor = themeManager.customColor
            } else {
                // Default to blue
                previewColor = Color.blue
                hue = 0.66
            }
        }
    }
    
    private func updateColor() {
        // Convert Hue to Color
        previewColor = Color(hue: hue, saturation: 1.0, brightness: 1.0)
    }
    
    private func saveTheme() {
        themeManager.customColor = previewColor
        themeManager.activeTheme = .custom
        HapticManager.shared.success()
        dismiss()
    }
}

#Preview {
    CustomThemeView()
        .environmentObject(AppDataStore())
        .environmentObject(ThemeManager.shared)
}
