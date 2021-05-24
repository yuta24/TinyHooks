import SwiftUI

public enum TriggerType {
    case always
    case once
}

public typealias Reducer<S, A> = (S, A) -> S
public typealias Dispatch<A> = (A) -> Void
public typealias Dispose = () -> Void

enum HookType {
    case state
    case effect
    case reducer
}

protocol HookHolder {
    var type: HookType { get }
}

class StateHookHolder<S>: HookHolder {
    let type: HookType = .state

    var state: S

    init(state: S) {
        self.state = state
    }
}

class EffectHookHolder: HookHolder {
    let type: HookType = .effect

    let trigger: TriggerType
    let closure: () -> Dispose?
    var dispose: Dispose?
    var hasRun: Bool = false

    init(trigger: TriggerType, closure: @escaping () -> Dispose?) {
        self.trigger = trigger
        self.closure = closure
    }
}

class ReducerHookHolder<S, A>: HookHolder {
    let type: HookType = .reducer

    var state: S
    let dispatch: Dispatch<A>

    init(state: S, dispatch: @escaping Dispatch<A>) {
        self.state = state
        self.dispatch = dispatch
    }
}

final class Dispatcher: ObservableObject {
    let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    private var holders: [HookType: HookHolder] = [:]

    deinit {
        holders.forEach { _, value in
            switch value {
            case let value as EffectHookHolder:
                value.dispose?()
            default:
                break
            }
        }
    }

    func useState<S>(initial state: () -> S) -> Binding<S> {
        if let holder = holders[.state] as? StateHookHolder<S> {
            return .init(
                get: {
                    return holder.state
                },
                set: { [unowned self] in
                    holder.state = $0

                    DispatchQueue.main.async {
                        objectWillChange.send()
                    }
                })
        }

        let holder = StateHookHolder(state: state())
        holders[.state] = holder

        return .init(
            get: {
                return holder.state
            },
            set: { [unowned self] in
                holder.state = $0

                DispatchQueue.main.async {
                    objectWillChange.send()
                }
            })
    }

    func useEffect(trigger: TriggerType, closure: @escaping () -> Dispose?) {
        guard !holders.contains(where: { $0.key == .effect }) else {
            return
        }

        let holder = EffectHookHolder(trigger: trigger, closure: closure)
        holders[.effect] = holder
    }

    func useReducer<S, A>(reducer: @escaping Reducer<S, A>, initial state: () -> S) -> (S, Dispatch<A>) {
        if let holder = holders[.reducer] as? ReducerHookHolder<S, A> {
            return (holder.state, holder.dispatch)
        }

        let dispatch: Dispatch<A> = { [unowned self] action in
            queue.addOperation {
                guard let holder = holders[.reducer] as? ReducerHookHolder<S, A> else {
                    return
                }

                holder.state = reducer(holder.state, action)

                DispatchQueue.main.async {
                    objectWillChange.send()
                }
            }
        }

        let holder = ReducerHookHolder(state: state(), dispatch: dispatch)
        holders[.reducer] = holder

        return (holder.state, holder.dispatch)
    }

    func willRenderer() {
    }

    func didRenderer() {
        queue.addOperation { [unowned self] in
            guard let holder = holders[.effect] as? EffectHookHolder else {
                return
            }

            switch holder.trigger {
            case .always:
                if holder.hasRun {
                    _ = holder.closure()
                } else {
                    holder.dispose = holder.closure()
                }
                holder.hasRun = true
            case .once:
                guard !holder.hasRun else {
                    return
                }
                holder.dispose = holder.closure()
                holder.hasRun = true
            }
        }
    }
}

public class Hook {
    let dispatcher: Dispatcher

    init(_ dispatcher: Dispatcher) {
        self.dispatcher = dispatcher
    }

    public func useState<S>(initial state: @autoclosure () -> S) -> Binding<S> {
        return dispatcher.useState(initial: state)
    }

    public func useEffect(trigger: TriggerType, closure: @escaping () -> Dispose?) {
        dispatcher.useEffect(trigger: trigger, closure: closure)
    }

    public func useReducer<S, A>(reducer: @escaping Reducer<S, A>, initial state: @autoclosure () -> S) -> (S, Dispatch<A>) {
        return dispatcher.useReducer(reducer: reducer, initial: state)
    }
}

public typealias Renderer<Content: View> = (Hook) -> Content

public struct Component<Content: View>: View {
    let renderer: Renderer<Content>

    @StateObject var dispatcher: Dispatcher = .init()

    public var body: some View {
        dispatcher.willRenderer()
        let content = renderer(Hook(dispatcher))
        dispatcher.didRenderer()
        return content
    }

    public init(@ViewBuilder renderer: @escaping Renderer<Content>) {
        self.renderer = renderer
    }
}
