import SwiftUI

struct AboutView: View {
    let readme: String

    var body: some View {
        DisclosureGroup("About this case study") {
            Text(readme)
        }
    }
}

