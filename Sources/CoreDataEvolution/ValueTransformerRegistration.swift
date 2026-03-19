//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/10 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import Foundation

/// Foundation ships this transformer as a registered singleton. Exposing the registration name
/// through `CDRegisteredValueTransformer` keeps `.transformed(Type.self)` usable for the common
/// `Transformable` secure-unarchive path without requiring users to write their own retroactive
/// conformance.
extension NSSecureUnarchiveFromDataTransformer: CDRegisteredValueTransformer {
  public class var transformerName: NSValueTransformerName {
    .secureUnarchiveFromDataTransformerName
  }
}
