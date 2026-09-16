import Foundation
import UniformTypeIdentifiers

struct MIMETypeMapper {
    func mimeType(forFileName fileName: String) -> String {
        switch (fileName as NSString).pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "heic", "heif": return "image/heic"
        case "gif": return "image/gif"
        case "tiff", "tif": return "image/tiff"
        case "webp": return "image/webp"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "m4v": return "video/x-m4v"
        case "mkv": return "video/x-matroska"
        case "avi": return "video/x-msvideo"
        case "webm": return "video/webm"
        case "flv": return "video/x-flv"
        case "wmv": return "video/x-ms-wmv"
        case "3gp": return "video/3gpp"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "m4a": return "audio/mp4"
        case "aac": return "audio/aac"
        case "pdf": return "application/pdf"
        case "txt": return "text/plain"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        default: return "application/octet-stream"
        }
    }

    func mimeType(forUTI uti: String) -> String {
        print("DEBUG: Converting UTI: \(uti)")
        switch uti {
        case "public.jpeg", "public.jpg": return "image/jpeg"
        case "public.png": return "image/png"
        case "public.heic", "public.heif": return "image/heic"
        case "public.tiff": return "image/tiff"
        case "public.gif": return "image/gif"
        case "public.mpeg-4", "public.mp4": return "video/mp4"
        case "public.quicktime-movie", "public.mov": return "video/quicktime"
        default:
            if let mimeType = UTType(uti)?.preferredMIMEType {
                print("DEBUG: Converted to MIME type: \(mimeType)")
                return mimeType
            }
            if uti.contains("image") { return "image/jpeg" }
            if uti.contains("video") { return "video/quicktime" }
            return uti
        }
    }
}
