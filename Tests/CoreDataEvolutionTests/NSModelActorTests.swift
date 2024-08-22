import CoreDataEvolution
import CoreDataEvolutionMacros
import Testing

struct NSModelActorTests {
  @Test func createNewItem() async throws {
    let stack = TestStack()
    let handler = DataHandler(container: stack.container)
    _ = try await handler.createNemItem(showThread: true)
    let count = try await handler.getItemCount()
    #expect(count == 1)
  }

  @MainActor
  @Test func createNewItemInMainActor() async throws {
    let stack = TestStack()
    let handler = DataHandler(container: stack.container, mode: .viewContext)
    _ = try await handler.createNemItem(showThread: true)
    let count = try await handler.getItemCount()
    #expect(count == 1)
  }
}
