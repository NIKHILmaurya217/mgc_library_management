// ============================================================
// RFID Library Attendance System
// FIRMWARE v9.0
// ============================================================
//
// ── ENROLLMENT FLOW ─────────────────────────────────────────
//   1. Flutter app presses "Register Card" button
//   2. Flutter writes  cmd_mode: "enroll"  to Firestore
//      devices/esp32_main
//   3. ESP32 picks it up (polls every 3.5 s) → enters enroll mode
//      Green LED blinks, buzzer double-beep
//   4. User scans the new card
//   5. ESP32 writes UID to temp_scans (as always)
//      ALSO writes  enroll_uid  field to devices/esp32_main
//   6. Flutter reads enroll_uid, links it to the student doc,
//      sets  uid  field on the student in Firestore
//   7. Flutter writes  cmd_mode: "attendance"  (or ESP auto-exits
//      after 30 s timeout) → ESP back to attendance mode
//
// ── ATTENDANCE FLOW ─────────────────────────────────────────
//   Every card scan (attendance mode):
//     1. Log UID to temp_scans (Flutter live feed)
//     2. Query Firebase students by UID
//        ┌─ FOUND ─────────────────────────────────────────┐
//        │  First scan ever (sheetSynced != true):          │
//        │    → POST student row to Sheets  (once only)     │
//        │    → Patch sheetSynced:true on Firebase doc      │
//        │  Every scan:                                     │
//        │    → Mark Entry/Exit in Sheets attendance tab    │
//        │    → Toggle status in Firebase student doc       │
//        │    → Append doc to Firebase attendance collection│
//        │    → Green LED + buzzer                          │
//        └──────────────────────────────────────────────────┘
//        ┌─ NOT FOUND ──────────────────────────────────────┐
//        │  Red LED + 3 beeps. Nothing else.                │
//        │  Flutter sees temp_scan UID and can prompt       │
//        │  the librarian to register that card.            │
//        └──────────────────────────────────────────────────┘
//
// ── OFFLINE (no WiFi) ───────────────────────────────────────
//   Scans queued to SPIFFS (uid + IST timestamp).
//   On reconnect → syncOffline() replays each entry fully.
//
// ── FIREBASE COMMANDS (Flutter → Firestore → ESP32) ────────
//   cmd_mode : "enroll"      → enter enroll mode
//   cmd_mode : "attendance"  → exit enroll mode
//   cmd_reboot : true        → reboot ESP32
//   cmd_lock   : true        → LED/buzzer hardware test
//
// ── TELEMETRY (ESP32 → Firestore, every 30 s) ───────────────
//   devices/esp32_main : uptime, rssi, firmware, mode, last_ping
//
// ── GOOGLE SHEETS API CALLS ─────────────────────────────────
//   action=upsert_student  → called ONCE per student (ever)
//   action=attendance      → called on every valid scan
//
// WIRING:
//   MFRC522 → ESP32 : SDA→D5, SCK→D18, MOSI→D23, MISO→D19, RST→D4
//   Buzzer  → D25   Green LED → D26   Red LED → D27   Button → D32
//
// LIBRARIES (Arduino Library Manager):
//   - MFRC522             by GithubCommunity
//   - ArduinoJson         by Benoit Blanchon  (v6.x)
//   - Firebase ESP Client by Mobizt
//
// ARDUINO IDE SETTINGS:
//   Board           : ESP32 Dev Module
//   Partition Scheme: Default 4MB with spiffs
// ============================================================


#include <Arduino.h>
#include <SPI.h>
#include <MFRC522.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <SPIFFS.h>
#include <time.h>
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"


// ============================================================
// ⚙️  CONFIGURATION
// ============================================================

// Google Apps Script Web App URL
// Script must handle:
//   ?action=upsert_student&uid=&name=&roll=&cls=&phone=
//   ?action=attendance&uid=&name=&roll=&action=Entry|Exit&ts=
static const char SCRIPT_URL[] = "";   // ← paste /exec URL

// Firebase
#define FIREBASE_PROJECT_ID    "mgc-management"
#define FIREBASE_API_KEY       "PASTE_YOUR_WEB_API_KEY_HERE"
#define FIREBASE_USER_EMAIL    "admin@library.com"
#define FIREBASE_USER_PASSWORD "PASTE_YOUR_PASSWORD_HERE"

