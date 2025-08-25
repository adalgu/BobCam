import SwiftUI

struct ContentView: View {
    var body: some View {
        Rectangle()
            .fill(Color.red)
            .ignoresSafeArea()
            .overlay(
                VStack {
                    Text("SIMPLE RED TEST - Build 1900+")
                        .font(.largeTitle)
                        .fontWeight(.black)
                        .foregroundColor(.yellow)
                        .padding()
                    
                    Text("Simple deployment test!")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                    
                    Text(Date().formatted())
                        .font(.headline)
                        .foregroundColor(.green)
                        .padding()
                    
                    Spacer()
                }
            )
    }
}

#Preview {
    ContentView()
}