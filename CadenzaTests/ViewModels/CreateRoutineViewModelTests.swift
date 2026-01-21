import XCTest
@testable import Cadenza

@MainActor
final class CreateRoutineViewModelTests: XCTestCase {

    func testInitialStateIsValid() {
        let viewModel = CreateRoutineViewModel(apiClient: MockAPIClientImpl.shared)
        XCTAssertEqual(viewModel.title, "")
        XCTAssertEqual(viewModel.description, "")
        XCTAssertFalse(viewModel.isCreating)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.canCreate)
    }

    func testCanCreateIsFalseWhenTitleEmpty() {
        let viewModel = CreateRoutineViewModel(apiClient: MockAPIClientImpl.shared)
        viewModel.title = ""
        XCTAssertFalse(viewModel.canCreate)
    }

    func testCanCreateIsFalseWhenTitleOnlyWhitespace() {
        let viewModel = CreateRoutineViewModel(apiClient: MockAPIClientImpl.shared)
        viewModel.title = "   "
        XCTAssertFalse(viewModel.canCreate)
    }

    func testCanCreateIsTrueWhenTitleProvided() {
        let viewModel = CreateRoutineViewModel(apiClient: MockAPIClientImpl.shared)
        viewModel.title = "My Routine"
        XCTAssertTrue(viewModel.canCreate)
    }

    func testCreateRoutineReturnsRoutine() async throws {
        let viewModel = CreateRoutineViewModel(apiClient: MockAPIClientImpl.shared)
        viewModel.title = "My Routine"
        viewModel.description = "Description"

        let routine = try await viewModel.createRoutine(token: testToken)

        XCTAssertNotNil(routine)
        XCTAssertFalse(viewModel.isCreating)
    }

    func testCreateRoutineHandlesEmptyDescription() async throws {
        let viewModel = CreateRoutineViewModel(apiClient: MockAPIClientImpl.shared)
        viewModel.title = "My Routine"
        viewModel.description = ""

        let routine = try await viewModel.createRoutine(token: testToken)

        XCTAssertNotNil(routine)
    }

    func testCreateRoutineThrowsWhenCannotCreate() async {
        let viewModel = CreateRoutineViewModel(apiClient: MockAPIClientImpl.shared)
        viewModel.title = ""

        do {
            _ = try await viewModel.createRoutine(token: testToken)
            XCTFail("Should throw validation error")
        } catch CreateRoutineViewModel.ValidationError.invalidInput {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}