// WiFi networks (tried in order)
struct KnownNetwork { const char* ssid; const char* pass; };
static const KnownNetwork KNOWN_NETWORKS[] = {
  { "mgc1155", "19931993"   },
  { "Mgcl",    "8052954491" },
};
static const uint8_t KNOWN_NETWORK_COUNT = 2;

static const char AP_NAME[] = "Library-RFID-Setup";

// Timezone: IST = UTC+5:30
static const long GMT_OFFSET  = 19800;
static const int  DST_OFFSET  = 0;
static const char NTP_SERVER[]  = "pool.ntp.org";
static const char NTP_SERVER2[] = "time.google.com";
static const char NTP_SERVER3[] = "time.cloudflare.com";


// ============================================================
// PINS
// ============================================================
#define PIN_RFID_SS   5
#define PIN_RFID_RST  4
#define PIN_BUZZER    25
#define PIN_LED_GREEN 26
#define PIN_LED_RED   27
#define PIN_BUTTON    32


// ============================================================
// TIMING
// ============================================================
#define COOLDOWN_MS        3000    // ignore same-card re-scan
#define ENROLL_TIMEOUT_MS  30000   // auto-exit enroll mode after 30 s
#define WIFI_ATTEMPT_MS    8000    // per-network connect timeout
#define HTTP_TIMEOUT_MS    8000    // Sheets HTTP timeout
#define FB_CMD_INTERVAL    3500    // Firestore command poll interval
#define FB_TELEM_INTERVAL  30000   // Firestore telemetry interval


// ============================================================
// SPIFFS OFFLINE QUEUE
// Lines: uid,YYYY-MM-DD HH:MM:SS
// ============================================================
#define OFFLINE_FILE "/q.txt"


// ============================================================
// STATE
// ============================================================
struct State {
  bool     wifiOK      = false;
  bool     fbOK        = false;
  bool     ntpSynced   = false;
  bool     enrollMode  = false;
  uint32_t lastScanMs  = 0;
  uint32_t enrollStart = 0;
  uint32_t btnHoldMs   = 0;
  uint32_t lastCmdMs   = 0;
  uint32_t lastTelemMs = 0;
  char     lastUID[12] = { 0 };
};
static State sys;


// ============================================================
// STUDENT (populated from Firestore query)
// ============================================================
struct Student {
  String docId;
  String uid;
  String name;
  String roll;
  String cls;
  String phone;
  String status;        // "Inside" or "Left"
  bool   sheetSynced;   // true = already added to Sheets
  bool   found = false;
};


// ============================================================
// OBJECTS
// ============================================================
static MFRC522      rfid(PIN_RFID_SS, PIN_RFID_RST);
static FirebaseData fbdo;
static FirebaseAuth fbAuth;
static FirebaseConfig fbConfig;


// ============================================================
// FORWARD DECLARATIONS
// ============================================================
void    beep(uint8_t n, uint16_t ms);
void    blink(uint8_t pin, uint8_t n);
String  getUID();
String  nowIST();
String  nowFirestore();
String  urlEncode(const String& s);
bool    smartConnect();
bool    launchAP();
void    resetWiFi();

void    fbInit();
void    fbSendTelemetry();
void    fbReceiveCommands();
void    fbLogTempScan(const String& uid, bool isEnroll);
void    fbSetEnrollUID(const String& uid);
Student fbQueryStudent(const String& uid);
void    fbMarkSheetSynced(const Student& s);
void    fbUpdateStatus(const Student& s, const String& newStatus);
void    fbLogAttendance(const Student& s, const String& action);

String  sheetsRequest(const String& params);
void    sheetsUpsertStudent(const Student& s);
void    sheetsMarkAttendance(const Student& s, const String& action, const String& ts);

void    handleEnrollScan(const String& uid);
void    handleAttendanceScan(const String& uid);
void    saveOffline(const String& uid);
void    syncOffline();

void    enterEnrollMode();
void    exitEnrollMode();


