import SwiftUI

struct ContentView: View {
    var quadRecorder = QuadRecorder()
    @State private var errorAlert = false
    @State private var result: SimpleResult = Ok()
    @State private var preview: Image? = nil

    var body: some View {
        ZStack {
            if let preview = preview {
                preview
            }
            VStack {
                Text("Hello, world!")
                    .padding()
                Button(action: {
                    // 録画の状態を切り替え
                    if case .recording = quadRecorder.status {
                        result = quadRecorder.stop()
                    }
                    else {
                        result = quadRecorder.start()
                    }

                    // 処理が失敗した場合はアラートを表示
                    if case let .failure(e) = result {
                        errorAlert = true
                    }
                }) {
                    Text("hoge")
                }
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
