# LinkUp

LinkUp is a comprehensive Flutter-based mobile application designed to empower students to connect, share resources, collaborate in study groups, and participate in discussion forums. 

## Features
- **Authentication**: Secure user login and registration powered by Firebase Auth.
- **Resource Sharing**: Upload, organize, and download study resources (e.g., notes, past papers), complete with built-in PDF viewing.
- **Forums & Discussions**: Engage in Q&A or open discussions with other students.
- **Study Groups**: Create and join study groups to collaborate with your peers.
- **Notifications**: Real-time notifications for replies, votes, comments, and follows via Firebase Realtime Database.
- **Search & Filtering**: Comprehensive search system for notes and questions, categorized by semester and year filters.
- **Theming**: Elegant Light and Dark mode options handled natively via Riverpod and custom themes.
- **Bookmarking**: Save your favorite resources or forum posts for quick access later.

## Tech Stack
- **Frontend**: Flutter & Dart (SDK ^3.10.7)
- **State Management**: [flutter_riverpod](https://pub.dev/packages/flutter_riverpod)
- **Backend & Database**: Firebase (Auth, Realtime Database, Cloud Storage)
- **Networking API**: [dio](https://pub.dev/packages/dio)
- **Dependency Injection**: [get_it](https://pub.dev/packages/get_it)
- **Styling/UI**: [google_fonts](https://pub.dev/packages/google_fonts), [flutter_animate](https://pub.dev/packages/flutter_animate), [cupertino_icons](https://pub.dev/packages/cupertino_icons)
- **Utilities**: [file_picker](https://pub.dev/packages/file_picker), [url_launcher](https://pub.dev/packages/url_launcher), [shared_preferences](https://pub.dev/packages/shared_preferences), [syncfusion_flutter_pdfviewer](https://pub.dev/packages/syncfusion_flutter_pdfviewer)

## Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) 
- Dart SDK
- Git
- An IDE like VS Code or Android Studio

### Installation

1. Clone the repository:
   ```bash
   git clone <your-repository-url>
   cd project__v2
   ```

2. Install the necessary dependencies:
   ```bash
   flutter pub get
   ```

3. Setup Firebase:
   This app requires a Firebase project. Make sure you configure it by running the `flutterfire` CLI from the root folder:
   ```bash
   flutterfire configure
   ```
   This will generate the `lib/firebase_options.dart` file automatically.
   
4. Run the app:
   ```bash
   flutter run
   ```

## Folder Structure

Let's take a look at how the `lib/` directory is organized:
```
lib/
├── core/             # Core configurations and theme definitions (AppTheme)
├── features/         # Main app features separated module by module
│   ├── auth/         # Authentication screens and logic
│   ├── forum/        # Discussion boards
│   ├── home/         # Main dashboard and feed
│   ├── main_navigation/ # Bottom navigation framework
│   ├── notifications/# Notifications screen and logic
│   ├── onboarding/   # Splash screen, initial setup steps
│   ├── profile/      # User profile management
│   ├── resource/     # Resource detail, actions, and sharing
│   ├── saved/        # Saved items/bookmarks management
│   ├── search/       # App-wide Search and custom filtering features
│   ├── settings/     # User app settings
│   ├── study_groups/ # Study group creation and interaction
│   └── upload/       # File upload functionality
├── models/           # Data models (User, Resource, Forum, Comment, Notification, etc.)
├── providers/        # Global context Riverpod providers
├── services/         # Core services interacting securely with Firebase
└── main.dart         # Main entry point 
```

## Contributing
Issues and Pull Requests are always welcome! Feel free to contribute or suggest features to enhance the app.

## License
[Add License Information Here if Applicable]
