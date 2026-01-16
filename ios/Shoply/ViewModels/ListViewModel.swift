import FirebaseFirestore
import Foundation

@MainActor
final class ListViewModel: ObservableObject {
    @Published var items: [ShoppingItem] = []
    @Published var lastScannedBarcode: String?

    private let repository = ListRepository()
    private var itemsListener: ListenerRegistration?
    private var listId: String?
    private var userId: String?

    func bind(listId: String, userId: String, force: Bool = false, resetState: Bool = true) {
        if !force, self.listId == listId && self.userId == userId {
            return
        }

        itemsListener?.remove()
        itemsListener = nil
        if resetState {
            items = []
            lastScannedBarcode = nil
        }
        self.listId = listId
        self.userId = userId

        itemsListener = repository.listenToItems(listId: listId) { [weak self] items in
            Task { @MainActor in
                self?.items = items
            }
        }
    }

    func refresh() async {
        guard let listId = listId, let userId = userId else { return }
        bind(listId: listId, userId: userId, force: true, resetState: false)
    }

    func addItem(name: String, barcode: String? = nil) {
        guard let listId = listId, let userId = userId else { return }
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
        repository.addItem(listId: listId, name: name, barcode: barcode, userId: userId)
    }

    func toggleBought(_ item: ShoppingItem) {
        guard let listId = listId, let userId = userId else { return }
        repository.toggleBought(listId: listId, item: item, userId: userId)
    }

    func handleScan(barcode: String) {
        lastScannedBarcode = barcode
    }

    func clearScan() {
        lastScannedBarcode = nil
    }

    func itemForBarcode(_ barcode: String) -> ShoppingItem? {
        items.first { $0.barcode == barcode }
    }
}
