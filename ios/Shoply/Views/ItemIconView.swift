import SwiftUI

struct ItemIconView: View {
    let icon: String
    let size: CGFloat

    var body: some View {
        if icon.isEmpty {
            EmptyView()
        } else if let image = decodedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
        } else {
            Text(icon)
                .font(.system(size: size * 0.9))
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
