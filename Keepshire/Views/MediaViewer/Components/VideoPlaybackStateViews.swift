import SwiftUI

struct VideoLoadingView: View {
    let fileName: String?

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text("Loading \(fileName ?? "video")...")
                .font(.headline)
                .foregroundColor(.white)
        }
    }
}

struct VideoErrorView: View {
    let errorMessage: String
    let isFormatUnsupported: Bool
    let fileName: String?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isFormatUnsupported ? "play.slash" : "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(isFormatUnsupported ? .orange : .red)

            Text(isFormatUnsupported ? "Unsupported Video Format" : "Error loading video")
                .font(.headline)
                .foregroundColor(.white)

            if let fileName = fileName {
                Text(fileName)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
                    .padding(.horizontal, 40)
            }

            Text(errorMessage)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if isFormatUnsupported {
                VStack(spacing: 8) {
                    Text("Supported formats:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))

                    Text("MP4, MOV, M4V")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 10)
            }
        }
        .padding()
    }
}