// ============================================================
// SETUP
// ============================================================
void setup() {
  Serial.begin(115200);
  Serial.println(F("\n=== RFID Attendance v9.0 ==="));

  pinMode(PIN_BUZZER,    OUTPUT);
  pinMode(PIN_LED_GREEN, OUTPUT);
  pinMode(PIN_LED_RED,   OUTPUT);
  pinMode(PIN_BUTTON,    INPUT_PULLUP);
  digitalWrite(PIN_BUZZER,    LOW);
  digitalWrite(PIN_LED_GREEN, LOW);
  digitalWrite(PIN_LED_RED,   LOW);

  if (!SPIFFS.begin(true)) Serial.println(F("SPIFFS FAIL"));

  SPI.begin();
  rfid.PCD_Init();
  delay(50);
  Serial.println(F("RFID OK"));

  sys.wifiOK = smartConnect();

  if (sys.wifiOK) {
    delay(1000);
    configTime(GMT_OFFSET, DST_OFFSET, NTP_SERVER, NTP_SERVER2, NTP_SERVER3);
    delay(500);
    struct tm t;
    sys.ntpSynced = getLocalTime(&t, 8000);
    if (sys.ntpSynced) {
      char buf[24];
      strftime(buf, sizeof(buf), "%d-%b-%Y %H:%M:%S", &t);
      Serial.printf("NTP: %s\n", buf);
    }
    fbInit();
    syncOffline();
  }

  beep(1, 150);
  Serial.println(F("## READY ##"));
}


// ============================================================
// MAIN LOOP
// ============================================================
void loop() {
  // Button hold 5 s → WiFi reset
  if (digitalRead(PIN_BUTTON) == LOW) {
    if (!sys.btnHoldMs) sys.btnHoldMs = millis();
    if (millis() - sys.btnHoldMs > 5000) { sys.btnHoldMs = 0; resetWiFi(); }
  } else {
    sys.btnHoldMs = 0;
  }

  // WiFi watchdog
  if (sys.wifiOK && WiFi.status() != WL_CONNECTED) {
    Serial.println(F("WiFi lost — reconnecting"));
    sys.wifiOK = smartConnect();
    if (sys.wifiOK) { fbInit(); syncOffline(); }
  }

  // Enroll mode auto-timeout
  if (sys.enrollMode && millis() - sys.enrollStart > ENROLL_TIMEOUT_MS) {
    Serial.println(F("Enroll timeout"));
    exitEnrollMode();
  }

  // Firebase background tasks
  if (sys.wifiOK && sys.fbOK) {
    fbReceiveCommands();   // also handles enroll/attendance mode cmds
    fbSendTelemetry();
  }

  // RFID
  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) {
    delay(50);
    return;
  }

  String uid = getUID();
  uint32_t now = millis();

  // Cooldown — ignore same card
  if (uid == String(sys.lastUID) && (now - sys.lastScanMs) < COOLDOWN_MS) {
    rfid.PICC_HaltA();
    return;
  }
  uid.toCharArray(sys.lastUID, sizeof(sys.lastUID));
  sys.lastScanMs = now;

  // Route to enroll or attendance handler
  if (sys.enrollMode) {
    handleEnrollScan(uid);
  } else {
    if (sys.wifiOK) {
      handleAttendanceScan(uid);
    } else {
      saveOffline(uid);
      blink(PIN_LED_RED, 2);
      Serial.println(F("Offline — queued"));
    }
  }

  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
}


// ============================================================
// ENROLL MODE: triggered by Flutter → Firestore cmd_mode:"enroll"
// ============================================================
void enterEnrollMode() {
  sys.enrollMode  = true;
  sys.enrollStart = millis();
  Serial.println(F("## ENROLL MODE ##"));
  beep(2, 100);
  blink(PIN_LED_GREEN, 2);
}

void exitEnrollMode() {
  sys.enrollMode = false;
  Serial.println(F("## ATTENDANCE MODE ##"));
  beep(1, 300);

  // Clear enroll_uid so Flutter knows the session ended
  if (sys.fbOK) {
    FirebaseJson clr;
    clr.set("fields/enroll_uid/stringValue", "");
    Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "",
      "devices/esp32_main", clr.raw(), "enroll_uid");
  }
}

