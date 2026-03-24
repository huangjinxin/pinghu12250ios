//
//  ShoppingView.swift
//  pinghu12250
//
//  独立购物页面 - 从作品广场中提取
//

import SwiftUI

struct ShoppingView: View {
    @StateObject private var viewModel = WorksViewModel()

    var body: some View {
        QRProductsView(viewModel: viewModel)
    }
}
