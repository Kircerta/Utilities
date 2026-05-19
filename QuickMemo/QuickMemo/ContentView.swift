import SwiftUI

struct ContentView: View {
    
    @AppStorage("savedMemoText") private var memoText: String = ""
    
    var body: some View {

        TextEditor(text: $memoText)
            

            .frame(width: 350, height: 250)
            
            .font(.system(size: 14, design: .default))
            
            .padding(8)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// currently, the app is in the form of menu bar icon. No option to exit.
// new functionalities will be implement as the development goes on.