// Called when a card is scanned while in enroll mode
void handleEnrollScan(const String& uid) {
  Serial.println("Enroll scan: " + uid);

  // 1. Log to temp_scans with enroll flag (Flutter live feed)
  if (sys.fbOK) fbLogTempScan(uid, true);

  // 2. Write UID to devices/esp32_main → enroll_uid
  //    Flutter reads this field and links it to the student doc
  if (sys.fbOK) {
    fbSetEnrollUID(uid);
    Serial.println(F("enroll_uid written → waiting for Flutter to link"));
  }

  // 3. Feedback
  blink(PIN_LED_GREEN, 3);
  beep(3, 80);

  // 4. Auto-exit enroll mode after one card scan
  //    Flutter can re-trigger if needed for the next student
  exitEnrollMode();
}


// ============================================================
// ATTENDANCE SCAN
// ============================================================
void handleAttendanceScan(const String& uid) {
  Serial.println("\n── Scan: " + uid + " ──");
  beep(1, 30);

  // 1. Log temp_scan (Flutter live feed — always)
  if (sys.fbOK) fbLogTempScan(uid, false);

  // 2. Look up student in Firebase
  Student student;
  if (sys.fbOK) student = fbQueryStudent(uid);

  // 3. Unknown card
  if (!student.found) {
    Serial.println(F("Unknown — not enrolled in Firebase"));
    blink(PIN_LED_RED, 3);
    beep(3, 80);
    return;
  }

  // 4. Known student ─────────────────────────────────────────
  String ts     = nowIST();
  String action = (student.status == "Inside") ? "Exit" : "Entry";
  String newStatus = (action == "Entry") ? "Inside" : "Left";

  Serial.printf("Student: %s | %s | %s\n",
    student.name.c_str(), student.roll.c_str(), action.c_str());

  // 4a. First-ever scan → sync student row to Sheets (once only)
  if (!student.sheetSynced) {
    sheetsUpsertStudent(student);
    if (sys.fbOK) fbMarkSheetSynced(student);
  }

  // 4b. Mark attendance in Sheets
  sheetsMarkAttendance(student, action, ts);

  // 4c. Update Firebase student status
  if (sys.fbOK) fbUpdateStatus(student, newStatus);

  // 4d. Log Firebase attendance history
  if (sys.fbOK) fbLogAttendance(student, action);

  // 4e. Feedback
  if (action == "Entry") {
    Serial.println("✅ ENTRY: " + student.name);
    blink(PIN_LED_GREEN, 1);
    beep(1, 400);
  } else {
    Serial.println("✅ EXIT:  " + student.name);
    blink(PIN_LED_GREEN, 2);
    beep(2, 150);
  }
}


// ============================================================
// FIREBASE — INIT
// ============================================================
void fbInit() {
  Serial.println(F("Firebase init..."));
  fbConfig.api_key               = FIREBASE_API_KEY;
  fbAuth.user.email              = FIREBASE_USER_EMAIL;
  fbAuth.user.password           = FIREBASE_USER_PASSWORD;
  fbConfig.token_status_callback = tokenStatusCallback;

  Firebase.begin(&fbConfig, &fbAuth);
  Firebase.reconnectWiFi(true);

  uint32_t t0 = millis();
  while (!Firebase.ready() && millis() - t0 < 10000) delay(300);

  sys.fbOK = Firebase.ready();
  Serial.printf("Firebase: %s\n", sys.fbOK ? "OK" : "FAIL");
}


// ============================================================
// FIREBASE — LOG TEMP SCAN
// Collection: temp_scans
// Fields: uid, timestamp, isEnroll
// Flutter listens here in real time for both live feed + enroll
// ============================================================
void fbLogTempScan(const String& uid, bool isEnroll) {
  FirebaseJson doc;
  doc.set("fields/uid/stringValue",        uid.c_str());
  doc.set("fields/isEnroll/booleanValue",  isEnroll);
  doc.set("fields/timestamp/timestampValue", nowFirestore().c_str());

  if (!Firebase.Firestore.createDocument(&fbdo, FIREBASE_PROJECT_ID, "",
      "temp_scans", doc.raw()))
    Serial.println("temp_scan err: " + fbdo.errorReason());
  else
    Serial.println("temp_scan: " + uid);
}


