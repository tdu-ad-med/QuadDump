import CoreMotion

class IMURecorder {
    // IMUにアクセスするためのクラス
    private let motionManager = CMMotionManager()

    private let encodeQueue: OperationQueue = {
        // 2つ以上のスレッドから同時にファイルへ書き込まれるとよくないので
        // OperationQueueの並列化はしない
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    // IMUへのアクセスが開始されているか
    private var isEnable: Bool = false

    // IMUを録画するクラス
    private let imuWriter = RawWriter()
    private var isRecording: Bool { imuWriter.isRecording }

    // 録画開始時刻
    private var startTime: TimeInterval = ProcessInfo.processInfo.systemUptime

    // IMUから最後にデータを取得した時刻
    private var lastUpdate: TimeInterval = 0.0

    // 最後にpreviewCallbackを呼んだ時刻
    private var previewLastUpdate: TimeInterval = 0.0

    // IMUのプレビューを表示するときに呼ぶコールバック関数
    private var previewCallback: ((IMUPreview) -> ())? = nil
    private var timestampCallback: ((TimeInterval, Double) -> ())? = nil

    deinit {
        if isEnable { let _ = disable() }
    }

    // プレビューデータを受け取るコールバック関数の登録
    func preview(_ preview: ((IMUPreview) -> ())?) {
        previewCallback = preview
    }
    func timestamp(_ timestamp: ((TimeInterval, Double) -> ())?) {
        timestampCallback = timestamp
    }

    // IMUへのアクセスを開始
    func enable() -> SimpleResult {
        if isEnable { return Err("IMUは既に開始しています") }
        guard motionManager.isDeviceMotionAvailable else { return Err("IMUの取得に失敗しました") }
        motionManager.deviceMotionUpdateInterval = 0.001
        motionManager.startDeviceMotionUpdates(
            using: .xMagneticNorthZVertical,
            to: encodeQueue,
            withHandler: motionHandler
        )
        isEnable = true
        return Ok()
    }

    // IMUへのアクセスを停止
    func disable() -> SimpleResult {
        if !isEnable { return Err("IMUは既に終了しています") }

        encodeQueue.addOperation { [weak self] in
            guard let self = self else { return }
            if self.isRecording { self.stop() }  // 録画中であれば録画を終了
        }
        motionManager.stopDeviceMotionUpdates()
        isEnable = false

        return Ok()
    }

    // 録画開始
    func start(_ outputDir: URL, _ startTime: TimeInterval, error: ((String) -> ())? = nil) {
        encodeQueue.addOperation { [weak self] in
            guard let self = self else { return }
            self.startTime = startTime
            if case let .failure(e) = self.imuWriter.create( url: outputDir.appendingPathComponent("imu")) {
                self.stop()
                DispatchQueue.main.async { error?(e.description) }
            }
        }
    }

    // 録画終了
    func stop(error: ((String) -> ())? = nil) {
        encodeQueue.addOperation { [weak self] in
            guard let self = self else { return }
            self.imuWriter.finish { e in
                DispatchQueue.main.async { error?(e) }
            }
        }
    }

    // IMUが更新されたときに呼ばれるメソッド
    func motionHandler(motion: CMDeviceMotion?, error: Error?) {
        guard let motion = motion, error == nil else { return }

        // フレームレートの計算
        let fps = 1.0 / (motion.timestamp - lastUpdate)
        lastUpdate = motion.timestamp

        // プレビュー用のデータ作成
        let preview = IMUPreview(
            gravity: (motion.gravity.x, motion.gravity.y, motion.gravity.z),
            userAcceleration: (motion.userAcceleration.x, motion.userAcceleration.y, motion.userAcceleration.z),
            attitude: (motion.attitude.roll, motion.attitude.pitch, motion.attitude.yaw),
            timestamp: motion.timestamp - startTime,
            fps: fps
        )

        // 録画が開始されている場合
        if isRecording {
            let _ = imuWriter.append(data: [
                preview.timestamp,
                preview.gravity.0,
                preview.gravity.1,
                preview.gravity.2,
                preview.userAcceleration.0,
                preview.userAcceleration.1,
                preview.userAcceleration.2,
                preview.attitude.0,
                preview.attitude.1,
                preview.attitude.2
            ])
        }

        // fps60などでプレビューするとUIがカクつくため、応急措置としてプレビューのfpsを落としている
        // あとで原因を探る
        if (motion.timestamp - previewLastUpdate) > (1.0 / 10.0) {
            previewLastUpdate = motion.timestamp
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.timestampCallback?(self.isRecording ? preview.timestamp : 0.0, fps)
                self.previewCallback?(preview)
            }
        }
    }

    struct IMUPreview {
        let gravity: (Double, Double, Double)
        let userAcceleration: (Double, Double, Double)
        let attitude: (Double, Double, Double)
        let timestamp: TimeInterval
        let fps: Double
    }
}
