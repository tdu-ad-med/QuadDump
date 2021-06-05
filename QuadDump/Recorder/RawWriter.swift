import Foundation
import AVFoundation

class RawRecorder {
    private var fileHandle: FileHandle?
    var isRecord: Bool {
        get { return self.fileHandle != nil }
    }

    deinit {
        reset()
    }

    func reset() {
        if let fileHandle = self.fileHandle {
            try! fileHandle.close()
        }
        self.fileHandle = nil
    }

    func startRecord() {
        reset()

        // 保存先のパスを取得
        let outputURL = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).last!.appendingPathComponent("preview.raw")

        // 既にファイルが存在する場合は削除
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try! FileManager.default.removeItem(at: outputURL)
        }

        // ファイルの作成
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil, attributes: nil) else {
            return
        }

        // ファイルハンドルの作成
        self.fileHandle = try! FileHandle(forWritingTo: outputURL)
    }

    func appendFrame(pixelBuffer: CVPixelBuffer) {
        guard let fileHandle = self.fileHandle else { return }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let depthData = UnsafeBufferPointer(
            start: CVPixelBufferGetBaseAddress(pixelBuffer)!.assumingMemoryBound(to: UInt8.self),
            count: CVPixelBufferGetBytesPerRow(pixelBuffer) * CVPixelBufferGetHeight(pixelBuffer)
        )
        try! fileHandle.write(contentsOf: depthData)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    }

    func stopRecord() {
        reset()
    }
}