// ============================================================
// FIREBASE — SET ENROLL UID
// Writes the scanned UID to devices/esp32_main → enroll_uid
// Flutter watches this field to know which card to link
// ============================================================
void fbSetEnrollUID(const String& uid) {
  FirebaseJson patch;
  patch.set("fields/enroll_uid/stringValue", uid.c_str());
  if (!Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "",
      "devices/esp32_main", patch.raw(), "enroll_uid"))
    Serial.println("enroll_uid err: " + fbdo.errorReason());
}


// ============================================================
// FIREBASE — QUERY STUDENT BY UID
// ============================================================
Student fbQueryStudent(const String& uid) {
  Student s;
  s.uid = uid;

  FirebaseJson query;
  query.set("structuredQuery/from/[0]/collectionId", "students");
  query.set("structuredQuery/where/fieldFilter/field/fieldPath", "uid");
  query.set("structuredQuery/where/fieldFilter/op",              "EQUAL");
  query.set("structuredQuery/where/fieldFilter/value/stringValue", uid.c_str());
  query.set("structuredQuery/limit", 1);

  if (!Firebase.Firestore.runQuery(&fbdo, FIREBASE_PROJECT_ID, "", query.raw())) {
    Serial.println("Query err: " + fbdo.errorReason());
    return s;
  }

  String p = fbdo.payload();
  if (p == "[]" || p.length() < 10) return s;

  // Helper: extract stringValue for a named field
  auto str = [&](const String& field) -> String {
    String needle = "\"" + field + "\":{\"stringValue\":\"";
    int i = p.indexOf(needle);
    if (i == -1) return "";
    int start = i + needle.length();
    return p.substring(start, p.indexOf("\"", start));
  };

  // Helper: extract booleanValue for a named field
  auto boolean = [&](const String& field) -> bool {
    String needle = "\"" + field + "\":{\"booleanValue\":";
    int i = p.indexOf(needle);
    if (i == -1) return false;
    int start = i + needle.length();
    return p.substring(start, start + 4) == "true";
  };

  s.name        = str("name");
  s.roll        = str("roll");
  s.cls         = str("class");   // match your Firestore field name
  s.phone       = str("phone");
  s.status      = str("status");
  s.sheetSynced = boolean("sheetSynced");
  if (s.status.isEmpty()) s.status = "Left";

  // Extract document ID from full resource path
  int pi = p.indexOf("\"name\":\"");
  if (pi != -1) {
    int ps   = pi + 8;
    String path = p.substring(ps, p.indexOf("\"", ps));
    s.docId = path.substring(path.lastIndexOf('/') + 1);
  }

  s.found = !s.docId.isEmpty() && !s.name.isEmpty();
  return s;
}


// ============================================================
// FIREBASE — MARK SHEET SYNCED
// Sets sheetSynced:true on the student doc so we never
// call upsert_student again for this student
// ============================================================
void fbMarkSheetSynced(const Student& s) {
  FirebaseJson patch;
  patch.set("fields/sheetSynced/booleanValue", true);
  if (!Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "",
      ("students/" + s.docId).c_str(), patch.raw(), "sheetSynced"))
    Serial.println("sheetSynced patch err: " + fbdo.errorReason());
  else
    Serial.println(F("sheetSynced → true"));
}


// ============================================================
// FIREBASE — UPDATE STUDENT STATUS  (Inside / Left)
// ============================================================
void fbUpdateStatus(const Student& s, const String& newStatus) {
  FirebaseJson patch;
  patch.set("fields/status/stringValue", newStatus.c_str());
  if (!Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "",
      ("students/" + s.docId).c_str(), patch.raw(), "status"))
    Serial.println("status patch err: " + fbdo.errorReason());
  else
    Serial.println("Firebase status → " + newStatus);
}


