const fs = require('fs');
const path = require('path');

const sampleRate = 22050;
const root = path.join(__dirname, '..');

function writeWav(targetPath, samples) {
  const numChannels = 1;
  const bitsPerSample = 16;
  const byteRate = (sampleRate * numChannels * bitsPerSample) / 8;
  const blockAlign = (numChannels * bitsPerSample) / 8;
  const dataSize = samples.length * 2;
  const buffer = Buffer.alloc(44 + dataSize);

  buffer.write('RIFF', 0);
  buffer.writeUInt32LE(36 + dataSize, 4);
  buffer.write('WAVE', 8);
  buffer.write('fmt ', 12);
  buffer.writeUInt32LE(16, 16);
  buffer.writeUInt16LE(1, 20);
  buffer.writeUInt16LE(numChannels, 22);
  buffer.writeUInt32LE(sampleRate, 24);
  buffer.writeUInt32LE(byteRate, 28);
  buffer.writeUInt16LE(blockAlign, 32);
  buffer.writeUInt16LE(bitsPerSample, 34);
  buffer.write('data', 36);
  buffer.writeUInt32LE(dataSize, 40);

  for (let i = 0; i < samples.length; i += 1) {
    const clamped = Math.max(-32768, Math.min(32767, Math.round(samples[i])));
    buffer.writeInt16LE(clamped, 44 + i * 2);
  }

  fs.mkdirSync(path.dirname(targetPath), { recursive: true });
  fs.writeFileSync(targetPath, buffer);
}

function tone(freq, duration, volume = 0.32) {
  const count = Math.floor(sampleRate * duration);
  const fade = Math.floor(sampleRate * 0.02);
  const out = [];
  for (let i = 0; i < count; i += 1) {
    const t = i / sampleRate;
    const attack = Math.min(1, i / fade);
    const release = Math.max(0, 1 - Math.max(0, i - count + fade) / fade);
    const env = attack * release;
    out.push(Math.sin(2 * Math.PI * freq * t) * 32767 * volume * env);
  }
  return out;
}

function silence(duration) {
  return new Array(Math.floor(sampleRate * duration)).fill(0);
}

const samples = [
  ...tone(784, 0.11),
  ...silence(0.03),
  ...tone(988, 0.14),
  ...silence(0.02),
  ...tone(1175, 0.16, 0.28),
];

const source = path.join(root, 'assets', 'sounds', 'alghaith_notify.wav');
const deployTargets = [
  path.join(root, 'android', 'app', 'src', 'main', 'res', 'raw', 'alghaith_notify.wav'),
  path.join(root, 'ios', 'Runner', 'alghaith_notify.wav'),
];

if (!fs.existsSync(source)) {
  writeWav(source, samples);
  console.log(`Created default sound at ${source}`);
}

for (const target of deployTargets) {
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.copyFileSync(source, target);
  console.log(`Copied to ${target}`);
}
