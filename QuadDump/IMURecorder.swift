import CoreMotion

class IMURecorder {
    private var motionManager = CMMotionManager()
    private let operationQueue = OperationQueue()
    private var isEnable: Bool = false
    private var isRecording: Bool = false
    private var lastUpdate: TimeInterval = 0.0
    private var previewLastUpdate: TimeInterval = 0.0
    private var previewCallback: ((IMUPreview) -> ())? = nil

    init() {
        operationQueue.maxConcurrentOperationCount = 1
    }

    deinit {
        let _ = disable()
    }

    func preview(_ preview: ((IMUPreview) -> ())?) {
        self.previewCallback = preview
    }

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

    func disable() -> SimpleResult {
        if (!isEnable) { return Err("IMUは既に終了しています") }
        let _ = stop()
        motionManager.stopDeviceMotionUpdates()
        isEnable = false
        return Ok()
    }

    func start() -> SimpleResult {
        operationQueue.addOperation({
            self.isRecording = true
        })
        return Ok()
    }

    func stop() -> SimpleResult {
        operationQueue.addOperation({
            self.isRecording = false
        })
        return Ok()
    }

    func motionHandler(motion: CMDeviceMotion?, error: Error?) {
        guard let motion = motion, error == nil else { return }

        let fps = 1.0 / (motion.timestamp - lastUpdate)
        lastUpdate = motion.timestamp

        let preview = IMUPreview(
            acceleration: (motion.userAcceleration.x, motion.userAcceleration.y, motion.userAcceleration.z),
            attitude: (motion.attitude.roll, motion.attitude.pitch, motion.attitude.yaw),
            timestamp: motion.timestamp,
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
