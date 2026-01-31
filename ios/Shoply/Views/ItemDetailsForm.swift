import PhotosUI
import SwiftUI

struct ItemDetailsForm: View {
    @Binding var draft: ItemDetailsDraft
    let allowBarcodeEdit: Bool
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var photoSelection: PhotosPickerItem?
    @State private var showCameraPicker = false

    private let stockIcons = ["🧺", "🥛", "🍞", "🧀", "🍎", "🧴"]

    var body: some View {
        let alignment: TextAlignment = layoutDirection == .rightToLeft ? .trailing : .leading

        Section("Item") {
            TextField("Name", text: $draft.name)
                .multilineTextAlignment(alignment)
            TextField("Barcode", text: $draft.barcode)
                .keyboardType(.numberPad)
                .disabled(!allowBarcodeEdit)
                .foregroundColor(allowBarcodeEdit ? .primary : .secondary)
                .multilineTextAlignment(alignment)
        }

        Section("Details") {
            TextField("Price", text: $draft.priceText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(alignment)
            TextField("Description", text: $draft.descriptionText, axis: .vertical)
                .multilineTextAlignment(alignment)
        }

        Section("Icon") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(stockIcons, id: \.self) { icon in
                        Button {
                            draft.icon = icon
                        } label: {
                            Text(icon)
                                .font(.system(size: 22))
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color(.secondarySystemBackground))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            HStack(spacing: 12) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCameraPicker = true
                    } label: {
                        Label("Camera", systemImage: "camera")
                    }
                }

                PhotosPicker(selection: $photoSelection, matching: .images) {
                    Label("Library", systemImage: "photo")
                }

                Spacer()

                if !draft.icon.isEmpty {
                    Button("Remove Icon") {
                        draft.icon = ""
                    }
                    .foregroundColor(.secondary)
                }
            }

            if !draft.icon.isEmpty {
                ItemIconView(icon: draft.icon, size: 48)
                    .padding(.top, 4)
            }
        }
        .onChange(of: photoSelection) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let encoded = encodeImage(image) {
                    await MainActor.run {
                        draft.icon = encoded
                    }
                }
            }
        }
        .sheet(isPresented: $showCameraPicker) {
            CameraPicker { image in
                if let encoded = encodeImage(image) {
                    draft.icon = encoded
                }
            }
        }
    }

    private func encodeImage(_ image: UIImage) -> String? {
        let maxDimension: CGFloat = 256
        let resized = resizeImage(image, maxDimension: maxDimension)
        guard let data = resized.jpegData(compressionQuality: 0.8) else { return nil }
        return "img:" + data.base64EncodedString()
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImage: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImage = onImage
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
