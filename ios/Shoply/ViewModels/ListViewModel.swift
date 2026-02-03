import FirebaseFirestore
import Foundation

@MainActor
final class ListViewModel: ObservableObject {
    @Published var items: [ShoppingItem] = []
    @Published var catalogItems: [CatalogItem] = []
    @Published var lastScannedBarcode: String?
    @Published var undoAction: UndoAction?

    private let repository = ListRepository()
    private var itemsListener: ListenerRegistration?
    private var catalogListener: ListenerRegistration?
    private var listId: String?
    private var userId: String?

    func bind(listId: String, userId: String, force: Bool = false, resetState: Bool = true) {
        if !force, self.listId == listId && self.userId == userId {
            return
        }

        itemsListener?.remove()
        itemsListener = nil
        catalogListener?.remove()
        catalogListener = nil
        if resetState {
            items = []
            catalogItems = []
            lastScannedBarcode = nil
            undoAction = nil
        }
        self.listId = listId
        self.userId = userId

        itemsListener = repository.listenToItems(listId: listId) { [weak self] items in
            Task { @MainActor in
                self?.items = items
            }
        }

        catalogListener = repository.listenToCatalogItems(userId: userId) { [weak self] items in
            Task { @MainActor in
                self?.catalogItems = items
            }
        }
    }

    func refresh() async {
        guard let listId = listId, let userId = userId else { return }
        bind(listId: listId, userId: userId, force: true, resetState: false)
    }

    func addItem(
        name: String,
        barcode: String? = nil,
        price: Double? = nil,
        description: String? = nil,
        icon: String? = nil
    ) {
        guard let listId = listId, let userId = userId else { return }
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
        if let existing = existingItem(name: name, barcode: barcode) {
            repository.adjustQuantity(
                listId: listId,
                itemId: existing.id,
                delta: 1,
                markUnbought: existing.isBought,
                barcode: barcode,
                price: price,
                description: description,
                icon: icon
            )
        } else {
            repository.addItem(
                listId: listId,
                name: name,
                barcode: barcode,
                price: price,
                description: description,
                icon: icon,
                userId: userId
            )
        }
        rememberItem(
            name: name,
            barcode: barcode,
            price: price,
            description: description,
            icon: icon
        )
    }

    func toggleBought(_ item: ShoppingItem) {
        guard let listId = listId, let userId = userId else { return }
        undoAction = UndoAction(
            listId: listId,
            itemId: item.id,
            wasBought: item.isBought,
            name: item.name
        )
        repository.toggleBought(listId: listId, item: item, userId: userId)
    }

    func setBought(_ item: ShoppingItem, isBought: Bool) {
        guard let listId = listId, let userId = userId else { return }
        undoAction = UndoAction(
            listId: listId,
            itemId: item.id,
            wasBought: item.isBought,
            name: item.name
        )
        repository.setBought(listId: listId, itemId: item.id, isBought: isBought, userId: userId)
    }

    func incrementQuantity(_ item: ShoppingItem) {
        guard let listId = listId else { return }
        repository.adjustQuantity(
            listId: listId,
            itemId: item.id,
            delta: 1,
            markUnbought: false,
            barcode: nil,
            price: nil,
            description: nil,
            icon: nil
        )
    }

    func decrementQuantity(_ item: ShoppingItem) {
        guard let listId = listId else { return }
        repository.adjustQuantity(
            listId: listId,
            itemId: item.id,
            delta: -1,
            markUnbought: false,
            barcode: nil,
            price: nil,
            description: nil,
            icon: nil
        )
    }

    func adjustQuantity(_ item: ShoppingItem, delta: Int) {
        guard let listId = listId else { return }
        if delta == 0 { return }
        repository.adjustQuantity(
            listId: listId,
            itemId: item.id,
            delta: delta,
            markUnbought: false,
            barcode: nil,
            price: nil,
            description: nil,
            icon: nil
        )
    }

    func deleteItem(_ item: ShoppingItem) {
        guard let listId = listId else { return }
        repository.deleteItem(listId: listId, itemId: item.id)
    }

    func updateItemDetails(itemId: String, draft: ItemDetailsDraft) {
        guard let listId = listId, let userId = userId else { return }
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let barcode = draft.barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        repository.updateItemDetails(
            listId: listId,
            itemId: itemId,
            name: name,
            barcode: barcode,
            price: draft.priceValue,
            description: draft.descriptionText,
            icon: draft.icon
        )
        rememberItem(
            name: name,
            barcode: barcode.isEmpty ? nil : barcode,
            price: draft.priceValue,
            description: draft.descriptionText,
            icon: draft.icon
        )
    }

    func applyScanPurchase(_ item: ShoppingItem, amount: Int) {
        guard let listId = listId else { return }
        if amount >= item.quantity {
            setBought(item, isBought: true)
            return
        }
        let remaining = max(1, item.quantity - amount)
        repository.updateQuantity(listId: listId, itemId: item.id, quantity: remaining, markUnbought: false)
    }

    func undoLastToggle() {
        guard let action = undoAction, let userId = userId else { return }
        repository.setBought(
            listId: action.listId,
            itemId: action.itemId,
            isBought: action.wasBought,
            userId: userId
        )
        undoAction = nil
    }

    func clearUndo() {
        undoAction = nil
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

    func catalogItemForBarcode(_ barcode: String) -> CatalogItem? {
        catalogItems.first { $0.barcode == barcode }
    }

    func matchingCatalogItem(for name: String) -> CatalogItem? {
        let trimmed = normalizedName(name)
        guard !trimmed.isEmpty else { return nil }
        return catalogItems.first { $0.normalizedName == trimmed }
    }

    func suggestions(for name: String, limit: Int = 4) -> [CatalogItem] {
        let query = normalizedName(name)
        guard !query.isEmpty else { return [] }
        let matches = catalogItems.filter {
            $0.normalizedName.hasPrefix(query) || $0.normalizedName.contains(query)
        }
        return Array(matches.prefix(limit))
    }

    private func existingItem(name: String, barcode: String?) -> ShoppingItem? {
        let trimmedBarcode = barcode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedBarcode.isEmpty {
            if let match = items.first(where: { $0.barcode == trimmedBarcode }) {
                return match
            }
        }
        let normalized = normalizedName(name)
        guard !normalized.isEmpty else { return nil }
        return items.first { $0.normalizedName == normalized }
    }

    private func rememberItem(
        name: String,
        barcode: String?,
        price: Double?,
        description: String?,
        icon: String?
    ) {
        guard let userId = userId else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalized = normalizedName(trimmed)
        let existing = catalogItems.first {
            if let barcode, !barcode.isEmpty, $0.barcode == barcode {
                return true
            }
            return $0.normalizedName == normalized
        }

        let resolvedBarcode = barcode ?? existing?.barcode
        let resolvedPrice = price ?? existing?.price
        let resolvedDescription = description ?? existing?.itemDescription
        let resolvedIcon = icon ?? existing?.icon

        repository.upsertCatalogItem(
            userId: userId,
            itemId: existing?.id,
            name: trimmed,
            barcode: resolvedBarcode,
            price: resolvedPrice,
            description: resolvedDescription,
            icon: resolvedIcon
        )
    }

    private func normalizedName(_ name: String) -> String {
        name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct UndoAction: Equatable {
    let listId: String
    let itemId: String
    let wasBought: Bool
    let name: String
}
