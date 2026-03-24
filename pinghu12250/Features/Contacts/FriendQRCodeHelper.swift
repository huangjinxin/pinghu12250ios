//
//  FriendQRCodeHelper.swift
//  pinghu12250
//
//  好友二维码协议辅助
//

import Foundation
import CoreImage.CIFilterBuiltins
import UIKit

enum FriendQRCodeHelper {
    static func payload(for userId: String) -> String {
        "pinghu://friend?userId=\(userId)"
    }

    static func parseUserId(from code: String) -> String? {
        guard let components = URLComponents(string: code),
              components.scheme == "pinghu",
              components.host == "friend",
              let userId = components.queryItems?.first(where: { $0.name == "userId" })?.value,
              !userId.isEmpty else {
            return nil
        }
        return userId
    }

    static func generateQRCodeImage(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 12, y: 12)
        let scaledImage = outputImage.transformed(by: transform)
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
