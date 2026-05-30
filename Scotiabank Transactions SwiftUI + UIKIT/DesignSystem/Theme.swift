//
//  Theme.swift
//  Scotiabank Transactions SwiftUI + UIKIT
//
//  Central design tokens shared by the SwiftUI list screen and the UIKit detail
//  screen, so the two stay visually consistent and the palette changes in one place.
//
//  Colours are semantic and adapt to Light/Dark Mode. Where a colour must match
//  Scotiabank brand exactly (red, the credit green) it's defined explicitly;
//  everything else uses system semantic colours so the app is correct in both
//  appearances for free.
//

import SwiftUI
import UIKit

enum Theme {

    enum Palette {
        /// Scotiabank brand red — toolbar background and the detail Close button.
        static let brandRed = Color(red: 0xDA / 255, green: 0x1A / 255, blue: 0x32 / 255)
        static let brandRedUI = UIColor(red: 0xDA / 255, green: 0x1A / 255, blue: 0x32 / 255, alpha: 1)

        /// Green for CREDIT amounts. A fixed pair (not `.systemGreen`) so it
        /// reads well on both light and dark backgrounds, matching the live app.
        static let creditUI = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0x3F / 255, green: 0xD0 / 255, blue: 0x8D / 255, alpha: 1)
                : UIColor(red: 0x12 / 255, green: 0x8A / 255, blue: 0x52 / 255, alpha: 1)
        }
        static let credit = Color(uiColor: creditUI)

        /// Link/affordance blue — the detail ToolTip's "Show more"/"Show less"
        /// toggle (Figure 1). A fixed brand-leaning blue rather than `.systemBlue`
        /// so it matches the design in both appearances.
        static let linkUI = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0x4D / 255, green: 0xA6 / 255, blue: 0xFF / 255, alpha: 1)
                : UIColor(red: 0x00 / 255, green: 0x5A / 255, blue: 0xA0 / 255, alpha: 1)
        }
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32

        static let checkmarkDiameter: CGFloat = 56
        /// Apple HIG minimum interactive target.
        static let minTapTarget: CGFloat = 44
    }
}
