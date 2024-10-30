//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2024/10/30 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import Foundation
import SwiftSyntax
import SwiftSyntaxMacros

/// Determines whether to generate an initializer based on the attribute node.
///
/// This function checks the attribute node for an argument labeled "disableGenerateInit" with a boolean value.
/// If such an argument is found and its value is false, the function returns false, indicating that an initializer should not be generated.
/// Otherwise, it returns true, indicating that an initializer should be generated.
///
/// - Parameter node: The attribute node to check.
/// - Returns: A boolean indicating whether to generate an initializer.
func shouldGenerateInitializer(from node: AttributeSyntax) -> Bool {
    guard let argumentList = node.arguments?.as(LabeledExprListSyntax.self) else {
        return true // Default to true if no arguments are present.
    }

    for argument in argumentList {
        if argument.label?.text == "disableGenerateInit",
           let booleanLiteral = argument.expression.as(BooleanLiteralExprSyntax.self)
        {
            return booleanLiteral.literal.text != "true" // Return false if "disableGenerateInit" is set to true.
        }
    }
    return true // Default to true if "disableGenerateInit" is not found or is set to false.
}

/// Checks if the access level of the declared type is public.
///
/// This function iterates through the modifiers of the declaration to check if the "public" access level is specified.
///
/// - Parameter declaration: The declaration to check.
/// - Returns: A boolean indicating whether the access level is public.
func isPublic(from declaration: some DeclGroupSyntax) -> Bool {
    return declaration.modifiers.contains { modifier in
        modifier.name.text == "public" // Check if the "public" modifier is present.
    }
}