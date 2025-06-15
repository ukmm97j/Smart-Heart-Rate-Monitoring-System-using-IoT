#include <SoftwareSerial.h>
#include <WiFiEsp.h>
#include <LiquidCrystal_I2C.h>

// ===== LCD Display =====
LiquidCrystal_I2C lcd(0x27, 16, 2);

// ===== Pins =====
const int pulsePin = A0;
const int switchPin = 6;

// ===== WiFi & ThingSpeak =====
char ssid[] = "m97";
char pass[] = "10101010";
unsigned long channelID = 2978406;
String writeAPIKey = "2B4T0HOR6XEDH8XQ";
char server[] = "api.thingspeak.com";
WiFiEspClient client;
int status = WL_IDLE_STATUS;

// ===== ESP-01 Serial Connection =====
SoftwareSerial espSerial(2, 3); // RX, TX

// ===== Timer =====
const unsigned long measureDuration = 25000;

void setup() {
  Serial.begin(9600);
  espSerial.begin(9600);
  WiFi.init(&espSerial);

  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Connecting WiFi");

  pinMode(switchPin, INPUT_PULLUP);
  pinMode(pulsePin, INPUT);

  while (status != WL_CONNECTED) {
    Serial.print("Connecting to WiFi...");
    status = WiFi.begin(ssid, pass);
    delay(5000);
  }

  Serial.println("Connected to WiFi");

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("WiFi Connected");
  delay(2000);
}

void loop() {
  if (digitalRead(switchPin) == LOW) {
    measureAndSend();
  } else {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Switch is OFF");
    delay(1000);
  }
}

void measureAndSend() {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Place Finger...");
  delay(2000);

  long total = 0;
  int samples = 0;
  int seconds = measureDuration / 1000;

  for (int i = 0; i < seconds; i++) {
    if (digitalRead(switchPin) == HIGH) {
      lcd.clear();
      lcd.print("Interrupted");
      delay(2000);
      return;
    }

    int raw = analogRead(pulsePin);
    int sum = 0;
for (int j = 0; j < 5; j++) {
  sum += analogRead(pulsePin);
  delay(5);
}
int avgRaw = sum / 5;
int bpm = map(avgRaw, 500, 800, 60, 140); 

    total += bpm;
    samples++;

    lcd.setCursor(0, 1);
    lcd.print("Countdown: " + String(seconds - i) + "s ");
    delay(1000);
  }

  int avgBPM = total / samples;
  String activity = classifyActivity(avgBPM);
  int activityCode = getActivityCode(activity);
  int alertCode = (avgBPM > 99) ? 1 : 0;

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("BPM: " + String(avgBPM));
  lcd.setCursor(0, 1);
  lcd.print(activity);
  delay(3000);

  sendToThingSpeak(avgBPM, activityCode, alertCode);

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Thank you!");
  delay(2000);
}

void sendToThingSpeak(int bpm, int activityCode, int alertCode) {
  if (client.connect(server, 80)) {
    String url = "/update?api_key=" + writeAPIKey +
                 "&field1=" + String(bpm) +
                 "&field2=" + String(activityCode) +
                 "&field4=" + String(alertCode);

    client.print("GET " + url + " HTTP/1.1\r\n");
    client.print("Host: " + String(server) + "\r\n");
    client.print("Connection: close\r\n\r\n");
    client.stop();

    Serial.println("✔ Data sent: BPM=" + String(bpm) + " | Act=" + String(activityCode) + " | Alert=" + String(alertCode));
  } else {
    Serial.println("❌ Failed to connect to ThingSpeak.");
  }
}

String classifyActivity(int bpm) {
  if (bpm < 80) return "Rest";
  else if (bpm <= 110) return "Work";
  else return "Exercise";
}

int getActivityCode(String activity) {
  if (activity == "Rest") return 1;
  if (activity == "Work") return 2;
  if (activity == "Exercise") return 3;
  return 0;
}
