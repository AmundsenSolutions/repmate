import SwiftUI

struct HomeHeaderView: View {
    var body: some View {
        HStack {
            Text("Vext")
                .font(.headline)
                .bold()
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.top, 10)
    }
}
