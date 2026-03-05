import SwiftUI

struct HomeHeaderView: View {
    var body: some View {
        HStack {
            Text("RepMate")
                .font(.headline)
                .bold()
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.top, 10)
    }
}
