//
//  ImagePickerView.swift
//  Petio
//
//  Выбор аватара: галерея, камера, удаление. Вспомогательный UIImagePickerController.
//

import SwiftUI
import PhotosUI

// MARK: - AvatarPickerButton

struct AvatarPickerButton: View {
    @Binding var photoPath: String?
    let placeholder: String
    let imageName: String?
    let size: CGFloat
    var isCircle: Bool = false

    init(photoPath: Binding<String?>, placeholder: String = "🐾", imageName: String? = nil, size: CGFloat = 44, isCircle: Bool = false) {
        self._photoPath = photoPath
        self.placeholder = placeholder
        self.imageName = imageName
        self.size = size
        self.isCircle = isCircle
    }

    @State private var showOptions = false
    @State private var showGallery = false
    @State private var showCamera = false
    @State private var selectedItem: PhotosPickerItem?

    @ViewBuilder
    private var avatarContent: some View {
        if isCircle {
            CircleAvatarView(url: photoPath, fallbackLetter: placeholder, size: size)
        } else {
            AvatarView(url: photoPath, placeholder: placeholder, imageName: imageName, size: size)
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            avatarContent
            Image(systemName: "camera.fill")
                .font(.system(size: size * 0.18, weight: .medium))
                .foregroundColor(.white)
                .padding(size * 0.1)
                .background(PetCareTheme.primary)
                .clipShape(Circle())
                .offset(x: 4, y: 4)
        }
        .contentShape(Rectangle())
        .onTapGesture { showOptions = true }
        .confirmationDialog("Фото", isPresented: $showOptions, titleVisibility: .visible) {
            Button("Выбрать из галереи") { showGallery = true }
            Button("Сделать фото") { showCamera = true }
            Button("Стандартная аватарка") { photoPath = "ava_\(Int.random(in: 1...9))" }
            if photoPath != nil {
                Button("Убрать фото", role: .destructive) { photoPath = nil }
            }
            Button("Отмена", role: .cancel) { }
        }
        .photosPicker(isPresented: $showGallery, selection: $selectedItem, matching: .images)
        .sheet(isPresented: $showCamera) {
            CameraPickerView { image in
                photoPath = saveImageLocally(image)
                showCamera = false
            } onCancel: {
                showCamera = false
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    photoPath = saveImageLocally(image)
                }
            }
        }
    }
}

// MARK: - Save image to local storage

func saveImageLocally(_ image: UIImage) -> String? {
    guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
    let avatarsDir = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("avatars")
    try? FileManager.default.createDirectory(at: avatarsDir, withIntermediateDirectories: true)
    let fileURL = avatarsDir.appendingPathComponent(UUID().uuidString + ".jpg")
    try? data.write(to: fileURL)
    return fileURL.absoluteString
}

// MARK: - PostImagePickerButton

struct PostImagePickerButton: View {
    @Binding var selectedImage: UIImage?

    @State private var showOptions = false
    @State private var showGallery = false
    @State private var showCamera = false
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        Button { showOptions = true } label: {
            if let img = selectedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipped()
                    .cornerRadius(10)
                    .overlay(alignment: .topTrailing) {
                        Button {
                            selectedImage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.5).clipShape(Circle()))
                        }
                        .padding(4)
                    }
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(PetCareTheme.border, lineWidth: 1.5)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 28))
                            .foregroundColor(PetCareTheme.muted)
                    )
            }
        }
        .buttonStyle(.plain)
        .confirmationDialog("Фото", isPresented: $showOptions, titleVisibility: .visible) {
            Button("Выбрать из галереи") { showGallery = true }
            Button("Сделать фото") { showCamera = true }
            if selectedImage != nil {
                Button("Убрать фото", role: .destructive) { selectedImage = nil }
            }
            Button("Отмена", role: .cancel) { }
        }
        .photosPicker(isPresented: $showGallery, selection: $selectedItem, matching: .images)
        .sheet(isPresented: $showCamera) {
            CameraPickerView { image in
                selectedImage = image
                showCamera = false
            } onCancel: {
                showCamera = false
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
    }
}

// MARK: - CameraPickerView

struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.onCapture(image)
            } else {
                parent.onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}
