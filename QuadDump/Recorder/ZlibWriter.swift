import Compression
import Foundation
import AVFoundation
import VideoToolbox

class ZlibWriter {
    private var outputDir: URL? = nil
    private var dstBuffer: UnsafeMutableBufferPointer<UInt8>?

    var isRecording: Bool { outputDir != nil }

    private func reset() {
        if let buffer = self.dstBuffer {
            buffer.deallocate()
            self.dstBuffer = nil
        }
    }

    deinit {
        reset()
    }

    func create(url: URL) -> SimpleResult {
        reset()

        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try FileManager.default.createDirectory(atPath: url.path, withIntermediateDirectories: true, attributes: nil)
        }
        catch {
            return Err("フォルダの作成に失敗しました")
        }

        outputDir = url
        return Ok()
    }

    func append(pixelBuffer: CVPixelBuffer, frameNumber: UInt64) -> SimpleResult {
        guard let outputDir = outputDir else { return Err("録画が開始されていません") }

        // zlibで圧縮後のデータサイズが圧縮前のデータサイズを上回ることがあるため
        // 圧縮後のデータサイズを格納するためのメモリを多めに確保しておく
        // There are cases where the size of zlib output data is lager than the size of input data.
        // Therefore, allocate twice the memory of the input data.
        let buffer_size = CVPixelBufferGetBytesPerRow(pixelBuffer) * CVPixelBufferGetHeight(pixelBuffer)
        let capacity = buffer_size * 2
        if (nil == dstBuffer) || (capacity > dstBuffer!.count) {
            dstBuffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: capacity)
        }
        guard let dstBuffer = dstBuffer else { return Err("メモリの確保に失敗しました") }

        // 画像の圧縮
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let compressedSize = compression_encode_buffer(
            dstBuffer.baseAddress!, dstBuffer.count,
            CVPixelBufferGetBaseAddress(pixelBuffer)!.assumingMemoryBound(to: UInt8.self), buffer_size,
            nil,
            COMPRESSION_ZLIB
        )
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        if 0 == compressedSize { return Err("圧縮に失敗しました") }

        let url = outputDir.appendingPathComponent(String(frameNumber))

        // 既にファイルが存在する場合は削除
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
        catch { return Err("ファイルの作成に失敗しました") }

        // ファイルの作成
        guard FileManager.default.createFile(
            atPath: url.path,
            contents: Data(bytes: dstBuffer.baseAddress!, count: compressedSize),
            attributes: nil
        )
        else { return Err("ファイルの書き込みに失敗しました") }

        return Ok()
    }
}
