// ============================================================
// RFID Library Attendance System (FIREBASE MOBIZT LIBRARY VERSION)
// PRODUCTION FIRMWARE v6.0
// ============================================================
// WIRING REMAINS THE SAME
// ============================================================

#include <Arduino.h>
#include <SPI.h>
#include <MFRC522.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h> // Make sure to install "Firebase ESP32 Client" by Mobizt in Arduino IDE
#include "addons/TokenHelper.h"

// ============================================================
// ⚙️ CONFIGURATION 
// ============================================================

// 🔴 YOUR FIREBASE CREDENTIALS (REQUIRED FOR MOBIZT LIBRARY)
#define FIREBASE_PROJECT_ID "mgc-management"
#define FIREBASE_API_KEY "PASTE_YOUR_WEB_API_KEY_HERE"
#define FIREBASE_USER_EMAIL "admin@library.com"
#define FIREBASE_USER_PASSWORD "PASTE_YOUR_PASSWORD_HERE"

// Admin Master Card UID
#define ADMIN_UID "17F0E700"  

// Known WiFi networks
const char* WIFI_SSID = "mgc1155";
const char* WIFI_PASS = "19931993";

// Pins
#define PIN_RFID_SS 5
#define PIN_RFID_RST 4
#define PIN_BUZZER 25
#define PIN_LED_GREEN 26
#define PIN_LED_RED 27

// Constants
#define COOLDOWN_MS 3000

// State
bool enrollMode = false;
uint32_t lastScanMs = 0;
uint32_t lastTelemetryMs = 0;
uint32_t lastCommandMs = 0;
char lastUID[12] = { 0 };

// Objects
MFRC522 rfid(PIN_RFID_SS, PIN_RFID_RST);
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Forward Declarations
void beep(uint8_t n, uint16_t ms);
void blink(uint8_t pin, uint8_t n);
String getUID();
void logTempScan(const String& uid);
void processAttendance(const String& uid);
void sendTelemetry();
void receiveCommands();

// ============================================================
// SETUP
// ============================================================
void setup() {
  Serial.begin(115200);
  Serial.println(F("\n=== RFID Firebase Mobizt Attendance v6.0 ==="));

  pinMode(PIN_BUZZER, OUTPUT);
  pinMode(PIN_LED_GREEN, OUTPUT);
  pinMode(PIN_LED_RED, OUTPUT);

  SPI.begin();
  rfid.PCD_Init();
  delay(50);
  Serial.println(F("RFID OK"));

  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi Connected!");
  blink(PIN_LED_GREEN, 2);

  // Configure Firebase (Mobizt)
  Serial.printf("Firebase Client v%s\n\n", FIREBASE_CLIENT_VERSION);
  config.api_key = FIREBASE_API_KEY;
  auth.user.email = FIREBASE_USER_EMAIL;
  auth.user.password = FIREBASE_USER_PASSWORD;
  config.token_status_callback = tokenStatusCallback;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  // Set NTP Time for precise timestamps
  configTime(19800, 0, "pool.ntp.org"); 

  beep(1, 150);
  Serial.println(F("## FIREBASE READY ##"));
}

// ============================================================
// LOOP
// ============================================================
void loop() {
  receiveCommands();
  sendTelemetry(); // Non-blocking heartbeat every 30s

  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) {
    delay(50);
    return;
  }

  String uid = getUID();
  uint32_t now = millis();

  if (uid == String(lastUID) && (now - lastScanMs) < COOLDOWN_MS) {
    rfid.PICC_HaltA();
    return;
  }
  uid.toCharArray(lastUID, sizeof(lastUID));
  lastScanMs = now;

  // 1. ALWAYS LOG TO TEMP SCANS
  // This allows the Flutter ScannerPage to see EVERY card instantly
  logTempScan(uid);

  // 2. PROCESS SPECIFIC LOGIC
  if (uid == String(ADMIN_UID)) {
    enrollMode = !enrollMode;
    if (enrollMode) {
      Serial.println("ENTRY MODE DISABLED. ENROLL MODE ACTIVE.");
      beep(2, 100);
      blink(PIN_LED_GREEN, 2);
    } else {
      Serial.println("ENROLL MODE DISABLED. ATTENDANCE ACTIVE.");
      beep(1, 300);
    }
  } else {
    if (enrollMode) {
      Serial.println("Scanned for Enrollment: " + uid);
      beep(3, 80);
      blink(PIN_LED_GREEN, 3);
      // Wait for Flutter app to consume it
    } else {
      processAttendance(uid);
    }
  }

  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
}

// ============================================================
// FIREBASE OPERATIONS
// ============================================================

