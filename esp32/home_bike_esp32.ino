#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <Preferences.h>
#include <time.h>

// Install libraries in Arduino IDE:
// - Firebase_ESP_Client by Mobizt
// - ArduinoJson

#define WIFI_SSID       "YOUR_WIFI"
#define WIFI_PASSWORD   "YOUR_PASS"

#define API_KEY         "YOUR_FIREBASE_WEB_API_KEY"
#define DATABASE_URL    "https://rebike-30829-default-rtdb.firebaseio.com/"

// Use a dedicated Firebase Auth user for the ESP32 device
#define USER_EMAIL      "YOUR_DEVICE_ACCOUNT_EMAIL"
#define USER_PASSWORD   "YOUR_DEVICE_PASSWORD"

#define SENSOR_PIN      27
#define MOTION_COOLDOWN_MS 3000

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
Preferences prefs;

unsigned long lastMotionMs = 0;
String deviceUid = "";

void connectWiFi(const char* ssid, const char* password) {
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(300);
  }
}

void loadProvisionedWiFi(String &ssid, String &pass) {
  prefs.begin("wifi", true);
  ssid = prefs.getString("ssid", "");
  pass = prefs.getString("pass", "");
  prefs.end();
}

void saveProvisionedWiFi(const String &ssid, const String &pass) {
  prefs.begin("wifi", false);
  prefs.putString("ssid", ssid);
  prefs.putString("pass", pass);
  prefs.end();
}

void syncTime() {
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  time_t now = time(nullptr);
  while (now < 1700000000) { // wait for valid epoch
    delay(500);
    now = time(nullptr);
  }
}

long nowMillis() {
  time_t now = time(nullptr);
  return ((long)now) * 1000L;
}

void setup() {
  Serial.begin(115200);
  pinMode(SENSOR_PIN, INPUT);

  String savedSsid, savedPass;
  loadProvisionedWiFi(savedSsid, savedPass);

  if (savedSsid.length() > 0) {
    connectWiFi(savedSsid.c_str(), savedPass.c_str());
  } else {
    connectWiFi(WIFI_SSID, WIFI_PASSWORD);
  }

  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;

  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;

  Firebase.reconnectWiFi(true);
  Firebase.begin(&config, &auth);

  syncTime();

  while (auth.token.uid == "") {
    delay(200);
  }
  deviceUid = auth.token.uid.c_str();
  Firebase.RTDB.setString(&fbdo, "/system/deviceUid", deviceUid);
  Firebase.RTDB.setBool(&fbdo, "/system/alert", false);
}

void loop() {
  // Heartbeat
  Firebase.RTDB.setInt(&fbdo, "/system/lastSeen", nowMillis());

  // Check provisioning updates
  if (Firebase.RTDB.getString(&fbdo, "/provisioning/ssid")) {
    String newSsid = fbdo.to<const char*>();
    String newPass = "";
    if (Firebase.RTDB.getString(&fbdo, "/provisioning/password")) {
      newPass = fbdo.to<const char*>();
    }

    String currentSsid, currentPass;
    loadProvisionedWiFi(currentSsid, currentPass);

    if (newSsid.length() > 0 && (newSsid != currentSsid || newPass != currentPass)) {
      saveProvisionedWiFi(newSsid, newPass);
      ESP.restart();
    }
  }

  int motion = digitalRead(SENSOR_PIN);
  unsigned long now = millis();

  if (motion == HIGH && (now - lastMotionMs) > MOTION_COOLDOWN_MS) {
    lastMotionMs = now;

    bool armed = false;
    if (Firebase.RTDB.getBool(&fbdo, "/system/armed")) {
      armed = fbdo.boolData();
    }

    if (armed) {
      Firebase.RTDB.setBool(&fbdo, "/system/alert", true);
      Firebase.RTDB.setInt(&fbdo, "/system/lastMotion", nowMillis());
      Serial.println("Motion detected -> alert true");
    }
  }

  delay(100);
}
