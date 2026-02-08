#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <Preferences.h>
#include <time.h>

// Install libraries in Arduino IDE:
// - Firebase_ESP_Client by Mobizt
// - ArduinoJson

#define WIFI_SSID       "Extender"
#define WIFI_PASSWORD   "12345678"

#define API_KEY         "AIzaSyDOzLV01C_s6W0d1TTcGaGxSifgFanKUbo"
#define DATABASE_URL    "https://rebike-30829-default-rtdb.firebaseio.com/"

// Use a dedicated Firebase Auth user for the ESP32 device
#define USER_EMAIL      "device1@re.com"
#define USER_PASSWORD   "device1"

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
    Serial.print("WiFi status: ");
    Serial.println(WiFi.status());
  }
  Serial.print("WiFi connected. IP: ");
  Serial.println(WiFi.localIP());
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

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("Booting...");
  pinMode(SENSOR_PIN, INPUT);

  String savedSsid, savedPass;
  loadProvisionedWiFi(savedSsid, savedPass);

  Serial.println("WiFi connect start");
  if (savedSsid.length() > 0) {
    connectWiFi(savedSsid.c_str(), savedPass.c_str());
  } else {
    connectWiFi(WIFI_SSID, WIFI_PASSWORD);
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
      Serial.println("New WiFi provision detected. Saving and rebooting...");
      saveProvisionedWiFi(newSsid, newPass);
      ESP.restart();
    }
  } else {
    Serial.print("Provision read error: ");
    Serial.println(fbdo.errorReason());
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

  delay(100);
}
