import ARKit
import SwiftUI
import GRDB

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
	private var isRecording: Bool { colorWriter.isRecording }

	// カメラの解像度とピクセルフォーマット (width, height, pixelFormat)
	public private(set) var colorCamInfo: (Int, Int, OSType)? = nil
	public private(set) var depthCamInfo: (Int, Int, OSType)? = nil
	public private(set) var confidenceCamInfo: (Int, Int, OSType)? = nil

	// 録画に関する情報を設定
	private var info: QuadRecorder.Info?

	// カメラから最後にデータを取得した時刻
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

		encodeQueue.addOperation { [weak self] in
			guard let self = self else { return }
			if self.isRecording { self.stop() }  // 録画中であれば録画を終了
		}
		session.pause()
		isEnable = false

		return Ok()
	}

	// 録画開始
	func start(_ info: QuadRecorder.Info, error: ((String) -> ())? = nil) {
		encodeQueue.addOperation { [weak self] in
			guard let self = self else { return }

			guard let camInfo = self.colorCamInfo else {
				self.stop()
				DispatchQueue.main.async { error?("カメラの解像度を取得できませんでした") }
				return
			}

			self.info = info

			// テーブルの作成
			guard let _ = ( try? info.dbQueue.write { db in
				try db.create(table: "camera") { t in
					t.autoIncrementedPrimaryKey("id").notNull()
					t.column("timestamp"            , .double ).notNull()
					t.column("color_frame"          , .integer).unique()
					t.column("depth_zlib"           , .blob   )
					t.column("confidence_zlib"      , .blob   )
					t.column("intrinsics_matrix_3x3", .blob   )
					t.column("projection_matrix_4x4", .blob   )
					t.column("view_matrix_4x4"      , .blob   )
				}
			} )
			else {
				self.stop()
				DispatchQueue.main.async { error?("cameraテーブルの作成に失敗しました") }
				return
			}

			// カラーカメラの記録を開始
			if case let .failure(e) = self.colorWriter.create(
				url: info.outputDir.appendingPathComponent("camera.mp4"),
				width: camInfo.0, height: camInfo.1, pixelFormat: camInfo.2
			) {
				self.stop()
				DispatchQueue.main.async { error?(e.description) }
			}
		}
	}

	// 録画終了
	func stop(error: ((String) -> ())? = nil) {
		encodeQueue.addOperation { [weak self] in
			guard let self = self else { return }
			self.info = nil
			self.colorWriter.finish { e in
				DispatchQueue.main.async { error?(e) }
			}
		}
	}

	// ARSessionからこのメソッドにカメラの映像が送られてくる
	func session(_ session: ARSession, didUpdate frame: ARFrame) {
		encodeQueue.addOperation { [weak self] in
			guard let self = self else { return }

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

			let timestamp = frame.timestamp - (self.info?.startTime ?? 0.0)

			// 録画が開始されている場合
			if self.isRecording {
				if timestamp >= 0 {
					// カラーカメラの画像を追加
					let _ = self.colorWriter.append(pixelBuffer: colorPixelBuffer, timestamp: timestamp)

					// デプスと信頼度マップの画像をzlibへ変換
					var depth_zlib: Data? = nil
					if let depthPixelBuffer = depthPixelBuffer {
						depth_zlib = self.depthWriter.convert(pixelBuffer: depthPixelBuffer)
					}
					var confidence_zlib: Data? = nil
					if let confidencePixelBuffer = confidencePixelBuffer {
						confidence_zlib = self.confidenceWriter.convert(pixelBuffer: confidencePixelBuffer)
					}

					let _ = ( try? self.info?.dbQueue.write { db in
						try Camera(
							id: nil,
							timestamp: timestamp,
							color_frame: self.colorWriter.lastFrameNumber,
							depth_zlib: depth_zlib,
							confidence_zlib: confidence_zlib,
							intrinsics_matrix_3x3: Data([
								intr[0, 0], intr[1, 0], intr[2, 0],
								intr[0, 1], intr[1, 1], intr[2, 1],
								intr[0, 2], intr[1, 2], intr[2, 2]
							]),
							projection_matrix_4x4: Data([
								proj[0, 0], proj[1, 0], proj[2, 0], proj[3, 0],
								proj[0, 1], proj[1, 1], proj[2, 1], proj[3, 1],
								proj[0, 2], proj[1, 2], proj[2, 2], proj[3, 2],
								proj[0, 3], proj[1, 3], proj[2, 3], proj[3, 3]
							]),
							view_matrix_4x4: Data([
								view[0, 0], view[1, 0], view[2, 0], view[3, 0],
								view[0, 1], view[1, 1], view[2, 1], view[3, 1],
								view[0, 2], view[1, 2], view[2, 2], view[3, 2],
								view[0, 3], view[1, 3], view[2, 3], view[3, 3]
							])
						).insert(db)
					} )
				}
			}

			DispatchQueue.main.async { [weak self] in
				guard let self = self else { return }
				self.timestampCallback?(self.isRecording ? timestamp : 0.0, fps)
				self.previewCallback?(CamPreview(
					color: colorPixelBuffer,
					depth: depthPixelBuffer
				))
			}
		}
	}

	struct CamPreview {
		let color: CVPixelBuffer
		let depth: CVPixelBuffer?
	}
	struct Camera: Codable, FetchableRecord, PersistableRecord {
		let id                   : Int64?
		let timestamp            : Double
		let color_frame          : Int64?
		let depth_zlib           : Data?
		let confidence_zlib      : Data?
		let intrinsics_matrix_3x3: Data?
		let projection_matrix_4x4: Data?
		let view_matrix_4x4      : Data?
	}
}

extension Data {
	init(_ contentsOf: [Float]) {
		let buffer = contentsOf.withUnsafeBytes { body in body.bindMemory(to: UInt8.self) }
		self.init(buffer)
	}
}
