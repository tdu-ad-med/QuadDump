import Foundation

class RawWriter {
    private var fileHandle: FileHandle? = nil

    var isRecording: Bool { fileHandle != nil }

    func create(url: URL) -> SimpleResult {
        // 既に書き込みが開始している場合はエラー
        if isRecording { return Err("録画は既に開始しています") }

        do {
            // 既にファイルが存在する場合は削除
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }

            // ファイルの作成
            guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil) else {
                return Err("ファイルの作成に失敗しました")
            }

            // ファイルハンドルの作成
            fileHandle = try FileHandle(forWritingTo: url)
        }
        catch {
            return Err("ファイルの作成に失敗しました")
        }

        return Ok()
    }

    func append(data: [UInt64]) -> SimpleResult { return _append(data: data) }
    func append(data: [Float ]) -> SimpleResult { return _append(data: data) }
    func append(data: [Double]) -> SimpleResult { return _append(data: data) }
    private func _append<T: Numeric>(data: [T]) -> SimpleResult {
        guard let fileHandle = fileHandle else { return Err("録画が開始されていません") }

        // 書き込み
        let buffer = data.withUnsafeBytes { body in body.bindMemory(to: UInt8.self) }
        do { try fileHandle.write(contentsOf: buffer) }
        catch { return Err("データの書き込みに失敗しました") }

        return Ok()
    }

    func finish(errorCallback: ((String) -> ())? = nil) {
        if let fileHandle = fileHandle {
            self.fileHandle = nil
            do { try fileHandle.close() }
            catch { errorCallback?("ファイルの書き込みに失敗しました") }
        }
        else { errorCallback?("録画が開始されていません") }
    }
}
