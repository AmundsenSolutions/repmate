//
//  ViewModifiers.swift
//  Vext
//
//  Created by Aleksander Amundsen on 2026.
//

import SwiftUI

// MARK: - Hide Keyboard Extension

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
