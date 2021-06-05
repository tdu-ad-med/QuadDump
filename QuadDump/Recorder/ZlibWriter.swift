import Compression
import Foundation
import AVFoundation
import VideoToolbox

class ZIPRecorder {
    private var count: UInt64 = 0
    private var outputDirURL: URL?
    private var dstBuffer: UnsafeMutableBufferPointer<UInt8>?
    
    private func reset() {
        if let buffer = self.dstBuffer {
            buffer.deallocate()
            self.dstBuffer = nil
        }
        self.count = 0
    }

    deinit {
        reset()
    }

    func startRecord() {
        reset()

        outputDirURL = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).last!.appendingPathComponent("depth", isDirectory: true)
        if FileManager.default.fileExists(atPath: outputDirURL!.path) { try! FileManager.default.removeItem(at: outputDirURL!) }
        try! FileManager.default.createDirectory(atPath: outputDirURL!.path, withIntermediateDirectories: true, attributes: nil)
    }

    func appendFrame(pixelBuffer: CVPixelBuffer) {
        let capacity = CVPixelBufferGetBytesPerRow(pixelBuffer) * CVPixelBufferGetHeight(pixelBuffer)

        if nil == self.dstBuffer {
            // zlibで圧縮後のデータサイズが圧縮前のデータサイズを上回ることがあるため
            // 圧縮後のデータサイズを格納するためのメモリを多めに確保しておく
            // There are cases where the size of zlib output data is lager than the size of input data.
            // Therefore, allocate twice the memory of the input data.
            self.dstBuffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: capacity * 2)
        }
        guard
            let dstBuffer = self.dstBuffer,
            dstBuffer.count >= (capacity * 2)
        else {
            print("failed to compress")
            return
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let compressedSize = compression_encode_buffer(
            dstBuffer.baseAddress!, dstBuffer.count,
            CVPixelBufferGetBaseAddress(pixelBuffer)!.assumingMemoryBound(to: UInt8.self), capacity,
            nil,
            COMPRESSION_ZLIB
        )
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        if compressedSize == 0 {
            print("failed to compress")
            return
        }

        let outputURL = outputDirURL!.appendingPathComponent("\(self.count)")
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try! FileManager.default.removeItem(at: outputURL)
        }

        // ファイルの作成
        guard FileManager.default.createFile(
            atPath: outputURL.path,
            contents: Data(bytes: dstBuffer.baseAddress!, count: compressedSize),
            attributes: nil
        )
        else {
            print("failed to create file")
            return
        }

        // カウントの更新
        // update count
        self.count += 1
    }
}
