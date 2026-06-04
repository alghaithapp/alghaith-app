import fs from 'fs';
import path from 'path';
import sharp from 'sharp';

const IMAGES_DIR = path.resolve('assets/images');
/** Max edge length for UI assets (768 is enough for 2–3× mobile cards). */
const MAX_DIMENSION = 768;
const MIN_BYTES_TO_PROCESS = 50 * 1024;
const PNG_OPTS = { compressionLevel: 9, effort: 10, palette: false };
const JPEG_QUALITY = 82;

const exts = new Set(['.png', '.jpg', '.jpeg', '.webp']);

function formatBytes(n) {
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
  return `${(n / (1024 * 1024)).toFixed(2)} MB`;
}

async function compressFile(filePath) {
  const before = fs.statSync(filePath).size;
  if (before < MIN_BYTES_TO_PROCESS) {
    return { skipped: true, reason: 'small', before };
  }

  const ext = path.extname(filePath).toLowerCase();
  const meta = await sharp(filePath).metadata();
  const w = meta.width ?? 0;
  const h = meta.height ?? 0;
  const maxSide = Math.max(w, h);

  let pipeline = sharp(filePath, { failOn: 'none' });
  if (maxSide > MAX_DIMENSION) {
    pipeline = pipeline.resize({
      width: w >= h ? MAX_DIMENSION : undefined,
      height: h > w ? MAX_DIMENSION : undefined,
      fit: 'inside',
      withoutEnlargement: true,
    });
  }

  const tmp = `${filePath}.compress.tmp`;
  if (ext === '.png') {
    await pipeline.png(PNG_OPTS).toFile(tmp);
  } else if (ext === '.jpg' || ext === '.jpeg') {
    await pipeline.jpeg({ quality: JPEG_QUALITY, mozjpeg: true }).toFile(tmp);
  } else if (ext === '.webp') {
    await pipeline.webp({ quality: 80, effort: 6 }).toFile(tmp);
  } else {
    return { skipped: true, reason: 'ext', before };
  }

  const after = fs.statSync(tmp).size;
  if (after >= before) {
    fs.unlinkSync(tmp);
    return { skipped: true, reason: 'no_gain', before, after };
  }

  fs.renameSync(tmp, filePath);
  return { skipped: false, before, after, w, h, maxSide };
}

async function main() {
  const files = fs
    .readdirSync(IMAGES_DIR)
    .filter((f) => exts.has(path.extname(f).toLowerCase()))
    .map((f) => path.join(IMAGES_DIR, f))
    .sort();

  let totalBefore = 0;
  let totalAfter = 0;
  let compressed = 0;
  let skipped = 0;

  for (const filePath of files) {
    try {
      const r = await compressFile(filePath);
      if (r.skipped) {
        skipped++;
        totalBefore += r.before;
        totalAfter += r.before;
        continue;
      }
      compressed++;
      totalBefore += r.before;
      totalAfter += r.after;
      const pct = (((r.before - r.after) / r.before) * 100).toFixed(0);
      console.log(
        `${path.basename(filePath)}: ${formatBytes(r.before)} → ${formatBytes(r.after)} (-${pct}%)`,
      );
    } catch (err) {
      console.error(`${path.basename(filePath)}: ERROR ${err.message}`);
    }
  }

  const saved = totalBefore - totalAfter;
  const pct =
    totalBefore > 0 ? ((saved / totalBefore) * 100).toFixed(1) : '0';
  console.log('---');
  console.log(
    `Files: ${files.length} | compressed: ${compressed} | skipped: ${skipped}`,
  );
  console.log(
    `Total: ${formatBytes(totalBefore)} → ${formatBytes(totalAfter)} (saved ${formatBytes(saved)}, -${pct}%)`,
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
