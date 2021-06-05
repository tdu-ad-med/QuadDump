import SwiftUI

struct Home: View {
    @Binding var errorAlert: Bool
    @Binding var result: SimpleResult

    var quadRecorder = QuadRecorder()
    @State private var isRecording: Bool = false
    @State private var camPreview: CamRecorder.CamPreview? = nil
    @State private var imuPreview: IMURecorder.IMUPreview? = nil
    @State private var gpsPreview: GPSRecorder.GPSPreview? = nil
    @State private var timer: String = "00:00:00"
    private let timerFont = Font.custom("DIN Condensed", size: 48)
    private let normalFont = Font.custom("DIN Condensed", size: 24)
    private let smallFont = Font.custom("DIN Condensed", size: 16)

    var body: some View {
        ZStack(alignment: .center) {
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

                // カラーとデプスのプレビュー
                VStack() {
                    let width = geometry.size.width
                    let previewHeight = width * camPreview.colorSize.width / camPreview.colorSize.height
                    let top = max(geometry.size.height - previewHeight, 0) / 3
                    TabView {
                        camPreview.colorImage
                            .resizable()
                            .scaledToFit()
                        if let depthImage = camPreview.depthImage {
                            depthImage
                                .resizable()
                                .scaledToFit()
                        }
                    }
                        .tabViewStyle(PageTabViewStyle())
                        .frame(width: width, height: previewHeight)
                        .padding(.top, top)
                    Spacer()
                }

                // 撮影時間の表示
                VStack {
                    Text(self.timer)
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
                            Text(String(format: "%.1f Hz", camPreview.fps))
                                .font(normalFont)
                        }.frame(width: 70, height: 40)
                        VStack {
                            Text("IMU")
                                .font(smallFont)
                            Text(String(format: "%.1f Hz", imuPreview?.fps ?? 0))
                                .font(normalFont)
                        }.frame(width: 70, height: 40)
                        VStack {
                            Text("GPS")
                                .font(smallFont)
                            Text(String(format: "%.1f Hz", gpsPreview?.fps ?? 0))
                                .font(normalFont)
                        }.frame(width: 70, height: 40)
                    }
                    .padding(.bottom, 126)
                }
                .foregroundColor(Color(hex: 0xfeffff))
                .shadow(color: Color(hex: 0x000000, alpha: 0.4), radius: 6)

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
                            self.timer = TimeInterval(0).hhmmss
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
            }})}
            else { Text("please wait").font(normalFont) }
        }
        .onAppear {
            result = quadRecorder.enable()

            // 処理が失敗した場合はアラートを表示
            if case let .failure(_) = result {
                errorAlert = true
                isRecording = false
                return
            }

            quadRecorder.preview(
                camPreview: { camPreview in
                    self.camPreview = camPreview
                    if case let .recording(_) = self.quadRecorder.status {
                        self.timer = camPreview.timestamp.hhmmss
                    }
                },
                imuPreview: { imuPreview in
                    self.imuPreview = imuPreview
                },
                gpsPreview: { gpsPreview in
                    self.gpsPreview = gpsPreview
                }
            )
        }
        .onDisappear {
            result = quadRecorder.disable()

            // 処理が失敗した場合はアラートを表示
            if case let .failure(_) = result {
                errorAlert = true
                isRecording = false
                return
            }
        }
    }
}
