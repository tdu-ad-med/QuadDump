import Foundation
import UIKit

class QuadRecorder {
    // 録画に関する情報
    struct Info {
        let startTime: TimeInterval

        init() {
            startTime = Date().timeIntervalSince1970
        }
    }

    // 録画状態
    enum Status {
        case idol             // 録画していない状態
        case recording(Info)  // 録画中
        case error(String)    // エラーにより録画が中断された状態
    }

    // setterのみをプライベートにする
    public private(set) var status: Status = .idol

    deinit {
        // 録画中であれば録画を終了
        if case .recording = status {
            let _ = stop()
        }
    }

    func start() {
        // 録画中であれば何もしない
        if case .recording = status { return }

        // 録画開始時刻を記録

        // statusをrecordingに更新
        status = .recording(Info())
    }

    func stop() {
        // 録画中でなければ何もしない
        guard case .recording = status else { return }

        // statusをidolに更新
        status = .idol
    }
}
