import CoreLocation

class GPSRecorder: NSObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    private var isEnable: Bool = false
    private var isRecording: Bool = false
    private var lastUpdate: TimeInterval = 0.0
    private var previewLastUpdate: TimeInterval = 0.0
    private var previewCallback: ((GPSPreview) -> ())? = nil
    private let systemUptime = Date(timeIntervalSinceNow: -ProcessInfo.processInfo.systemUptime)  // システムが起動した日時

    deinit {
        let _ = disable()
    }

    func preview(_ preview: ((GPSPreview) -> ())?) {
        self.previewCallback = preview
    }

    func enable() -> SimpleResult {
        if isEnable { return Err("GPSは既に開始しています") }

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()

        isEnable = true

        return Ok()
    }

    func disable() -> SimpleResult {
        if (!isEnable) { return Err("GPSは既に終了しています") }
        let _ = stop()
        locationManager.stopUpdatingLocation()
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

    // GPS座標が更新されたときに呼ばれるDelegate
    func locationManager(_ locationManager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for (index, location) in locations.enumerated() {
            // システムが起動してからの時刻に変換
            let timestamp = systemUptime.distance(to: location.timestamp)

            let fps = 1.0 / (timestamp - lastUpdate)
            lastUpdate = timestamp
            
            let preview = GPSPreview(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitude: location.altitude,
                horizontalAccuracy: location.horizontalAccuracy,
                verticalAccuracy: location.verticalAccuracy,
                timestamp: timestamp,
                fps: fps
            )

            if index == (locations.count - 1) {
                if (timestamp - previewLastUpdate) > 0.1 {
                    previewLastUpdate = timestamp
                    previewCallback?(preview)
                }
            }
        }
    }

    // GPSへのアクセス権限が変更されたときに呼ばれるDelegate
    func locationManagerDidChangeAuthorization(_ locationManager: CLLocationManager) {
        switch locationManager.authorizationStatus {
        case .restricted, .denied, .notDetermined:     // GPSへのアクセス権がないとき
            break
        case .authorizedAlways, .authorizedWhenInUse:  // GPSへのアクセス権があるとき
            // 高精度のGPS座標取得を要求
            locationManager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "trajectory")
        }
    }

    struct GPSPreview {
        let latitude: Double            // 緯度
        let longitude: Double           // 経度
        let altitude: Double            // 高度
        let horizontalAccuracy: Double  // メートル単位で表されるlatitude, longitudeの誤差の半径
        let verticalAccuracy: Double    // メートル単位で表されるaltitudeの誤差
        let timestamp: TimeInterval
        let fps: Double
    }
}
