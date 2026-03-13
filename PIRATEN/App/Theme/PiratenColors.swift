//
//  PiratenColors.swift
//  PIRATEN
//
//  Created by Claude Code on 22.02.26.
//

import SwiftUI
import UIKit

extension Color {
    /// Primary brand color (#FF8800 light, #FF9A1A dark)
    /// Used for titles, icons, CTAs
    static let piratenPrimary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.604, blue: 0.102, alpha: 1.0)  // #FF9A1A
            : UIColor(red: 1.0, green: 0.533, blue: 0.0, alpha: 1.0)    // #FF8800
    })

    /// Background color — warm peach light, warm dark
    /// Used for full-screen backgrounds
    static let piratenBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.110, green: 0.102, blue: 0.090, alpha: 1.0)  // #1C1A17
        : UIColor(red: 252/255, green: 248/255, blue: 244/255, alpha: 0.5)    // #fcf8f4
    })

    /// Surface color for cards and elevated areas
    static let piratenSurface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.173, green: 0.165, blue: 0.153, alpha: 1.0)  // #2C2A27
            : UIColor.white
    })

    /// Light orange background for unread items (forum topics, messages)
    static let piratenUnreadBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.200, green: 0.150, blue: 0.080, alpha: 1.0)  // warm dark tint
            : UIColor(red: 1.0, green: 0.953, blue: 0.910, alpha: 1.0)    // #FFF3E8
    })

    /// Icon button background — peach tint for toolbar icon circles
    static let piratenIconBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.239, green: 0.180, blue: 0.102, alpha: 1.0)  // #3D2E1A
            //: UIColor(red: 1.0, green: 0.878, blue: 0.749, alpha: 1.0)    // #FFE0BF
            : UIColor.white
    })
}
