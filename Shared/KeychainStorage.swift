import SwiftUI
import Valet

@propertyWrapper
struct KeychainStorage: DynamicProperty {
    let key: String
    @State private var value: String

    init(wrappedValue: String = "", _ key: String) {
        self.key = key
        let valet = Valet.valet(with: Identifier(nonEmpty: "CloudNews")!,
                                accessibility: .afterFirstUnlock)
        let initialValue = try? valet.string(forKey: key)
        self._value = State<String>(initialValue: initialValue ?? wrappedValue)
    }

    var wrappedValue: String {
        get  { value }

        nonmutating set {
            value = newValue
            do {
                let valet = Valet.valet(with: Identifier(nonEmpty: "CloudNews")!,
                                        accessibility: .afterFirstUnlock)
                try valet.setString(value, forKey: key)
            } catch let error {
                fatalError("\(error)")
            }
        }
    }

    var projectedValue: Binding<String> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}
