//
//  FriendQRScannerView.swift
//  pinghu12250
//
//  好友二维码扫描
//

import SwiftUI
import AVFoundation

struct FriendQRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    var onScanUserId: ((String) -> Void)?
    @State private var scannedCode: String?
    @State private var isProcessing = false
    @State private var resultMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                QRCameraView(scannedCode: $scannedCode)
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white, lineWidth: 2)
                        .frame(width: 240, height: 240)
                        .background(.clear)
                    Spacer()

                    if let msg = resultMessage {
                        Text(msg)
                            .font(.subheadline)
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .padding(.bottom, 40)
                    } else {
                        Text("扫描好友二维码")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("扫一扫加好友")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
            .onChange(of: scannedCode) { _, code in
                guard let code, !isProcessing else { return }
                handleScan(code)
            }
        }
    }

    private func handleScan(_ code: String) {
        isProcessing = true

        guard let userId = FriendQRCodeHelper.parseUserId(from: code) else {
            resultMessage = "无法识别的好友二维码"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isProcessing = false
                resultMessage = nil
            }
            return
        }

        onScanUserId?(userId)
        dismiss()
    }
}
