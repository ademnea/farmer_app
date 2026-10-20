# Farmer App

# HPGM - Hive Performance & Growth Monitoring

![CI/CD Status](https://github.com/yourusername/farmer_app/actions/workflows/flutter_ci_cd.yml/badge.svg)

HPGM (Honey Productivity, Guide and Monitor) is a comprehensive Flutter application designed to help beekeepers track hive productivity, monitor bee activity, and manage apiaries efficiently. The app provides data-driven insights to optimize beekeeping operations and maximize honey production.

## 📱 Features

- **Apiary Management**: Track and manage multiple apiaries and hives
- **Bee Activity Monitoring**: Advanced video analysis to count bees entering and exiting hives
- **Foraging Analysis**: Analyze bee foraging patterns and efficiency
- **Environmental Monitoring**: Track temperature, humidity, and weight of hives
- **PDF Reporting**: Generate detailed bee foraging analysis reports
- **Inspection Records**: Keep detailed records of hive inspections
- **Recommendations**: Get AI-powered recommendations based on hive performance
- **Dashboard**: View key metrics and performance indicators
- **Multi-platform**: Works on Android, iOS, Web, Windows, Linux, and macOS

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (version 3.7.0 or higher)
- Dart SDK (version 3.7.0 or higher)
- Android Studio / VS Code with Flutter extensions
- Git

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/farmer_app.git

2.  Navigate to the project directory:

cd farmer_app

3. Install dependencies:

flutter pub get

4. Run the application:

flutter run

🛠️ Building for Different Platforms
Android
flutter build apk --release
iOS
flutter build ios --release
Web
flutter build web --release
Windows
flutter build windows --release
Linux
flutter build linux --release
macOS
flutter build macos --release


📊 Architecture
HPGM follows a modular architecture with separate components for:

UI/presentation
Business logic
Data access
External services integration
The app uses various Flutter packages for PDF generation, data visualization, and device sensor integration.

🧪 Testing
Run tests using:
# Run unit tests
flutter test test/unit/

# Run widget tests
flutter test test/widget/

# Run a specific test file
flutter test test/unit/app_utils_test.dart





