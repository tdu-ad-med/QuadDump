import SwiftUI

struct ContentView: View {
    var quadRecorder = QuadRecorder()
    @State private var isRecording: Bool = false
    @State private var errorAlert = false
    @State private var result: SimpleResult = Ok()
    @State private var preview: ARRecorder.ARPreview? = nil
    private let timerFont = Font.custom("DIN Condensed", size: 48)
    private let normalFont = Font.custom("DIN Condensed", size: 24)
    private let smallFont = Font.custom("DIN Condensed", size: 16)

    var body: some View {
        ZStack(alignment: .center) {
            if let preview = preview { GeometryReader(content: { geometry in ZStack {
                // カメラをぼかした背景の表示
                preview.colorImage
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
                    let previewHeight = width * preview.colorSize.width / preview.colorSize.height
                    let top = max(geometry.size.height - previewHeight, 0) / 3
                    TabView {
                        preview.colorImage
                            .resizable()
                            .scaledToFit()
                        if let depthImage = preview.depthImage {
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
                    Text("1:07:33")
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
                            Text("32.8 Hz")
                                .font(normalFont)
                        }.frame(width: 70, height: 40)
                        VStack {
                            Text("IMU")
                                .font(smallFont)
                            Text("122.5 Hz")
                                .font(normalFont)
                        }.frame(width: 70, height: 40)
                        VStack {
                            Text("GPS")
                                .font(smallFont)
                            Text("0.75 Hz")
                                .font(normalFont)
                        }.frame(width: 70, height: 40)
                        VStack {
                            Text("Data Size")
                                .font(smallFont)
                            Text("12.2 GB")
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
                            let result = quadRecorder.start()
                            // 処理が失敗した場合はアラートを表示
                            if case let .failure(e) = result {
                                errorAlert = true
                                isRecording = false
                            }
                        },
                        end: {
                            result = quadRecorder.stop()
                            // 処理が失敗した場合はアラートを表示
                            if case let .failure(e) = result {
                                errorAlert = true
                            }
                        }
                    )
                    .padding(.bottom, 16)
                    .alert(isPresented: $errorAlert) {
                        var description: String? = nil
                        if case let .failure(e) = result { description = e.description }
                        return Alert(title: Text("Error"), message: Text(description ?? ""), dismissButton: .default(Text("OK")))
                    }
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
            print("appear")
            let _ = quadRecorder.enable()
            quadRecorder.arRecorder.callback = { preview in
                self.preview = preview
            }
        }
        .onDisappear {
            print("disappear")
            let _ = quadRecorder.disable()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
