import Compression
import Foundation
import AVFoundation
import VideoToolbox

class ZlibWriter {
    private let writer = RawWriter()
    private var dstBuffer: UnsafeMutableBufferPointer<UInt8>?

    var isRecording: Bool { writer.isRecording }

    private func reset() {
        if let buffer = dstBuffer {
            buffer.deallocate()
            dstBuffer = nil
        }
    }

    deinit {
        reset()
    }

    func create(url: URL) -> SimpleResult {
        reset()
        return writer.create(url: url)
    }

    func append(pixelBuffer: CVPixelBuffer) -> SimpleResult {
        guard isRecording else { return Err("録画が開始されていません") }

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

        var data = Data()

        // 圧縮後のサイズを記録
        data.append(contentsOf: [UInt64(compressedSize)])

        // 圧縮データを記録
        data.append(Data(bytes: dstBuffer.baseAddress!, count: compressedSize))

        return writer.append(data: data)
    }

    func finish(errorCallback: ((String) -> ())? = nil) {
        return writer.finish(errorCallback: errorCallback)
    }
}
