import Foundation
import GRDB

class QuadRecorder {
	// setterのみをプライベートにする
	public private(set) var status: Status = .disable

	private var dbQueue: DatabaseQueue?

	private let camRecorder = CamRecorder()
	private let imuRecorder = IMURecorder()
	private let gpsRecorder = GPSRecorder()

	deinit {
		let _ = disable()
	}

	func preview(camPreview: ((CamRecorder.CamPreview) -> ())?) {
		camRecorder.preview(camPreview)
	}
	func preview(imuPreview: ((IMURecorder.IMUPreview) -> ())?) {
		imuRecorder.preview(imuPreview)
	}
	func preview(gpsPreview: ((GPSRecorder.GPSPreview) -> ())?) {
		gpsRecorder.preview(gpsPreview)
	}

	func timestamp(cam: ((TimeInterval, Double) -> ())?) {
		camRecorder.timestamp(cam)
	}
	func timestamp(imu: ((TimeInterval, Double) -> ())?) {
		imuRecorder.timestamp(imu)
	}
	func timestamp(gps: ((TimeInterval, Double) -> ())?) {
		gpsRecorder.timestamp(gps)
	}

	// センサーへのアクセスを開始
	func enable() -> SimpleResult {
		if case let .failure(e) = camRecorder.enable() { return Err(e.description) }
		if case let .failure(e) = imuRecorder.enable() { return Err(e.description) }
		if case let .failure(e) = gpsRecorder.enable() { return Err(e.description) }
		status = .idol
		return Ok()
	}

	// センサーへのアクセスを終了
	func disable() -> SimpleResult {
		let _ = stop()
		if case let .failure(e) = camRecorder.disable() { return Err(e.description) }
		if case let .failure(e) = imuRecorder.disable() { return Err(e.description) }
		if case let .failure(e) = gpsRecorder.disable() { return Err(e.description) }
		status = .disable
		return Ok()
	}

	// 録画開始
	func start(error: ((String) -> ())? = nil) {
		if case .disable   = status { error?("センサーへアクセスしていません"); return }
		if case .recording = status { error?("録画は既に開始しています"); return }

		// 録画開始時刻の記録
		let startDate = Date()
		let startTime = ProcessInfo.processInfo.systemUptime

		// 保存先のフォルダを作成
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss_SSS"
		let outputDirName = formatter.string(from: startDate)
		guard let outputDir = URL.docs?.createDir(name: outputDirName) else {
			error?("保存先フォルダの作成に失敗しました")
			return
		}

		// 保存先のデータベースを作成
		dbQueue = try? DatabaseQueue(path: outputDir.appendingPathComponent("db.sqlite3").path)
		guard let dbQueue = dbQueue else {
			error?("データベースの作成に失敗しました")
			return
		}

		// 映像の情報を記録
		guard let _ = ( try? dbQueue.write { db in
			struct Description: Codable, FetchableRecord, PersistableRecord {
				let date: Date
				let color_width : Int
				let color_height: Int
				let depth_width : Int?
				let depth_height: Int?
				let confidence_width : Int?
				let confidence_height: Int?
			}
			try db.create(table: "description") { t in
				t.column("date"             , .datetime).notNull()
				t.column("color_width"      , .integer ).notNull()
				t.column("color_height"     , .integer ).notNull()
				t.column("depth_width"      , .integer )
				t.column("depth_height"     , .integer )
				t.column("confidence_width" , .integer )
				t.column("confidence_height", .integer )
			}
			try Description(
				date: startDate,
				color_width : camRecorder.colorCamInfo!.0,
				color_height: camRecorder.colorCamInfo!.1,
				depth_width : camRecorder.depthCamInfo?.0,
				depth_height: camRecorder.depthCamInfo?.1,
				confidence_width : camRecorder.confidenceCamInfo?.0,
				confidence_height: camRecorder.confidenceCamInfo?.1
			).insert(db)
		} )
		else { error?("descriptionテーブルの作成に失敗しました"); return }

		// 録画に関する情報を設定
		let info = Info(
			startDate: startDate,
			startTime: startTime,
			outputDir: outputDir,
			dbQueue  : dbQueue
		)

		// 各センサーの録画開始
		camRecorder.start(info) { e in error?(e) }
		imuRecorder.start(info) { e in error?(e) }
		gpsRecorder.start(info) { e in error?(e) }

		status = .recording(info)
	}

	// 録画終了
	func stop(error: ((String) -> ())? = nil) {
		if case .disable = status { error?("センサーへアクセスしていません") }
		if case .idol    = status { error?("録画は既に終了しています") }

		// 各センサーの録画終了
		camRecorder.stop { e in error?(e) }
		imuRecorder.stop { e in error?(e) }
		gpsRecorder.stop { e in error?(e) }

		status = .idol
	}

	// 録画に関する情報
	struct Info {
		let startDate: Date           // 録画開始時刻(日時)
		let startTime: TimeInterval   // 録画開始時刻(デバイスを起動してからのTimeInterval)
		let outputDir: URL            // 保存先ディレクトリ
		let dbQueue  : DatabaseQueue  // 保存先データベース
	}

	// 録画状態
	enum Status {
		case disable          // センサーにアクセスしていない状態
		case idol             // 録画していない状態
		case recording(Info)  // 録画中
	}
}
