import SwiftUI

struct ListSwitcherView: View {
    let lists: [ShoppingList]
    let selectedListId: String?
    let onSelect: (ShoppingList) -> Void
    let onCreate: () -> Void
    let onJoin: () -> Void

    var body: some View {
        Menu {
            ForEach(lists) { list in
                Button(list.title) {
                    onSelect(list)
                }
            }

            Divider()

            Button("New List") {
                onCreate()
            }

            Button("Join with Link") {
                onJoin()
            }
        } label: {
            HStack(spacing: 6) {
                Text(currentTitle)
                    .font(.system(size: 17, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
    }

    private var currentTitle: String {
        lists.first(where: { $0.id == selectedListId })?.title
            ?? NSLocalizedString("Lists", comment: "")
    }
}
