import AVFoundation

class MP4Writer {
    // MP4を書き込むクラス
    private var mp4: (AVAssetWriter, AVAssetWriterInput, AVAssetWriterInputPixelBufferAdaptor)? = nil

    var isRecording: Bool { mp4 != nil }

    func create(url: URL, width: Int, height: Int, pixelFormat: OSType) -> SimpleResult {
        // 既に書き込みが開始している場合はエラー
        if isRecording { return Err("録画は既に開始しています") }

        do {
            // 既にファイルが存在する場合は削除
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }

            // 書き込み開始
            let writer = try AVAssetWriter(outputURL: url, fileType: AVFileType.mp4) 

            // トラックの作成
            let track = AVAssetWriterInput(
                mediaType: AVMediaType.video,
                outputSettings: [
                    AVVideoCodecKey : AVVideoCodecType.hevc,
                    AVVideoWidthKey : width,
                    AVVideoHeightKey: height,
                ]
            )
            track.expectsMediaDataInRealTime = true
            //track.transform = CGAffineTransform(rotationAngle: CGFloat.pi * 0.5)  // 映像の回転

            // アダプタの作成
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: track,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(pixelFormat),
                    kCVPixelBufferWidthKey as String: width,
                    kCVPixelBufferHeightKey as String: height
                ]
            )

            // writerにトラックを追加
            if writer.canAdd(track) { writer.add(track) }
            else { return Err("mp4ファイルにトラックを追加できませんでした") }

            // 録画開始
            if !writer.startWriting() {
                return Err("録画の開始に失敗しました")
            }
            writer.startSession(atSourceTime: CMTime.zero)

            // 作成したインスタンスをプロパティに代入
            mp4 = (writer, track, adaptor)
        }
        catch {
            return Err("mp4ファイルの作成に失敗しました")
        }

        return Ok()
    }

    func append(pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) -> SimpleResult {
        guard let (_, _, adaptor) = mp4 else { return Err("録画が開始されていません") }

        // 処理が追い付いていない場合はフレームをスキップ
        if !adaptor.assetWriterInput.isReadyForMoreMediaData {
            return Err("mp4ファイルにフレームを追加できませんでした")
        }

        // フレームを追加
        let frameTime = CMTime(seconds: timestamp, preferredTimescale: 1000)
        if !adaptor.append(pixelBuffer, withPresentationTime: frameTime) {
            return Err("mp4ファイルにフレームを追加できませんでした")
        }

        return Ok()
    }

    func finish(error: ((String) -> ())? = nil) {
        guard let (writer, track, _) = mp4 else { error?("録画が開始されていません"); return }
        mp4 = nil

        // トラックにこれ以上動画を追加できないようにする
        track.markAsFinished()

        // メモ: writer.finishWriting を呼び出す場合は writer.endSession を呼び出さなくてもよい

        // 動画生成終了
        writer.finishWriting {
            // ここは呼び出し元とは異なるスレッドから呼ばれるようです
            if case .completed = writer.status {
                // 書き込みが成功
            }
            else {
                error?("動画の書き込みに失敗しました")
            }
        }
    }
}
