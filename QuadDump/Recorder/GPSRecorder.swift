import CoreLocation
import GRDB

class GPSRecorder: NSObject, CLLocationManagerDelegate {
	// GPSにアクセスするためのクラス
	private let locationManager = CLLocationManager()

	private let encodeQueue: OperationQueue = {
		// 2つ以上のスレッドから同時にファイルへ書き込まれるとよくないので
		// OperationQueueの並列化はしない
		let queue = OperationQueue()
		queue.maxConcurrentOperationCount = 1
		return queue
	}()

	// GPSへのアクセスが開始されているか
	private var isEnable: Bool = false

	// 録画に関する情報を設定
	private var info: QuadRecorder.Info?
	private var isRecording: Bool { return info != nil }

	// GPSから最後にデータを取得した時刻
	private var lastUpdate: TimeInterval = 0.0

	// 最後にpreviewCallbackを呼んだ時刻
	private var previewLastUpdate: TimeInterval = 0.0

	//GPSSのプレビューを表示するときに呼ぶコールバック関数
	private var previewCallback: ((GPSPreview) -> ())? = nil
	private var timestampCallback: ((TimeInterval, Double) -> ())? = nil

	// インスタンス作成時刻
	private var systemUptime = Date(timeIntervalSinceNow: -ProcessInfo.processInfo.systemUptime)

	deinit {
		if isEnable { let _ = disable() }
	}

	// プレビューデータを受け取るコールバック関数の登録
	func preview(_ preview: ((GPSPreview) -> ())?) {
		previewCallback = preview
	}
	func timestamp(_ timestamp: ((TimeInterval, Double) -> ())?) {
		timestampCallback = timestamp
	}

	// GPSへのアクセスを開始
	func enable() -> SimpleResult {
		if isEnable { return Err("GPSは既に開始しています") }

		locationManager.delegate = self
		locationManager.desiredAccuracy = kCLLocationAccuracyBest
		locationManager.requestWhenInUseAuthorization()
		locationManager.startUpdatingLocation()

		isEnable = true

		return Ok()
	}

	// GPSへのアクセスを停止
	func disable() -> SimpleResult {
		if (!isEnable) { return Err("GPSは既に終了しています") }

		encodeQueue.addOperation { [weak self] in
			guard let self = self else { return }
			if self.isRecording { self.stop() }  // 録画中であれば録画を終了
		}
		locationManager.stopUpdatingLocation()
		isEnable = false

		return Ok()
	}

	// 録画開始
	func start(_ info: QuadRecorder.Info, error: ((String) -> ())? = nil) {
		encodeQueue.addOperation { [weak self] in
			guard let self = self else { return }
			self.info = info
			self.systemUptime = Date(timeIntervalSinceNow: -ProcessInfo.processInfo.systemUptime)

			// テーブルの作成
			guard let _ = ( try? self.info?.dbQueue.write { db in
				try db.create(table: "gps") { t in
					t.autoIncrementedPrimaryKey("id").notNull()
					t.column("timestamp"          , .double).notNull()
					t.column("latitude"           , .double).notNull()
					t.column("longitude"          , .double).notNull()
					t.column("altitude"           , .double).notNull()
					t.column("horizontal_accuracy", .double).notNull()
					t.column("vertical_accuracy"  , .double).notNull()
				}
			} )
			else {
				self.stop()
				DispatchQueue.main.async { error?("gpsテーブルの作成に失敗しました") }
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

	// GPSが更新されたときに呼ばれるメソッド
	func locationManager(_ locationManager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		encodeQueue.addOperation { [weak self] in
			guard let self = self else { return }

			for (index, location) in locations.enumerated() {
				// システムが起動してからの時刻に変換
				let timestamp = self.systemUptime.distance(to: location.timestamp)

				// フレームレートの計算
				let fps = 1.0 / (timestamp - self.lastUpdate)
				self.lastUpdate = timestamp

				// プレビュー用のデータ作成
				let preview = GPSPreview(
					latitude          : location.coordinate.latitude,
					longitude         : location.coordinate.longitude,
					altitude          : location.altitude,
					horizontalAccuracy: location.horizontalAccuracy,
					verticalAccuracy  : location.verticalAccuracy,
					timestamp         : timestamp - (self.info?.startTime ?? 0.0),
					fps               : fps
				)

				// 録画が開始されている場合
				let _ = ( try? self.info?.dbQueue.write { db in
					try GPS(
						id: nil,
						timestamp          : preview.timestamp,
						latitude           : preview.latitude,
						longitude          : preview.longitude,
						altitude           : preview.altitude,
						horizontal_accuracy: preview.horizontalAccuracy,
						vertical_accuracy  : preview.verticalAccuracy
					).insert(db)
				} )

				if index == (locations.count - 1) {
					if (timestamp - self.previewLastUpdate) > (1.0 / 10.0) {
						self.previewLastUpdate = timestamp
						DispatchQueue.main.async { [weak self] in
							guard let self = self else { return }
							self.timestampCallback?(self.isRecording ? preview.timestamp : 0.0, fps)
							self.previewCallback?(preview)
						}
					}
				}
			}
		}
	}

	// GPSへのアクセス権限が変更されたときに呼ばれるDelegate
	func locationManagerDidChangeAuthorization(_ locationManager: CLLocationManager) {
		switch locationManager.authorizationStatus {
		case .restricted, .denied, .notDetermined:	   // GPSへのアクセス権がないとき
			break
		case .authorizedAlways, .authorizedWhenInUse:  // GPSへのアクセス権があるとき
			// 高精度のGPS座標取得を要求
			locationManager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "trajectory")
		@unknown default:
			break
		}
	}

	struct GPSPreview {
		let latitude          : Double		  // 緯度
		let longitude         : Double		  // 経度
		let altitude          : Double		  // 高度
		let horizontalAccuracy: Double		  // メートル単位で表されるlatitude, longitudeの誤差の半径
		let verticalAccuracy  : Double		  // メートル単位で表されるaltitudeの誤差
		let timestamp         : TimeInterval
		let fps               : Double
	}
	struct GPS: Codable, FetchableRecord, PersistableRecord {
		let id                 : Int64?
		let timestamp          : Double
		let latitude           : Double
		let longitude          : Double
		let altitude           : Double
		let horizontal_accuracy: Double
		let vertical_accuracy  : Double
	}
}
