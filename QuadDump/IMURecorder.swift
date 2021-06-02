import CoreMotion

class IMURecorder: Recorder {
    private var motionManager = CMMotionManager()
    private var isEnable: Bool = false
    private var isRecording: Bool = false
    private var lastUpdate: TimeInterval = 0.0
    private var previewLastUpdate: TimeInterval = 0.0
    private var previewCallback: ((IMUPreview) -> ())? = nil

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
            to: OperationQueue.current!,
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
        isRecording = true
        return Ok()
    }

    func stop() -> SimpleResult {
        isRecording = false
        return Ok()
    }

    func motionHandler(motion: CMDeviceMotion?, error: Error?) {
        guard let motion = motion, error == nil else { return }

        let fps = 1.0 / (motion.timestamp - lastUpdate)
        lastUpdate = motion.timestamp

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

        if (motion.timestamp - previewLastUpdate) > (1 / 10) {
            previewLastUpdate = motion.timestamp
            self.previewCallback?(IMUPreview(
                acceleration: (motion.userAcceleration.x, motion.userAcceleration.y, motion.userAcceleration.z),
                attitude: (motion.attitude.roll, motion.attitude.pitch, motion.attitude.yaw),
                timestamp: motion.timestamp,
                fps: fps
            ))
        }
    }

    struct IMUPreview {
        let acceleration: (Double, Double, Double)
        let attitude: (Double, Double, Double)
        let timestamp: TimeInterval
        let fps: Double
    }
}
