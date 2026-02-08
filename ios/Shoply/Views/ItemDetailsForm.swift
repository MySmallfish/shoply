import AVFoundation
import Photos
import SwiftUI
import UIKit

struct ItemDetailsForm: View {
    @Binding var draft: ItemDetailsDraft
    let allowBarcodeEdit: Bool
    let onScanBarcode: (() -> Void)?
    @Environment(\.layoutDirection) private var layoutDirection
    @AppStorage("appLanguage") private var appLanguage = "he"
    @State private var isEditingBarcode = false

    var body: some View {
        let isRTL = appLanguage.hasPrefix("he") || appLanguage.hasPrefix("ar") || layoutDirection == .rightToLeft
        // Use semantic "leading" everywhere and rely on layoutDirection to map it to the correct edge.
        // (In RTL, leading == right; trailing == left.)
        let alignment: TextAlignment = .leading
        let canEditBarcode = allowBarcodeEdit || isEditingBarcode

        itemSection(isRTL: isRTL, alignment: alignment, canEditBarcode: canEditBarcode)
        detailsSection(isRTL: isRTL, alignment: alignment)
        IconPickerSection(icon: $draft.icon, language: appLanguage)
    }

    @ViewBuilder
    private func itemSection(isRTL: Bool, alignment: TextAlignment, canEditBarcode: Bool) -> some View {
        Section {
            TextField(L10n.string("Name", language: appLanguage), text: $draft.name)
                .multilineTextAlignment(alignment)
            HStack(spacing: 8) {
                barcodeField(alignment: alignment, canEditBarcode: canEditBarcode)
                barcodeButtons
            }
        } header: {
            sectionHeader("Item", isRTL: isRTL)
        }
    }

    private func barcodeField(alignment: TextAlignment, canEditBarcode: Bool) -> some View {
        TextField(L10n.string("Barcode", language: appLanguage), text: $draft.barcode)
            .keyboardType(.numberPad)
            .disabled(!canEditBarcode)
            .foregroundColor(canEditBarcode ? .primary : .secondary)
            .multilineTextAlignment(alignment)
    }

    @ViewBuilder
    private var barcodeButtons: some View {
        let isRTL = appLanguage.hasPrefix("he") || appLanguage.hasPrefix("ar") || layoutDirection == .rightToLeft
        if isRTL {
            if !allowBarcodeEdit && !isEditingBarcode {
                Button {
                    isEditingBarcode = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel(L10n.string("Edit", language: appLanguage))
            }

            if !draft.barcode.isEmpty {
                Button {
                    UIPasteboard.general.string = draft.barcode
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .accessibilityLabel(L10n.string("Copy", language: appLanguage))
            }

            if let onScanBarcode {
                Button {
                    onScanBarcode()
                } label: {
                    Image(systemName: "barcode.viewfinder")
                }
                .accessibilityLabel(L10n.string("Scan Barcode", language: appLanguage))
            }
        } else {
            if let onScanBarcode {
                Button {
                    onScanBarcode()
                } label: {
                    Image(systemName: "barcode.viewfinder")
                }
                .accessibilityLabel(L10n.string("Scan Barcode", language: appLanguage))
            }

            if !draft.barcode.isEmpty {
                Button {
                    UIPasteboard.general.string = draft.barcode
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .accessibilityLabel(L10n.string("Copy", language: appLanguage))
            }

            if !allowBarcodeEdit && !isEditingBarcode {
                Button {
                    isEditingBarcode = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel(L10n.string("Edit", language: appLanguage))
            }
        }
    }

    @ViewBuilder
    private func detailsSection(isRTL: Bool, alignment: TextAlignment) -> some View {
        Section {
            TextField(L10n.string("Price", language: appLanguage), text: $draft.priceText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(alignment)
            TextField(L10n.string("Description", language: appLanguage), text: $draft.descriptionText, axis: .vertical)
                .multilineTextAlignment(alignment)
        } header: {
            sectionHeader("Details", isRTL: isRTL)
        }
    }

    private func sectionHeader(_ key: String, isRTL: Bool) -> some View {
        Text(L10n.string(key, language: appLanguage))
            .frame(maxWidth: .infinity, alignment: .leading)
            .textCase(nil)
    }
}

private struct IconPickerSection: View {
    @Binding var icon: String
    let language: String
    @State private var permissionAlert: PermissionAlert?

    private let stockIcons = ["🧺", "🥛", "🍞", "🧀", "🍎", "🧴"]

    var body: some View {
        iconContent
            .alert(item: $permissionAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text(L10n.string("Open Settings", language: language)), action: {
                        openSettings()
                    }),
                    secondaryButton: .cancel(Text(L10n.string("Cancel", language: language)))
                )
            }
    }

    @ViewBuilder
    private var iconContent: some View {
        let isRTL = language.hasPrefix("he") || language.hasPrefix("ar")
        Section {
            StockIconsRow(stockIcons: stockIcons, icon: $icon)
            IconActionRow(
                icon: $icon,
                language: language,
                isRTL: isRTL,
                onCameraTap: handleCameraTap,
                onLibraryTap: handleLibraryTap
            )

            if !icon.isEmpty {
                ItemIconView(icon: icon, size: 48)
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } header: {
            Text(L10n.string("Icon", language: language))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textCase(nil)
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
            return L10n.string("Camera Access", language: currentLanguage)
        case .library:
            return L10n.string("Photo Access", language: currentLanguage)
        }
    }

    var message: String {
        switch self {
        case .camera:
            return L10n.string("Camera access is required to take item photos.", language: currentLanguage)
        case .library:
            return L10n.string("Photo library access is required to choose an item image.", language: currentLanguage)
        }
    }

    fileprivate var currentLanguage: String {
        UserDefaults.standard.string(forKey: "appLanguage") ?? "he"
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
    let language: String
    let isRTL: Bool
    let onCameraTap: () -> Void
    let onLibraryTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !icon.isEmpty {
                Button(L10n.string("Remove Icon", language: language)) {
                    icon = ""
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(.borderless)
            }

            HStack(spacing: 12) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button(action: onCameraTap) {
                        Label(L10n.string("Camera", language: language), systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                    Button(action: onLibraryTap) {
                        Label(L10n.string("Library", language: language), systemImage: "photo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
