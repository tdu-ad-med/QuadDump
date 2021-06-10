import ARKit
import SwiftUI

class CamRecorder: NSObject, ARSessionDelegate {
    // カラーカメラとデプスカメラにアクセスするためのクラス
    private let session = ARSession()
    private let configuration = ARWorldTrackingConfiguration()

    private let encodeQueue: OperationQueue = {
        // 2つ以上のスレッドから同時にファイルへ書き込まれるとよくないので
        // OperationQueueの並列化はしない
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    // カメラへのアクセスが開始されているか
    public private(set) var isEnable: Bool = false

    // 動画を書き込むクラス
    private let colorWriter = MP4Writer()  // カラーカメラ
    private let depthWriter = ZlibWriter()  // デプスカメラ
    private let confidenceWriter = ZlibWriter()  // デプスカメラの信頼度マップ
    private let frameInfomationWriter = RawWriter()  // カメラ座標
    private var isRecording: Bool {
        colorWriter.isRecording && depthWriter.isRecording &&
        confidenceWriter.isRecording && frameInfomationWriter.isRecording
    }

    // カメラの解像度とピクセルフォーマット (width, height, pixelFormat)
    public private(set) var colorCamInfo: (Int, Int, OSType)? = nil
    public private(set) var depthCamInfo: (Int, Int, OSType)? = nil
    public private(set) var confidenceCamInfo: (Int, Int, OSType)? = nil

    // 録画開始時刻
    private var startTime: TimeInterval = ProcessInfo.processInfo.systemUptime

    // カメラから最後にデータを取得したフレーム番号、時刻
    private var lastFrameNumber: UInt64 = 0
    private var lastUpdate: TimeInterval = 0.0

    // カメラのプレビューを表示するときに呼ぶコールバック関数
    private var previewCallback: ((CamPreview) -> ())? = nil
    private var timestampCallback: ((TimeInterval, Double) -> ())? = nil

    // カメラの画像をImageへ変換するために使用するCIContext
    private let context = CIContext(mtlDevice: MTLCreateSystemDefaultDevice()!, options: nil)

    override init() {
        super.init()

        // delegateを設定
        session.delegate = self
        session.delegateQueue = DispatchQueue.main

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
    func timestamp(_ timestamp: ((TimeInterval, Double) -> ())?) {
        timestampCallback = timestamp
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

        encodeQueue.addOperation {
            if self.isRecording { self.stop() }  // 録画中であれば録画を終了
        }
        session.pause()
        isEnable = false

        return Ok()
    }

    // 録画開始
    func start(_ outputDir: URL, _ startTime: TimeInterval, error: ((String) -> ())? = nil) {
        guard let info = colorCamInfo else {
            error?("カメラの解像度を取得できませんでした")
            return
        }

        self.startTime = startTime
        lastFrameNumber = 0

        encodeQueue.addOperation {
            // カラーカメラの記録を開始
            if case let .failure(e) = self.colorWriter.create(
                url: outputDir.appendingPathComponent("camera.mp4"),
                width: info.0, height: info.1, pixelFormat: info.2
            ) {
                self.stop()
                DispatchQueue.main.async { error?(e.description) }
            }

            // デプスカメラの記録を開始
            if case let .failure(e) = self.depthWriter.create(
                url: outputDir.appendingPathComponent("depth")
            ) {
                self.stop()
                DispatchQueue.main.async { error?(e.description) }
            }

            // デプスの信頼度の記録を開始
            if case let .failure(e) = self.confidenceWriter.create(
                url: outputDir.appendingPathComponent("confidence")
            ) {
                self.stop()
                DispatchQueue.main.async { error?(e.description) }
            }

            // その他のパラメータの記録を開始
            if case let .failure(e) = self.frameInfomationWriter.create(
                url: outputDir.appendingPathComponent("cameraFrameInfo")
            ) {
                self.stop()
                DispatchQueue.main.async { error?(e.description) }
            }
        }
    }

    // 録画終了
    func stop(error: ((String) -> ())? = nil) {
        encodeQueue.addOperation {
            self.colorWriter.finish { e in
                DispatchQueue.main.async { error?(e) }
            }
            self.depthWriter.finish { e in
                DispatchQueue.main.async { error?(e) }
            }
            self.confidenceWriter.finish { e in
                DispatchQueue.main.async { error?(e) }
            }
            self.frameInfomationWriter.finish { e in
                DispatchQueue.main.async { error?(e) }
            }
        }
    }

    // ARSessionからこのメソッドにカメラの映像が送られてくる
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        encodeQueue.addOperation {
            // カラーカメラの画像と解像度、ピクセルフォーマットを取得
            let colorPixelBuffer = frame.capturedImage
            let colorWidth: Int = CVPixelBufferGetWidth(colorPixelBuffer)
            let colorHeight: Int = CVPixelBufferGetHeight(colorPixelBuffer)
            let colorPixelFormat: OSType = CVPixelBufferGetPixelFormatType(colorPixelBuffer)
            let colorSize = CGSize(width: colorWidth, height: colorHeight)
            let colorCamInfo: (Int, Int, OSType) = (colorWidth, colorHeight, colorPixelFormat)
            self.colorCamInfo = colorCamInfo

            // デプスカメラの画像と信頼度マップの取得
            let sceneDepth = frame.sceneDepth
            let depthPixelBuffer = sceneDepth?.depthMap
            let confidencePixelBuffer = sceneDepth?.confidenceMap
            if let depthPixelBuffer = depthPixelBuffer { self.depthCamInfo = (
                CVPixelBufferGetWidth(depthPixelBuffer),
                CVPixelBufferGetHeight(depthPixelBuffer),
                CVPixelBufferGetPixelFormatType(depthPixelBuffer)
            ) }
            if let confidencePixelBuffer = confidencePixelBuffer { self.confidenceCamInfo = (
                CVPixelBufferGetWidth(confidencePixelBuffer),
                CVPixelBufferGetHeight(confidencePixelBuffer),
                CVPixelBufferGetPixelFormatType(confidencePixelBuffer)
            ) }

            // カメラの内部パラメータ行列、プロジェクション行列、ビュー行列を取得
            let orientation = UIInterfaceOrientation.landscapeRight
            let intr = frame.camera.intrinsics
            let proj = frame.camera.projectionMatrix(for: orientation, viewportSize: colorSize, zNear: 0.001, zFar: 0)
            let view = frame.camera.viewMatrix(for: orientation)

            // フレームレートの計算
            let fps = 1.0 / (frame.timestamp - self.lastUpdate)
            self.lastUpdate = frame.timestamp

            let timestamp = frame.timestamp - self.startTime

            // 録画が開始されている場合
            if self.isRecording {
                if timestamp >= 0 {
                    // フレーム番号の更新
                    let frameNumber = self.lastFrameNumber
                    self.lastFrameNumber += 1

                    // カラーカメラの画像を追加
                    let isColorFrameExist: UInt8 = self.colorWriter.append(pixelBuffer: colorPixelBuffer, timestamp: timestamp).isSuccess ? 1 : 0

                    // デプスカメラの画像を追加
                    var isDepthFrameExist: UInt8 = 0
                    if let depthPixelBuffer = depthPixelBuffer {
                        isDepthFrameExist = self.depthWriter.append(pixelBuffer: depthPixelBuffer).isSuccess ? 1 : 0
                    }

                    // デプスの信頼度マップの画像を追加
                    var isConfidenceFrameExist: UInt8 = 0
                    if let confidencePixelBuffer = confidencePixelBuffer {
                        isConfidenceFrameExist = self.confidenceWriter.append(pixelBuffer: confidencePixelBuffer).isSuccess ? 1 : 0
                    }

                    // カメラ座標の追加
                    var frameInfomation = Data()
                    frameInfomation.append(contentsOf: [frameNumber])
                    frameInfomation.append(contentsOf: [timestamp])
                    frameInfomation.append(contentsOf: [isColorFrameExist, isDepthFrameExist, isConfidenceFrameExist])
                    frameInfomation.append(contentsOf: [
                        // ARFrame.camera.intrinsics
                        intr[0, 0], intr[1, 0], intr[2, 0],
                        intr[0, 1], intr[1, 1], intr[2, 1],
                        intr[0, 2], intr[1, 2], intr[2, 2],

                        // ARFrame.camera.projectionMatrix
                        proj[0, 0], proj[1, 0], proj[2, 0], proj[3, 0],
                        proj[0, 1], proj[1, 1], proj[2, 1], proj[3, 1],
                        proj[0, 2], proj[1, 2], proj[2, 2], proj[3, 2],
                        proj[0, 3], proj[1, 3], proj[2, 3], proj[3, 3],

                        // ARFrame.camera.viewMatrix
                        view[0, 0], view[1, 0], view[2, 0], view[3, 0],
                        view[0, 1], view[1, 1], view[2, 1], view[3, 1],
                        view[0, 2], view[1, 2], view[2, 2], view[3, 2],
                        view[0, 3], view[1, 3], view[2, 3], view[3, 3]
                    ])
                    let _ = self.frameInfomationWriter.append(data: frameInfomation)
                }
            }

            DispatchQueue.main.async {
                self.timestampCallback?(self.isRecording ? timestamp : 0.0, fps)
                self.previewCallback?(CamPreview(
                    colorImage: colorPixelBuffer,
                    depthImage: depthPixelBuffer
                ))
            }
        }
    }

    struct CamPreview {
        let colorImage: CVPixelBuffer
        let depthImage: CVPixelBuffer?
    }
}
