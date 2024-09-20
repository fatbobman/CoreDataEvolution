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
  @Test func createNewItemInMainActor() throws {
    let stack = TestStack()
    let handler = MainHandler(container: stack.container)
    _ = try handler.createNemItem(showThread: true)
    let count = try handler.getItemCount()
    #expect(count == 1)
  }
}
