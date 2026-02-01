import AVFoundation
import Photos
import SwiftUI
import UIKit

struct ItemDetailsForm: View {
    @Binding var draft: ItemDetailsDraft
    let allowBarcodeEdit: Bool
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var isEditingBarcode = false

    var body: some View {
        let alignment: TextAlignment = layoutDirection == .rightToLeft ? .trailing : .leading
        let canEditBarcode = allowBarcodeEdit || isEditingBarcode

        itemSection(alignment: alignment, canEditBarcode: canEditBarcode)
        detailsSection(alignment: alignment)
        IconPickerSection(icon: $draft.icon)
    }

    @ViewBuilder
    private func itemSection(alignment: TextAlignment, canEditBarcode: Bool) -> some View {
        Section("Item") {
            TextField("Name", text: $draft.name)
                .multilineTextAlignment(alignment)
            HStack(spacing: 8) {
                TextField("Barcode", text: $draft.barcode)
                    .keyboardType(.numberPad)
                    .disabled(!canEditBarcode)
                    .foregroundColor(canEditBarcode ? .primary : .secondary)
                    .multilineTextAlignment(alignment)

                if !draft.barcode.isEmpty {
                    Button {
                        UIPasteboard.general.string = draft.barcode
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .accessibilityLabel(NSLocalizedString("Copy", comment: ""))
                }

                if !allowBarcodeEdit && !isEditingBarcode {
                    Button {
                        isEditingBarcode = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel(NSLocalizedString("Edit", comment: ""))
                }
            }
        }
    }

    @ViewBuilder
    private func detailsSection(alignment: TextAlignment) -> some View {
        Section("Details") {
            TextField("Price", text: $draft.priceText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(alignment)
            TextField("Description", text: $draft.descriptionText, axis: .vertical)
                .multilineTextAlignment(alignment)
        }
    }
}

private struct IconPickerSection: View {
    @Binding var icon: String
    @State private var permissionAlert: PermissionAlert?

    private let stockIcons = ["🧺", "🥛", "🍞", "🧀", "🍎", "🧴"]

    var body: some View {
        iconContent
            .alert(item: $permissionAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text(NSLocalizedString("Open Settings", comment: "")), action: {
                        openSettings()
                    }),
                    secondaryButton: .cancel(Text(NSLocalizedString("Cancel", comment: "")))
                )
            }
    }

    private var iconContent: some View {
        Section("Icon") {
            StockIconsRow(stockIcons: stockIcons, icon: $icon)
            IconActionRow(icon: $icon, onCameraTap: handleCameraTap, onLibraryTap: handleLibraryTap)

            if !icon.isEmpty {
                ItemIconView(icon: icon, size: 48)
                    .padding(.top, 4)
            }
        }
    }

    private func handleCameraTap() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            presentPicker(source: .camera)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        presentPicker(source: .camera)
                    } else {
                        permissionAlert = .camera
                    }
                }
            }
        default:
            permissionAlert = .camera
        }
    }

    private func handleLibraryTap() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            presentPicker(source: .photoLibrary)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        presentPicker(source: .photoLibrary)
                    } else {
                        permissionAlert = .library
                    }
                }
            }
        default:
            permissionAlert = .library
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func presentPicker(source: UIImagePickerController.SourceType) {
        ImagePickerPresenter.shared.present(sourceType: source) { image in
            guard let image else { return }
            if let encoded = ItemIconEncoding.encode(image) {
                icon = encoded
            }
        }
    }
}

private enum PermissionAlert: Identifiable {
    case camera
    case library

    var id: Int {
        switch self {
        case .camera: return 0
        case .library: return 1
        }
    }

    var title: String {
        switch self {
        case .camera:
            return NSLocalizedString("Camera Access", comment: "")
        case .library:
            return NSLocalizedString("Photo Access", comment: "")
        }
    }

    var message: String {
        switch self {
        case .camera:
            return NSLocalizedString("Camera access is required to take item photos.", comment: "")
        case .library:
            return NSLocalizedString("Photo library access is required to choose an item image.", comment: "")
        }
    }
}

enum ItemIconEncoding {
    static func encode(_ image: UIImage) -> String? {
        let maxDimension: CGFloat = 256
        let resized = resizeImage(image, maxDimension: maxDimension)
        guard let data = resized.jpegData(compressionQuality: 0.8) else { return nil }
        return "img:" + data.base64EncodedString()
    }

    private static func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
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

final class ImagePickerPresenter: NSObject {
    static let shared = ImagePickerPresenter()

    private var onImage: ((UIImage?) -> Void)?
    private var isPresenting = false

    func present(sourceType: UIImagePickerController.SourceType, onImage: @escaping (UIImage?) -> Void) {
        DispatchQueue.main.async {
            guard !self.isPresenting else {
                return
            }
            guard let topController = self.topViewController() else {
                return
            }
            self.isPresenting = true
            self.onImage = onImage

            let picker = UIImagePickerController()
            picker.sourceType = sourceType
            picker.mediaTypes = ["public.image"]
            picker.delegate = self
            topController.present(picker, animated: true)
        }
    }

    private func finish(with image: UIImage?, picker: UIImagePickerController) {
        onImage?(image)
        onImage = nil
        isPresenting = false
        picker.dismiss(animated: true)
    }

    private func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        var controller = keyWindow?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}

extension ImagePickerPresenter: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        if let image = info[.originalImage] as? UIImage {
            finish(with: image, picker: picker)
        } else {
            finish(with: nil, picker: picker)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        finish(with: nil, picker: picker)
    }
}


private struct StockIconsRow: View {
    let stockIcons: [String]
    @Binding var icon: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(stockIcons, id: \.self) { iconValue in
                    Button {
                        icon = iconValue
                    } label: {
                        Text(iconValue)
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
    }
}

private struct IconActionRow: View {
    @Binding var icon: String
    let onCameraTap: () -> Void
    let onLibraryTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button(action: onCameraTap) {
                    Label("Camera", systemImage: "camera")
                }
                .buttonStyle(.borderless)
            }

            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                Button(action: onLibraryTap) {
                    Label("Library", systemImage: "photo")
                }
                .buttonStyle(.borderless)
            }

            Spacer()

            if !icon.isEmpty {
                Button("Remove Icon") {
                    icon = ""
                }
                .foregroundColor(.secondary)
                .buttonStyle(.borderless)
            }
        }
    }
}
