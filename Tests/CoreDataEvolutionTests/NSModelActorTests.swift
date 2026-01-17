import CoreDataEvolution
/// Test suite for NSModelActor functionality
/// This struct contains tests that verify the behavior of actors decorated with @NSModelActor and @NSMainModelActor macros
import Testing

struct NSModelActorTests {
  /// Test case for creating and managing Core Data items using a background actor
  /// This test verifies that:
  /// 1. Items can be created successfully in a background context
  /// 2. The item count is tracked correctly
  /// 3. Items can be deleted properly
  /// 4. Thread safety is maintained through the actor model
  @Test func createNewItem() async throws {
    // Initialize the test Core Data stack
    // TestStack provides a pre-configured NSPersistentContainer for testing
    let stack = TestStack()

    // Create a DataHandler actor instance with custom executor
    // The DataHandler is decorated with @NSModelActor(disableGenerateInit: true)
    // This creates an actor that operates on a background thread with its own managed object context
    let handler = DataHandler(container: stack.container, viewName: "hello")

    // Create a new item asynchronously using the actor
    // The showThread parameter enables thread information logging for debugging
    // Returns the NSManagedObjectID of the created item
    let id = try await handler.createNemItem(showThread: true)

    // Verify that exactly one item was created
    // This tests the actor's ability to perform read operations safely
    let count = try await handler.getItemCount()
    #expect(count == 1)

    // Delete the created item using its object ID
    // This tests the actor's ability to perform delete operations safely
    try await handler.delItem(id)

    // Verify that the item was successfully deleted
    // The count should return to zero after deletion
    let newCount = try await handler.getItemCount()
    #expect(newCount == 0)
  }

  /// Test case for creating Core Data items using a main thread actor
  /// This test verifies that:
  /// 1. Main thread actors work correctly with @NSMainModelActor
  /// 2. Items can be created synchronously on the main thread
  /// 3. Thread information can be logged for verification
  @MainActor
  @Test func createNewItemInMainActor() throws {
    // Initialize the test Core Data stack
    let stack = TestStack()

    // Create a MainHandler instance decorated with @NSMainModelActor
    // Unlike DataHandler, this operates on the main thread and doesn't require async/await
    // The MainHandler provides the same Core Data operations but runs synchronously on the main thread
    let handler = MainHandler(modelContainer: stack.container)

    // Create a new item synchronously on the main thread
    // The showThread parameter will log main thread information
    // Since this is a synchronous operation, we discard the returned object ID
    _ = try handler.createNemItem(showThread: true)

    // Verify that the item was created successfully
    // This operation also runs synchronously on the main thread
    let count = try handler.getItemCount()
    #expect(count == 1)
  }
}
