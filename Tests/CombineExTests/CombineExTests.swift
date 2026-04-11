import Combine
import CombineEx
import Foundation
import Testing

private enum TestError: Error, Equatable {
    case boom
}

private final class ManualSubscriber<Input, Failure: Error>: Subscriber {
    var subscription: Subscription?
    var values: [Input] = []
    var completion: Subscribers.Completion<Failure>?

    func receive(subscription: Subscription) {
        self.subscription = subscription
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        values.append(input)
        return .none
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        self.completion = completion
    }
}

@Test
func lazyFutureRunsOnlyAfterSubscription() async throws {
    var runCount = 0
    let publisher = LazyFuture<Int, Never> { promise in
        runCount += 1
        promise(.success(42))
    }

    #expect(runCount == 0)

    let value = try await publisher.eraseType().async()

    #expect(value == 42)
    #expect(runCount == 1)
}

@Test
func lazyFuturePropagatesFailure() async {
    let publisher = LazyFuture<Int, TestError> { promise in
        promise(.failure(.boom))
    }

    do {
        _ = try await publisher.eraseType().async()
        Issue.record("Expected publisher to fail")
    }
    catch let error as TestError {
        #expect(error == .boom)
    }
    catch {
        Issue.record("Expected TestError.boom, got \(error)")
    }
}

@Test
func lazyFutureDoesNotRunAfterCancellationBeforeDemand() {
    var runCount = 0
    let publisher = LazyFuture<Int, Never> { promise in
        runCount += 1
        promise(.success(1))
    }
    let subscriber = ManualSubscriber<Int, Never>()

    publisher.receive(subscriber: subscriber)
    subscriber.subscription?.cancel()
    subscriber.subscription?.request(.unlimited)

    #expect(runCount == 0)
    #expect(subscriber.values == [])
}

@Test
func resultPublisherPublishesSuccessValue() async throws {
    let publisher = Result<Int, TestError>.success(7).asPublisher

    let value = try await publisher.async()

    #expect(value == 7)
}

@Test
func resultPublisherPropagatesFailure() async {
    let publisher = Result<Int, TestError>.failure(.boom).asPublisher

    do {
        _ = try await publisher.async()
        Issue.record("Expected publisher to fail")
    }
    catch let error as TestError {
        #expect(error == .boom)
    }
    catch {
        Issue.record("Expected TestError.boom, got \(error)")
    }
}

@Test
func propertyRemovesDuplicateValues() {
    struct Model {
        var count: Int
        var name: String
    }

    let subject = PassthroughSubject<Model, Never>()
    var received: [Int] = []

    let cancellable = subject
        .property(\.count)
        .sink { received.append($0) }

    withExtendedLifetime(cancellable) {
        subject.send(Model(count: 1, name: "one"))
        subject.send(Model(count: 1, name: "same count"))
        subject.send(Model(count: 2, name: "two"))
        subject.send(Model(count: 2, name: "still two"))
        subject.send(Model(count: 3, name: "three"))
    }

    #expect(received == [1, 2, 3])
}

@Test
func propertyUsesCustomEquality() {
    struct Model {
        var name: String
    }

    let subject = PassthroughSubject<Model, Never>()
    var received: [String] = []

    let cancellable = subject
        .property(\.name) { $0.caseInsensitiveCompare($1) == .orderedSame }
        .sink { received.append($0) }

    withExtendedLifetime(cancellable) {
        subject.send(Model(name: "One"))
        subject.send(Model(name: "one"))
        subject.send(Model(name: "Two"))
    }

    #expect(received == ["One", "Two"])
}

@Test
func serialFlatMapWaitsForCurrentPublisherBeforeStartingNext() {
    var started: [Int] = []
    var promises: [Int: (Result<Int, Never>) -> Void] = [:]
    var received: [Int] = []

    let cancellable = [1, 2, 3].publisher
        .serialFlatMap { value in
            LazyFuture<Int, Never> { promise in
                started.append(value)
                promises[value] = promise
            }
        }
        .sink { received.append($0) }

    withExtendedLifetime(cancellable) {
        #expect(started == [1])

        promises[1]?(.success(10))
        #expect(started == [1, 2])
        #expect(received == [10])

        promises[2]?(.success(20))
        #expect(started == [1, 2, 3])
        #expect(received == [10, 20])

        promises[3]?(.success(30))
    }

    #expect(received == [10, 20, 30])
}

