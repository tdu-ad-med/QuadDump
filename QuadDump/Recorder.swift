protocol Recorder {
	// センサーへのアクセスを開始
	func enable() -> SimpleResult

	// センサーへのアクセスを終了
	func disable() -> SimpleResult

	// センサーの録画を開始
	func start() -> SimpleResult

	// センサーの録画を終了
	func stop() -> SimpleResult
}
