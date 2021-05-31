import ARKit
import SwiftUI

class ARRecorder: NSObject, ARSessionDelegate, Recorder {
    private var session = ARSession()
    private var isEnable: Bool = false
    private var lastUpdate: TimeInterval = 0.0
    var callback: ((ARPreview) -> ())? = nil

    public override init() {
        super.init()
        self.session.delegate = self
    }

    deinit { let _ = disable() }

    func enable() -> SimpleResult {
        if isEnable { return Err("IMUは既に開始しています") }
        let configuration = ARWorldTrackingConfiguration()

        // LiDARセンサーを搭載している場合はデプスを取得する
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics = .sceneDepth
        }

        self.session.delegateQueue = DispatchQueue.global(qos: .userInteractive)

        self.session.run(configuration)
        isEnable = true

        return Ok()
    }

    func disable() -> SimpleResult {
        if (!isEnable) { return Err("IMUは既に終了しています") }
        let _ = stop()
        self.session.pause()
        isEnable = false
        return Ok()
    }

    func start() -> SimpleResult {
        return Ok()
    }

    func stop() -> SimpleResult {
        return Ok()
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let colorPixelBuffer = frame.capturedImage

        let sceneDepth = frame.sceneDepth
        let depthPixelBuffer = sceneDepth?.depthMap
        let confidencePixelBuffer = sceneDepth?.confidenceMap

        let fps = 1.0 / (frame.timestamp - lastUpdate)
        lastUpdate = frame.timestamp

        guard let callback = self.callback else { return }

        let context = CIContext(options: nil)
        let colorCIImage = CIImage(cvPixelBuffer: colorPixelBuffer).oriented(CGImagePropertyOrientation.right)
        guard let colorCGImage = context.createCGImage(colorCIImage, from: colorCIImage.extent) else { return }
        let colorUIImage = UIImage(cgImage: colorCGImage)
        let colorImage = Image(uiImage: colorUIImage)
        let colorSize = CGSize(width: CVPixelBufferGetWidth(colorPixelBuffer), height: CVPixelBufferGetHeight(colorPixelBuffer))

        var depthImage: Image? = nil
        var depthSize: CGSize = .zero
        if let depthPixelBuffer = depthPixelBuffer {
            let depthCIImage = CIImage(cvPixelBuffer: depthPixelBuffer).oriented(CGImagePropertyOrientation.right)
            guard let depthCGImage = context.createCGImage(depthCIImage, from: depthCIImage.extent) else { return }
            let depthUIImage = UIImage(cgImage: depthCGImage)
            depthImage = Image(uiImage: depthUIImage)
            depthSize = CGSize(width: CVPixelBufferGetWidth(depthPixelBuffer), height: CVPixelBufferGetHeight(depthPixelBuffer))
        }

        callback(ARPreview(
            colorImage: colorImage,
            colorSize: colorSize,
            depthImage: depthImage,
            depthSize: depthSize,
            fps: fps
        ))
    }

    struct ARPreview {
        let colorImage: Image
        let colorSize: CGSize
        let depthImage: Image?
        let depthSize: CGSize
        let fps: Double
    }
}