@Test
func flatMapLatestPublishesOnlyMostRecentInnerPublisher() {
    let subject = PassthroughSubject<Int, Never>()
    var innerSubjects: [Int: PassthroughSubject<String, Never>] = [:]
    var received: [String] = []

    let cancellable = subject
        .flatMapLatest { value in
            let inner = PassthroughSubject<String, Never>()
            innerSubjects[value] = inner
            return inner.eraseToAnyPublisher()
        }
        .sink { received.append($0) }

    withExtendedLifetime(cancellable) {
        subject.send(1)
        innerSubjects[1]?.send("first")

        subject.send(2)
        innerSubjects[1]?.send("stale")
        innerSubjects[2]?.send("second")
    }

    #expect(received == ["first", "second"])
}

@Test
func flatMapValueTransformsSingleValuePublisher() async throws {
    let value = try await Just(3)
        .flatMapValue { Just($0 * 4) }
        .eraseType()
        .async()

    #expect(value == 12)
}

@Test
func singleValuePublisherAsResultWrapsSuccessAndFailure() async throws {
    let success = try await Just(4)
        .addErrorType(TestError.self)
        .asResult()
        .async()
    let failure = try await Fail<Int, TestError>(error: .boom)
        .asResult()
        .async()

    #expect(success == .success(4))
    #expect(failure == .failure(.boom))
}

@Test
func mapWithSideEffectReturnsMappedValuesAndRunsTransform() async throws {
    var sideEffects: [Int] = []

    let values = try await [1, 2, 3].publisher
        .mapWithSideEffect { value in
            sideEffects.append(value)
            return value * 2
        }
        .collect()
        .eraseType()
        .async()

    #expect(sideEffects == [1, 2, 3])
    #expect(values == [2, 4, 6])
}

@Test
func sideEffectClosureRunsWithoutChangingOutput() async throws {
    var sideEffects: [Int] = []

    let values = try await [1, 2].publisher
        .sideEffect { sideEffects.append($0) }
        .collect()
        .eraseType()
        .async()

    #expect(sideEffects == [1, 2])
    #expect(values == [1, 2])
}

@Test
func sideEffectPublisherRunsForEachOutput() async throws {
    var sideEffects: [Int] = []

    let values = try await [1, 2].publisher
        .sideEffect { value in
            LazyFuture<Void, Never> { promise in
                sideEffects.append(value)
                promise(.success(()))
            }
            .eraseType()
        }
        .collect()
        .eraseType()
        .async()

    #expect(sideEffects == [1, 2])
    #expect(values == [1, 2])
}

@Test
func runAsSideEffectReportsSuccessAndFailure() {
    var completions: [TestError?] = []

    Just(())
        .addErrorType(TestError.self)
        .eraseType()
        .runAsSideEffect { completions.append($0) }
    Fail<Void, TestError>(error: .boom)
        .eraseType()
        .runAsSideEffect { completions.append($0) }

    #expect(completions == [nil, .some(.boom)])
}

@Suite(.serialized)
struct EnvironmentDependentTests {
    @Test
    func runAsSideEffectLogsUnhandledFailure() {
        let oldEnvironment = CombineEx.env
        var loggedErrors: [TestError] = []
        CombineEx.env.logGeneralError = { error in
            if let error = error as? TestError {
                loggedErrors.append(error)
            }
        }
        defer { CombineEx.env = oldEnvironment }

        Fail<Void, TestError>(error: .boom)
            .eraseType()
            .runAsSideEffect()

        #expect(loggedErrors == [.boom])
    }

    @Test
    func convertToSideEffectRunsSuccessHandlerAndLogsFailure() async throws {
        let oldEnvironment = CombineEx.env
        var loggedErrors: [TestError] = []
        CombineEx.env.logGeneralError = { error in
            if let error = error as? TestError {
                loggedErrors.append(error)
            }
        }
        defer { CombineEx.env = oldEnvironment }

        var sideEffectValue: Int?
        try await Just(9)
            .addErrorType(TestError.self)
            .eraseType()
            .convertToSideEffect { sideEffectValue = $0 }
            .async()

        try await Fail<Int, TestError>(error: .boom)
            .eraseType()
            .convertToSideEffect { _ in Issue.record("Unexpected side effect") }
            .async()

        #expect(sideEffectValue == 9)
        #expect(loggedErrors == [.boom])
    }

    @Test
    func environmentCanOverrideCurrentDateProvider() {
        let oldEnvironment = CombineEx.env
        let date = Date(timeIntervalSince1970: 123)
        CombineEx.env.now = { date }
        defer { CombineEx.env = oldEnvironment }

        #expect(CombineEx.env.now() == date)
    }
}

