import SwiftUI
import TinyHooks

extension View {
    func eraseToAnyView() -> AnyView {
        return AnyView(self)
    }
}

enum Action {
    case increment
    case decrement
}

func reducer(count: Int, action: Action) -> Int {
    switch action {
    case .increment:
        return count + 1
    case .decrement:
        return count - 1
    }
}

struct ContentView: View {
    var body: some View {
        Component { hook -> AnyView in
            hook.useEffect(trigger: .once) {
                print("once")

                return .none
            }

            let (count, dispatch) = hook.useReducer(reducer: reducer, initial: 0)

            return VStack {
                Text("\(count)")

                HStack {
                    Button(action: { dispatch(.decrement) }, label: {
                        Text("-")
                    })
                    Button(action: { dispatch(.increment) }, label: {
                        Text("+")
                    })
                }
            }
            .eraseToAnyView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
