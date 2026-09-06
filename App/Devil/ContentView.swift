import DevilKit
import SwiftUI

struct ContentView: View {
  var body: some View {
    VStack(spacing: 8) {
      Text(Brew.name)
        .font(.largeTitle.weight(.semibold))
      Text(Brew.brewer)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
  }
}

#Preview {
  ContentView()
}
