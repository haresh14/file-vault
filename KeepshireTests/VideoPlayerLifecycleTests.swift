import Testing
@testable import Keepshire

struct VideoPlayerLifecycleTests {
    @Test func preservesVideoFileTypeMapping() {
        #expect(VideoPlayerLifecycle.fileExtension(from: "video/mp4") == "mp4")
        #expect(VideoPlayerLifecycle.fileExtension(from: "video/quicktime") == "mov")
        #expect(VideoPlayerLifecycle.fileExtension(from: "video/x-m4v") == "m4v")
        #expect(VideoPlayerLifecycle.fileExtension(from: "video/x-matroska") == "mkv")
        #expect(VideoPlayerLifecycle.fileExtension(from: "video/x-msvideo") == "avi")
        #expect(VideoPlayerLifecycle.fileExtension(from: "video/webm") == "webm")
        #expect(VideoPlayerLifecycle.fileExtension(from: "video/x-flv") == "flv")
        #expect(VideoPlayerLifecycle.fileExtension(from: "video/x-ms-wmv") == "wmv")
        #expect(VideoPlayerLifecycle.fileExtension(from: "video/3gpp") == "3gp")
        #expect(VideoPlayerLifecycle.fileExtension(from: nil) == "mp4")
        #expect(VideoPlayerLifecycle.fileExtension(from: "unknown") == "mp4")
    }

    @Test func preservesUnsupportedFormatMessaging() {
        let mkvMessage = VideoPlayerLifecycle.unsupportedFormatMessage(fileType: "video/x-matroska")
        let aviMessage = VideoPlayerLifecycle.unsupportedFormatMessage(fileType: "video/x-msvideo")

        #expect(mkvMessage.contains("MKV video contains codecs"))
        #expect(aviMessage.contains("AVI"))
        #expect(aviMessage.contains("safely stored"))
    }
}
