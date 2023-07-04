import Observation
import SwiftUI

class Observations {}

@Observable
class Suspect {
  init(name: String, suspiciousness: Int) {
    self.name = name
    self.suspiciousness = suspiciousness
  }

  var name: String = ""
  var suspiciousness: Int = 0
}

struct HomeView: View {
  @State var suspect =
    Suspect(name: "Jimmy The Shrimp", suspiciousness: 0)

  var body: some View {
    VStack(spacing: 0) {
      let _ = print("HomeView.body")
      GroupBox {
        Button {
          suspect.suspiciousness = 10
        } label: {
          Text("EXTREMELY SUSPICIOUS \(suspect.suspiciousness)")
        }

        Button {
          suspect.suspiciousness = 0
        } label: {
          Text("BARELY SUSPICIOUS")
        }
      }
      .padding(.horizontal, 20)
      SuspectView(suspect: suspect)
    }
  }
}

struct SuspectView: View {
  var suspect: Suspect

  var body: some View {
    Form {
      let _ = print("SuspectView.body")
      Text("Report on **\(suspect.name)**")
//      LabeledContent("Suspiciousness") {
//        Text("\(suspect.suspiciousness)")
//      }
//      Text(renderedSuspiciousness).italic()
    }.formStyle(.grouped)
  }

  var renderedSuspiciousness: String {
    switch suspect.suspiciousness {
    case 0: "A totally boring person"
    case 1: "Something about them seems off"
    case 2: "They're definitely hiding something"
    case 3: "They're probably a criminal"
    case 4: "They're definitely a criminal"
    case 5: "Man, they're so criminal"
    case 6: "I'd be shocked if they weren't a criminal"
    case 7: "My money's on them being a criminal"
    default: "HELP I'M TRAPPED IN A SUSPICIOUSNESS FACTORY"
    }
  }
}

#Preview {
  HomeView()
}
