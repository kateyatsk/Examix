# Lingvistik

Lingvistik is an iOS application designed to help users learn languages and test their grammar knowledge. The app provides a comprehensive platform for studying rules, taking tests, and tracking progress across multiple languages including English, French, German, Russian, and Belarusian.

## 📱 Features

* Multi-Language Support: Support for learning and testing in English, French, German, Russian, and Belarusian.
* Interactive Tests: Take grammar tests with various variants and difficulty levels.
* Grammar Rules: Access to detailed grammar rules and study materials (PDF integration).
* User Authentication: Secure sign-in via Email and Google (Firebase Auth).
* Profile Management: User profiles with progress tracking and avatar customization.
* Bookmarks: Save difficult questions or rules to review later.
* Results & Analytics: View detailed test results and summaries to monitor improvement.
* Dark & Light Mode: Fully supported UI for different system appearances.

## 🛠 Tech Stack

* Language: [Swift](https://developer.apple.com/swift/)
* UI Framework: [SwiftUI](https://developer.apple.com/xcode/swiftui/)
* Architecture: MVVM (Model-View-ViewModel)
* Backend / Database:
    * [Firebase Authentication](https://firebase.google.com/docs/auth) (Google Sign-In, Email)
    * [Cloud Firestore](https://firebase.google.com/docs/firestore) (Data storage for tests and users)
* Animations: [Lottie](https://airbnb.design/lottie/)
* Package Manager: Swift Package Manager (SPM)

## 📂 Project Structure

The project follows a clean architecture approach with clear separation of concerns:

```text
Lingvistik
├── App
│   └── LingvistikApp.swift       # Application entry point
├── Core
│   ├── Model                     # Data models (LanguageModel, TestResult)
│   └── ViewModel                 # ViewModels (UserViewModel, TestViewModel)
├── Services
│   ├── Authentication            # Auth logic (SignInGoogleHelper)
│   └── Firestore                 # Database interactions
├── Views
│   ├── Authentication            # Login/Signup screens
│   ├── Home                      # Dashboard
│   ├── Tests                     # Test taking interface
│   ├── Results                   # Test results and summaries
│   ├── Profile                   # User profile settings
│   ├── Rules                     # Grammar rules viewer
│   └── Bookmark                  # Saved content
├── Resources
│   ├── Assets.xcassets           # Images and colors
│   ├── Fonts                     # Custom fonts (Montserrat, KottaOne)
│   └── Rules                     # PDF files for language rules
└── Utilities                     # Helper extensions and managers
