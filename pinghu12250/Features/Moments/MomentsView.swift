//
//  MomentsView.swift
//  pinghu12250
//
//  朋友圈视图
//

import SwiftUI

struct MomentsView: View {
    @StateObject private var vm = MomentsViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.lg) {
                ForEach(vm.moments) { moment in
                    MomentCardView(moment: moment)
                }
            }
            .padding()
        }
        .navigationTitle("朋友圈")
        .refreshable {
            vm.loadMoments()
        }
        .task {
            vm.loadMoments()
        }
    }
}
