import ARKit
import SwiftUI

class CamRecorder: NSObject, ARSessionDelegate {
    // カラーカメラとデプスカメラにアクセスするためのクラス
    private let session = ARSession()
    private let configuration = ARWorldTrackingConfiguration()
    private let delegateQueue = DispatchQueue.global(qos: .userInteractive)

    // カメラへのアクセスが開始されているか
    private var isEnable: Bool = false

    // 録画が開始されているか
    private var isRecording: Bool = false

    // 録画開始時刻
    private var startTime: TimeInterval = ProcessInfo.processInfo.systemUptime

    // カメラから最後にデータを取得した時刻
    private var lastUpdate: TimeInterval = 0.0

    // 最後にpreviewCallbackを呼んだ時刻
    private var previewLastUpdate: TimeInterval = 0.0

    // カメラのプレビューを表示するときに呼ぶコールバック関数
    private var previewCallback: ((CamPreview) -> ())? = nil

    // カメラの画像をImageへ変換するために使用するCIContext
    private let context = CIContext(mtlDevice: MTLCreateSystemDefaultDevice()!, options: nil)

    override init() {
        super.init()

        // delegateを設定
        session.delegate = self
        session.delegateQueue = self.delegateQueue

        // オートフォーカスを無効にする
        //configuration.isAutoFocusEnabled = false

        // LiDARセンサーを搭載している場合はデプスを取得する
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics = .sceneDepth
        }
    }

    deinit {
        if isEnable { let _ = disable() }
    }

    // プレビュー画像を受け取るコールバック関数の登録
    func preview(_ preview: ((CamPreview) -> ())?) {
        previewCallback = preview
    }

    // カメラへのアクセスを開始
    func enable() -> SimpleResult {
        if isEnable { return Err("Cameraは既に開始しています") }

        session.run(configuration)
        isEnable = true

        return Ok()
    }

    // カメラへのアクセスを停止
    func disable() -> SimpleResult {
        if !isEnable { return Err("Cameraは既に終了しています") }

        if isRecording { let _ = stop() }  // 録画中であれば録画を終了
        session.pause()
        isEnable = false

        return Ok()
    }

    // 録画開始
    func start(_ startTime: TimeInterval) -> SimpleResult {
        if isRecording { return Err("録画は既に開始しています") }

        delegateQueue.sync {
            self.startTime = startTime
            self.isRecording = true
        }

        return Ok()
    }

    // 録画終了
    func stop() -> SimpleResult {
        if !isRecording { return Err("録画は既に終了しています") }

        delegateQueue.sync {
            self.isRecording = false
        }

        return Ok()
    }

    // ARSessionからこのメソッドにカメラの映像が送られてくる
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let colorPixelBuffer = frame.capturedImage
        let colorSize = CGSize(width: CVPixelBufferGetWidth(colorPixelBuffer), height: CVPixelBufferGetHeight(colorPixelBuffer))

        let sceneDepth = frame.sceneDepth
        let depthPixelBuffer = sceneDepth?.depthMap
        let confidencePixelBuffer = sceneDepth?.confidenceMap

        let fps = 1.0 / (frame.timestamp - lastUpdate)
        lastUpdate = frame.timestamp

        let orientation = UIInterfaceOrientation.landscapeRight
        let camera = frame.camera
        let cameraIntrinsicsInversed = camera.intrinsics.inverse
        let projectionMatrix = camera.projectionMatrix(for: orientation, viewportSize: colorSize, zNear: 0.001, zFar: 0)
        let viewMatrix = camera.viewMatrix(for: orientation)

        // 以下はプレビューのための処理
        guard let previewCallback = previewCallback else { return }

        // fps60などでプレビューするとUIがカクつくため、応急措置としてプレビューのfpsを落としている
        // あとで原因を探る
        if (frame.timestamp - previewLastUpdate) > 0.05 {
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
                previewCallback(CamPreview(
                    colorImage: colorImage,
                    colorSize: colorSize,
                    depthImage: depthImage,
                    depthSize: depthSize,
                    timestamp: frame.timestamp - self.startTime,
                    fps: fps
                ))
            }
        }
    }

    struct CamPreview {
        let colorImage: Image
        let colorSize: CGSize
        let depthImage: Image?
        let depthSize: CGSize
        let timestamp: TimeInterval
        let fps: Double
    }
}
