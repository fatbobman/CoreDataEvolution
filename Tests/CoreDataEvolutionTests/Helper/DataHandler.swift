//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2024/8/22 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import CoreData
import CoreDataEvolution

@NSModelActor(disableGenerateInit: true)
public actor DataHandler {
    let viewName: String

    func createNemItem(_ timestamp: Date = .now, showThread: Bool = false) throws -> NSManagedObjectID {
        let item = Item(context: modelContext)
        item.timestamp = timestamp
        if showThread {
            print(Thread.current)
        }
        try modelContext.save()
        return item.objectID
    }

    func delItem(_ item: Item) throws {
        modelContext.delete(item)
        try modelContext.save()
    }

    func delItem(_ itemID: NSManagedObjectID) throws {
        guard let item = self[itemID, as: Item.self] else {
            fatalError("Can't load model by ID:\(itemID)")
        }
        try delItem(item)
    }

    private func getAllItems() throws -> [Item] {
        let request = Item.fetchRequest()
        return try modelContext.fetch(request)
    }

    func getItemCount() throws -> Int {
        try getAllItems().count
    }

    init(container: NSPersistentContainer, viewName: String) {
        modelContainer = container
        self.viewName = viewName
        let context = container.newBackgroundContext()
        context.name = viewName
        modelExecutor = .init(context: context)
    }
}
