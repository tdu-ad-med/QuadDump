import SwiftUI

struct ContentView: View {
    var quadRecorder = QuadRecorder()
    @State private var isRecording: Bool = false
    @State private var errorAlert = false
    @State private var result: SimpleResult = Ok()
    @State private var preview: Image? = nil
    private let font = Font.custom("DIN Condensed", size: 32)

    var body: some View {
        ZStack {
            if let preview = preview {
                    ZStack {
                        GeometryReader(content: { geometry in
                            preview
                                .resizable()
                                .scaledToFill()
                                .edgesIgnoringSafeArea(.all)
                                .blur(radius: 30)
                                .opacity(0.4)
                                .background(Color(hex: 0x000000))
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        })
                        VStack {
                            Spacer()
                            preview
                                .resizable()
                                .scaledToFit()
                            Spacer()
                            Spacer()
                        }
                    }
            }
            VStack {
                Text("00:00:00")
                    .font(font)
                    .foregroundColor(Color(hex: 0xfeffff))
                    .shadow(color: Color(hex: 0x000000, alpha: 0.4), radius: 6)
                    .padding(.top, 16)
                Spacer()
            }
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
        }
        .onAppear {
            print("appear")
            let _ = quadRecorder.enable()
            quadRecorder.arRecorder.callback = { image in
                self.preview = image
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
