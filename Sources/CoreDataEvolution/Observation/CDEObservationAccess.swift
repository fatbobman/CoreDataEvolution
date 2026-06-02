#if compiler(>=6.2)
  //
  //  ------------------------------------------------
  //  Original project: CoreDataEvolution
  //  Created on 2026/5/31 by Fatbobman(东坡肘子)
  //  X: @fatbobman
  //  Mastodon: @fatbobman@mastodon.social
  //  GitHub: @fatbobman
  //  Blog: https://fatbobman.com
  //  ------------------------------------------------
  //  Copyright © 2024-present Fatbobman. All rights reserved.

  @preconcurrency import CoreData
  import Observation

  @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
  public typealias CDEObservable = Observation.Observable

  @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
  public typealias CDEObservationRegistrar = Observation.ObservationRegistrar

  @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
  public func _cdeObservationAccess<Root: CDEObservable, Value>(
    _ object: Root,
    _ keyPath: KeyPath<Root, Value>,
    registrar: CDEObservationRegistrar
  ) {
    registrar.access(object, keyPath: keyPath)
    guard let managedObject = object as? NSManagedObject else {
      return
    }

    _cdeRegisterObservedObjectIfNeeded(managedObject)
  }

#endif
