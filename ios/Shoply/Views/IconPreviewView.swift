import SwiftUI

struct IconPreviewView: View {
    let icon: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image = decodedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(24)
            } else {
                Text(icon)
                    .font(.system(size: 120))
                    .foregroundColor(.white)
            }
        }
        .onTapGesture {
            dismiss()
        }
    }

    private var decodedImage: UIImage? {
        guard icon.hasPrefix("img:") else { return nil }
        let payload = String(icon.dropFirst(4))
        guard let data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters) else {
            return nil
        }
        return UIImage(data: data)
    }
}
