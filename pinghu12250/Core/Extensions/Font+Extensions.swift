import SwiftUI
import UIKit
import Combine

extension Font {
    /// 楷体回退链，与Web端 'KaiTi, STKaiti, serif' 一致
    static func fallbackKaiTi(size: CGFloat) -> Font {
        for name in ["KaiTi", "STKaiti", "Kaiti SC"] {
            if UIFont(name: name, size: size) != nil {
                return .custom(name, size: size)
            }
        }
        return .system(size: size, design: .serif)
    }
}
