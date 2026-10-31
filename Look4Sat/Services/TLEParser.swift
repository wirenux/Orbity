import Foundation

enum TLEParser {
    /// Parses 3-line TLE blocks (name, line 1, line 2).
    static func parse(_ text: String) -> [TLE] {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var result: [TLE] = []
        var i = 0
        while i + 2 < lines.count {
            let (n, l1, l2) = (lines[i], lines[i + 1], lines[i + 2])
            guard l1.hasPrefix("1 "), l2.hasPrefix("2 "),
                  l1.count >= 32,
                  let id = Int(l1.slice(2, 7).trimmingCharacters(in: .whitespaces)),
                  let epoch = epoch(from: l1)
            else { i += 1; continue }          // resync on malformed input
            result.append(TLE(name: n, line1: l1, line2: l2, noradID: id, epoch: epoch))
            i += 3
        }
        return result
    }

    static func epoch(from l1: String) -> Date? {
        guard l1.count >= 32,
              let yy = Int(l1.slice(18, 20)),
              let day = Double(l1.slice(20, 32).trimmingCharacters(in: .whitespaces))
        else { return nil }
        let year = yy < 57 ? 2000 + yy : 1900 + yy
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .gmt
        guard let jan1 = cal.date(from: DateComponents(year: year, month: 1, day: 1))
        else { return nil }
        return jan1.addingTimeInterval((day - 1) * 86_400)
    }
}

private extension String {
    func slice(_ from: Int, _ to: Int) -> String {
        let s = index(startIndex, offsetBy: from)
        let e = index(startIndex, offsetBy: to)
        return String(self[s..<e])
    }
}
