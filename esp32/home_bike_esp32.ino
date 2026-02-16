#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <time.h>
#include <TinyGPS++.h>

// Install libraries in Arduino IDE:
// - Firebase_ESP_Client by Mobizt
// - ArduinoJson
// - TinyGPSPlus by Mikal Hart

#define WIFI_SSID       "TharunKrishna_PC"
#define WIFI_PASSWORD   "12345678"

#define API_KEY         "AIzaSyDOzLV01C_s6W0d1TTcGaGxSifgFanKUbo"
#define DATABASE_URL    "https://rebike-30829-default-rtdb.firebaseio.com/"

// Use a dedicated Firebase Auth user for the ESP32 device
#define USER_EMAIL      "device1@re.com"
#define USER_PASSWORD   "device1"

#define SENSOR_PIN      27
#define MOTION_COOLDOWN_MS 3000
#define GPS_RX_PIN      35
#define GPS_TX_PIN      32
#define GPS_BAUD        9600
#define GPS_UPDATE_MS   2000
#define ENABLE_REMOTE_PROVISIONING 0

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
TinyGPSPlus gps;
HardwareSerial gpsSerial(2);

unsigned long lastMotionMs = 0;
unsigned long lastGpsUpdateMs = 0;
String deviceUid = "";

void scanAndPrintVisibleSsids() {
  Serial.println("Scanning nearby WiFi networks...");
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  delay(100);

  const int n = WiFi.scanNetworks(false, true);
  if (n <= 0) {
    Serial.println("No WiFi networks found");
    return;
  }

  Serial.print("Found ");
  Serial.print(n);
  Serial.println(" networks:");
  for (int i = 0; i < n; i++) {
    Serial.print("  [");
    Serial.print(i);
    Serial.print("] SSID=");
    Serial.print(WiFi.SSID(i));
    Serial.print(" RSSI=");
    Serial.print(WiFi.RSSI(i));
    Serial.print("dBm CH=");
    Serial.print(WiFi.channel(i));
    Serial.print(" ENC=");
    Serial.println(WiFi.encryptionType(i));
  }
  WiFi.scanDelete();
}

void onWiFiEvent(WiFiEvent_t event, WiFiEventInfo_t info) {
  if (event == ARDUINO_EVENT_WIFI_STA_DISCONNECTED) {
    Serial.print("WiFi disconnected. reason=");
    Serial.println(info.wifi_sta_disconnected.reason);
  }
}

bool connectWiFi(const char* ssid, const char* password, unsigned long timeoutMs = 20000) {
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  WiFi.setAutoReconnect(true);
  WiFi.begin(ssid, password);
  const unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED) {
    delay(300);
    Serial.print("WiFi status: ");
    Serial.println(WiFi.status());
    if (millis() - start > timeoutMs) {
      Serial.println("WiFi connect timeout");
      return false;
    }
  }
  Serial.print("WiFi connected. IP: ");
  Serial.println(WiFi.localIP());
  return true;
}

void syncTime() {
  configTime(0, 0, "time.google.com", "pool.ntp.org", "time.cloudflare.com");
  time_t now = time(nullptr);
  int tries = 0;
  while (now < 1700000000) { // wait for valid epoch
    delay(500);
    now = time(nullptr);
    tries++;
    Serial.print("NTP sync attempt ");
    Serial.print(tries);
    Serial.print(" epoch=");
    Serial.println((long)now);
    if (tries >= 40) {
      Serial.println("NTP sync failed");
      break;
    }
  }
  Serial.print("NTP epoch final=");
  Serial.println((long)now);
}

long nowEpochSeconds() {
  return (long)time(nullptr);
}

