import SwiftUI

struct AdjustQuantityView: View {
    private let item: ShoppingItem
    private let onApply: (Int) -> Void
    private let onEditDetails: () -> Void
    private let onIconTap: ((String) -> Void)?

    @State private var amount: Int
    @State private var mode: QuantityMode

    @AppStorage("appLanguage") private var appLanguage = "he"

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(
        item: ShoppingItem,
        onApply: @escaping (Int) -> Void,
        onEditDetails: @escaping () -> Void,
        onIconTap: ((String) -> Void)? = nil
    ) {
        self.item = item
        let defaultMode: QuantityMode = item.quantity <= 0 ? .need : .bought
        self._mode = State(initialValue: defaultMode)
        let startingAmount = defaultMode == .bought ? max(1, item.quantity) : 1
        self._amount = State(initialValue: startingAmount)
        self.onApply = onApply
        self.onEditDetails = onEditDetails
        self.onIconTap = onIconTap
    }

    var body: some View {
        let isRTL = appLanguage.hasPrefix("he")
            || appLanguage.hasPrefix("ar")
        NavigationStack {
            VStack(spacing: 20) {
                HStack(alignment: .center, spacing: 12) {
                    // Don't rely on automatic mirroring for RTL: it has been inconsistent inside sheets.
                    if isRTL {
                        headerText(isRTL: true)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        headerIcon
                    } else {
                        headerIcon
                        headerText(isRTL: false)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity)
                .environment(\.layoutDirection, .leftToRight)

                Picker("Mode", selection: $mode) {
                    ForEach(QuantityMode.allCases) { selection in
                        Text(selection.titleKey).tag(selection)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    if isRTL { Spacer(minLength: 0) }
                    Button("Edit Item") { onEditDetails() }
                        .buttonStyle(.bordered)
                    if !isRTL { Spacer(minLength: 0) }
                }
                .frame(maxWidth: .infinity)
                .environment(\.layoutDirection, .leftToRight)

                Text("How much?")
                    .font(.system(size: 14, weight: .semibold))
                    // "Leading" is the start edge: left in LTR, right in RTL.
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 24) {
                    if isRTL {
                        incrementButton
                        amountText
                        decrementButton
                    } else {
                        decrementButton
                        amountText
                        incrementButton
                    }
                }
                .frame(maxWidth: .infinity)
                .environment(\.layoutDirection, .leftToRight)

                Spacer()
            }
            .padding(20)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Update Item")
                        .font(.headline)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        let resolved = max(1, amount)
                        let delta = mode == .bought ? -resolved : resolved
                        onApply(delta)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        // SwiftUI RTL propagation into a sheet + NavigationStack has been flaky on iOS 26.x,
        // so we force it based on the app-selected locale.
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
    }

    @ViewBuilder
    private var headerIcon: some View {
        if let icon = item.icon, !icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let onIconTap {
                Button {
                    onIconTap(icon)
                } label: {
                    ItemIconView(icon: icon, size: 28)
                }
                .buttonStyle(.plain)
            } else {
                ItemIconView(icon: icon, size: 28)
            }
        }
    }

    private func headerText(isRTL: Bool) -> some View {
        VStack(alignment: isRTL ? .trailing : .leading, spacing: 6) {
            Text(item.name)
                .font(.system(size: 18, weight: .semibold))
                .multilineTextAlignment(isRTL ? .trailing : .leading)
            Text(leftToBuyText)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(isRTL ? .trailing : .leading)
        }
    }

    private var leftToBuyText: String {
        let template = localized("left_to_buy_format")
        let formattingLocale = Locale(identifier: appLanguage)
        return String(format: template, locale: formattingLocale, item.quantity)
    }

    private func localized(_ key: String) -> String {
        // Use the app-selected language, not the Simulator's language order.
        // (The Simulator is currently `en-IL, he-IL`, which breaks Foundation localization APIs.)
        let languageCode = appLanguage.split(separator: "-").first.map(String.init) ?? appLanguage
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        }
        return Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }

    private var amountText: some View {
        Text("\(max(1, amount))")
            .font(.system(size: 44, weight: .bold, design: .rounded))
            .frame(minWidth: 80)
    }

    private var decrementButton: some View {
        Button {
            if amount > 1 {
                amount -= 1
            }
        } label: {
            Image(systemName: "minus")
                .font(.system(size: 20, weight: .bold))
                .frame(width: 56, height: 56)
                .background(Color(.secondarySystemBackground))
                .clipShape(Circle())
        }
    }

    private var incrementButton: some View {
        Button {
            amount += 1
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .frame(width: 56, height: 56)
                .background(Color(.secondarySystemBackground))
                .clipShape(Circle())
        }
    }
}

private enum QuantityMode: String, CaseIterable, Identifiable {
    case bought
    case need

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .bought: "Bought"
        case .need: "Need"
        }
    }
}
