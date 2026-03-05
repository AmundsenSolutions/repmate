//
//  HapticManager.swift
//  RepMate
//
//  Created by Aleksander Amundsen on 2026.
//

import UIKit

/// App-wide haptic feedback engine.
class HapticManager {
    /// Singleton instance.
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

    /// Selection tick.
    func selection() {
        #if !targetEnvironment(simulator)
        selectionGenerator.selectionChanged()
        #endif
    }
    
    /// Success burst.
    func success() {
        #if !targetEnvironment(simulator)
        notificationGenerator.notificationOccurred(.success)
        #endif
    }
    
    /// Error burst.
    func error() {
        #if !targetEnvironment(simulator)
        notificationGenerator.notificationOccurred(.error)
        #endif
    }
    
    /// Warning burst.
    func warning() {
        #if !targetEnvironment(simulator)
        notificationGenerator.notificationOccurred(.warning)
        #endif
    }
    
    /// Medium impact.
    func impact() {
        #if !targetEnvironment(simulator)
        impactGenerator.impactOccurred()
        #endif
    }
    
    /// Heavy impact.
    func heavyImpact() {
        #if !targetEnvironment(simulator)
        heavyImpactGenerator.impactOccurred()
        #endif
    }
    
    /// Light impact.
    func lightImpact() {
        #if !targetEnvironment(simulator)
        lightImpactGenerator.impactOccurred()
        #endif
    }
}
