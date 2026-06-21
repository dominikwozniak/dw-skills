#!/usr/bin/env node
// Generates the pixel-art "dw-skills" wordmark as two SVGs (dark + light).
// Each "pixel" is a <rect> on a fixed grid — no fonts, no <style>, no script,
// so GitHub's SVG sanitizer renders it identically everywhere.
//
//   node scripts/gen-banner.mjs
//
// Emits assets/banner-dark.svg and assets/banner-light.svg. Dev tooling only
// (never shipped in a plugin) — re-run to regenerate after editing the font.

import { writeFileSync, mkdirSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..")

// 5×7 bitmap font — only the glyphs in "dw-skills". '#' = filled pixel.
const FONT = {
  d: ["....#", "....#", "....#", ".####", "#...#", "#...#", ".####"],
  w: [".....", ".....", "#...#", "#...#", "#.#.#", "#.#.#", ".#.#."],
  "-": [".....", ".....", ".....", ".###.", ".....", ".....", "....."],
  s: [".....", ".....", ".####", "#....", ".###.", "....#", "####."],
  k: ["#....", "#....", "#..#.", "#.#..", "##...", "#.#..", "#..#."],
  i: ["..#..", ".....", "..#..", "..#..", "..#..", "..#..", "..#.."],
  l: [".#...", ".#...", ".#...", ".#...", ".#...", ".#...", ".#..."],
}

const WORD = "dw-skills"
const ACCENT_GLYPHS = 2 // first N glyphs ("dw") use the accent colour

const CELL = 14 // grid pitch in px
const PIXEL = 12 // rect size in px (CELL - PIXEL = inter-pixel gap)
const GLYPH_W = 5
const GLYPH_H = 7
const GLYPH_GAP = 1 // empty columns between glyphs
const PAD = CELL // outer padding

const COLS = WORD.length * GLYPH_W + (WORD.length - 1) * GLYPH_GAP
const W = COLS * CELL + PAD * 2
const H = GLYPH_H * CELL + PAD * 2

function rects(accent, muted) {
  const out = []
  let colCursor = 0
  WORD.split("").forEach((ch, gi) => {
    const glyph = FONT[ch]
    const fill = gi < ACCENT_GLYPHS ? accent : muted
    for (let r = 0; r < GLYPH_H; r++) {
      for (let c = 0; c < GLYPH_W; c++) {
        if (glyph[r][c] !== "#") continue
        const x = PAD + (colCursor + c) * CELL
        const y = PAD + r * CELL
        out.push(`  <rect x="${x}" y="${y}" width="${PIXEL}" height="${PIXEL}" fill="${fill}"/>`)
      }
    }
    colCursor += GLYPH_W + GLYPH_GAP
  })
  return out.join("\n")
}

function svg(accent, muted) {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" role="img" aria-label="dw-skills">
  <title>dw-skills</title>
${rects(accent, muted)}
</svg>
`
}

const VARIANTS = {
  // light pixels for dark backgrounds
  "banner-dark.svg": svg("#f2f2f2", "#8a8a8a"),
  // dark pixels for light backgrounds
  "banner-light.svg": svg("#161616", "#6a6a6a"),
}

mkdirSync(join(ROOT, "assets"), { recursive: true })
for (const [name, body] of Object.entries(VARIANTS)) {
  writeFileSync(join(ROOT, "assets", name), body)
  console.log(`wrote assets/${name}`)
}
