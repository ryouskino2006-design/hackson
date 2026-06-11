#define DECODE_NEC
#include <IRremote.hpp>
#define BAUD 921600 // ボーレート（速め）
#define PIN 0 // A0 アナログ出⼒
#define RESOLUTION 10 // 量⼦化10bit

const int CHILD_ID = 0;
const int PIN_IR_RECV = 2;
const int LED_INDICATOR = 13;
const int melodyLength = 29;

// 楽譜データ（木下さん作成の資産をそのまま維持）
String melody[] = {
  "C4", "D4", "E4", "F4","E4","D4","C4",
  "E4","F4","G4","A4","G4","F4","E4",
  "C4","C4","C4","C4",
  "C4","C4","D4","D4","E4","E4","F4","F4","E4","D4","C4"
};

// ★duration（長さ）のみ、不整合を防ぐためご指摘通り削除しました

float startTime[]  = {
  0.0f, 0.5f, 1.0f, 1.5f, 2.0f, 2.5f, 3.0f,      
  4.0f, 4.5f, 5.0f, 5.5f, 6.0f, 6.5f, 7.0f,      
  8.0f, 9.0f, 10.0f, 11.0f,                      
  12.0f, 12.25f, 12.5f, 12.75f, 13.0f, 13.25f, 13.5f, 13.75f, 
  14.0f, 14.5f, 15.0f
};

float amplitude[]  = {
  0.8f, 0.5f, 0.5f, 0.5f, 0.5f, 0.5f, 0.5f, 
  0.8f, 0.5f, 0.5f, 0.5f, 0.5f, 0.5f, 0.5f, 
  0.7f, 0.7f, 0.7f, 0.7f,                  
  0.3f, 0.3f, 0.3f, 0.3f, 0.3f, 0.3f, 0.3f, 0.3f,
  0.6f, 0.8f, 1.0f
};

void setup() {
  Serial.begin(BAUD);
  IrReceiver.begin(PIN_IR_RECV);
  pinMode(LED_INDICATOR, OUTPUT);
}

void loop() {
  if (IrReceiver.decode()) {
    if (IrReceiver.decodedIRData.protocol == NEC) {
      int address = (int)IrReceiver.decodedIRData.address;
      bool accept = (CHILD_ID < 0) ? (address == 0) : (address == CHILD_ID);
      
      if (accept) {
        uint8_t command = (uint8_t)IrReceiver.decodedIRData.command;
        if (command > 0) {
          digitalWrite(LED_INDICATOR, HIGH); // 受信確認LEDを点灯
          sendMelody();                      // Processingへ楽譜データを送信
        } else {
          digitalWrite(LED_INDICATOR, LOW);
        }
      }
    } 
    IrReceiver.resume();
  }
}

// 【修正】durationの出力を無くし、「音名:開始時間:音量」で送信する
void sendMelody(){
  for(int i = 0; i < melodyLength; i++){
    Serial.print(melody[i]);
    Serial.print(":");
    // duration[i] の出力を削除
    Serial.print(startTime[i]);
    Serial.print(":");
    Serial.print(amplitude[i]);

    if(i < 28){
      Serial.print(",");
    }
  }
  Serial.println();
}

// 【修正】倍速時（startTimeを半分にする）
void sendMelodyDouble(){
  for(int i = 0; i < melodyLength; i++){
    Serial.print(melody[i]);
    Serial.print(":");
    // durationの出力を削除
    Serial.print(startTime[i] * 0.5f); 
    Serial.print(":");
    Serial.print(amplitude[i]);
    if(i < 28) Serial.print(",");
  }
  Serial.println();
}

// 【修正】半速時（startTimeを2倍にする）
void sendMelodyHalf(){
  for(int i = 0; i < melodyLength; i++){
    Serial.print(melody[i]);
    Serial.print(":");
    // durationの出力を削除
    Serial.print(startTime[i] * 2.0f); 
    Serial.print(":");
    Serial.print(amplitude[i]);
    if(i < 28) Serial.print(",");
  }
  Serial.println();
}
