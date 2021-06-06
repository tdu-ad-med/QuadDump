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
    func start(error: ((String) -> ())? = nil) {
        if case .disable   = status { error?("センサーへアクセスしていません"); return }
        if case .recording = status { error?("録画は既に開始しています"); return }

        // 録画開始時刻の記録
        let startDate = Date()
        let startTime = ProcessInfo.processInfo.systemUptime

        // 保存先のフォルダを作成
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let outputDirName = formatter.string(from: startDate)
        guard let outputDir = URL.docs?.createDir(name: outputDirName) else {
            error?("保存先フォルダの作成に失敗しました")
            return
        }

        // 録画に関する情報を設定
        let info = Info(
            startDate: startDate,
            startTime: startTime,
            outputDir: outputDir
        )

        // 映像の情報を記述したテキストファイルを保存
        guard
            let colorCamInfo = camRecorder.colorCamInfo,
            let videoInfo = try? JSONSerialization.data(withJSONObject: [
                "camera.mp4": [
                    "width": colorCamInfo.0,
                    "height": colorCamInfo.1,
                    "format": "hevc"
                ],
                "depth/*": [
                    "width": camRecorder.depthCamInfo?.0 ?? 0,
                    "height": camRecorder.depthCamInfo?.1 ?? 0,
                    "format": "zlib,[[[float]]]"
                ],
                "confidence/*": [
                    "width": camRecorder.confidenceCamInfo?.0 ?? 0,
                    "height": camRecorder.confidenceCamInfo?.1 ?? 0,
                    "format": "zlib,[[[uint8]]]"
                ],
                "cameraPosition": [
                    "format": "raw,[uint64(frameNumber),double(timestampe),float3x3(intrinsics),float4x4(projectionMatrix),float4x4(viewMatrix)]"
                ],
                "imu": [
                    "format": "raw,[double(timestampe),double3(accleration),double3(attitude)]"
                ],
                "gps": [
                    "format": "raw,[double(timestampe),double(latitude),double(longitude),double(altitude),double(horizontalAccuracy),double(verticalAccuracy)]"
                ]
            ], options: []),
            FileManager.default.createFile(
                atPath: outputDir.appendingPathComponent("info.json").path,
                contents: videoInfo,
                attributes: nil
            )
        else { error?("ファイルの書き込みに失敗しました"); return }

        // 各センサーの録画開始
        camRecorder.start(outputDir, info.startTime) { e in error?(e) }
        imuRecorder.start(outputDir, info.startTime) { e in error?(e) }
        gpsRecorder.start(outputDir, info.startTime) { e in error?(e) }

        status = .recording(info)
    }

    // 録画終了
    func stop(error: ((String) -> ())? = nil) {
        if case .disable = status { error?("センサーへアクセスしていません") }
        if case .idol    = status { error?("録画は既に終了しています") }

        // 各センサーの録画終了
        camRecorder.stop { e in error?(e) }
        imuRecorder.stop { e in error?(e) }
        gpsRecorder.stop { e in error?(e) }

        status = .idol
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
