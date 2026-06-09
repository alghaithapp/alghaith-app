import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.join(__dirname, '..');
const distDir = path.join(rootDir, 'dist');
const websiteDir = path.join(rootDir, 'website');

function copyRecursiveSync(src, dest) {
  const exists = fs.existsSync(src);
  const stats = exists && fs.statSync(src);
  const isDirectory = exists && stats.isDirectory();
  if (isDirectory) {
    if (!fs.existsSync(dest)) {
      fs.mkdirSync(dest, { recursive: true });
    }
    fs.readdirSync(src).forEach((childItemName) => {
      // dist/admin is produced by Vite; do not overwrite it with stale website/admin.
      if (childItemName === 'admin') return;
      copyRecursiveSync(path.join(src, childItemName), path.join(dest, childItemName));
    });
  } else {
    fs.copyFileSync(src, dest);
  }
}

console.log('--- Starting Post-Build Script ---');

try {
  if (!fs.existsSync(distDir)) {
    console.log('Creating dist directory...');
    fs.mkdirSync(distDir, { recursive: true });
  }

  if (fs.existsSync(websiteDir)) {
    console.log('Copying website files to dist...');
    copyRecursiveSync(websiteDir, distDir);
  } else {
    console.log('Website directory not found!');
  }

  // Ensure website/index.html is the main entry in dist
  const websiteIndex = path.join(websiteDir, 'index.html');
  const distIndex = path.join(distDir, 'index.html');
  if (fs.existsSync(websiteIndex)) {
    console.log('Setting main index.html...');
    fs.copyFileSync(websiteIndex, distIndex);
  }

  console.log('Post-build completed successfully.');
} catch (err) {
  console.error('Post-build failed:', err);
  process.exit(1);
}
