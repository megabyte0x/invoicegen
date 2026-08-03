import sharp from 'sharp';
import { mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const source = resolve(root, 'site/assets/invoicegen-preview.png');
const output = resolve(root, 'site/public/assets');
const widths = [640, 960, 1280, 1536];

await mkdir(output, { recursive: true });
for (const width of widths) {
  const suffix = width === 1536 ? '' : `-${width}`;
  await sharp(source).resize({ width, withoutEnlargement: true })
    .png({ compressionLevel: 9 })
    .toFile(resolve(output, `invoicegen-preview${suffix}.png`));
  await sharp(source).resize({ width, withoutEnlargement: true })
    .webp({ quality: 82 })
    .toFile(resolve(output, `invoicegen-preview${suffix}.webp`));
}
