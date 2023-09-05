//
//  View - New Windows.swift
//  Cork
//
//  Created by David Bureš on 22.07.2022.
//

import SwiftUI

extension View
{
    @MainActor
    private func newWindowInternal(with title: String) -> NSWindow
    {
        let window = NSWindow(
            contentRect: NSRect(x: 20, y: 20, width: 680, height: 600),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.isReleasedWhenClosed = false
        window.title = title
        window.makeKeyAndOrderFront(nil)
        return window
    }
    
    @MainActor
    func openNewWindow(with title: String = "new Window")
    {
        newWindowInternal(with: title).contentView = NSHostingView(rootView: self)
    }
}
