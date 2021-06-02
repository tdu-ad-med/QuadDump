import ARKit
import SwiftUI

class ARRecorder: NSObject, ARSessionDelegate, Recorder {
    private var session = ARSession()
    private let delegateQueue = DispatchQueue.global(qos: .userInteractive)
    private var isEnable: Bool = false
    private var isRecording: Bool = false
    private var lastUpdate: TimeInterval = 0.0
    private var previewLastUpdate: TimeInterval = 0.0
    private var previewCallback: ((ARPreview) -> ())? = nil
    private let context = CIContext(mtlDevice: MTLCreateSystemDefaultDevice()!, options: nil)

    override init() {
        super.init()
        self.session.delegate = self
    }

    deinit { let _ = disable() }

    func preview(_ preview: ((ARPreview) -> ())?) {
        self.previewCallback = preview
    }

    func enable() -> SimpleResult {
        if isEnable { return Err("ARは既に開始しています") }

        let configuration = ARWorldTrackingConfiguration()

        // オートフォーカスを無効にする
        //configuration.isAutoFocusEnabled = false

        // LiDARセンサーを搭載している場合はデプスを取得する
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics = .sceneDepth
        }

        self.session.delegateQueue = self.delegateQueue

        self.session.run(configuration)
        isEnable = true

        return Ok()
    }

    func disable() -> SimpleResult {
        if (!isEnable) { return Err("ARは既に終了しています") }
        let _ = stop()
        self.session.pause()
        isEnable = false
        return Ok()
    }

    func start() -> SimpleResult {
        self.delegateQueue.sync {
            self.isRecording = true
        }
        return Ok()
    }

    func stop() -> SimpleResult {
        self.delegateQueue.sync {
            self.isRecording = false
        }
        return Ok()
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let colorPixelBuffer = frame.capturedImage

        let sceneDepth = frame.sceneDepth
        let depthPixelBuffer = sceneDepth?.depthMap
        let confidencePixelBuffer = sceneDepth?.confidenceMap
        let colorSize = CGSize(width: CVPixelBufferGetWidth(colorPixelBuffer), height: CVPixelBufferGetHeight(colorPixelBuffer))

        let fps = 1.0 / (frame.timestamp - lastUpdate)
        lastUpdate = frame.timestamp

        let orientation = UIInterfaceOrientation.landscapeRight
        let camera = frame.camera
        let cameraIntrinsicsInversed = camera.intrinsics.inverse
        let projectionMatrix = camera.projectionMatrix(for: orientation, viewportSize: colorSize, zNear: 0.001, zFar: 0)
        let viewMatrix = camera.viewMatrix(for: orientation)

        // 以下はプレビューのための処理
        guard let previewCallback = self.previewCallback else { return }

        if (frame.timestamp - previewLastUpdate) > (1 / 20) {
            previewLastUpdate = frame.timestamp

            let colorCIImage = CIImage(cvPixelBuffer: colorPixelBuffer).oriented(CGImagePropertyOrientation.right)
            guard let colorCGImage = context.createCGImage(colorCIImage, from: colorCIImage.extent) else { return }
            let colorUIImage = UIImage(cgImage: colorCGImage)
            let colorImage = Image(uiImage: colorUIImage)

            var depthImage: Image? = nil
            var depthSize: CGSize = .zero
            if let depthPixelBuffer = depthPixelBuffer {
                let depthCIImage = CIImage(cvPixelBuffer: depthPixelBuffer).oriented(CGImagePropertyOrientation.right)
                guard let depthCGImage = context.createCGImage(depthCIImage, from: depthCIImage.extent) else { return }
                let depthUIImage = UIImage(cgImage: depthCGImage)
                depthImage = Image(uiImage: depthUIImage)
                depthSize = CGSize(width: CVPixelBufferGetWidth(depthPixelBuffer), height: CVPixelBufferGetHeight(depthPixelBuffer))
            }

            DispatchQueue.main.async {
                previewCallback(ARPreview(
                    colorImage: colorImage,
                    colorSize: colorSize,
                    depthImage: depthImage,
                    depthSize: depthSize,
                    timestamp: frame.timestamp,
                    fps: fps
                ))
            }
        }
    }

    struct ARPreview {
        let colorImage: Image
        let colorSize: CGSize
        let depthImage: Image?
        let depthSize: CGSize
        let timestamp: TimeInterval
        let fps: Double
    }
}
