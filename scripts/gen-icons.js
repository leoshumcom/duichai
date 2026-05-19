const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const svgPath = path.join(__dirname, '..', 'assets', '火柴.svg');
const svg = fs.readFileSync(svgPath, 'utf-8');

const sizes = {
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
};

async function main() {
  const outDir = path.join(__dirname, '..', 'app', 'android', 'app', 'src', 'main', 'res');

  for (const [dir, size] of Object.entries(sizes)) {
    const targetDir = path.join(outDir, dir);
    if (!fs.existsSync(targetDir)) {
      fs.mkdirSync(targetDir, { recursive: true });
    }

    const buffer = await sharp(Buffer.from(svg), { density: 300 })
      .resize(size, size, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
      .png()
      .toBuffer();

    const outPath = path.join(targetDir, 'ic_launcher.png');
    fs.writeFileSync(outPath, buffer);
    console.log(`Generated ${dir}/ic_launcher.png (${size}x${size})`);
  }

  // Favicon for website
  const faviconDir = path.join(__dirname, '..', 'website');
  const favicon = await sharp(Buffer.from(svg), { density: 300 })
    .resize(32, 32, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
    .png()
    .toBuffer();
  fs.writeFileSync(path.join(faviconDir, 'favicon.png'), favicon);
  console.log('Generated favicon.png (32x32)');

  // Apple touch icon 180x180
  const appleIcon = await sharp(Buffer.from(svg), { density: 300 })
    .resize(180, 180, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
    .png()
    .toBuffer();
  fs.writeFileSync(path.join(faviconDir, 'apple-touch-icon.png'), appleIcon);
  console.log('Generated apple-touch-icon.png (180x180)');
}

main().catch(console.error);
