import AVFoundation
import FirebaseFirestore
import Photos
import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage("appLanguage") private var appLanguage = "he"
    @AppStorage("fontSizeOption") private var fontSizeOption = "default"

    @State private var fullName = ""
    @State private var notificationEmail = ""
    @State private var avatarIcon = ""

    @State private var isLoaded = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var permissionAlert: PermissionAlert?

    private let db = Firestore.firestore()

    var body: some View {
        let isRTL = appLanguage.hasPrefix("he") || appLanguage.hasPrefix("ar")
        NavigationStack {
            Form {
                profileSection(isRTL: isRTL)
                displaySection(isRTL: isRTL)
            }
            .navigationTitle(L10n.string("Settings", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("Close", language: appLanguage)) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("Save", language: appLanguage)) {
                        saveProfile()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                    .disabled(isSaving)
                }
            }
            .onAppear { loadIfNeeded() }
            .alert(item: $permissionAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text(L10n.string("Open Settings", language: appLanguage))) {
                        openSettings()
                    },
                    secondaryButton: .cancel(Text(L10n.string("Cancel", language: appLanguage)))
                )
            }
            .alert(
                L10n.string("Save failed", language: appLanguage),
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button(L10n.string("OK", language: appLanguage)) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
    }

    @ViewBuilder
    private func profileSection(isRTL: Bool) -> some View {
        Section {
            if !avatarIcon.isEmpty {
                HStack {
                    Spacer(minLength: 0)
                    ItemIconView(icon: avatarIcon, size: 72)
                    Spacer(minLength: 0)
                }
            }

            HStack(spacing: 12) {
                Button {
                    handleCameraTap()
                } label: {
                    Label(L10n.string("Camera", language: appLanguage), systemImage: "camera")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)

                Button {
                    handleLibraryTap()
                } label: {
                    Label(L10n.string("Library", language: appLanguage), systemImage: "photo")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }

            if !avatarIcon.isEmpty {
                Button(L10n.string("Remove Photo", language: appLanguage), role: .destructive) {
                    avatarIcon = ""
                }
            }

            TextField(L10n.string("Full Name", language: appLanguage), text: $fullName)
                .multilineTextAlignment(isRTL ? .trailing : .leading)
                .environment(\.layoutDirection, .leftToRight)
            TextField(L10n.string("Notification Email", language: appLanguage), text: $notificationEmail)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .multilineTextAlignment(isRTL ? .trailing : .leading)
                .environment(\.layoutDirection, .leftToRight)

            if let email = session.user?.email, !email.isEmpty {
                Text(String(format: L10n.string("Signed in as %@", language: appLanguage), email))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                    .environment(\.layoutDirection, .leftToRight)
            }
        } header: {
            Text(L10n.string("Profile", language: appLanguage))
                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                .textCase(nil)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    @ViewBuilder
    private func displaySection(isRTL: Bool) -> some View {
        Section {
            Picker(L10n.string("Font Size", language: appLanguage), selection: $fontSizeOption) {
                Text(L10n.string("Small", language: appLanguage)).tag("small")
                Text(L10n.string("Default", language: appLanguage)).tag("default")
                Text(L10n.string("Large", language: appLanguage)).tag("large")
            }
            .pickerStyle(.segmented)

            Text(L10n.string("Font size preview", language: appLanguage))
                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                .environment(\.layoutDirection, .leftToRight)
        } header: {
            Text(L10n.string("Display", language: appLanguage))
                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                .textCase(nil)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    private func loadIfNeeded() {
        guard !isLoaded else { return }
        guard let user = session.user else { return }
        isLoaded = true
        let fallbackName = user.displayName ?? ""
        let fallbackEmail = user.email ?? ""
        fullName = fallbackName
        notificationEmail = fallbackEmail

        db.collection("users").document(user.uid).getDocument { snapshot, _ in
            guard let data = snapshot?.data() else { return }
            if let displayName = data["displayName"] as? String, !displayName.isEmpty {
                fullName = displayName
            }
            if let notifyEmail = data["notificationEmail"] as? String, !notifyEmail.isEmpty {
                notificationEmail = notifyEmail
            }
            if let icon = data["avatarIcon"] as? String {
                avatarIcon = icon
            }
        }
    }

    private func saveProfile() {
        guard let user = session.user else { return }
        isSaving = true
        errorMessage = nil
        var updates: [String: Any] = [
            "displayName": fullName.trimmingCharacters(in: .whitespacesAndNewlines),
            "notificationEmail": notificationEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        updates["avatarIcon"] = avatarIcon.isEmpty ? FieldValue.delete() : avatarIcon

        db.collection("users").document(user.uid).setData(updates, merge: true) { error in
            isSaving = false
            if let error {
                errorMessage = error.localizedDescription
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

    private func presentPicker(source: UIImagePickerController.SourceType) {
        ImagePickerPresenter.shared.present(sourceType: source) { image in
            guard let image else { return }
            if let encoded = ItemIconEncoding.encode(image) {
                avatarIcon = encoded
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
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
