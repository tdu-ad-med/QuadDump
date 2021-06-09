import SwiftUI

struct Home: View {
    @State private var errorAlert = false
    @State private var result: SimpleResult = Ok()
    let quadRecorder = QuadRecorder()

    var body: some View {
        ZStack {
            // カメラのプレビュー
            CameraView(quadRecorder: quadRecorder)

            // 録画時間やセンサーのフレームレートの表示
            StatusTextView(quadRecorder: quadRecorder)

            // 操作ボタン
            ButtonsView(quadRecorder: quadRecorder, errorAlert: $errorAlert, result: $result)
        }
        .alert(isPresented: $errorAlert) {
            var description: String? = nil
            if case let .failure(e) = result { description = e.description }
            return Alert(title: Text("Error"), message: Text(description ?? ""), dismissButton: .default(Text("OK")))
        }
    }
}

struct CameraView: View {
    let quadRecorder: QuadRecorder
    @State private var camPreview: CamRecorder.CamPreview? = nil
    private let normalFont = Font.custom("DIN Condensed", size: 24)

    var body: some View {
        ZStack {
            if let camPreview = camPreview { GeometryReader(content: { geometry in ZStack {
                // カメラをぼかした背景の表示
                camPreview.colorImage
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 10)
                    .opacity(0.4)
                    .background(Color(hex: 0x000000))
                    .edgesIgnoringSafeArea(.all)
                    .frame(width: geometry.size.width, height: geometry.size.height)

                // カラーのプレビュー
                VStack() {
                    let width = geometry.size.width
                    let previewHeight = width * camPreview.colorSize.width / camPreview.colorSize.height
                    let top = max(geometry.size.height - previewHeight, 0) / 3
                    camPreview.colorImage
                        .resizable()
                        .scaledToFit()
                        .frame(width: width, height: previewHeight)
                        .padding(.top, top)
                    Spacer()
                }
            }})}
            else { Text("please wait").font(normalFont) }
        }
        .onAppear {
            quadRecorder.preview { camPreview in
                self.camPreview = camPreview
            }
        }
    }
}

struct StatusTextView: View {
    let quadRecorder: QuadRecorder
    @State private var camTime: (TimeInterval, Double) = (0.0, 0.0)
    @State private var imuTime: (TimeInterval, Double) = (0.0, 0.0)
    @State private var gpsTime: (TimeInterval, Double) = (0.0, 0.0)
    private let timerFont = Font.custom("DIN Condensed", size: 48)
    private let normalFont = Font.custom("DIN Condensed", size: 24)
    private let smallFont = Font.custom("DIN Condensed", size: 16)

    var body: some View {
        ZStack {
            // 撮影時間の表示
            VStack {
                Text(camTime.0.hhmmss)
                    .font(timerFont)
                    .foregroundColor(Color(hex: 0xfeffff))
                    .shadow(color: Color(hex: 0x000000, alpha: 0.4), radius: 6)
                    .padding(.top, 40)
                Spacer()
            }

            // フレームレートなどの情報を表示
            VStack {
                Spacer()
                HStack {
                    VStack {
                        Text("Camera")
                            .font(smallFont)
                        Text(String(format: "%.1f Hz", camTime.1))
                            .font(normalFont)
                        Text(camTime.0.hhmmss)
                            .font(smallFont)
                    }.frame(width: 70, height: 40)
                    VStack {
                        Text("IMU")
                            .font(smallFont)
                        Text(String(format: "%.1f Hz", imuTime.1))
                            .font(normalFont)
                        Text(imuTime.0.hhmmss)
                            .font(smallFont)
                    }.frame(width: 70, height: 40)
                    VStack {
                        Text("GPS")
                            .font(smallFont)
                        Text(String(format: "%.1f Hz", gpsTime.1))
                            .font(normalFont)
                        Text(gpsTime.0.hhmmss)
                            .font(smallFont)
                    }.frame(width: 70, height: 40)
                }
                .padding(.bottom, 126)
            }
            .foregroundColor(Color(hex: 0xfeffff))
            .shadow(color: Color(hex: 0x000000, alpha: 0.4), radius: 6)
        }
        .onAppear {
            quadRecorder.timestamp(cam: { (time, fps) in
                self.camTime = (time, fps)
            })
            quadRecorder.timestamp(imu: { (time, fps) in
                self.imuTime = (time, fps)
            })
            quadRecorder.timestamp(gps: { (time, fps) in
                self.gpsTime = (time, fps)
            })
        }
    }
}

struct ButtonsView: View {
    let quadRecorder: QuadRecorder
    @Binding var errorAlert: Bool
    @Binding var result: SimpleResult
    @State private var isRecording: Bool = false

    var body: some View {
        ZStack {
            // 録画ボタンの表示
            VStack {
                Spacer()
                RecordButton(state: $isRecording,
                    begin: {
                        quadRecorder.start { e in
                            // 処理が失敗した場合はアラートを表示
                            isRecording = false
                            result = Err(e)
                            errorAlert = true
                        }
                    },
                    end: {
                        quadRecorder.stop { e in
                            // 処理が失敗した場合はアラートを表示
                            result = Err(e)
                            errorAlert = true
                        }
                    }
                )
                .padding(.bottom, 16)
            }

            // 録画一覧に飛ぶボタンの表示
            VStack {
                Spacer()
                HStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: 0x000000, alpha: 0.6))
                        .frame(width: 49, height: 49)
                        .padding(.leading, 20)
                    Spacer()
                }
                .padding(.bottom, 27)
            }
        }
        .onAppear {
            result = quadRecorder.enable()

            // 処理が失敗した場合はアラートを表示
            if case .failure = result {
                errorAlert = true
                isRecording = false
                return
            }
        }
        .onDisappear {
            result = quadRecorder.disable()

            // 処理が失敗した場合はアラートを表示
            if case .failure = result {
                errorAlert = true
                isRecording = false
                return
            }
        }
    }
}