void updateGps() {
  while (gpsSerial.available() > 0) {
    gps.encode(gpsSerial.read());
  }

  unsigned long nowMs = millis();
  if ((nowMs - lastGpsUpdateMs) < GPS_UPDATE_MS) {
    return;
  }
  lastGpsUpdateMs = nowMs;

  if (!gps.location.isValid()) {
    Serial.println("GPS: waiting for fix");
    return;
  }

  const double lat = gps.location.lat();
  const double lng = gps.location.lng();
  const long fixTime = nowEpochSeconds();

  Firebase.RTDB.setDouble(&fbdo, "/system/gps/lat", lat);
  Firebase.RTDB.setDouble(&fbdo, "/system/gps/lng", lng);
  Firebase.RTDB.setInt(&fbdo, "/system/gps/fixTime", fixTime);

  if (gps.altitude.isValid()) {
    Firebase.RTDB.setDouble(&fbdo, "/system/gps/altMeters", gps.altitude.meters());
  }
  if (gps.satellites.isValid()) {
    Firebase.RTDB.setInt(&fbdo, "/system/gps/sats", gps.satellites.value());
  }
  if (gps.hdop.isValid()) {
    Firebase.RTDB.setDouble(&fbdo, "/system/gps/hdop", gps.hdop.hdop());
  }

  Serial.print("GPS fix: ");
  Serial.print(lat, 6);
  Serial.print(", ");
  Serial.println(lng, 6);
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("Booting...");
  WiFi.onEvent(onWiFiEvent);
  pinMode(SENSOR_PIN, INPUT);
  gpsSerial.begin(GPS_BAUD, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);

  scanAndPrintVisibleSsids();
  Serial.println("WiFi connect start");
  bool wifiConnected = connectWiFi(WIFI_SSID, WIFI_PASSWORD, 20000);

  if (!wifiConnected) {
    Serial.println("No WiFi available. Rebooting in 5s...");
    delay(5000);
    ESP.restart();
  }

  Serial.println("Firebase begin");
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;

  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;

  Firebase.reconnectWiFi(true);
  Firebase.begin(&config, &auth);

  Serial.println("Sync time");
  syncTime();

  Serial.print("Waiting for Firebase auth");
  while (auth.token.uid == "") {
    delay(200);
    Serial.print(".");
  }
  Serial.println();
  Serial.print("Firebase UID: ");
  Serial.println(auth.token.uid.c_str());
  deviceUid = auth.token.uid.c_str();
  Firebase.RTDB.setString(&fbdo, "/system/deviceUid", deviceUid);
  Firebase.RTDB.setBool(&fbdo, "/system/alert", false);
}

void loop() {
  // Heartbeat
  if (Firebase.RTDB.setInt(&fbdo, "/system/lastSeen", nowEpochSeconds())) {
    Serial.println("Heartbeat updated");
  } else {
    Serial.print("Heartbeat error: ");
    Serial.println(fbdo.errorReason());
  }

#if ENABLE_REMOTE_PROVISIONING
  // Check provisioning updates
  if (Firebase.RTDB.getString(&fbdo, "/provisioning/ssid")) {
    String newSsid = fbdo.to<const char*>();
    String newPass = "";
    if (Firebase.RTDB.getString(&fbdo, "/provisioning/password")) {
      newPass = fbdo.to<const char*>();
    }

    if (newSsid.length() > 0) {
      Serial.println("Remote provisioning update detected. Rebooting...");
      ESP.restart();
    }
  } else {
    Serial.print("Provision read error: ");
    Serial.println(fbdo.errorReason());
  }
#endif

  int motion = digitalRead(SENSOR_PIN);
  unsigned long now = millis();

  if (motion == HIGH && (now - lastMotionMs) > MOTION_COOLDOWN_MS) {
    lastMotionMs = now;

    bool armed = false;
    if (Firebase.RTDB.getBool(&fbdo, "/system/armed")) {
      armed = fbdo.boolData();
    }

    if (armed) {
      if (Firebase.RTDB.setBool(&fbdo, "/system/alert", true)) {
        Serial.println("Alert set true");
      } else {
        Serial.print("Alert write error: ");
        Serial.println(fbdo.errorReason());
      }
      if (Firebase.RTDB.setInt(&fbdo, "/system/lastMotion", nowEpochSeconds())) {
        Serial.println("LastMotion updated");
      } else {
        Serial.print("LastMotion error: ");
        Serial.println(fbdo.errorReason());
      }
      Serial.println("Motion detected -> alert true");
    }
  }

  updateGps();
  delay(100);
}
