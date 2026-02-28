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

    @Test func multipartDataContainsImageAndContent() {
        let image = UIImage(systemName: "star")!
        let imageData = image.jpegData(compressionQuality: 0.8)!
        let boundary = "TestBoundary"
        let content = "Тестовый пост"
        let club = "Собаки"

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
        #expect(bodyString.contains("name=\"content\""))
        #expect(bodyString.contains(content))
        #expect(body.count > imageData.count)
    }

}