// ============================================================
// FIREBASE — LOG ATTENDANCE HISTORY
// Collection: attendance
// ============================================================
void fbLogAttendance(const Student& s, const String& action) {
  FirebaseJson doc;
  doc.set("fields/studentId/stringValue",   s.docId.c_str());
  doc.set("fields/studentName/stringValue", s.name.c_str());
  doc.set("fields/studentRoll/stringValue", s.roll.c_str());
  doc.set("fields/uid/stringValue",         s.uid.c_str());
  doc.set("fields/action/stringValue",      action.c_str());
  doc.set("fields/timestamp/timestampValue", nowFirestore().c_str());

  if (!Firebase.Firestore.createDocument(&fbdo, FIREBASE_PROJECT_ID, "",
      "attendance", doc.raw()))
    Serial.println("attendance log err: " + fbdo.errorReason());
  else
    Serial.println("Firebase attendance: " + action);
}


// ============================================================
// FIREBASE — TELEMETRY  (every 30 s)
// ============================================================
void fbSendTelemetry() {
  if (sys.lastTelemMs && millis() - sys.lastTelemMs < FB_TELEM_INTERVAL) return;
  sys.lastTelemMs = millis();

  FirebaseJson doc;
  doc.set("fields/firmware/stringValue",    "v9.0");
  doc.set("fields/mode/stringValue",        sys.enrollMode ? "enroll" : "attendance");
  doc.set("fields/wifi_ssid/stringValue",   WiFi.SSID().c_str());
  doc.set("fields/rssi/integerValue",       String(WiFi.RSSI()).c_str());
  doc.set("fields/uptime_sec/integerValue", String(millis() / 1000).c_str());
  doc.set("fields/last_ping/timestampValue", nowFirestore().c_str());

  if (!Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "",
      "devices/esp32_main", doc.raw(), ""))
    Serial.println("Telemetry err: " + fbdo.errorReason());
  else
    Serial.println(F("Telemetry OK"));
}


// ============================================================
// FIREBASE — RECEIVE COMMANDS  (poll every 3.5 s)
// Reads devices/esp32_main and acts on command fields
// ============================================================
void fbReceiveCommands() {
  if (sys.lastCmdMs && millis() - sys.lastCmdMs < FB_CMD_INTERVAL) return;
  sys.lastCmdMs = millis();

  if (!Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "",
      "devices/esp32_main")) return;

  String p = fbdo.payload();

  // ── cmd_reboot ─────────────────────────────────────────────
  if (p.indexOf("\"cmd_reboot\":{\"booleanValue\":true}") != -1) {
    Serial.println(F("CMD: REBOOT"));
    beep(3, 100);
    FirebaseJson clr; clr.set("fields/cmd_reboot/booleanValue", false);
    Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "",
      "devices/esp32_main", clr.raw(), "cmd_reboot");
    delay(500);
    ESP.restart();
  }

  // ── cmd_lock (hardware test) ───────────────────────────────
  if (p.indexOf("\"cmd_lock\":{\"booleanValue\":true}") != -1) {
    Serial.println(F("CMD: LOCK TEST"));
    blink(PIN_LED_RED, 4);
    beep(2, 500);
    FirebaseJson clr; clr.set("fields/cmd_lock/booleanValue", false);
    Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "",
      "devices/esp32_main", clr.raw(), "cmd_lock");
  }

  // ── cmd_mode ───────────────────────────────────────────────
  int modeIdx = p.indexOf("\"cmd_mode\":{\"stringValue\":\"");
  if (modeIdx != -1) {
    int vs = modeIdx + 27;
    String mode = p.substring(vs, p.indexOf("\"", vs));

    if (mode == "enroll" && !sys.enrollMode)      enterEnrollMode();
    else if (mode == "attendance" && sys.enrollMode) exitEnrollMode();

    // Clear the command so it doesn't re-trigger
    FirebaseJson clr; clr.set("fields/cmd_mode/stringValue", "");
    Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "",
      "devices/esp32_main", clr.raw(), "cmd_mode");
  }
}


// ============================================================
// GOOGLE SHEETS — GENERIC REQUEST
// ============================================================
String sheetsRequest(const String& params) {
  if (!sys.wifiOK || strlen(SCRIPT_URL) == 0) return "";

  static WiFiClientSecure client;
  client.setInsecure();

  String url = String(SCRIPT_URL) + "?" + params;
  Serial.println("Sheets: " + url);

  HTTPClient http;
  http.begin(client, url);
  http.setFollowRedirects(HTTPC_STRICT_FOLLOW_REDIRECTS);
  http.setTimeout(HTTP_TIMEOUT_MS);

  int    code = http.GET();
  String body = "";
  if (code > 0) {
    body = http.getString();
    Serial.printf("Sheets %d | %s\n", code, body.c_str());
  } else {
    Serial.printf("Sheets err: %s\n", http.errorToString(code).c_str());
  }
  http.end();
  return body;
}