@Test
func replaceErrorUsesRecoveryValue() async throws {
    let value = try await Fail<Int, TestError>(error: .boom)
        .replaceError { error in
            #expect(error == .boom)
            return 5
        }
        .eraseType()
        .async()

    #expect(value == 5)
}

@Test
func replaceErrorWithNilPublishesNilForNonOptionalOutput() async throws {
    let value = try await Fail<Int, TestError>(error: .boom)
        .replaceErrorWithNil()
        .eraseType()
        .async()

    #expect(value == nil)
}

@Test
func replaceErrorWithNilPublishesNilForOptionalOutput() async throws {
    let value = try await Fail<Int?, TestError>(error: .boom)
        .replaceErrorWithNil()
        .eraseType()
        .async()

    #expect(value == nil)
}

@Test
func errorTypeHelpersMapPublisherFailures() async throws {
    let added = try await Just(6)
        .addErrorType(TestError.self)
        .eraseType()
        .async()
    #expect(added == 6)

    do {
        _ = try await Fail<Int, TestError>(error: .boom)
            .forceErrorType(TestError.self)
            .eraseType()
            .async()
        Issue.record("Expected publisher to fail")
    }
    catch let error as TestError {
        #expect(error == .boom)
    }
    catch {
        Issue.record("Expected TestError.boom, got \(error)")
    }
}

@Test
func sideEffectIfErrorRunsOnlyForFailures() async throws {
    var errors: [TestError] = []

    let value = try await Just(8)
        .addErrorType(TestError.self)
        .eraseType()
        .sideEffectIfError { errors.append($0) }
        .async()
    #expect(value == 8)
    #expect(errors == [])

    do {
        _ = try await Fail<Int, TestError>(error: .boom)
            .eraseType()
            .sideEffectIfError { errors.append($0) }
            .async()
        Issue.record("Expected publisher to fail")
    }
    catch let error as TestError {
        #expect(error == .boom)
    }
    catch {
        Issue.record("Expected TestError.boom, got \(error)")
    }

    #expect(errors == [.boom])
}

@Test
func ignoreCancelReplacesCancelFailureWithVoid() async throws {
    try await Fail<Void, Cancel>(error: .cancel)
        .ignoreCancel()
        .eraseType()
        .async()
}

@Test
func makePublisherPublishesAsyncSuccessAndFailure() async throws {
    let nonThrowing = try await makePublisher {
        11
    }
    .async()
    let throwingSuccess = try await makePublisher { () async throws -> Int in
        12
    }
    .async()

    #expect(nonThrowing == 11)
    #expect(throwingSuccess == 12)

    do {
        _ = try await makePublisher { () async throws -> Int in
            throw TestError.boom
        }
        .async()
        Issue.record("Expected publisher to fail")
    }
    catch let error as TestError {
        #expect(error == .boom)
    }
    catch {
        Issue.record("Expected TestError.boom, got \(error)")
    }
}

@Test
func asyncThrowsCancelWhenSingleValuePublisherCompletesWithoutOutput() async {
    do {
        _ = try await Empty<Int, Never>(completeImmediately: true).async()
        Issue.record("Expected publisher to throw Cancel.cancel")
    }
    catch Cancel.cancel {
    }
    catch {
        Issue.record("Expected Cancel.cancel, got \(error)")
    }
}

@Test
func asyncPublisherGetRunsAsyncCallbacksForEachElement() async {
    var received: [Int] = []

    await [1, 2, 3].publisher.values.get { value in
        received.append(value)
    }

    #expect(received == [1, 2, 3])
}

@Test
func asyncPublisherGetPropagatesCallbackFailure() async {
    var received: [Int] = []

    do {
        try await [1, 2, 3].publisher.values.get { value in
            received.append(value)
            if value == 2 {
                throw TestError.boom
            }
        }
        Issue.record("Expected callback to throw")
    }
    catch let error as TestError {
        #expect(error == .boom)
    }
    catch {
        Issue.record("Expected TestError.boom, got \(error)")
    }

    #expect(received == [1, 2])
}

@Test
func processAllRunsTransformForEveryElement() async throws {
    var processed: [Int] = []

    try await [1, 2, 3]
        .processAll { value in
            LazyFuture<Void, TestError> { promise in
                processed.append(value)
                promise(.success(()))
            }
            .eraseType()
        }
        .async()

    #expect(processed == [1, 2, 3])
}

@Test
func processAllHandlesEmptyArrays() async throws {
    var transformDidRun = false

    try await [Int]()
        .processAll { _ -> AnySingleValuePublisher<Void, TestError> in
            transformDidRun = true
            return Just(())
                .addErrorType(TestError.self)
                .eraseType()
        }
        .async()

    let publishers: [AnySingleValuePublisher<Void, TestError>] = []
    try await publishers.processAll().async()

    #expect(transformDidRun == false)
}

