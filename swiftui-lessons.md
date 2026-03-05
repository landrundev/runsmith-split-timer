# SwiftUI Patterns, Pitfalls & Fixes

Lessons discovered during Runsmith Split Timer development.

---

## 1. `.onTapGesture` Steals Taps from Child Buttons

**Problem**: Wrapping a `Button` inside an `HStack` with `.contentShape(Rectangle()).onTapGesture { ... }` causes the gesture to intercept taps meant for the button. The button's action never fires.

**Fix**: Split the view into separate `if/else` branches so the `.onTapGesture` is only attached to the non-interactive state (e.g., the display-only branch), not the branch containing buttons.

```swift
// BAD — onTapGesture steals taps from Save button
HStack {
    if isEditing {
        TextField(...)
        Button("Save") { save() } // never fires
    } else {
        Text(value)
    }
}
.contentShape(Rectangle())
.onTapGesture { isEditing = true }

// GOOD — separate branches, gesture only on display state
if isEditing {
    HStack {
        TextField(...)
            .onSubmit { save() }
        Button("Save") { save() }
    }
} else {
    HStack { Text(value); Spacer(); Image(...) }
        .contentShape(Rectangle())
        .onTapGesture { isEditing = true }
}
```

---

## 2. TextField `onCommit` Is Deprecated — Use `.onSubmit`

**Problem**: `TextField("...", text: $binding, onCommit: { ... })` is deprecated in iOS 15+.

**Fix**: Use the `.onSubmit` modifier with `.submitLabel(.done)`:

```swift
TextField("Enter name", text: $name)
    .submitLabel(.done)
    .onSubmit { saveName() }
```

---

## 3. `didSet` Property Observers Fire Before Other State Updates

**Problem**: Using `@Published var foo { didSet { refresh() } }` where `refresh()` resets related state (e.g., clears a selection array) means switching `foo` wipes out state the user expects to keep.

**Fix**: Save state before the reset and restore what's still valid after:

```swift
private func refreshCandidates() {
    let previousIds = chosenIds
    // ... rebuild candidates ...
    let validIds = Set(candidates.map(\.id))
    chosenIds = previousIds.filter { validIds.contains($0) }
}
```

---

## 4. Make Domain Model Fields Non-Optional When Business Rules Require Them

**Problem**: `Athlete.gender: Gender?` allowed athletes without gender to slip through CSV import, causing them to vanish from gender-filtered views (Relay Builder).

**Fix**: Make the field non-optional (`gender: Gender`) at the model level. Use `guard let` in UI code where the state variable is still optional (pre-selection). Add a fallback in the persistence layer for legacy nil data:

```swift
// Model: required
var gender: Gender

// Store fetch: fallback for legacy data
gender: entity.gender.flatMap { Gender(rawValue: $0) } ?? .male

// UI: guard before construction
guard let gender = editGender else { return }
let athlete = Athlete(..., gender: gender)
```

---

## 5. CSV Import: Normalize Flexible Input Formats

**Problem**: CSV gender column might contain "M", "m", "Male", "male", "F", "f", "Female", "female". Strict `Gender(rawValue:)` only matches "M"/"F".

**Fix**: Add a normalization helper:

```swift
private static func normalizeGender(_ raw: String) -> Gender? {
    switch raw.lowercased() {
    case "m", "male":  return .male
    case "f", "female": return .female
    default: return nil
    }
}
```

---

## 6. CADisplayLink Must Use `.common` Run Loop Mode

Using `.default` causes the display link to freeze during scroll gestures. Always add to `.common`:

```swift
displayLink.add(to: .main, forMode: .common)
```

---

## 7. Elapsed Time: Recompute from `startedAt`, Never Accumulate

Accumulating `+0.01s` per tick drifts over time. Always compute:

```swift
let elapsed = Date().timeIntervalSince(startedAt)
```

---

## 8. Glassmorphism Button Patterns

Reusable `ButtonStyle` structs work well for consistent glass effects across the app:

- Use `@Environment(\.isEnabled)` to handle disabled state opacity
- Use `configuration.isPressed` for press animation (scale + opacity)
- Pair with a `.glassActionBar()` ViewModifier using `.ultraThinMaterial` for the bottom bar background
- Use `.ignoresSafeAreaEdges: .bottom` on the material to extend through the safe area
