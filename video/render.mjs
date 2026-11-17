import puppeteer from 'puppeteer-core';
import { mkdirSync, rmSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const frames = join(here, 'frames');
const out = join(here, '..', 'site', 'video');
const fps = 30, seconds = 20, only = process.argv[2] ? process.argv[2].split(',').map(Number) : null;

rmSync(frames, { recursive: true, force: true });
mkdirSync(frames, { recursive: true });
mkdirSync(out, { recursive: true });

const browser = await puppeteer.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
const page = await browser.newPage();
await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 });
await page.goto(pathToFileURL(join(here, 'launch.html')).href, { waitUntil: 'networkidle0' });
await page.evaluate(() => window.ready);

if (only) {
  for (const second of only) {
    await page.evaluate((ms) => window.seek(ms), second * 1000);
    await page.screenshot({ path: join(frames, `still-${second}.jpg`), type: 'jpeg', quality: 80 });
  }
} else {
  for (let frame = 0; frame < fps * seconds; frame++) {
    await page.evaluate((ms) => window.seek(ms), (frame / fps) * 1000);
    await page.screenshot({ path: join(frames, `${String(frame).padStart(4, '0')}.png`) });
  }
  const ffmpeg = '/opt/homebrew/bin/ffmpeg';
  execFileSync(ffmpeg, ['-loglevel', 'error', '-y', '-framerate', String(fps), '-i', join(frames, '%04d.png'), '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '21', '-preset', 'slow', '-movflags', '+faststart', join(out, 'launch.mp4')]);
  execFileSync(ffmpeg, ['-loglevel', 'error', '-y', '-i', join(frames, '0450.png'), '-q:v', '3', join(out, 'poster.jpg')]);
}
await browser.close();
