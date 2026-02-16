#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <time.h>
#include <TinyGPS++.h>
#include <esp_sleep.h>

// Libraries:
// - Firebase_ESP_Client by Mobizt
// - TinyGPSPlus by Mikal Hart

#define WIFI_SSID       "TharunKrishna_PC"
#define WIFI_PASSWORD   "12345678"

#define API_KEY         "AIzaSyDOzLV01C_s6W0d1TTcGaGxSifgFanKUbo"
#define DATABASE_URL    "https://rebike-30829-default-rtdb.firebaseio.com/"

// Dedicated Firebase user for ESP32
#define USER_EMAIL      "device1@re.com"
#define USER_PASSWORD   "device1"

#define SENSOR_PIN      27
#define MOTION_COOLDOWN_MS 3000

#define GPS_RX_PIN      35
#define GPS_TX_PIN      32
#define GPS_BAUD        9600
#define GPS_UPDATE_MS   2000

// Deep sleep mode:
// 1 = enabled (wake on vibration pin)
// 0 = disabled (continuous mode)
#define ENABLE_DEEP_SLEEP 1

// If enabled, ESP sleeps while armed and only wakes on vibration.
// App will show offline while sleeping (expected).
#define SLEEP_WHEN_ARMED_ONLY 1

#define HEARTBEAT_INTERVAL_MS 5000
#define ALERT_SEND_RETRIES 5
#define ALERT_RETRY_DELAY_MS 800
#define ARMED_POLL_INTERVAL_MS 3000

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
TinyGPSPlus gps;
HardwareSerial gpsSerial(2);

unsigned long lastMotionMs = 0;
unsigned long lastGpsUpdateMs = 0;
unsigned long lastHeartbeatMs = 0;
unsigned long lastArmedPollMs = 0;
String deviceUid = "";
bool trackingActive = false;

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
  while (now < 1700000000) {
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

bool readArmed(bool &armed) {
  if (!Firebase.RTDB.getBool(&fbdo, "/system/armed")) {
    Serial.print("Read armed error: ");
    Serial.println(fbdo.errorReason());
    return false;
  }
  armed = fbdo.boolData();
  return true;
}

bool writeAlertPayload() {
  const long nowEpoch = nowEpochSeconds();
  for (int i = 0; i < ALERT_SEND_RETRIES; i++) {
    const bool alertOk = Firebase.RTDB.setBool(&fbdo, "/system/alert", true);
    const bool motionOk = Firebase.RTDB.setInt(&fbdo, "/system/lastMotion", nowEpoch);
    const bool seenOk = Firebase.RTDB.setInt(&fbdo, "/system/lastSeen", nowEpoch);
    if (alertOk && motionOk && seenOk) {
      Serial.println("Alert payload sent successfully");
      return true;
    }
    Serial.print("Alert payload retry ");
    Serial.println(i + 1);
    delay(ALERT_RETRY_DELAY_MS);
  }
  Serial.print("Alert payload failed: ");
  Serial.println(fbdo.errorReason());
  return false;
}

void configureWakeSource() {
  // Wake when SENSOR_PIN goes HIGH (matching current motion logic).
  esp_sleep_enable_ext0_wakeup((gpio_num_t)SENSOR_PIN, 1);
}

void goDeepSleepNow(const char* reason) {
  Serial.print("Entering deep sleep: ");
  Serial.println(reason);
  Serial.flush();
  delay(100);
  esp_deep_sleep_start();
}

void updateGps() {
  while (gpsSerial.available() > 0) {
    gps.encode(gpsSerial.read());
  }

  const unsigned long nowMs = millis();
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

  if (!connectWiFi(WIFI_SSID, WIFI_PASSWORD, 20000)) {
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

  const long nowEpoch = nowEpochSeconds();
  Firebase.RTDB.setInt(&fbdo, "/system/lastSeen", nowEpoch);

#if ENABLE_DEEP_SLEEP
  configureWakeSource();
  const esp_sleep_wakeup_cause_t wakeReason = esp_sleep_get_wakeup_cause();
  bool armed = false;
  readArmed(armed);

  if (wakeReason == ESP_SLEEP_WAKEUP_EXT0) {
    Serial.println("Wake reason: vibration");
    if (armed) {
      if (writeAlertPayload()) {
        trackingActive = true;
        Serial.println("Tracking mode active: streaming GPS until disarmed");
      } else {
        Serial.println("Staying awake to retry alert in loop");
      }
    } else {
      goDeepSleepNow("woke by vibration but system disarmed");
    }
  } else {
    Serial.print("Wake reason: ");
    Serial.println((int)wakeReason);
    if (SLEEP_WHEN_ARMED_ONLY && armed) {
      goDeepSleepNow("armed at boot; waiting for vibration");
    }
  }
#endif
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi(WIFI_SSID, WIFI_PASSWORD, 10000);
  }

  const unsigned long nowMs = millis();
  if ((nowMs - lastHeartbeatMs) >= HEARTBEAT_INTERVAL_MS) {
    lastHeartbeatMs = nowMs;
    if (Firebase.RTDB.setInt(&fbdo, "/system/lastSeen", nowEpochSeconds())) {
      Serial.println("Heartbeat updated");
    } else {
      Serial.print("Heartbeat error: ");
      Serial.println(fbdo.errorReason());
    }
  }

  int motion = digitalRead(SENSOR_PIN);
  if (motion == HIGH && (nowMs - lastMotionMs) > MOTION_COOLDOWN_MS) {
    lastMotionMs = nowMs;

    bool armed = false;
    if (readArmed(armed) && armed) {
      if (writeAlertPayload()) {
        Serial.println("Motion detected -> alert true");
#if ENABLE_DEEP_SLEEP
        trackingActive = true;
        Serial.println("Tracking mode active: streaming GPS until disarmed");
#endif
      }
    }
  }

  if (trackingActive) {
    updateGps();
  }

#if ENABLE_DEEP_SLEEP
  if ((nowMs - lastArmedPollMs) >= ARMED_POLL_INTERVAL_MS) {
    lastArmedPollMs = nowMs;
    bool armed = false;
    if (readArmed(armed)) {
      if (!armed) {
        trackingActive = false;
        goDeepSleepNow("disarmed; back to sleep");
      }
    }
  }
#endif

  delay(100);
}
