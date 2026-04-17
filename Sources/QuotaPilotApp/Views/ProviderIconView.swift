import SwiftUI
import QuotaPilotCore

struct ProviderIconView: View {
    let provider: QuotaProvider
    var size: CGFloat = 16
    var tint: Color = .secondary

    var body: some View {
        Group {
            if let image = ProviderBrandAsset.iconImage(for: self.provider, size: self.size) {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: self.provider.symbolName)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: self.size, height: self.size)
        .foregroundStyle(self.tint)
    }
}