// ============================================================
// GOOGLE SHEETS — UPSERT STUDENT  (called ONCE per student)
// Adds a row to the Students sheet if not already present.
// Your Apps Script: action=upsert_student
//   Check if row with uid exists → skip. Else → append.
// ============================================================
void sheetsUpsertStudent(const Student& s) {
  String params = "action=upsert_student"
    "&uid="   + s.uid                 +
    "&name="  + urlEncode(s.name)     +
    "&roll="  + urlEncode(s.roll)     +
    "&cls="   + urlEncode(s.cls)      +
    "&phone=" + urlEncode(s.phone);

  if (sheetsRequest(params).isEmpty())
    Serial.println(F("Sheets upsert failed"));
}


// ============================================================
// GOOGLE SHEETS — MARK ATTENDANCE
// Your Apps Script: action=attendance
//   Find/create today's row for uid. Write entry or exit time.
// ============================================================
void sheetsMarkAttendance(const Student& s, const String& action,
                          const String& ts) {
  String safeTs = ts; safeTs.replace(" ", "%20");

  String params = "action=attendance"
    "&uid="    + s.uid                 +
    "&name="   + urlEncode(s.name)     +
    "&roll="   + urlEncode(s.roll)     +
    "&action=" + action                +
    "&ts="     + safeTs;

  if (sheetsRequest(params).isEmpty()) {
    saveOffline(s.uid);   // retry on next reconnect
    Serial.println(F("Sheets attendance failed — queued"));
  }
}


// ============================================================
// OFFLINE QUEUE — SAVE
// ============================================================
void saveOffline(const String& uid) {
  File f = SPIFFS.open(OFFLINE_FILE, "a");
  if (f) {
    f.printf("%s,%s\n", uid.c_str(), nowIST().c_str());
    f.close();
    Serial.println("Offline queued: " + uid);
  }
}


// ============================================================
// OFFLINE QUEUE — SYNC ON RECONNECT
// Re-runs the full attendance flow for each queued scan.
// Scans that are still unknown in Firebase stay in the queue.
// ============================================================
void syncOffline() {
  if (!SPIFFS.exists(OFFLINE_FILE)) { Serial.println(F("No offline queue")); return; }

  File f = SPIFFS.open(OFFLINE_FILE, "r");
  if (!f) return;

  Serial.println(F("Syncing offline queue..."));

  // Read all lines into memory first so we can rewrite the file
  struct Entry { String uid; String ts; };
  Entry entries[50];   // max 50 queued scans (adjust if needed)
  int   total = 0;

  char line[40];
  while (f.available() && total < 50) {
    int len = f.readBytesUntil('\n', line, sizeof(line) - 1);
    line[len] = '\0';
    if (len == 0) continue;
    char* comma = strchr(line, ',');
    if (!comma) continue;
    *comma = '\0';
    entries[total].uid = String(line);
    entries[total].ts  = String(comma + 1);
    entries[total].ts.trim();
    total++;
  }
  f.close();

  int ok = 0, retry = 0;
  // Reopen for rewriting only the failed entries
  File fw = SPIFFS.open(OFFLINE_FILE, "w");

  for (int i = 0; i < total; i++) {
    String uid = entries[i].uid;
    String ts  = entries[i].ts;

    Student s;
    if (sys.fbOK) s = fbQueryStudent(uid);

    if (s.found) {
      String action    = (s.status == "Inside") ? "Exit" : "Entry";
      String newStatus = (action == "Entry") ? "Inside" : "Left";

      if (!s.sheetSynced) {
        sheetsUpsertStudent(s);
        if (sys.fbOK) fbMarkSheetSynced(s);
      }
      sheetsMarkAttendance(s, action, ts);
      if (sys.fbOK) fbUpdateStatus(s, newStatus);
      if (sys.fbOK) fbLogAttendance(s, action);
      ok++;
    } else {
      // Still unknown — keep in queue
      if (fw) fw.printf("%s,%s\n", uid.c_str(), ts.c_str());
      retry++;
    }
    delay(400);
  }

  if (fw) fw.close();
  if (retry == 0) SPIFFS.remove(OFFLINE_FILE);

  Serial.printf("Sync done: ok=%d queued=%d\n", ok, retry);
  if (ok > 0) blink(PIN_LED_GREEN, 2);
}


