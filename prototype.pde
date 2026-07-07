import ddf.minim.*;
import ddf.minim.ugens.*;

Minim minim;
AudioOutput out;
String currentNote = "";

// トランペット倍音ウェーブテーブル
Waveform lowWave;
Waveform midWave;
Waveform highWave;

// 演奏状態管理用フラグ
boolean isPlaying = false; 

// 「かエルの歌」の楽譜データ定義
String[] pitches = {
  "C4", "D4", "E4", "F4", "E4", "D4", "C4", "R",  
  "E4", "F4", "G4", "A4", "G4", "F4", "E4", "R",  
  "C4", "R",  "C4", "R",  "C4", "R",  "C4", "R",  
  "C4", "C4", "D4", "D4", "E4", "E4", "F4", "F4", 
  "E4", "D4", "C4", "R"                           
};

float[] durations = {
  1.0,  1.0,  1.0,  1.0,  1.0,  1.0,  1.0,  1.0,
  1.0,  1.0,  1.0,  1.0,  1.0,  1.0,  1.0,  1.0,
  1.0,  1.0,  1.0,  1.0,  1.0,  1.0,  1.0,  1.0,
  0.5,  0.5,  0.5,  0.5,  0.5,  0.5,  0.5,  0.5,
  1.0,  1.0,  1.0,  1.0
};

int noteIndex = 0;
float tempoBPM = 120.0;
int lastTriggerTime = 0;
float nextNoteDuration = 0;

void setup() {
  size(512, 230); 
  pixelDensity(1);
  
  minim = new Minim(this);
  out = minim.getLineOut();
  out.setTempo(tempoBPM);

  // ウェーブテーブルの生成
  lowWave   = WavetableGenerator.gen10(4096, new float[] { 1.0f, 0.72f, 0.5f, 0.3f, 0.1f });
  midWave   = WavetableGenerator.gen10(4096, new float[] { 1.0f, 0.43f, 0.3f, 0.15f, 0.05f });
  highWave  = WavetableGenerator.gen10(4096, new float[] { 1.0f, 0.028f, 0.01f });
  
  lastTriggerTime = millis();
}

void draw() {
  background(0);
  
  // 1. トリガー用の視覚的「状態インジケータ」を描画
  if (isPlaying) {
    fill(40, 150, 40); // 演奏中は緑
  } else {
    fill(150, 40, 40);  // 停止中は赤
  }
  rect(15, 15, 140, 40, 7);
  
  fill(255);
  textSize(14);
  textAlign(CENTER, CENTER);
  if (isPlaying) {
    text("■ STOP (演奏中)", 85, 32);
  } else {
    text("▶ START (停止中)", 85, 32);
  }
  textAlign(LEFT, BASELINE); // 位置合わせを元に戻す

  // 2. オシロスコープ（波形描画）
  stroke(255);
  for (int i = 0; i < out.bufferSize() - 1; i++) {
    line(i, 110 + out.left.get(i)*50, i+1, 110 + out.left.get(i+1)*50);
  }
  
  // 3. シーケンス制御（再生フラグがONの時のみ進行）
  if (isPlaying) {
    int currentTime = millis();
    float msPerBeat = (60.0 / tempoBPM) * 1000.0;
    if (currentTime - lastTriggerTime >= nextNoteDuration * msPerBeat) {
      triggerNextNote();
      lastTriggerTime = currentTime;
    }
  }

  // ステータス表示
  fill(255);
  textSize(13);
  text("【音質測定用・「p」キーで再生/停止】", 170, 38);
  textSize(20);
  text("Playing Note: " + currentNote, 15, 200);
}

// マウス入力用の関数（mousePressed）を削除し、誤動作を完全に防止

// キーボードのキーが押された時の処理
void keyPressed() {
  // 小文字の 'p' または大文字の 'P' が押されたときだけ実行
  if (key == 'p' || key == 'P') {
    togglePlayback();
  }
}

void togglePlayback() {
  isPlaying = !isPlaying;
  if (isPlaying) {
    // 再開時はタイミングを強制同期
    lastTriggerTime = millis();
    nextNoteDuration = 0; 
  } else {
    currentNote = "[ 一時停止 ]";
  }
}

void triggerNextNote() {
  String pitch = pitches[noteIndex];
  float duration = durations[noteIndex];
  float amplitude = 0.6; 
  
  nextNoteDuration = duration;
  currentNote = pitch;

  if (!pitch.equals("R")) {
    try {
      float freq = Frequency.ofPitch(pitch).asHz();
      
      Waveform selectedWave = midWave;
      if (freq < 550)       selectedWave = lowWave;
      else if (freq > 900)  selectedWave = highWave;
      
      out.playNote(0, duration - 0.05, new TrumpetInstrument(freq, amplitude, selectedWave));
    } catch (Exception e) {
      // 安全弁
    }
  } else {
    currentNote = "[ 休符 ]";
  }

  noteIndex = (noteIndex + 1) % pitches.length;
}

// ==================================================
// 長時間演奏・測定対策済の楽器定義クラス
// ==================================================
class TrumpetInstrument implements Instrument {
  Oscil wave;
  ADSR adsr;      
  Oscil vib;      
  Summer freqSum;
  Constant baseFreq;
  float maxAmp;

  TrumpetInstrument(float frequency, float maxAmp, Waveform wf) {
    this.maxAmp = maxAmp;
    freqSum = new Summer();
    baseFreq = new Constant(frequency);
    
    vib = new Oscil(5.5f, 3.0f, Waves.SINE);
    baseFreq.patch(freqSum);
    vib.patch(freqSum);
    
    wave = new Oscil(frequency, maxAmp, wf);
    freqSum.patch(wave.frequency);
    
    adsr = new ADSR(maxAmp, 0.05f, 0.0f, 1.0f, 0.03f, 0.0f, 0.0f);
    wave.patch(adsr);
  }

  void noteOn(float duration) {
    adsr.noteOn();   
    adsr.patch(out); 
  }

  void noteOff() {
    adsr.noteOff();  
    
    new Thread(new Runnable() {
      public void run() {
        try {
          Thread.sleep(40);    
          adsr.unpatch(out);   
          wave.unpatch(adsr);  
          vib.unpatch(freqSum);
          baseFreq.unpatch(freqSum);
        } catch (Exception e) {
          // 安全弁
        }
      }
    }).start();
  }
}
