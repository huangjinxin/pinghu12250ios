//
//  MomentsViewModel.swift
//  pinghu12250
//
//  朋友圈视图模型
//

import SwiftUI
import Combine

@MainActor
class MomentsViewModel: ObservableObject {
    @Published var moments: [Moment] = []

    func loadMoments() {
        moments = [
            Moment(id: "m1", userName: "小明", content: "今天学会了桂林山水这一课！", timestamp: Date().addingTimeInterval(-7200), likes: 10, comments: 3),
            Moment(id: "m2", userName: "小红", content: "完成了数学作业，好开心！", timestamp: Date().addingTimeInterval(-86400), likes: 5, comments: 1),
            Moment(id: "m3", userName: "小刚", content: "获得了学习之星奖励🌟", timestamp: Date().addingTimeInterval(-172800), likes: 15, comments: 5)
        ]
    }
}
