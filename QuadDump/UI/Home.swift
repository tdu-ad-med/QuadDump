import SwiftUI

struct Home: View {
    @State private var errorAlert = false
    @State private var result: SimpleResult = Ok()
    @State private var previewMode: Bool = false
    let quadRecorder = QuadRecorder()

    var body: some View {
        ZStack {
            // カメラのプレビュー
            CameraViewSub(quadRecorder: quadRecorder)

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

struct CameraViewSub: View {
    let quadRecorder: QuadRecorder
    @State private var previewMode: Bool = false

    var body: some View {
        ZStack {
            GeometryReader(content: { geometry in ZStack {
                // カラーのプレビュー
                VStack() {
                    let width = geometry.size.width
                    let previewHeight = width * 16 / 12
                    let top = max(geometry.size.height - previewHeight, 0) / 3
                    CameraView(quadRecorder: quadRecorder, previewMode: $previewMode)
                        .frame(width: width, height: previewHeight)
                        .padding(.top, top)
                        // タップイベントの処理
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                .onEnded { value in
                                    previewMode = !previewMode
                                }
                        )
                    Spacer()
                }
            }})
        }
    }
}

struct StatusTextView: View {
    let quadRecorder: QuadRecorder
    @State private var camTime: (TimeInterval, Double) = (0.0, 0.0)
    @State private var imuTime: (TimeInterval, Double) = (0.0, 0.0)
    @State private var gpsTime: (TimeInterval, Double) = (0.0, 0.0)
    @State private var firstAnim: Bool = true
    private let timerFont = Font.custom("DIN Condensed", size: 48)
    private let normalFont = Font.custom("DIN Condensed", size: 24)
    private let smallFont = Font.custom("DIN Condensed", size: 16)

    // バネマスダンパー系で臨界減衰となるようなアニメーションの作成
    //   臨界減衰となる条件: damping = sqrt(stiffness) * 2
    private var buttonAnimation: Animation {
        Animation.interpolatingSpring(mass: 1.0, stiffness: 100, damping: sqrt(60) * 2)
    }

    var body: some View {
        ZStack {
            // 撮影時間の表示
            VStack {
                Text(camTime.0.hhmmss)
                    .font(timerFont)
                    .foregroundColor(Color(hex: 0xfeffff))
                    .shadow(color: Color(hex: 0x000000, alpha: 0.4), radius: 6)
                    .padding(.top, firstAnim ? -60 : 40)
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
                    }
                    .frame(width: firstAnim ? 120 : 70, height: 40)
                    .rotationEffect(Angle(degrees: firstAnim ? 10.0 : 0.0))
                    VStack {
                        Text("IMU")
                            .font(smallFont)
                        Text(String(format: "%.1f Hz", imuTime.1))
                            .font(normalFont)
                        Text(imuTime.0.hhmmss)
                            .font(smallFont)
                    }
                    .frame(width: firstAnim ? 120 : 70, height: 40)
                    VStack {
                        Text("GPS")
                            .font(smallFont)
                        Text(String(format: "%.1f Hz", gpsTime.1))
                            .font(normalFont)
                        Text(gpsTime.0.hhmmss)
                            .font(smallFont)
                    }
                    .frame(width: firstAnim ? 120 : 70, height: 40)
                    .rotationEffect(Angle(degrees: firstAnim ? -10.0 : 0.0))
                }
                .padding(.bottom, firstAnim ? -80 : 120)
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
            firstAnim = false
        }
        .onDisappear {
            firstAnim = true
        }
        .animation(buttonAnimation, value: firstAnim)
    }
}

struct ButtonsView: View {
    let quadRecorder: QuadRecorder
    @Binding var errorAlert: Bool
    @Binding var result: SimpleResult
    @State private var isRecording: Bool = false

    // バネマスダンパー系で臨界減衰となるようなアニメーションの作成
    //   臨界減衰となる条件: damping = sqrt(stiffness) * 2
    private var buttonAnimation: Animation {
        Animation.interpolatingSpring(mass: 1.0, stiffness: 100, damping: sqrt(60) * 2)
    }

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
