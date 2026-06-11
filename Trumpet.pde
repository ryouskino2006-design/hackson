import processing.serial.*;
Serial port; 
import ddf.minim.*;
import ddf.minim.ugens.*;

Minim minim;
AudioOutput out;

// 楽譜データを保持する配列
int melodyLength = 29;
String[] melody = new String[melodyLength];
float[] duration = new float[melodyLength];
float[] amplitude = new float[melodyLength];

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
  out.setTempo(120); // 親機のテンポ感と同期
  
  // シリアルポート設定
  port = new Serial(this, "/dev/cu.usbmodem34B7DA636B9C2", 921600);
  port.clear();
  port.bufferUntil('\n'); 
  
  println("赤外線同期による自動楽譜展開システムを待機中...");
}

void draw() {
  background(0);
}

// Arduinoから一括データ（音名:長さ:音量）が届いた瞬間に呼び出されるイベント
void serialEvent(Serial p) {
  String inString = p.readStringUntil('\n');
  if(inString != null){
    inString = trim(inString);
    println("受信した生データ: " + inString);
    
    String[] notes = split(inString, ',');
    
    // 受信したすべての音（最大29音）を配列に格納する
    for(int i = 0; i < notes.length; i++){
      if(i >= melodyLength) break;
      String[] data = split(notes[i], ':');
      
      // 【修正】要素数が 3（音名:長さ:音量）のデータを正しく分解
      if(data.length == 3){
        melody[i]    = data[0];
        duration[i]  = float(data[1]); // 2番目は duration（音の長さ）
        amplitude[i] = float(data[2]); // 3番目は amplitude（音量）
      }
    }
    
    // 楽譜の展開が終わったら、人間のキー入力を待たずに勝手に演奏スタート
    playSong();
  }
}

// 送られてきた duration（音の長さ）を順に積み上げてタイムラインを作る関数
void playSong() {
  out.pauseNotes(); // 登録中の発音ズレを防ぐために一時停止
  
  float currentDelay = 0.0f; // 音を鳴らす開始タイミング（秒）を管理する変数
  
  for (int i = 0; i < melody.length; i++) {
    if (melody[i] != null && !melody[i].equals("")) { 
      float hz = Frequency.ofPitch(melody[i]).asHz();
      
      // 周波数に応じた倍音ウェーブの自動選択
      Waveform selectedWave = midWave; 
      if (hz < 550)       selectedWave = lowWave;        
      else if (hz > 900)  selectedWave = highWave;       
    
      // ★【重要】受信した瞬間から、それぞれの音の長さ（duration[i]）ずつ
      // 開始タイミング（currentDelay）を後ろにズラしながらMinimに予約していく
      out.playNote(currentDelay, duration[i], new Trumpet(hz, amplitude[i], selectedWave));
      
      // 次の音の開始位置は、今の音の長さ分だけ進めた位置にする
      currentDelay += duration[i]; 
    }
  }
  
  out.resumeNotes(); // 構築したタイムラインを一斉に再生開始！
  println("▶ 親機の合図に合わせて最初からカノン演奏を開始しました。");
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
    vib = new Oscil(5.5f, 3.0f, Waves.SINE); 

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
    ampEnv.activate(releaseTime, maxAmp, 0);
  }
}
