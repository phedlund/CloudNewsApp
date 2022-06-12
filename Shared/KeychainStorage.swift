import SwiftUI
import KeychainAccess

@propertyWrapper
struct KeychainStorage: DynamicProperty {
    let key: String
    @State private var value: String
    private let keychain = Keychain(service: "dev.hedlund.CloudNews")

    init(wrappedValue: String = "", _ key: String) {
        self.key = key
        let initialValue = (try? keychain.get(key)) ?? wrappedValue
        self._value = State<String>(initialValue: initialValue)
    }

    var wrappedValue: String {
        get  { value }

        nonmutating set {
            value = newValue
            do {
                try keychain.set(value, key: key)
            } catch let error {
                fatalError("\(error)")
            }
        }
    }

    var projectedValue: Binding<String> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}
