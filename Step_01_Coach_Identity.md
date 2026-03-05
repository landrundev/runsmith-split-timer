# Step 01 â Add Coach Name Storage with UserDefaults

---

## CREATE `SplitDeck/Domain/CoachIdentity.swift`

```swift
import Foundation

enum CoachIdentity {
    private static let key = "runsmith_coachName"

    static var name: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static var hasName: Bool {
        name?.isEmpty == false
    }
}
```

---

## MODIFY `SplitDeck/Views/Home/AboutView.swift`

### Change 1: Add state properties for coach name editing

**Find** (the opening of the struct body):
```swift
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let runsmithURL = URL(string: "https://runsmith.app.link/")!
```

**Replace with**:
```swift
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let runsmithURL = URL(string: "https://runsmith.app.link/")!

    @State private var coachName = CoachIdentity.name ?? ""
    @State private var isEditingCoachName = false
    @State private var editingCoachNameDraft = ""
```

---

### Change 2: Insert the "Coach Name" section between the Features divider and "The Runsmith Platform" section

**Find**:
```swift
                Divider().padding(.horizontal)

                // Runsmith platform CTA
                VStack(spacing: 12) {
                    sectionHeader("The Runsmith Platform", icon: "globe")
```

**Replace with**:
```swift
                Divider().padding(.horizontal)

                // Coach name
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Coach Name", icon: "person.crop.circle")

                    HStack {
                        if coachName.isEmpty {
                            Text("Not set")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(coachName)
                                .font(.subheadline)
                        }
                        Spacer()
                        Button {
                            editingCoachNameDraft = coachName
                            isEditingCoachName = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(Theme.runsmithPink)
                        }
                    }
                    .padding(.horizontal, 4)

                    Text("Your name appears in exported split payloads so the host coach can identify your data during merge.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .alert("Coach Name", isPresented: $isEditingCoachName) {
                    TextField("e.g. Coach Williams", text: $editingCoachNameDraft)
                        .autocorrectionDisabled()
                    Button("Save") {
                        let trimmed = editingCoachNameDraft.trimmingCharacters(in: .whitespaces)
                        coachName = trimmed
                        CoachIdentity.name = trimmed.isEmpty ? nil : trimmed
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Enter your name as it will appear to other coaches.")
                }

                Divider().padding(.horizontal)

                // Runsmith platform CTA
                VStack(spacing: 12) {
                    sectionHeader("The Runsmith Platform", icon: "globe")
```

---

## Verification Checklist

- [ ] Build succeeds with no errors or warnings
- [ ] `CoachIdentity.name` can be set and read back from `UserDefaults` (verify with a quick test: set a name, background the app, relaunch, check `CoachIdentity.name` returns the same value)
- [ ] `CoachIdentity.hasName` returns `false` when no name is set, `true` when a non-empty name is saved
- [ ] Opening the About screen shows a "Coach Name" section between Features and "The Runsmith Platform"
- [ ] When no name is saved, the section displays "Not set" in secondary color
- [ ] Tapping the pencil icon shows an alert with a text field pre-filled with the current name (or empty if none)
- [ ] Typing a name and tapping "Save" updates the displayed name immediately
- [ ] Tapping "Cancel" dismisses the alert without changing the displayed name
- [ ] After saving, force-quitting and relaunching the app shows the saved name in the About screen (persists across restarts)
- [ ] Saving an empty/whitespace-only string sets `CoachIdentity.name` to `nil` and displays "Not set"
