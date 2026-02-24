//
//  HapticManager.swift
//  Vext
//
//  Created by Aleksander Amundsen on 2026.
//

import UIKit

/// Centralized manager for all haptic feedback in the application.
/// Uses `UISelectionFeedbackGenerator`, `UINotificationFeedbackGenerator`, and `UIImpactFeedbackGenerator`.
class HapticManager {
    /// Shared singleton instance.
    static let shared = HapticManager()
    
    #if !targetEnvironment(simulator)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    #endif

    private init() {
        #if !targetEnvironment(simulator)
        // Prepares generators to reduce latency
        selectionGenerator.prepare()
        notificationGenerator.prepare()
        impactGenerator.prepare()
        heavyImpactGenerator.prepare()
        lightImpactGenerator.prepare()
        #endif
    }

    /// Triggers a selection feedback (e.g., picker wheels, light toggles).
    func selection() {
        #if !targetEnvironment(simulator)
        selectionGenerator.selectionChanged()
        #endif
    }
    
    /// Triggers a success notification feedback.
    func success() {
        #if !targetEnvironment(simulator)
        notificationGenerator.notificationOccurred(.success)
        #endif
    }
    
    /// Triggers an error notification feedback.
    func error() {
        #if !targetEnvironment(simulator)
        notificationGenerator.notificationOccurred(.error)
        #endif
    }
    
    /// Triggers a warning notification feedback.
    func warning() {
        #if !targetEnvironment(simulator)
        notificationGenerator.notificationOccurred(.warning)
        #endif
    }
    
    /// Triggers a medium impact feedback (e.g., buttons, collisions).
    func impact() {
        #if !targetEnvironment(simulator)
        impactGenerator.impactOccurred()
        #endif
    }
    
    /// Triggers a heavy impact feedback.
    func heavyImpact() {
        #if !targetEnvironment(simulator)
        heavyImpactGenerator.impactOccurred()
        #endif
    }
    
    /// Triggers a light impact feedback.
    func lightImpact() {
        #if !targetEnvironment(simulator)
        lightImpactGenerator.impactOccurred()
        #endif
    }
}
