import Foundation

class QuadRecorder {
    // setterのみをプライベートにする
    public private(set) var status: Status = .disable

    private let camRecorder = CamRecorder()
    private let imuRecorder = IMURecorder()
    private let gpsRecorder = GPSRecorder()

    deinit {
        let _ = disable()
    }

    func preview(
        camPreview: ((CamRecorder.CamPreview) -> ())? = nil,
        imuPreview: ((IMURecorder.IMUPreview) -> ())? = nil,
        gpsPreview: ((GPSRecorder.GPSPreview) -> ())? = nil
    ) {
        camRecorder.preview(camPreview)
        imuRecorder.preview(imuPreview)
        gpsRecorder.preview(gpsPreview)
    }

    // センサーへのアクセスを開始
    func enable() -> SimpleResult {
        if case let .failure(e) = camRecorder.enable() { return Err(e.description) }
        if case let .failure(e) = imuRecorder.enable() { return Err(e.description) }
        if case let .failure(e) = gpsRecorder.enable() { return Err(e.description) }
        status = .idol
        return Ok()
    }

    // センサーへのアクセスを終了
    func disable() -> SimpleResult {
        let _ = stop()
        if case let .failure(e) = camRecorder.disable() { return Err(e.description) }
        if case let .failure(e) = imuRecorder.disable() { return Err(e.description) }
        if case let .failure(e) = gpsRecorder.disable() { return Err(e.description) }
        status = .disable
        return Ok()
    }

    // 録画開始
    func start() -> SimpleResult {
        if case .disable   = status { return Err("センサーへアクセスしていません") }
        if case .recording = status { return Err("録画は既に開始しています") }

        // 録画開始時刻の記録
        let startDate = Date()
        let startTime = ProcessInfo.processInfo.systemUptime

        // 保存先のフォルダを作成
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let outputDirName = formatter.string(from: startDate)
        guard let outputDir = URL.docs?.createDir(name: outputDirName) else {
            return Err("保存先フォルダの作成に失敗しました")
        }

        // 録画に関する情報を設定
        let info = Info(
            startDate: startDate,
            startTime: startTime,
            outputDir: outputDir
        )

        // 各センサーの録画開始
        if case let .failure(e) = camRecorder.start(outputDir, info.startTime) { return Err(e.description) }
        if case let .failure(e) = imuRecorder.start(info.startTime) { return Err(e.description) }
        if case let .failure(e) = gpsRecorder.start(info.startTime) { return Err(e.description) }

        status = .recording(info)

        return Ok()
    }

    // 録画終了
    func stop() -> SimpleResult {
        if case .disable = status { return Err("センサーへアクセスしていません") }
        if case .idol    = status { return Err("録画は既に終了しています") }

        // 各センサーの録画終了
        if case let .failure(e) = camRecorder.stop() { return Err(e.description) }
        if case let .failure(e) = imuRecorder.stop() { return Err(e.description) }
        if case let .failure(e) = gpsRecorder.stop() { return Err(e.description) }

        status = .idol

        return Ok()
    }

    // 録画に関する情報
    struct Info {
        let startDate: Date          // 録画開始時刻(日時)
        let startTime: TimeInterval  // 録画開始時刻(デバイスを起動してからのTimeInterval)
        let outputDir: URL           // 保存先ディレクトリ
    }

    // 録画状態
    enum Status {
        case disable          // センサーにアクセスしていない状態
        case idol             // 録画していない状態
        case recording(Info)  // 録画中
    }
}
