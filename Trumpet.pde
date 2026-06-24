import processing.serial.*;
Serial port;
import ddf.minim.*;
import ddf.minim.ugens.*;

// 1. 変数の宣言
Waveform lowWave;
Waveform midWave;
Waveform highWave;

Minim minim;
AudioOutput out;
String currentNote = "";

void setup() {
  size(512, 200);
  pixelDensity(1);
  minim = new Minim(this);
  out = minim.getLineOut();
  out.setTempo(120);
  

  lowWave   = WavetableGenerator.gen10(4096, new float[] { 1.0f, 0.72f, 0.5f, 0.3f, 0.1f });
  midWave   = WavetableGenerator.gen10(4096, new float[] { 1.0f, 0.43f, 0.3f, 0.15f, 0.05f });
  highWave  = WavetableGenerator.gen10(4096, new float[] { 1.0f, 0.028f, 0.01f });
  
  // シリアルポート設定
  port = new Serial(this, "/dev/cu.usbmodem64E83364FFA82", 115200);
  port.clear();
  port.bufferUntil('\n');
}

void draw() {
  background(0);
  stroke(255);
  for (int i = 0; i < out.bufferSize() - 1; i++) {
    line(i, 50 + out.left.get(i)*50, i+1, 50 + out.left.get(i+1)*50);
  }
  fill(255);
  text("note: " + currentNote, 10, 180);
}

void serialEvent(Serial p) {
  String inString = p.readStringUntil('\n');
  if (inString == null) return;
  inString = trim(inString);
  if (inString.length() == 0) return;
  currentNote = inString;

  String[] parts = split(inString, ',');
  
  if (parts.length < 3) {
    if (inString.equals("C2")) {
      println("🥁 ドラム音(C2)を受信");
    }
    return;
  }
  
  String pitch = parts[0];
  if (pitch.equals("R")) {
    println("♪ [休符]");
    return;
  }
  
  float duration  = float(parts[1]);
  float amplitude = float(parts[2]);
  
  playNote(pitch, duration, amplitude);
}

void playNote(String pitch, float duration, float amplitude) {
  try {
    float freq = Frequency.ofPitch(pitch).asHz();
    
    // 3. 周波数に応じて3つのウェーブテーブルの値を正しく出し分け
    Waveform selectedWave = midWave;
    if (freq < 550)       selectedWave = lowWave;
    else if (freq > 900)  selectedWave = highWave;
    
    out.playNote(0, duration, new TrumpetInstrument(freq, amplitude, selectedWave));
  } catch (Exception e) {
    // 安全弁
  }
}

class TrumpetInstrument implements Instrument {
  Oscil wave;
  Line ampEnv;
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
    
    wave = new Oscil(frequency, 0, wf);
    freqSum.patch(wave.frequency);
    
    ampEnv = new Line();
    ampEnv.patch(wave.amplitude);
  }

  void noteOn(float duration) {
    float attackTime = 0.05f;
    ampEnv.activate(attackTime, 0, this.maxAmp);
    wave.patch(out);
  }

  void noteOff() {
    float fadeOutTime = 0.03f; 
    ampEnv.activate(fadeOutTime, this.maxAmp, 0);
    
    // 音が消えるのを待ってから安全に切断
    out.setNoteOffset(fadeOutTime);
    wave.unpatch(out);
  }
}
