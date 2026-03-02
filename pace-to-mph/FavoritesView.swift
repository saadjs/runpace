import SwiftUI

struct FavoritesView: View {
    @Bindable var store: FavoritesStore
    @State private var showClearConfirmation = false

    var body: some View {
        Group {
            if store.favorites.isEmpty {
                ContentUnavailableView {
                    Label("No Favorites", systemImage: "star")
                } description: {
                    Text("Pin conversions from the converter or history to see them here.")
                }
            } else {
                GlassEffectContainer {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(store.favorites) { fav in
                                favoriteCard(fav)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !store.favorites.isEmpty {
                    Button("Clear") {
                        showClearConfirmation = true
                    }
                }
            }
        }
        .alert("Clear Favorites", isPresented: $showClearConfirmation) {
            Button("Clear", role: .destructive) {
                store.clear()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove all favorites?")
        }
    }

    private func favoriteCard(_ fav: FavoriteConversion) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(fav.input)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(fav.inputSuffix)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Text(fav.result)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.green)
                    Text(fav.resultSuffix)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(fav.input) \(fav.inputSuffix) equals \(fav.result) \(fav.resultSuffix)")

            Spacer()

            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    store.remove(id: fav.id)
                }
            } label: {
                Image(systemName: "star.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.yellow)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove from favorites")
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        FavoritesView(store: FavoritesStore())
    }
}
