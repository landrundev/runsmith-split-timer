# Step 01 â Add Coach Name to the Athletes Screen

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

    static var hasName: Bool { name?.isEmpty == false }
}
```

---

## MODIFY `SplitDeck/Views/AthleteProfile/AthleteRosterView.swift`

### Change 1 â Add state variables for coach name editing

Find this block near the top of the struct:

```swift
    // Delete athlete
    @State private var athleteToDelete: Athlete? = nil
```

Add these lines directly AFTER it:

```swift

    // Coach name
    @State private var coachName = CoachIdentity.name ?? ""
    @State private var isEditingCoachName = false
```

### Change 2 â Add coach name section at the top of the List

Find this line inside `var body: some View`:

```swift
        List {
            if athletes.isEmpty {
```

Replace it with:

```swift
        List {
            coachNameSection

            if athletes.isEmpty {
```

### Change 3 â Add the coachNameSection computed property

Add this new computed property AFTER the `filteredAthletes` computed property and BEFORE `var body: some View`:

```swift
    private var coachNameSection: some View {
        Section {
            HStack {
                Image(systemName: "person.text.rectangle")
                    .foregroundStyle(Theme.runsmithPink)
                    .frame(width: 24)

                if isEditingCoachName {
                    TextField("Enter your name", text: $coachName, onCommit: {
                        saveCoachName()
                    })
                    .textFieldStyle(.plain)
                    .submitLabel(.done)

                    Button("Save") {
                        saveCoachName()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.runsmithPink)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(coachName.isEmpty ? "Tap to set your name" : coachName)
                            .foregroundStyle(coachName.isEmpty ? .secondary : .primary)
                        if !coachName.isEmpty {
                            Text("Coach Name")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        isEditingCoachName = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.runsmithPink)
                    }
                    .buttonStyle(.plain)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !isEditingCoachName {
                    isEditingCoachName = true
                }
            }
        } header: {
            Text("Coach")
        }
    }

    private func saveCoachName() {
        let trimmed = coachName.trimmingCharacters(in: .whitespaces)
        coachName = trimmed
        CoachIdentity.name = trimmed.isEmpty ? nil : trimmed
        isEditingCoachName = false
    }
```

---

## Verification

- [ ] Build succeeds
- [ ] Open the **Athletes** screen (person.2 icon from Home)
- [ ] At the top of the list, there is a **"Coach"** section with a row showing "Tap to set your name"
- [ ] Tap the row â it switches to an editable text field
- [ ] Type a name (e.g., "Coach Davis") and tap **Save** or press Return
- [ ] The row now shows "Coach Davis" with "Coach Name" caption below it
- [ ] Tap the **pencil icon** â the name becomes editable again
- [ ] Kill the app completely and reopen â the name is still there
- [ ] The coach name section appears above the athlete list (or the empty state) at all times
