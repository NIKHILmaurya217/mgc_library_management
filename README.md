# RFID Attendance and Fee Management System

This project is a comprehensive Attendance and Fee Management System built with **Flutter**, **Firebase**, and **ESP32** (with an RFID module). It provides a full-stack solution for managing student attendance via RFID cards and tracking their fee payments.

## Features

*   **Student Management:** Add, update, and manage student details.
*   **RFID Attendance System:** Uses an ESP32 micro-controller and an RFID scanner to record student attendance automatically.
*   **Fee Management:** Track student fee statuses, manage payments, and generate fee reports.
*   **Authentication:** Secure login and registration for administrators/teachers.
*   **Firebase Integration:** Real-time database updates, cloud functions, and secure authentication.
*   **Cross-Platform:** Built with Flutter, supporting both Android and Web/iOS.

## Tech Stack

*   **Frontend:** Flutter (Dart)
*   **Backend / Database:** Firebase (Firestore, Firebase Auth, Cloud Functions)
*   **Hardware / IoT:** ESP32, RFID Reader (MFRC522), Arduino IDE/C++

## Folder Structure

*   `lib/`: Contains the Flutter application source code (UI, models, authentication, state management).
*   `functions/`: Contains Firebase Cloud Functions (Node.js).
*   `esp32_firebase_firmware/` & `rfid_attendance_v9.ino`: Contains the C++ firmware for the ESP32 to scan RFID tags and send data to Firebase.
*   `web/`, `android/`, `windows/`: Platform-specific configuration files for the Flutter app.

## Setup Instructions

### 1. Flutter App Setup

1.  Ensure you have Flutter installed.
2.  Clone the repository and run `flutter pub get` in the root directory to install dependencies.
3.  Configure Firebase for your Flutter project using the FlutterFire CLI.
4.  Run the app using `flutter run`.

### 2. Firebase Setup

1.  Set up a Firebase project and enable Firestore and Firebase Authentication.
2.  Deploy the cloud functions by navigating to the `functions/` directory, running `npm install`, and then `firebase deploy --only functions`.

### 3. ESP32 Setup

1.  Open `rfid_attendance_v9.ino` in the Arduino IDE.
2.  Install the required libraries (Firebase ESP32 Client, MFRC522).
3.  Update the Wi-Fi credentials and Firebase config (Database URL, API Key) in the code.
4.  Flash the code to your ESP32 board.

## Contributing

Contributions are welcome! Please create an issue or submit a pull request for any improvements or bug fixes.
