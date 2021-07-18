import CoreMotion
import GRDB

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

	// 録画に関する情報を設定
	private var info: QuadRecorder.Info?
	private var isRecording: Bool { return info != nil }

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
	func start(_ info: QuadRecorder.Info, error: ((String) -> ())? = nil) {
		encodeQueue.addOperation { [weak self] in
			guard let self = self else { return }
			self.info = info

			// テーブルの作成
			guard let _ = ( try? self.info?.dbQueue.write { db in
				try db.create(table: "imu") { t in
					t.autoIncrementedPrimaryKey("id").notNull()
					t.column("timestamp"         , .double).notNull()
					t.column("gravity_x"         , .double).notNull()
					t.column("gravity_y"         , .double).notNull()
					t.column("gravity_z"         , .double).notNull()
					t.column("user_accleration_x", .double).notNull()
					t.column("user_accleration_y", .double).notNull()
					t.column("user_accleration_z", .double).notNull()
					t.column("attitude_x"        , .double).notNull()
					t.column("attitude_y"        , .double).notNull()
					t.column("attitude_z"        , .double).notNull()
				}
			} )
			else {
				self.stop()
				DispatchQueue.main.async { error?("imuテーブルの作成に失敗しました") }
				return
			}
		}
	}

	// 録画終了
	func stop(error: ((String) -> ())? = nil) {
		encodeQueue.addOperation { [weak self] in
			guard let self = self else { return }
			self.info = nil
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
			timestamp: motion.timestamp - (self.info?.startTime ?? 0.0),
			fps: fps
		)

		// 録画が開始されている場合
		let _ = ( try? info?.dbQueue.write { db in
			try IMU(
				id: nil,
				timestamp         : preview.timestamp,
				gravity_x         : preview.gravity.0,
				gravity_y         : preview.gravity.1,
				gravity_z         : preview.gravity.2,
				user_accleration_x: preview.userAcceleration.0,
				user_accleration_y: preview.userAcceleration.1,
				user_accleration_z: preview.userAcceleration.2,
				attitude_x        : preview.attitude.0,
				attitude_y        : preview.attitude.1,
				attitude_z        : preview.attitude.2
			).insert(db)
		} )

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
		let gravity         : (Double, Double, Double)
		let userAcceleration: (Double, Double, Double)
		let attitude        : (Double, Double, Double)
		let timestamp       : TimeInterval
		let fps             : Double
	}
	struct IMU: Codable, FetchableRecord, PersistableRecord {
		let id                 : Int64?
		let timestamp          : Double
		let gravity_x          : Double
		let gravity_y          : Double
		let gravity_z          : Double
		let user_accleration_x : Double
		let user_accleration_y : Double
		let user_accleration_z : Double
		let attitude_x         : Double
		let attitude_y         : Double
		let attitude_z         : Double
	}
}
