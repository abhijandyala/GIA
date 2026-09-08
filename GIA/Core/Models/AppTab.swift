enum AppTab: String, CaseIterable, Identifiable {
    case plan
    case map
    case group

    var id: Self { self }

    var title: String {
        switch self {
        case .plan:
            "Plan"
        case .map:
            "Map"
        case .group:
            "Group"
        }
    }

    func symbolName(isSelected: Bool) -> String {
        switch self {
        case .plan:
            "list.bullet"
        case .map:
            isSelected ? "map.fill" : "map"
        case .group:
            isSelected ? "person.2.fill" : "person.2"
        }
    }
}
