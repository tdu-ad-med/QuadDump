import AVFoundation

class MP4Recorder {
    private var writer: AVAssetWriter?
    private var tracks: [(AVAssetWriterInput, AVAssetWriterInputPixelBufferAdaptor)] = []
    private var isRecord_: Bool = false
    var isRecord: Bool {
        get { return self.isRecord_ }
    }

    func prepare() {
        // 保存先のパスを取得
        let outputURL = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).last!.appendingPathComponent("preview.mp4")

        // 既にファイルが存在する場合は削除
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try! FileManager.default.removeItem(at: outputURL)
        }

        self.writer = try! AVAssetWriter(outputURL: outputURL, fileType: AVFileType.mp4) 
        self.tracks = []
    }

    func addTrack(width: Int, height: Int, pixelFormat: OSType, lossless: Bool) -> Int? {
        guard let writer = self.writer else {
            return nil
        }

        if self.isRecord_ {
            return nil
        }

        var outputSettings: [String : Any] = [
            //AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ]
        if lossless {
            outputSettings[AVVideoCompressionPropertiesKey] = ["LossLess": true]
        }
        let writerInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: outputSettings)

        // 映像の回転
        writerInput.transform = CGAffineTransform(rotationAngle: CGFloat.pi * 0.5)
        writer.add(writerInput)

        let sourcePixelBufferAttributes: [String:Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(pixelFormat),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )
        writerInput.expectsMediaDataInRealTime = true

        self.tracks.append((writerInput, adaptor))
        return self.tracks.count - 1
    }

    func startRecord() {
        guard let writer = self.writer else {
            print("Failed to start writing.")
            return
        }

        if self.isRecord_ {
            print("Failed to start writing.")
            return
        }

        // 動画生成開始
        if (!writer.startWriting()) {
            print("Failed to start writing.")
            return
        }

        writer.startSession(atSourceTime: CMTime.zero)
        self.isRecord_ = true
    }

    func appendFrame(
        trackIndex: Int,
        pixelBuffer: CVPixelBuffer,
        timestamp: Int64
    ) {
        if (!self.isRecord_) { return }

        let adaptor = self.tracks[trackIndex].1
        if !adaptor.assetWriterInput.isReadyForMoreMediaData {
            print("skip")
            return
        }
        let frameTime = CMTimeMake(value: timestamp, timescale: 1000)
        if !adaptor.append(pixelBuffer, withPresentationTime: frameTime) {
            print("Failed to append buffer.")
        }
    }

    func stopRecord() {
        guard let writer = self.writer else {
            return
        }

        // 動画生成終了
        for track in self.tracks {
            track.0.markAsFinished()
        }
        //writer.endSession(atSourceTime: CMTimeMake(value: timestamp, timescale: 1000))
        writer.finishWriting {
            print("Finish writing!")
        }

        self.writer = nil
        self.tracks = []
        self.isRecord_ = false
    }
}
