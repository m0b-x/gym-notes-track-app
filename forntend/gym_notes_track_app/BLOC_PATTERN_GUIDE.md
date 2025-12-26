# BLoC Pattern Guide for Gym Notes App

## What is BLoC?

**BLoC (Business Logic Component)** is a design pattern created by Google for Flutter apps. It helps you separate your business logic from your UI code.

### Core Concepts

#### 1. **Streams & Events**
- User actions (like button clicks) trigger **Events**
- Events are sent to the BLoC
- BLoC processes events and outputs **States**

#### 2. **Three Main Components**

```
┌─────────────┐         ┌──────────┐         ┌─────────────┐
│    UI       │ Events  │   BLoC   │ States  │     UI      │
│  (Widget)   │────────>│ (Logic)  │────────>│ (Rebuilds)  │
└─────────────┘         └──────────┘         └─────────────┘
```

**Events**: User actions (CreateFolder, DeleteNote, etc.)  
**BLoC**: Processes events, contains business logic  
**States**: Represents UI state (Loading, Loaded, Error)

---

## How We Used BLoC in This App

### 1. **Models** (`lib/models/`)
Data structures that represent our domain:
- `Folder`: Represents a note folder
- `Note`: Represents a markdown note

### 2. **Events** (`lib/bloc/*/...event.dart`)
User actions that can happen:

**Folder Events:**
- `LoadFolders`: Load all folders
- `CreateFolder`: Create a new folder
- `DeleteFolder`: Delete a folder
- `UpdateFolder`: Rename a folder

**Note Events:**
- `LoadNotes`: Load notes in a folder
- `CreateNote`: Create a new note
- `UpdateNote`: Update note content
- `DeleteNote`: Delete a note

### 3. **States** (`lib/bloc/*/...state.dart`)
Different UI states:

**Folder States:**
- `FolderInitial`: Before loading
- `FolderLoading`: Currently loading
- `FolderLoaded`: Successfully loaded (contains folder list)
- `FolderError`: An error occurred

**Note States:**
- `NoteInitial`: Before loading
- `NoteLoading`: Currently loading
- `NoteLoaded`: Successfully loaded (contains note list)
- `NoteError`: An error occurred

### 4. **BLoCs** (`lib/bloc/*/...bloc.dart`)
The brain of the operation:
- `FolderBloc`: Manages folder operations
- `NoteBloc`: Manages note operations

Each BLoC:
- Listens to events
- Processes business logic
- Emits new states

---

## How BLoC Works in Practice

### Example: Creating a Folder

1. **User taps "+" button** → UI sends event
```dart
context.read<FolderBloc>().add(CreateFolder('My Workout Notes'));
```

2. **FolderBloc receives event** → Processes it
```dart
Future<void> _onCreateFolder(CreateFolder event, Emitter<FolderState> emit) async {
  final newFolder = Folder(
    id: _uuid.v4(),
    name: event.name,
    createdAt: DateTime.now(),
  );
  _folders.add(newFolder);
  emit(FolderLoaded(List.from(_folders))); // Emit new state
}
```

3. **BLoC emits new state** → UI rebuilds automatically
```dart
BlocBuilder<FolderBloc, FolderState>(
  builder: (context, state) {
    if (state is FolderLoaded) {
      return ListView.builder(/* show folders */);
    }
  }
)
```

---

## Key BLoC Widgets

### 1. **BlocProvider** - Provides BLoC to widget tree
```dart
BlocProvider(
  create: (context) => FolderBloc(),
  child: MyWidget(),
)
```

### 2. **BlocBuilder** - Rebuilds UI when state changes
```dart
BlocBuilder<FolderBloc, FolderState>(
  builder: (context, state) {
    if (state is FolderLoading) return CircularProgressIndicator();
    if (state is FolderLoaded) return FolderList(state.folders);
    return ErrorWidget();
  },
)
```

### 3. **context.read()** - Send events to BLoC
```dart
context.read<FolderBloc>().add(CreateFolder('New Folder'));
```

---

## Benefits of BLoC Pattern

✅ **Separation of Concerns**: Business logic separate from UI  
✅ **Testability**: Easy to test logic without UI  
✅ **Reusability**: BLoCs can be reused across widgets  
✅ **Predictable State**: State changes are explicit and trackable  
✅ **Scalability**: Easy to add new features  

---

## App Structure

```
lib/
├── models/
│   ├── folder.dart          # Folder data model
│   └── note.dart            # Note data model
│
├── bloc/
│   ├── folder/
│   │   ├── folder_event.dart    # Folder events
│   │   ├── folder_state.dart    # Folder states
│   │   └── folder_bloc.dart     # Folder business logic
│   │
│   └── note/
│       ├── note_event.dart      # Note events
│       ├── note_state.dart      # Note states
│       └── note_bloc.dart       # Note business logic
│
├── pages/
│   ├── folders_page.dart        # Main page (folder list)
│   ├── notes_page.dart          # Notes list for a folder
│   └── note_editor_page.dart    # Note editor with markdown
│
└── main.dart                    # App entry point with BLoC providers
```

---

## Running the App

1. Ensure you have Flutter installed
2. Run: `flutter pub get`
3. Run: `flutter run`
4. Choose your target device

---

## Next Steps & Enhancements

- Add persistent storage (SQLite, Hive, etc.)
- Add markdown preview/rendering
- Add search functionality
- Add note tags/categories
- Add cloud sync
- Add authentication

---

## Learn More

- [BLoC Package Documentation](https://bloclibrary.dev)
- [Flutter BLoC Tutorial](https://bloclibrary.dev/#/fluttertodostutorial)
- [Equatable Package](https://pub.dev/packages/equatable) - For state comparison
