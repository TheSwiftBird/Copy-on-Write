// The plain, non-CoW value type:
struct User {
    var name: String
}

// This is the key part of the implementation, which lets the code
// reason about whether it’s time to duplicate the underlying data:
class CoWRef<V> {
    
    var value: V
    
    init(_ value: V) {
        self.value = value
    }
    
}

// Typically, you declare a separate wrapper object for CoW:
struct CoWBox<V> {
    
    var valueRef: CoWRef<V>
    
    init(_ value: V) {
        valueRef = CoWRef(value)
    }
    
    var value: V {
        get {
            valueRef.value
        } set {
            if isKnownUniquelyReferenced(&valueRef) {
                valueRef.value = newValue
            } else {
                valueRef = CoWRef(newValue)
            }
        }
    }
    
}

// You can make the implementation a bit more transparent to the client code,
// so it doesn’t need to call `value` in order to access the data:
@propertyWrapper
struct CopyOnWrite<V> {
    
    var valueRef: CoWRef<V>
    
    init(wrappedValue: V) {
        valueRef = CoWRef(wrappedValue)
    }
    
    // This init works, but it requires explicit type declaration:
    init(wrappedValue: CopyOnWrite<V>) {
        valueRef = wrappedValue.valueRef
    }
    
    // Alternative way of creating a CoW wrapper
    // that shares another wrapper’s underlying data:
    init(reusing cowObject: CopyOnWrite<V>) {
        valueRef = cowObject.valueRef
    }
    
    var wrappedValue: V {
        get {
            valueRef.value
        } set {
            if isKnownUniquelyReferenced(&valueRef) {
                valueRef.value = newValue
            } else {
                valueRef = CoWRef(newValue)
            }
        }
    }
    
    var projectedValue: Self { self }
    
}

// You can hide the CoW behavior within your type,
// but that’s not going to look very nice:
struct CoWUser {
    
    private struct _User {
        var name: String
    }
    
    private var userRef: CoWRef<_User>
    
    init(name: String) {
        userRef = CoWRef(_User(name: name))
    }
    
    // You’ll have to do this kind of stuff for each property:
    var name: String {
        get {
            userRef.value.name
        } set {
            if isKnownUniquelyReferenced(&userRef) {
                userRef.value.name = newValue
            } else {
                var newUser = userRef.value
                newUser.name = newValue
                userRef = CoWRef(newUser)
            }
        }
    }
    
}

func testCoW() {
    // Use the memory-graph debugger to see the number of CoWRef instances.
    
    var user1 = CoWBox(User(name: "Alice"))
    var user2 = user1
    
    print(user1.value.name)
    print(user2.value.name)
    
    user2.value.name = "Bob"
    
    print(user1.value.name)
    print(user2.value.name)
    
    @CopyOnWrite var user3 = User(name: "Alice")
    // Without the explicit type, you’ll get
    // the “Ambiguous use of 'init(wrappedValue:)'” error.
    @CopyOnWrite var user4: User = $user3
    @CopyOnWrite(reusing: $user3) var user5
    
    print(user3.name)
    print(user4.name)
    print(user5.name)
    
    user4.name = "Bob"
    user5.name = "Charlie"
    
    print(user3.name)
    print(user4.name)
    print(user5.name)
}
