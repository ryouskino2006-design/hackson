import processing.serial.*;
Serial port; // シリアルポート
import ddf.minim.*;
import ddf.minim.ugens.*;

Waveform currentWaveform;
Minim minim;
AudioOutput out;
int melodyLength = 29;
String[] melody = new String[melodyLength];
float[] duration = new float[melodyLength];
float[] startTime = new float[melodyLength];
float[] amplitude = new float[melodyLength];

void setup(){
  size (512 , 200);
  minim = new Minim(this);
  out = minim.getLineOut();
  out.setTempo(120);
  
  // トランペット特有の芯のある明るい響きを再現する倍音
  currentWaveform = WavetableGenerator.gen10(4096, new float[] { 1.0f, 1.0f, 0.7f, 0.5f, 0.3f, 0.2f, 0.1f, 0.05f });
  
  port = new Serial(this, "/dev/cu.usbmodem34B7DA64C6002", 921600);
  port.clear();
  port.bufferUntil('\n');
  delay(1000); 
  port.write('A'); 
  println("Arduinoに送信リクエストを送りました...");
}

void draw() {
  background(0);
}

void serialEvent(Serial p) {
  String inString = p.readStringUntil('\n');
  if(inString != null){
    println("受信した生データ: " + inString);
    String[] notes = split(trim(inString), ',');
    for(int i=0; i<notes.length; i++){
      String[] data = split(notes[i], ':');
      if(data.length == 4){
        melody[i] = data[0];
        duration[i] = float(data[1]);
        startTime[i] = float(data[2]);
        amplitude[i] = float(data[3]);
      }
    }
  }
}

class Trumpet implements Instrument {
  Oscil wave;
  Line ampEnv; // 音量をコントロールする直線
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
    
    // Lineを初期化して、waveのamplitude（音量）にパッチする
    ampEnv = new Line(); 
    ampEnv.patch(wave.amplitude);
  }

  void noteOn(float duration) {
    // 音が鳴るとき：0.01秒かけて無音(0)から指定の音量(maxAmp)へ立ち上げる
    ampEnv.activate(0.01f, 0, maxAmp);
    wave.patch(out);
  }

  void noteOff() {
    // 音が消えるとき：0.03秒（30ミリ秒）かけて、現在の音量から0へ滑らかに落とす
    ampEnv.activate(0.03f, maxAmp, 0);
    
    // 【重要】音量が0に落ちきるのを少しだけ待ってから、スピーカーから切断する
    // これにより「ブチッ」という不連続な雑音が完全に消えます
    delay(30); 
    wave.unpatch(out);
  }
}
// ==========================================
// 演奏用の関数（クラスの外側）
// ==========================================
void playSong() {
  out.pauseNotes();
  boolean hasData = false;
  for (int i = 0; i < melody.length; i++) {
    if (melody[i] != null) { 
      out.playNote(startTime[i], duration[i],
        new Trumpet(Frequency.ofPitch(melody[i]).asHz(), amplitude[i], currentWaveform));
      hasData = true;
    }
  }
  if (!hasData) {
    println("まだデータが届いていないようです。Arduinoを確認してください。");
  }
  out.resumeNotes();
}
 
void keyPressed() {
  if (key == 'p') {
    playSong();
  }
}
