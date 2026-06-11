import processing.serial.*;
Serial port; 
import ddf.minim.*;
import ddf.minim.ugens.*;

Minim minim;
AudioOutput out;

// トランペットのエンベロープ設定
float attackTime = 0.145f; // 145ms
float releaseTime= 0.030f; // 30ms

// 解像度4096のWavetableを用いた倍音合成用ウェーブ
Waveform lowWave   = WavetableGenerator.gen10(4096, new float[] { 1.0f, 0.72f, 0.5f, 0.3f, 0.1f });
Waveform midWave   = WavetableGenerator.gen10(4096, new float[] { 1.0f, 0.43f, 0.3f, 0.15f, 0.05f });
Waveform highWave  = WavetableGenerator.gen10(4096, new float[] { 1.0f, 0.028f, 0.01f });

void setup(){
  size (512 , 200);
  minim = new Minim(this);
  out = minim.getLineOut();
  
  // シリアルポート設定（※ポート名はご自身の環境に合わせてください）
  port = new Serial(this, "/dev/cu.usbmodem34B7DA636B9C2", 921600);
  port.clear();
  port.bufferUntil('\n'); 
  
  println("赤外線同期によるリアルタイム自動演奏を待機中...");
}

void draw() {
  background(0);
}

// Arduinoからデータが届いた瞬間に自動で呼び出されるイベント
void serialEvent(Serial p) {
  String inString = p.readStringUntil('\n');
  if(inString != null){
    inString = trim(inString);
    println("受信したデータ: " + inString);
    
    String[] notes = split(inString, ',');
    if(notes.length > 0 && !notes[0].equals("")){
      String[] data = split(notes[0], ':');
      
      // 要素数が 3（音名:開始時間:音量）に一致しているかチェック
      if(data.length >= 3){
        String noteName = data[0];    
        float amp = float(data[2]);       
        
        if (noteName != null && !noteName.equals("")) {
          float hz = Frequency.ofPitch(noteName).asHz();
          
          // 周波数に応じた倍音ウェーブの自動選択
          Waveform selectedWave = midWave; 
          if (hz < 550) {
            selectedWave = lowWave;        
          } else if (hz > 900) {
            selectedWave = highWave;       
          }
          
          // ★届いた瞬間（0.0f秒後）に、固定長（0.4秒）で即座に演奏をトリガー
          out.playNote(0.0f, 0.4f, new Trumpet(hz, amp, selectedWave));
        }
      }
    }
  }
}

// --- トランペットクラス（ノイズ対策版） ---
class Trumpet implements Instrument {
  Oscil wave;
  Line ampEnv; 
  Oscil vib;      
  Summer freqSum; 
  Constant baseFreq; 
  float maxAmp;

  Trumpet(float frequency, float maxAmp, Waveform wf) {
    this.maxAmp = maxAmp;
    
    freqSum = new Summer();
    baseFreq = new Constant(frequency);
    vib = new Oscil(5.5f, 3.0f, Waves.SINE); // 5Hz付近（5.5Hz）ビブラート

    baseFreq.patch(freqSum);
    vib.patch(freqSum);

    wave = new Oscil(frequency, 0, wf);
    freqSum.patch(wave.frequency);
    
    ampEnv = new Line(); 
    ampEnv.patch(wave.amplitude);
  }

  void noteOn(float duration) {
    ampEnv.activate(attackTime, 0, maxAmp);
    wave.patch(out);
  }

  void noteOff() {
    // 30ms（releaseTime）かけて滑らかに音量を0へ落とす
    ampEnv.activate(releaseTime, maxAmp, 0);
    
    // ★手動のdelayや強引なunpatchを無くすことで、Minimに安全にフェードアウトさせ、ノイズを完全解消
  }
}
