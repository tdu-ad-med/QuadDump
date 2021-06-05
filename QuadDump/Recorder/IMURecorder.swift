import CoreMotion

class IMURecorder {
    // IMUにアクセスするためのクラス
    private let motionManager = CMMotionManager()
    private let operationQueue = OperationQueue()

    // IMUへのアクセスが開始されているか
    private var isEnable: Bool = false

    // 録画が開始されているか
    private var isRecording: Bool = false

    // 録画開始時刻
    private var startTime: TimeInterval = ProcessInfo.processInfo.systemUptime

    // IMUから最後にデータを取得した時刻
    private var lastUpdate: TimeInterval = 0.0

    // 最後にpreviewCallbackを呼んだ時刻
    private var previewLastUpdate: TimeInterval = 0.0

    // IMUのプレビューを表示するときに呼ぶコールバック関数
    private var previewCallback: ((IMUPreview) -> ())? = nil

    init() {
        operationQueue.maxConcurrentOperationCount = 1
    }

    deinit {
        if isEnable { let _ = disable() }
    }

    // プレビューデータを受け取るコールバック関数の登録
    func preview(_ preview: ((IMUPreview) -> ())?) {
        previewCallback = preview
    }

    // IMUへのアクセスを開始
    func enable() -> SimpleResult {
        if isEnable { return Err("IMUは既に開始しています") }
        guard motionManager.isDeviceMotionAvailable else { return Err("IMUの取得に失敗しました") }
        motionManager.deviceMotionUpdateInterval = 0.001
        motionManager.startDeviceMotionUpdates(
            using: .xMagneticNorthZVertical,
            to: operationQueue,
            withHandler: motionHandler
        )
        isEnable = true
        return Ok()
    }

    // IMUへのアクセスを停止
    func disable() -> SimpleResult {
        if !isEnable { return Err("IMUは既に終了しています") }

        if isRecording { let _ = stop() }  // 録画中であれば録画を終了
        motionManager.stopDeviceMotionUpdates()
        isEnable = false

        return Ok()
    }

    // 録画開始
    func start(_ startTime: TimeInterval) -> SimpleResult {
        operationQueue.addOperation({
            self.startTime = startTime
            self.isRecording = true
        })
        return Ok()
    }

    // 録画終了
    func stop() -> SimpleResult {
        operationQueue.addOperation({
            self.isRecording = false
        })
        return Ok()
    }

    // IMUが更新されたときに呼ばれるメソッド
    func motionHandler(motion: CMDeviceMotion?, error: Error?) {
        guard let motion = motion, error == nil else { return }

        let fps = 1.0 / (motion.timestamp - lastUpdate)
        lastUpdate = motion.timestamp

        let preview = IMUPreview(
            acceleration: (motion.userAcceleration.x, motion.userAcceleration.y, motion.userAcceleration.z),
            attitude: (motion.attitude.roll, motion.attitude.pitch, motion.attitude.yaw),
            timestamp: motion.timestamp - startTime,
            fps: fps
        )

        if isRecording {
            var csv = ""
            csv += String(motion.timestamp) + ","
            csv += String(motion.userAcceleration.x) + ","
            csv += String(motion.userAcceleration.y) + ","
            csv += String(motion.userAcceleration.z) + ","
            csv += String(motion.attitude.roll) + ","
            csv += String(motion.attitude.pitch) + ","
            csv += String(motion.attitude.yaw) + "\n"
        }

        // fps60などでプレビューするとUIがカクつくため、応急措置としてプレビューのfpsを落としている
        // あとで原因を探る
        if (motion.timestamp - previewLastUpdate) > 0.1 {
            previewLastUpdate = motion.timestamp
            DispatchQueue.main.async {
                self.previewCallback?(preview)
            }
        }
    }

    struct IMUPreview {
        let acceleration: (Double, Double, Double)
        let attitude: (Double, Double, Double)
        let timestamp: TimeInterval
        let fps: Double
    }
}
