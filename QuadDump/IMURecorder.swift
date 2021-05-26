import UIKit
import CoreMotion

class IMURecorder: Recorder {
    private var motionManager = CMMotionManager()
    private var isEnable: Bool = false
    private var isRecording: Bool = false

    deinit {
        let _ = disable()
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
        if (!isRecording) { return }
        guard let motion = motion, error == nil else { return }
        var csv = ""
        csv += String(motion.timestamp) + ","
        csv += String(motion.userAcceleration.x) + ","
        csv += String(motion.userAcceleration.y) + ","
        csv += String(motion.userAcceleration.z) + ","
        csv += String(motion.attitude.roll) + ","
        csv += String(motion.attitude.pitch) + ","
        csv += String(motion.attitude.yaw) + "\n"
        print(csv)
    }
}
