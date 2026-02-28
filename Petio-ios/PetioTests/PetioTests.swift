//
//  PetioTests.swift
//  PetioTests
//
//  Created by Мирсаит Сабирзянов on 18.02.2026.
//

import Testing
import UIKit
@testable import Petio

struct PetioTests {

    // Creates a solid 1x1 red pixel UIImage — reliable JPEG encoding, no symbol/SF image dependencies.
    private func makeSolidImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        return renderer.image { ctx in ctx.cgContext.setFillColor(UIColor.red.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1)) }
    }

    @Test func jpegDataProducedFromSolidImage() {
        let image = makeSolidImage()
        let imageData = image.jpegData(compressionQuality: 0.8)
        #expect(imageData != nil)
        #expect((imageData?.count ?? 0) > 0)
    }

    @Test func multipartBodyStructure() {
        let imageData = makeSolidImage().jpegData(compressionQuality: 0.8)!
        let boundary = "TestBoundary"
        let content = "Тестовый пост"

        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\r\n")
        append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        append("\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"content\"\r\n\r\n")
        append(content)
        append("\r\n")
        append("--\(boundary)--\r\n")

        let bodyString = String(data: body, encoding: .utf8) ?? ""
        #expect(bodyString.contains("name=\"image\""))
        #expect(bodyString.contains("filename=\"photo.jpg\""))
        #expect(bodyString.contains("Content-Type: image/jpeg"))
        #expect(bodyString.contains("name=\"content\""))
        #expect(bodyString.contains(content))
        #expect(bodyString.hasSuffix("--\(boundary)--\r\n"))
        #expect(body.count > imageData.count)
    }

}