// ============================================================
// WIFI
// ============================================================
bool smartConnect() {
  Serial.println(F("\n── WiFi ──"));
  WiFi.mode(WIFI_STA);
  delay(100);

  for (uint8_t k = 0; k < KNOWN_NETWORK_COUNT; k++) {
    if (!KNOWN_NETWORKS[k].ssid || !strlen(KNOWN_NETWORKS[k].ssid)) continue;
    Serial.printf("Trying %s\n", KNOWN_NETWORKS[k].ssid);
    WiFi.disconnect(); delay(200);
    WiFi.begin(KNOWN_NETWORKS[k].ssid, KNOWN_NETWORKS[k].pass);

    uint32_t t0 = millis();
    while (millis() - t0 < WIFI_ATTEMPT_MS) {
      if (WiFi.status() == WL_CONNECTED) break;
      if (WiFi.status() == WL_NO_SSID_AVAIL) break;
      delay(500); Serial.print('.');
    }
    Serial.println();

    if (WiFi.status() == WL_CONNECTED) {
      Serial.printf("✅ %s | %s\n",
        KNOWN_NETWORKS[k].ssid, WiFi.localIP().toString().c_str());
      blink(PIN_LED_GREEN, 2); delay(800);
      return true;
    }
    WiFi.disconnect(); delay(200);
  }

  Serial.println(F("All failed → AP"));
  return launchAP();
}

bool launchAP() {
  WiFi.mode(WIFI_AP);
  WiFi.softAP(AP_NAME);
  Serial.printf("AP: %s | 192.168.4.1\n", AP_NAME);
  beep(2, 100);
  uint32_t t0 = millis();
  while (millis() - t0 < 60000) {
    if (WiFi.softAPgetStationNum() > 0) { delay(2000); break; }
    delay(500); Serial.print('.');
  }
  Serial.println(F("\nAP timeout — offline"));
  WiFi.mode(WIFI_STA);
  blink(PIN_LED_RED, 2); delay(1500);
  return false;
}

void resetWiFi() {
  Serial.println(F("Reset WiFi — rebooting"));
  beep(3, 150); delay(1000);
  WiFi.disconnect(); delay(300);
  ESP.restart();
}


// ============================================================
// UTILITIES
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

// IST timestamp for Sheets:  "YYYY-MM-DD HH:MM:SS"
String nowIST() {
  struct tm t;
  char buf[20] = "";
  if (getLocalTime(&t)) strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", &t);
  return String(buf);
}

// RFC3339 UTC timestamp for Firestore
String nowFirestore() {
  struct tm t;
  char buf[30] = "2026-01-01T00:00:00Z";
  if (getLocalTime(&t)) strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &t);
  return String(buf);
}

// Percent-encode a string for URL query params
String urlEncode(const String& s) {
  String out = "";
  for (int i = 0; i < (int)s.length(); i++) {
    char c = s[i];
    if (isAlphaNumeric(c) || c=='-' || c=='_' || c=='.' || c=='~') {
      out += c;
    } else {
      char hex[4]; snprintf(hex, sizeof(hex), "%%%02X", (uint8_t)c);
      out += hex;
    }
  }
  return out;
}

void beep(uint8_t n, uint16_t ms) {
  for (uint8_t i = 0; i < n; i++) {
    digitalWrite(PIN_BUZZER, HIGH); delay(ms);
    digitalWrite(PIN_BUZZER, LOW);
    if (i < n-1) delay(60);
  }
}

void blink(uint8_t pin, uint8_t n) {
  for (uint8_t i = 0; i < n; i++) {
    digitalWrite(pin, HIGH); delay(250);
    digitalWrite(pin, LOW);
    if (i < n-1) delay(80);
  }
}
