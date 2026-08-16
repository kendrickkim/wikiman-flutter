// Regenerates the launcher icons and the in-app icon from the Wikiman frontend
// favicon. Run `npm install` in the sibling wikiman-frontend repo first, then:
//   node tool/generate-app-icons.mjs

import fs from 'node:fs'
import path from 'node:path'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const projectRoot = path.resolve(__dirname, '..')
const frontendRoot =
  process.env.WIKIMAN_FRONTEND ?? path.resolve(projectRoot, '../wikiman-frontend')
const svgPath = path.join(frontendRoot, 'public/icons/favicon.svg')

// sharp lives in the frontend repo, which owns the favicon and its PWA icons.
const sharp = createRequire(path.join(frontendRoot, 'package.json'))('sharp')

const brandColor = '#1f6feb'
const iosDir = path.join(
  projectRoot,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset',
)
const androidResDir = path.join(projectRoot, 'android/app/src/main/res')
const flutterAssetDir = path.join(projectRoot, 'assets')

const iosIcons = [
  ['Icon-App-20x20@1x.png', 20],
  ['Icon-App-20x20@2x.png', 40],
  ['Icon-App-20x20@3x.png', 60],
  ['Icon-App-29x29@1x.png', 29],
  ['Icon-App-29x29@2x.png', 58],
  ['Icon-App-29x29@3x.png', 87],
  ['Icon-App-40x40@1x.png', 40],
  ['Icon-App-40x40@2x.png', 80],
  ['Icon-App-40x40@3x.png', 120],
  ['Icon-App-60x60@2x.png', 120],
  ['Icon-App-60x60@3x.png', 180],
  ['Icon-App-76x76@1x.png', 76],
  ['Icon-App-76x76@2x.png', 152],
  ['Icon-App-83.5x83.5@2x.png', 167],
  ['Icon-App-1024x1024@1x.png', 1024],
]

const launcherSizes = [
  ['mipmap-mdpi', 48],
  ['mipmap-hdpi', 72],
  ['mipmap-xhdpi', 96],
  ['mipmap-xxhdpi', 144],
  ['mipmap-xxxhdpi', 192],
]

// Adaptive icons crop to a 72/108 safe zone, so the glyph is inset to survive it.
const adaptiveSizes = [
  ['mipmap-mdpi', 108],
  ['mipmap-hdpi', 162],
  ['mipmap-xhdpi', 216],
  ['mipmap-xxhdpi', 324],
  ['mipmap-xxxhdpi', 432],
]

if (!fs.existsSync(svgPath)) {
  console.error('favicon.svg가 없습니다:', svgPath)
  process.exit(1)
}

const svg = fs.readFileSync(svgPath)
// The adaptive foreground reuses the favicon glyph without its background plate.
const glyphSvg = Buffer.from(svg.toString().replace(/<rect\b[^>]*\/>/, ''))

function render(source, size) {
  return sharp(source, { density: Math.max(72, size * 2) }).resize(size, size)
}

async function writeSquare(file, size) {
  // iOS rejects icons with an alpha channel, so the rounded corners are filled in.
  await render(svg, size).flatten({ background: brandColor }).png().toFile(file)
  console.log('wrote', path.relative(projectRoot, file))
}

async function writeAsset(file, size) {
  // The connection screen draws this over the app background, so the favicon's
  // rounded corners stay transparent instead of being filled in.
  await render(svg, size).png().toFile(file)
  console.log('wrote', path.relative(projectRoot, file))
}

async function writeForeground(file, size) {
  const glyph = Math.round((size * 72) / 108)
  const inset = Math.round((size - glyph) / 2)
  const glyphPng = await render(glyphSvg, glyph).png().toBuffer()
  await sharp({
    create: {
      width: size,
      height: size,
      channels: 4,
      background: { r: 0, g: 0, b: 0, alpha: 0 },
    },
  })
    .composite([{ input: glyphPng, top: inset, left: inset }])
    .png()
    .toFile(file)
  console.log('wrote', path.relative(projectRoot, file))
}

for (const [name, size] of iosIcons) {
  await writeSquare(path.join(iosDir, name), size)
}

for (const [dir, size] of launcherSizes) {
  const target = path.join(androidResDir, dir)
  fs.mkdirSync(target, { recursive: true })
  await writeSquare(path.join(target, 'ic_launcher.png'), size)
}

for (const [dir, size] of adaptiveSizes) {
  const target = path.join(androidResDir, dir)
  fs.mkdirSync(target, { recursive: true })
  await writeForeground(path.join(target, 'ic_launcher_foreground.png'), size)
}

fs.mkdirSync(flutterAssetDir, { recursive: true })
await writeAsset(path.join(flutterAssetDir, 'app_icon.png'), 512)
