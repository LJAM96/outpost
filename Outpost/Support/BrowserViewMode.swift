import Foundation

enum BrowserViewMode: String, CaseIterable {
    case list = "List"
    case columns = "Columns"
    case icons = "Icons"

    var systemImage: String {
        switch self {
        case .list: return "list.bullet"
        case .columns: return "rectangle.split.3x1"
        case .icons: return "square.grid.2x2"
        }
    }
}
