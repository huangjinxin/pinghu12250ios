//
//  SplitContainerView.swift
//  pinghu12250
//
//  双栏布局容器 - 横屏分栏，竖屏全屏
//

import SwiftUI

struct SplitContainerView<Sidebar: View, Detail: View>: View {
    @Environment(\.adaptiveLayout) var layout
    @Binding var selectedItem: AnyHashable?

    let sidebar: Sidebar
    let detail: (AnyHashable?) -> Detail

    init(
        selectedItem: Binding<AnyHashable?>,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder detail: @escaping (AnyHashable?) -> Detail
    ) {
        self._selectedItem = selectedItem
        self.sidebar = sidebar()
        self.detail = detail
    }

    var body: some View {
        if layout.isLandscape {
            landscapeLayout
        } else {
            portraitLayout
        }
    }

    private var landscapeLayout: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                sidebar
                    .frame(width: geometry.size.width * 0.33)

                Divider()

                detail(selectedItem)
                    .frame(width: geometry.size.width * 0.67)
            }
        }
    }

    private var portraitLayout: some View {
        NavigationStack {
            sidebar
        }
    }
}
