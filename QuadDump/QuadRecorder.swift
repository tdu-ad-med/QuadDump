import UIKit

class QuadRecorder {
    // setterのみをプライベートにする
    public private(set) var status: Status = .idol

    func start() -> Result<(), RecordError> {
        // 録画中であれば何もしない
        if case .recording = status { return Err("録画は既に開始しています") }

        // 保存先のフォルダを作成
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let outputDirName = formatter.string(from: date)
        guard let outputDir = URL.docs?.createDir(name: outputDirName) else {
            return Err("保存先フォルダの作成に失敗しました")
        }

        // 録画に関する情報を設定
        let info = Info(
            startTime: date,
            outputDir: outputDir
        )

        // statusをrecordingに更新
        status = .recording(info)

        return Ok()
    }

    func stop() -> Result<(), RecordError> {
        // 録画中でなければ何もしない
        guard case .recording = status else { return Err("録画は既に終了しています") }

        // statusをidolに更新
        status = .idol

        return Ok()
    }

    deinit { let _ = stop() }

    // 録画に関する情報
    struct Info {
        let startTime: Date  // 録画開始時刻
        let outputDir: URL   // 保存先ディレクトリ
    }

    // 録画状態
    enum Status {
        case idol             // 録画していない状態
        case recording(Info)  // 録画中
    }

    // エラー
    struct RecordError: Error {
        let description: String
    }

    private func Ok() -> Result<(), RecordError> {
        return .success(())
    }

    private func Err(_ description: String) -> Result<(), RecordError> {
        return .failure(RecordError(description: description))
    }
}
