#define DECODE_NEC
#include <IRremote.hpp>
#define BAUD 921600 // ボーレート（速め）
#define PIN 0 // A0 アナログ出⼒
#define RESOLUTION 10 // 量⼦化10bit

const int CHILD_ID = 0;
const int PIN_IR_RECV = 2;
const int LED_INDICATOR = 13;
const int melodyLength = 29;

// 楽譜データ
String melody[] = {
  "C4", "D4", "E4", "F4","E4","D4","C4",
  "E4","F4","G4","A4","G4","F4","E4",
  "C4","C4","C4","C4",
  "C4","C4","D4","D4","E4","E4","F4","F4","E4","D4","C4"
};

// ★duration（長さ）をしっかり復活させました！
float duration[] = {
  0.4f, 0.4f,0.4f,0.4f,0.4f,0.4f,0.4f,
  0.4f,0.4f,0.4f,0.4f,0.4f,0.4f,0.4f,
  0.4f,0.4f,0.4f,0.4f,
  0.2f,0.2f,0.2f,0.2f,0.2f,0.2f,0.2f,0.2f,0.4f,0.4f,0.4f,
};

// ★ご指摘の通り、不整合の元になる startTime（開始時間）をバッサリ削除しました

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

// 【修正】startTimeの出力を無くし、「音名:長さ:音量」で送信する
void sendMelody(){
  for(int i = 0; i < melodyLength; i++){
    Serial.print(melody[i]);
    Serial.print(":");
    Serial.print(duration[i]); // durationの出力を復活
    Serial.print(":");
    // startTime[i] の出力を削除
    Serial.print(amplitude[i]);

    if(i < 28){
      Serial.print(",");
    }
  }
  Serial.println();
}

// 【修正】倍速時（durationを半分にする仕様に変更）
void sendMelodyDouble(){
  for(int i = 0; i < melodyLength; i++){
    Serial.print(melody[i]);
    Serial.print(":");
    Serial.print(duration[i] * 0.5f); // テンポに合わせて音の長さ自体を半分に
    Serial.print(":");
    Serial.print(amplitude[i]);
    if(i < 28) Serial.print(",");
  }
  Serial.println();
}

// 【修正】半速時（durationを2倍にする仕様に変更）
void sendMelodyHalf(){
  for(int i = 0; i < melodyLength; i++){
    Serial.print(melody[i]);
    Serial.print(":");
    Serial.print(duration[i] * 2.0f); // テンポに合わせて音の長さ自体を2倍に
    Serial.print(":");
    Serial.print(amplitude[i]);
    if(i < 28) Serial.print(",");
  }
  Serial.println();
}