@Test
func processAllPropagatesFailure() async {
    let publishers: [AnySingleValuePublisher<Void, TestError>] = [
        Just(()).addErrorType(TestError.self).eraseType(),
        Fail<Void, TestError>(error: .boom).eraseType()
    ]

    do {
        try await publishers.processAll().async()
        Issue.record("Expected processAll to fail")
    }
    catch let error as TestError {
        #expect(error == .boom)
    }
    catch {
        Issue.record("Expected TestError.boom, got \(error)")
    }
}

@MainActor
@Test
func observableValueSupportsReferenceUpdates() throws {
    final class Box {
        var value: Int

        init(_ value: Int) {
            self.value = value
        }
    }

    let observable = ObservableValue(Box(1))
    observable.update(Box(2))
    observable.update { box in
        box.value = 3
    }
    try observable.update { (box: inout Box) throws in
        box.value = 4
    }

    #expect(observable.value.value == 4)
}

@MainActor
@Test
func observableValueSkipsDuplicateEquatableUpdates() throws {
    let observable = ObservableValue(1)
    var changeCount = 0
    let cancellable = observable.objectWillChange.sink {
        changeCount += 1
    }

    withExtendedLifetime(cancellable) {
        observable.maybeUpdate(1)
        observable.update { value in
            value = 1
        }
        try? observable.update { (value: inout Int) throws in
            value = 1
        }
        #expect(changeCount == 0)

        observable.maybeUpdate(2)
        observable.update { value in
            value = 3
        }
        try? observable.update { (value: inout Int) throws in
            value = 4
        }
    }

    #expect(observable.value == 4)
    #expect(changeCount == 3)
}

@MainActor
@Test
func observableValueSupportsOptionalInitIdentityHashingAndCodeStringDescription() {
    let first = ObservableValue<Int?>(nil)
    let second = first
    let third = ObservableValue<Int?>()

    #expect(first == second)
    #expect(first != third)
    #expect(first.value == nil)
    #expect(third.value == nil)
    #expect(Set([first, second, third]).count == 2)
    #expect(first.id === first)
    #expect(first.codeStringDescription(offset: 0, indent: 2, maxValueWidth: 80).isEmpty == false)
}

@Test
func combineLatestCollectionPublishesLatestValuesAndFinishesAfterAllUpstreamsFinish() {
    let first = PassthroughSubject<Int, Never>()
    let second = PassthroughSubject<Int, Never>()
    var received: [[Int]] = []
    var didFinish = false

    let cancellable = [first.eraseToAnyPublisher(), second.eraseToAnyPublisher()]
        .combineLatest
        .sink(
            receiveCompletion: { completion in
                if case .finished = completion {
                    didFinish = true
                }
            },
            receiveValue: { received.append($0) }
        )

    withExtendedLifetime(cancellable) {
        first.send(1)
        #expect(received == [])

        second.send(10)
        #expect(received == [[1, 10]])

        first.send(2)
        second.send(20)
        #expect(received == [[1, 10], [2, 10], [2, 20]])

        first.send(completion: .finished)
        #expect(didFinish == false)

        second.send(completion: .finished)
    }

    #expect(didFinish == true)
}

@Test
func combineLatestCollectionForwardsFailures() {
    let first = PassthroughSubject<Int, TestError>()
    let second = PassthroughSubject<Int, TestError>()
    var received: [[Int]] = []
    var failure: TestError?

    let cancellable = [first.eraseToAnyPublisher(), second.eraseToAnyPublisher()]
        .combineLatest
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    failure = error
                }
            },
            receiveValue: { received.append($0) }
        )

    withExtendedLifetime(cancellable) {
        first.send(1)
        second.send(2)
        first.send(completion: .failure(.boom))
        second.send(3)
    }

    #expect(received == [[1, 2]])
    #expect(failure == .boom)
}

@Test
func combineLatestCollectionCancellationStopsFutureValues() {
    let first = PassthroughSubject<Int, Never>()
    let second = PassthroughSubject<Int, Never>()
    var received: [[Int]] = []

    let cancellable = [first.eraseToAnyPublisher(), second.eraseToAnyPublisher()]
        .combineLatest
        .sink { received.append($0) }

    first.send(1)
    second.send(2)
    cancellable.cancel()
    first.send(3)
    second.send(4)

    #expect(received == [[1, 2]])
}
