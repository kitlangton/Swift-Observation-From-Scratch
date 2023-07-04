import Foundation
import Observation

class Suspect: Observable {
  init(name: String, suspiciousness: Int) {
    _name = name
    _suspiciousness = suspiciousness
  }

  var name: String {
    get {
      access(keyPath: \.name)
      return _name
    }

    set {
      withMutation(keyPath: \.name) {
        _name = newValue
      }
    }
  }

  var suspiciousness: Int {
    get {
      access(keyPath: \.suspiciousness)
      return _suspiciousness
    }

    set {
      withMutation(keyPath: \.suspiciousness) {
        _suspiciousness = newValue
      }
    }
  }

  internal nonisolated func access<Member>(
    keyPath: KeyPath<Suspect, Member>
  ) {
    _$observationRegistrar.access(self, keyPath: keyPath)
  }

  internal nonisolated func withMutation<Member, T>(
    keyPath: KeyPath<Suspect, Member>,
    _ mutation: () throws -> T
  ) rethrows
    -> T
  {
    try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
  }

  private let _$observationRegistrar = ObservationRegistrar()
  private var _name: String = ""
  private var _suspiciousness: Int = 0
}

let suspect = Suspect(name: "Glib Butler", suspiciousness: 33)
let suspect2 = Suspect(name: "Jimmy The Shrimp", suspiciousness: 10)

var ON_CHANGE_CLOSURE: (@Sendable () -> Void)?

class ObservationRegistrar: @unchecked Sendable {
  struct Observation: Identifiable {
    let id: UUID = .init()
    let keyPaths: Set<AnyKeyPath>
    let closure: @Sendable () -> Void
  }

  var lookups: [AnyKeyPath: Set<Observation.ID>] = [:]
  var observations: [Observation.ID: Observation] = [:]

  // (suspect.name, suspect.suspiciousness) -> C1
  // (suspect.name) -> C2
  //
  // suspect.name = "hello" -> C1() C2()
  // suspect.suspiciousness = 1_000 -> ...
  func withMutation<Subject, Member, T>(
    of subject: Subject,
    keyPath: KeyPath<Subject, Member>,
    _ mutation: () throws -> T
  ) rethrows
    -> T where Subject: Observable
  {
    print("withMutation(\(keyPath))")

    if let observationIds = lookups.removeValue(forKey: keyPath) {
      for observationId in observationIds {
        if let observation = observations.removeValue(forKey: observationId) {
          observation.closure()

          for keyPath in observation.keyPaths {
            lookups[keyPath]?.remove(observation.id)
            if lookups[keyPath]?.isEmpty ?? false {
              lookups.removeValue(forKey: keyPath)
            }
          }
        }
      }
    }

    return try mutation()
  }

  func cancel(_ observationId: Observation.ID) {
    print("cancel \(observationId)")
    if let observation = observations.removeValue(forKey: observationId) {
      for keyPath in observation.keyPaths {
        lookups[keyPath]?.remove(observation.id)
        if lookups[keyPath]?.isEmpty ?? false {
          lookups.removeValue(forKey: keyPath)
        }
      }
    }
  }

  func registerOnChange(
    _ keyPaths: Set<AnyKeyPath>,
    _ onChange: @escaping @Sendable () -> Void
  ) -> Observation.ID {
    let observation = Observation(keyPaths: keyPaths, closure: onChange)
    observations[observation.id] = observation
    for keyPath in keyPaths {
      lookups[keyPath, default: []].insert(observation.id)
    }
    return observation.id
  }

  func access<Subject, Member>(_ subject: Subject, keyPath: KeyPath<Subject, Member>) where Subject: Observable {
    print("access(\(keyPath))")
    GLOBAL_ACCESS_LIST?.trackAccess(self, keyPath: keyPath)
  }
}

// THREAD_LOCAL global-per-thread mutable variable
var GLOBAL_ACCESS_LIST: AccessList?

struct AccessList {
  struct Entry {
    var registrar: ObservationRegistrar
    var keyPaths: Set<AnyKeyPath> = []
  }

  var entries: [ObjectIdentifier: Entry] = [:]

  // [suspect1.registrar: [.name, suspiciousness]
  // ,suspect2.registrar: [.name, suspiciousness, .foo]]

  mutating func trackAccess(_ registrar: ObservationRegistrar, keyPath: AnyKeyPath) {
    let id = ObjectIdentifier(registrar)
    entries[id, default: Entry(registrar: registrar)].keyPaths.insert(keyPath)
  }

  // - create a new wrapped onChange
  //   - call the initial onChange
  //   - remove the callbacks from every associated object
  // - stash it into the registrars of every associated object
  func registerOnChange(_ onChange: @escaping @Sendable () -> Void) {
    let observationIds: Box<[ObjectIdentifier: ObservationRegistrar.Observation.ID]> = Box(value: [:])

    let cancellingOnChange: @Sendable () -> Void = {
      onChange()

      // cancel the observations on EVERY REGISTRAR
      for (registrarId, observationId) in observationIds.value {
        entries[registrarId]?.registrar.cancel(observationId)
      }
    }

    for entry in entries {
      let registrar = entry.value.registrar
      let keyPaths = entry.value.keyPaths

      let observationId = registrar.registerOnChange(
        keyPaths,
        cancellingOnChange
      )
      observationIds.value[entry.key] = observationId
    }
  }
}

class Box<A> {
  init(value: A) {
    self.value = value
  }

  var value: A
}

func withObservationTracking<T>(
  _ apply: () -> T,
  onChange: @escaping @Sendable () -> Void
)
  -> T
{
  // 1. Set a ACCESS_LIST
  GLOBAL_ACCESS_LIST = AccessList()
  // 2. call apply()
  let result = apply()
  //   - suspect1.access(\.name)
  //   - suspect1.access(\.suspiciousness)
  //   - suspect2.access(\.name)
  //   - suspect2.access(\.suspiciousness)
  // 3. USE AccessList
  //   - associate the closure
  //   - give it the ability to cancel all callbacks
  GLOBAL_ACCESS_LIST?.registerOnChange(onChange)

  // 2. ???
  return result
  // 3. PROFIT
}
// THREAD_LOCAL
// Locking
// Box

// apply: () -> T
withObservationTracking {
  // suspect.access(\.name)
  print("1: I am observing \(suspect.name) \(suspect.suspiciousness)")
  print("2: I am observing \(suspect2.name) \(suspect2.suspiciousness)")
} onChange: {
  print("CALLBACK IS BEING CALLED: Name/Suspiciousness changed!")
}

print("A")
// suspect.withMutation(\.name)
suspect.suspiciousness = 12
suspect2.name = "Jim Shrimp"
print("C")
suspect.name = "Jim Shrimp"
suspect2.suspiciousness = 12
