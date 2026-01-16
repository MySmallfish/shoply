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
    @State private var showScanPrompt = false
    @State private var scannedBarcode = ""
    @State private var scannedItemName = ""
    @State private var matchedItem: ShoppingItem?

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
                AddItemBar(text: $newItemName) {
                    listViewModel.addItem(name: newItemName)
                    newItemName = ""
                }
                .disabled(session.selectedListId == nil)
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
            AddScannedItemView(barcode: scannedBarcode, name: scannedItemName) { name in
                listViewModel.addItem(name: name, barcode: scannedBarcode)
                listViewModel.clearScan()
            }
        }
        .alert("Mark as bought?", isPresented: $showScanPrompt, presenting: matchedItem) { item in
            Button("Mark as bought") {
                listViewModel.toggleBought(item)
                listViewModel.clearScan()
            }
            Button("Cancel", role: .cancel) {
                listViewModel.clearScan()
            }
        } message: { item in
            Text("Mark \"\(item.name)\" as bought?")
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
        let activeItems = listViewModel.items.filter { !$0.isBought }
        let boughtItems = listViewModel.items.filter { $0.isBought }

        List {
            if !activeItems.isEmpty {
                Section("Active") {
                    ForEach(activeItems) { item in
                        ItemRow(item: item) {
                            listViewModel.toggleBought(item)
                        }
                    }
                }
            }

            if !boughtItems.isEmpty {
                Section("Bought") {
                    ForEach(boughtItems) { item in
                        ItemRow(item: item) {
                            listViewModel.toggleBought(item)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await listViewModel.refresh()
        }
        .overlay {
            if activeItems.isEmpty && boughtItems.isEmpty {
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
            matchedItem = item
            showScanPrompt = true
        } else {
            scannedBarcode = code
            scannedItemName = ""
            showAddFromScan = true
        }
    }
}
