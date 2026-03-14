import SwiftUI

// MARK: — Tab Bar Visibility

private struct TabBarHiddenKey: EnvironmentKey {
    static let defaultValue: Binding<Bool>? = nil
}

extension EnvironmentValues {
    var tabBarHidden: Binding<Bool>? {
        get { self[TabBarHiddenKey.self] }
        set { self[TabBarHiddenKey.self] = newValue }
    }
}

private struct HidesTabBarModifier: ViewModifier {
    @Environment(\.tabBarHidden) private var tabBarHidden

    func body(content: Content) -> some View {
        content
            .onAppear { tabBarHidden?.wrappedValue = true }
            .onDisappear { tabBarHidden?.wrappedValue = false }
    }
}

extension View {
    func hidesTabBar() -> some View {
        modifier(HidesTabBarModifier())
    }
}

// MARK: — isPresented variant

private struct AdaptiveSheetModifier<SheetContent: View>: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Binding var isPresented: Bool
    var onDismiss: (() -> Void)?
    @ViewBuilder var sheetContent: () -> SheetContent

    func body(content: Content) -> some View {
        if sizeClass == .regular {
            content.fullScreenCover(isPresented: $isPresented, onDismiss: onDismiss, content: sheetContent)
        } else {
            content.sheet(isPresented: $isPresented, onDismiss: onDismiss, content: sheetContent)
        }
    }
}

// MARK: — item variant

private struct AdaptiveSheetItemModifier<Item: Identifiable, SheetContent: View>: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Binding var item: Item?
    var onDismiss: (() -> Void)?
    @ViewBuilder var sheetContent: (Item) -> SheetContent

    func body(content: Content) -> some View {
        if sizeClass == .regular {
            content.fullScreenCover(item: $item, onDismiss: onDismiss, content: sheetContent)
        } else {
            content.sheet(item: $item, onDismiss: onDismiss, content: sheetContent)
        }
    }
}

// MARK: — View Extension

extension View {
    func adaptiveSheet<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(AdaptiveSheetModifier(isPresented: isPresented, onDismiss: onDismiss, sheetContent: content))
    }

    func adaptiveSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        modifier(AdaptiveSheetItemModifier(item: item, onDismiss: onDismiss, sheetContent: content))
    }
}
