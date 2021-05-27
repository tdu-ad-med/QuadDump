import ARKit

class ARRecorder: NSObject, ARSessionDelegate, Recorder {
    private var session = ARSession()
    private var isEnable: Bool = false
    var preview: UIImageView? = nil

    public override init() {
        super.init()
        self.session.delegate = self
    }

    deinit {
        let _ = disable()
    }

    func enable() -> SimpleResult {
        if isEnable { return Err("IMUは既に開始しています") }
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = .sceneDepth
        //configuration.frameSemantics = .smoothedSceneDepth
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

        guard let sceneDepth = frame.smoothedSceneDepth ?? frame.sceneDepth else { return }
        let depthPixelBuffer = sceneDepth.depthMap
        let confidencePixelBuffer = sceneDepth.confidenceMap!

        guard let preview = self.preview else { return }
        let context = CIContext(options: nil)
        let colorImage = CIImage(cvPixelBuffer: colorPixelBuffer).oriented(CGImagePropertyOrientation.right)
        guard let cameraColorImage = context.createCGImage(colorImage, from: colorImage.extent) else { return }
        preview.image = UIImage(cgImage: cameraColorImage)
    }
}
