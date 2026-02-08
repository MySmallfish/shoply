import SwiftUI

struct ListSwitcherView: View {
    @AppStorage("appLanguage") private var appLanguage = "he"

    let lists: [ShoppingList]
    let selectedListId: String?
    let currentUserId: String?
    let onSelect: (ShoppingList) -> Void
    let onRename: (ShoppingList) -> Void
    let onDelete: (ShoppingList) -> Void
    let onCreate: () -> Void
    let onJoin: () -> Void

    var body: some View {
        let selected = lists.first(where: { $0.id == selectedListId })
        Menu {
            ForEach(lists) { list in
                Button {
                    onSelect(list)
                } label: {
                    Text(list.title)
                }
            }

            Divider()

            if let selected, selected.createdBy == (currentUserId ?? "") {
                Button {
                    onRename(selected)
                } label: {
                    Text(L10n.string("Rename List", language: appLanguage))
                }

                Button(role: .destructive) {
                    onDelete(selected)
                } label: {
                    Text(L10n.string("Delete List", language: appLanguage))
                }

                Divider()
            }

            Button {
                onCreate()
            } label: {
                Text(L10n.string("New List", language: appLanguage))
            }

            Button {
                onJoin()
            } label: {
                Text(L10n.string("Join with Link", language: appLanguage))
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
            ?? L10n.string("Lists", language: appLanguage)
    }
}
