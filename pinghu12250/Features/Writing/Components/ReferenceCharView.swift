//
//  ReferenceCharView.swift
//  pinghu12250
//
//  参考字显示组件
//

import SwiftUI

struct ReferenceCharView: View {
    let character: Character
    let fontName: String?
    let opacity: Double

    init(character: Character, fontName: String? = nil, opacity: Double = 0.15) {
        self.character = character
        self.fontName = fontName
        self.opacity = opacity
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            Text(String(character))
                .font(fontForDisplay(size: size * 0.8))
                .foregroundColor(.black.opacity(opacity))
                .frame(width: size, height: size)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }

    private func fontForDisplay(size: CGFloat) -> Font {
        if let fontName = fontName {
            return .custom(fontName, size: size)
        }
        // 使用楷体作为后备字体
        return .custom("STKaiti", size: size)
    }
}

#Preview {
    VStack {
        ZStack {
            GridBackgroundView(gridType: .mi)
            ReferenceCharView(character: "永")
        }
        .frame(width: 200, height: 200)
        .background(Color.white)
        .border(Color.gray)
    }
    .padding()
}
