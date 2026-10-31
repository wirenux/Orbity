import SwiftUI
import SwiftData

struct SatelliteSearchView: View {
    @Query(sort: \SatelliteEntity.name) private var all: [SatelliteEntity]
    @State private var query = ""
    @State private var group: String? = nil

    private var groups: [String] { Array(Set(all.map(\.group))).sorted() }

    private var results: [SatelliteEntity] {
        all.filter { s in
            (group == nil || s.group == group) &&
            (query.isEmpty
             || s.name.localizedCaseInsensitiveContains(query)
             || String(s.noradID).contains(query))
        }
    }

    var body: some View {
        List(results) { sat in
            HStack {
                VStack(alignment: .leading) {
                    Text(sat.name)
                    Text("\(sat.noradID) · \(sat.group)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { sat.isTracked.toggle() } label: {
                    Image(systemName: sat.isTracked ? "star.fill" : "star")
                }
                .buttonStyle(.borderless)
            }
        }
        .searchable(text: $query, prompt: "Name or NORAD ID")
        .navigationTitle("Satellites")
        .toolbar {
            Menu {
                Button("All groups") { group = nil }
                ForEach(groups, id: \.self) { g in Button(g) { group = g } }
            } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
        }
        .overlay {
            if all.isEmpty {
                ContentUnavailableView("No TLEs yet", systemImage: "arrow.down.circle",
                                       description: Text("Downloading orbital data…"))
            }
        }
    }
}