void receiveCommands() {
  uint32_t now = millis();
  if (now - lastCommandMs >= 3500 || lastCommandMs == 0) { // Poll every 3.5s
    lastCommandMs = now;
    
    if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", "devices/esp32_main")) {
      String payload = fbdo.payload();
      
      // 1. REBOOT COMMAND
      if (payload.indexOf("\"cmd_reboot\":{\"booleanValue\":true}") != -1) {
        Serial.println("\n🔥 UI COMMAND: REBOOTING...");
        beep(3, 100);
        FirebaseJson clearCmd;
        clearCmd.set("fields/cmd_reboot/booleanValue", false);
        Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "", "devices/esp32_main", clearCmd.raw(), "cmd_reboot");
        delay(500);
        ESP.restart();
      }
      
      // 2. LOCK/LED TEST COMMAND
      if (payload.indexOf("\"cmd_lock\":{\"booleanValue\":true}") != -1) {
        Serial.println("\n🔥 UI COMMAND: HARDWARE LOCK TEST");
        blink(PIN_LED_RED, 4);
        beep(2, 500);
        FirebaseJson clearCmd;
        clearCmd.set("fields/cmd_lock/booleanValue", false);
        Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "", "devices/esp32_main", clearCmd.raw(), "cmd_lock");
      }
      
      // 3. MODE TOGGLE COMMAND
      int modeIdx = payload.indexOf("\"cmd_mode\":{\"stringValue\":\"");
      if (modeIdx != -1) {
        int vStart = modeIdx + 27;
        int vEnd = payload.indexOf("\"", vStart);
        String pendingMode = payload.substring(vStart, vEnd);
        
        if (pendingMode == "enroll" && !enrollMode) {
          enrollMode = true;
          Serial.println("\n🔥 UI COMMAND: ENROLL MODE ACTIVATED");
          beep(2, 100);
          blink(PIN_LED_GREEN, 2);
        } else if (pendingMode == "attendance" && enrollMode) {
          enrollMode = false;
          Serial.println("\n🔥 UI COMMAND: ATTENDANCE MODE ACTIVATED");
          beep(1, 300);
        }
        
        // Clear mode command
        FirebaseJson clearCmd;
        clearCmd.set("fields/cmd_mode/stringValue", "");
        Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "", "devices/esp32_main", clearCmd.raw(), "cmd_mode");
      }
    }
  }
}

void sendTelemetry() {
  uint32_t now = millis();
  if (now - lastTelemetryMs >= 30000 || lastTelemetryMs == 0) { // Every 30s
    lastTelemetryMs = now;
    
    FirebaseJson content;
    content.set("fields/uptime_sec/integerValue", String(now / 1000).c_str());
    content.set("fields/mode/stringValue", enrollMode ? "enroll" : "attendance");
    content.set("fields/firmware/stringValue", "v6.1");
    content.set("fields/wifiList/stringValue", WIFI_SSID);
    content.set("fields/rssi/integerValue", String(WiFi.RSSI()).c_str());
    
    struct tm t;
    if(getLocalTime(&t)) {
      char buf[30];
      strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &t);
      content.set("fields/last_ping/timestampValue", buf);
    } else {
      content.set("fields/last_ping/timestampValue", "2026-01-01T00:00:00Z");
    }
    
    // Update Document
    if (Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "", "devices/esp32_main", content.raw(), "")) {
      Serial.println("Telemetry Synced.");
    }
  }
}

void logTempScan(const String& uid) {
  FirebaseJson content;
  content.set("fields/uid/stringValue", uid.c_str());
  
  // Format current NTP time strictly to RFC3339 for Firestore
  struct tm t;
  if(getLocalTime(&t)) {
    char buf[30];
    strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &t);
    content.set("fields/timestamp/timestampValue", buf);
  } else {
    // Fallback if NTP fails
    content.set("fields/timestamp/timestampValue", "2026-01-01T00:00:00Z"); 
  }

  // Create document in temp_scans collection
  if (Firebase.Firestore.createDocument(&fbdo, FIREBASE_PROJECT_ID, "", "temp_scans", content.raw())) {
    Serial.println("TempScan Logged -> " + uid);
  } else {
    Serial.println("TempScan Error: " + fbdo.errorReason());
  }
}

