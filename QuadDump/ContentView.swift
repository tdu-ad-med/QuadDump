import SwiftUI

struct ContentView: View {
    @State private var errorAlert = false
    @State private var result: SimpleResult = Ok()

    var body: some View {
        Home(errorAlert: $errorAlert, result: $result)
            .alert(isPresented: $errorAlert) {
                var description: String? = nil
                if case let .failure(e) = result { description = e.description }
                return Alert(title: Text("Error"), message: Text(description ?? ""), dismissButton: .default(Text("OK")))
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDevice("iPad (8th generation)")
    }
}
