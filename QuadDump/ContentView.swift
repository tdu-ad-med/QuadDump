import SwiftUI

struct ContentView: View {
    var quadRecorder = QuadRecorder()
    @State private var isRecording: Bool = false
    @State private var errorAlert = false
    @State private var result: SimpleResult = Ok()
    @State private var preview: Image? = nil

    var body: some View {
        ZStack {
            if let preview = preview {
                preview
                    .resizable()
                    .scaledToFit()
                    .padding(.top, 74)
                    .padding(.bottom, 200)
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
                .padding(.bottom, 64)
                .alert(isPresented: $errorAlert) {
                    var description: String? = nil
                    if case let .failure(e) = result { description = e.description }
                    return Alert(title: Text("Error"), message: Text(description ?? ""), dismissButton: .default(Text("OK")))
                }
            }
            Text("Hello, world!")
                .padding(.bottom, 100)
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
