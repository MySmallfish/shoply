import SwiftUI

struct MainListView: View {
    @EnvironmentObject private var session: SessionViewModel
    @StateObject private var listViewModel = ListViewModel()

    @State private var newItemName = ""
    @State private var showScanner = false
    @State private var showInvite = false
    @State private var showCreateList = false
    @State private var showJoin = false
    @State private var showMembers = false
    @State private var showPendingInvites = false
    @State private var showAddFromScan = false
    @State private var scannedBarcode = ""
    @State private var scannedDraft = ItemDetailsDraft()
    @State private var adjustItem: ShoppingItem?
    @State private var selectedSuggestion: CatalogItem?
    @State private var showDetails = false
    @State private var detailsDraft = ItemDetailsDraft()
    @State private var undoTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                if let listId = session.selectedListId {
                    listContent(listId: listId)
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                let suggestions = listViewModel.suggestions(for: newItemName)
                VStack(spacing: 0) {
                    if !suggestions.isEmpty {
                        suggestionsView(suggestions)
                    }
                    AddItemBar(text: $newItemName, onAdd: addCurrentItem, onDetails: openDetails)
                        .disabled(session.selectedListId == nil)
                }
            }
        }
        .onAppear {
            bindIfNeeded()
        }
        .onChange(of: session.selectedListId) { _ in
            bindIfNeeded()
        }
        .onChange(of: listViewModel.lastScannedBarcode) { code in
            handleScan(code: code)
        }
        .onChange(of: newItemName) { value in
            if let suggestion = selectedSuggestion,
               normalizedName(value) != suggestion.normalizedName {
                selectedSuggestion = nil
            }
        }
        .onChange(of: listViewModel.undoAction) { action in
            undoTask?.cancel()
            guard let action else { return }
            undoTask = Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await MainActor.run {
                    if listViewModel.undoAction == action {
                        listViewModel.clearUndo()
                    }
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            ScannerView { code in
                listViewModel.handleScan(barcode: code)
                showScanner = false
            }
        }
        .sheet(isPresented: $showInvite) {
            InviteView()
                .environmentObject(session)
        }
        .sheet(isPresented: $showCreateList) {
            CreateListView()
                .environmentObject(session)
        }
        .sheet(isPresented: $showJoin) {
            JoinListView()
                .environmentObject(session)
        }
        .sheet(isPresented: $showMembers) {
            MembersView()
                .environmentObject(session)
        }
        .sheet(isPresented: $showPendingInvites) {
            PendingInvitesView()
                .environmentObject(session)
        }
        .sheet(isPresented: $showAddFromScan, onDismiss: {
            listViewModel.clearScan()
        }) {
            AddScannedItemView(barcode: scannedBarcode, draft: scannedDraft) { draft in
                addItemFromDraft(draft)
                listViewModel.clearScan()
            }
        }
        .sheet(isPresented: $showDetails) {
            AddItemDetailsView(draft: detailsDraft, allowBarcodeEdit: detailsDraft.barcode.isEmpty) { draft in
                addItemFromDraft(draft)
                newItemName = ""
                selectedSuggestion = nil
            }
        }
        .sheet(item: $adjustItem, onDismiss: {
            listViewModel.clearScan()
        }) { item in
            AdjustQuantityView(item: item) { delta in
                listViewModel.adjustQuantity(item, delta: delta)
            }
        }
        .confirmationDialog(
            "Merge lists?",
            isPresented: Binding(
                get: { session.mergePrompt != nil },
                set: { if !$0 { session.mergePrompt = nil } }
            )
        ) {
            Button("Merge") {
                if let prompt = session.mergePrompt {
                    session.mergeInvitedList(prompt)
                }
            }
            Button("Keep Separate") {
                if let prompt = session.mergePrompt {
                    session.keepInviteSeparate(prompt)
                }
            }
        } message: {
            if let prompt = session.mergePrompt {
                Text("You already have a list named \"\(prompt.existingListTitle)\". Merge it into \"\(prompt.invitedListTitle)\"?")
            }
        }
        .alert(
            "Merge failed",
            isPresented: Binding(
                get: { session.mergeActionError != nil },
                set: { if !$0 { session.mergeActionError = nil } }
            )
        ) {
            Button("OK") { session.mergeActionError = nil }
        } message: {
            Text(session.mergeActionError ?? "Unable to merge lists.")
        }
        .overlay(alignment: .bottom) {
            if let undoAction = listViewModel.undoAction {
                UndoToastView(
                    title: undoAction.wasBought ? "Marked unbought" : "Marked bought",
                    onUndo: { listViewModel.undoLastToggle() },
                    onDismiss: { listViewModel.clearUndo() }
                )
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ListSwitcherView(
                lists: session.lists,
                selectedListId: session.selectedListId,
                onSelect: { session.selectList($0.id) },
                onCreate: { showCreateList = true },
                onJoin: { showJoin = true }
            )

            Spacer()

            HStack(spacing: 14) {
                Button(action: { showMembers = true }) {
                    Image(systemName: "person.2")
                }
                Button(action: { showInvite = true }) {
                    Image(systemName: "person.badge.plus")
                }
                Button(action: { showScanner = true }) {
                    Image(systemName: "barcode.viewfinder")
                }
                Menu {
                    Button(pendingInvitesTitle) {
                        showPendingInvites = true
                    }
                    Button("Sign Out", role: .destructive) {
                        session.signOut()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .bottom)
    }

    @ViewBuilder
    private func listContent(listId: String) -> some View {
        List {
            ForEach(listViewModel.items) { item in
                ItemRow(item: item,
                        onTap: { adjustItem = item },
                        onIncrement: { listViewModel.incrementQuantity(item) },
                        onDecrement: { listViewModel.decrementQuantity(item) })
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await listViewModel.refresh()
        }
        .overlay {
            if listViewModel.items.isEmpty {
                emptyItemsState
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No list selected")
                .font(.system(size: 18, weight: .semibold))
            Text("Create a list to start sharing")
                .foregroundColor(.secondary)
            Button("Create List") {
                showCreateList = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyItemsState: some View {
        VStack(spacing: 10) {
            Image(systemName: "cart")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("Add your first item")
                .font(.system(size: 18, weight: .semibold))
            Text("Use the bar below or scan a barcode.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    private var pendingInvitesTitle: String {
        let count = session.pendingInvites.count
        return count > 0 ? "Pending Invitations (\(count))" : "Pending Invitations"
    }

    private func bindIfNeeded() {
        guard let listId = session.selectedListId,
              let userId = session.user?.uid else { return }
        listViewModel.bind(listId: listId, userId: userId)
    }

    private func handleScan(code: String?) {
        guard let code = code else { return }
        if let item = listViewModel.itemForBarcode(code) {
            adjustItem = item
        } else {
            scannedBarcode = code
            if let catalog = listViewModel.catalogItemForBarcode(code) {
                scannedDraft = ItemDetailsDraft(
                    name: catalog.name,
                    barcode: code,
                    priceText: catalog.price.map { String($0) } ?? "",
                    descriptionText: catalog.itemDescription ?? "",
                    icon: catalog.icon ?? ""
                )
            } else {
                scannedDraft = ItemDetailsDraft(name: "", barcode: code)
            }
            showAddFromScan = true
        }
    }

    private func addCurrentItem() {
        let trimmed = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let suggestion = selectedSuggestion ?? listViewModel.matchingCatalogItem(for: trimmed)
        listViewModel.addItem(
            name: trimmed,
            barcode: suggestion?.barcode,
            price: suggestion?.price,
            description: suggestion?.itemDescription,
            icon: suggestion?.icon
        )
        newItemName = ""
        selectedSuggestion = nil
    }

    private func openDetails() {
        let trimmed = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        let suggestion = selectedSuggestion ?? listViewModel.matchingCatalogItem(for: trimmed)
        detailsDraft = ItemDetailsDraft(
            name: trimmed.isEmpty ? (suggestion?.name ?? "") : trimmed,
            barcode: suggestion?.barcode ?? "",
            priceText: suggestion?.price.map { String($0) } ?? "",
            descriptionText: suggestion?.itemDescription ?? "",
            icon: suggestion?.icon ?? ""
        )
        showDetails = true
    }

    private func addItemFromDraft(_ draft: ItemDetailsDraft) {
        listViewModel.addItem(
            name: draft.name,
            barcode: draft.barcode.isEmpty ? nil : draft.barcode,
            price: draft.priceValue,
            description: draft.descriptionText,
            icon: draft.icon
        )
    }

    private func suggestionsView(_ suggestions: [CatalogItem]) -> some View {
        VStack(spacing: 6) {
            ForEach(suggestions) { suggestion in
                Button {
                    newItemName = suggestion.name
                    selectedSuggestion = suggestion
                } label: {
                    HStack(spacing: 10) {
                        if let icon = suggestion.icon, !icon.isEmpty {
                            Text(icon)
                                .font(.system(size: 16))
                        }
                        Text(suggestion.name)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .bottom)
    }

    private func normalizedName(_ name: String) -> String {
        name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct UndoToastView: View {
    let title: String
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Button("Undo") {
                onUndo()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.85))
        .clipShape(Capsule())
        .padding(.bottom, 80)
        .padding(.horizontal, 24)
        .onTapGesture {
            onDismiss()
        }
    }
}