void processAttendance(const String& uid) {
  Serial.println("\n── Attendance Check: " + uid + " ──");
  beep(1, 30);

  // 1. Query the 'students' collection where 'uid' == scanned uid
  FirebaseJson query;
  query.set("structuredQuery/from/[0]/collectionId", "students");
  query.set("structuredQuery/where/fieldFilter/field/fieldPath", "uid");
  query.set("structuredQuery/where/fieldFilter/op", "EQUAL");
  query.set("structuredQuery/where/fieldFilter/value/stringValue", uid.c_str());
  query.set("structuredQuery/limit", 1);

  if (!Firebase.Firestore.runQuery(&fbdo, FIREBASE_PROJECT_ID, "", query.raw())) {
    Serial.println("Query Error: " + fbdo.errorReason());
    blink(PIN_LED_RED, 2);
    return;
  }

  // Parse result (Mobizt returns JSON format of the document)
  String payload = fbdo.payload();
  
  // Checking if empty results using simple string find
  if (payload == "[]" || payload.length() < 10) {
    Serial.println("Unknown Card -> Denied");
    blink(PIN_LED_RED, 3);
    beep(3, 80);
    return;
  }

  // Find the exact document path and the current status
  int nameIdx = payload.indexOf("\"name\":{\"stringValue\":\"");
  String studentName = "Unknown";
  if (nameIdx != -1) {
    int nStart = nameIdx + 25;
    int nEnd = payload.indexOf("\"", nStart);
    studentName = payload.substring(nStart, nEnd);
  }

  int rollIdx = payload.indexOf("\"roll\":{\"stringValue\":\"");
  String studentRoll = "N/A";
  if (rollIdx != -1) {
    int rStart = rollIdx + 25;
    int rEnd = payload.indexOf("\"", rStart);
    studentRoll = payload.substring(rStart, rEnd);
  }
  
  // Find project document path
  int pathIdx = payload.indexOf("\"name\":\"");
  if (pathIdx == -1) return;
  
  int pathStart = pathIdx + 8;
  int pathEnd = payload.indexOf("\"", pathStart);
  String docPathRaw = payload.substring(pathStart, pathEnd); // Format: projects/.../documents/students/{doc_id}
  
  // Extract just the {doc_id} to use in Firestore.patchDocument
  int lastSlash = docPathRaw.lastIndexOf('/');
  String docId = docPathRaw.substring(lastSlash + 1);

  // Find current status
  int statusIdx = payload.indexOf("\"status\":{\"stringValue\":\"");
  String currentStatus = "Left";
  if (statusIdx != -1) {
    int sStart = statusIdx + 25;
    int sEnd = payload.indexOf("\"", sStart);
    currentStatus = payload.substring(sStart, sEnd);
  }

  // 2. Determine new status
  String newStatus = (currentStatus == "Inside") ? "Left" : "Inside";

  // 3. Patch specific document
  FirebaseJson patchData;
  patchData.set("fields/status/stringValue", newStatus.c_str());
  
  if (Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "", ("students/" + docId).c_str(), patchData.raw(), "status")) {
    Serial.println("Student Status Updated: " + newStatus);
    
    // 4. CREATE HISTORICAL ATTENDANCE LOG
    FirebaseJson attLog;
    attLog.set("fields/studentId/stringValue", docId.c_str());
    attLog.set("fields/studentName/stringValue", studentName.c_str());
    attLog.set("fields/studentRoll/stringValue", studentRoll.c_str());
    attLog.set("fields/uid/stringValue", uid.c_str());
    attLog.set("fields/action/stringValue", (newStatus == "Inside") ? "Entry" : "Exit");
    
    struct tm t;
    if(getLocalTime(&t)) {
      char buf[30];
      strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &t);
      attLog.set("fields/timestamp/timestampValue", buf);
    } else {
      attLog.set("fields/timestamp/timestampValue", "2026-01-01T00:00:00Z");
    }

    if (Firebase.Firestore.createDocument(&fbdo, FIREBASE_PROJECT_ID, "", "attendance", attLog.raw())) {
      Serial.println("Historical Attendance Logged: " + String((newStatus == "Inside") ? "Entry" : "Exit"));
    } else {
      Serial.println("Attendance Log Error: " + fbdo.errorReason());
    }
    
    if (newStatus == "Inside") {
      blink(PIN_LED_GREEN, 1);
      beep(1, 400);
    } else {
      blink(PIN_LED_GREEN, 2);
      beep(2, 150);
    }
  } else {
    Serial.println("Patch Error: " + fbdo.errorReason());
    blink(PIN_LED_RED, 2);
  }
}

// ============================================================
// HELPERS
// ============================================================
String getUID() {
  String uid = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) uid += '0';
    uid += String(rfid.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();
  return uid;
}

void beep(uint8_t n, uint16_t ms) {
  for (uint8_t i = 0; i < n; i++) {
    digitalWrite(PIN_BUZZER, HIGH);
    delay(ms);
    digitalWrite(PIN_BUZZER, LOW);
    if (i < n - 1) delay(60);
  }
}

void blink(uint8_t pin, uint8_t n) {
  for (uint8_t i = 0; i < n; i++) {
    digitalWrite(pin, HIGH);
    delay(250);
    digitalWrite(pin, LOW);
    if (i < n - 1) delay(80);
  }
}
