"use strict";
const { readFileSync, writeFileSync } = require("fs");

const STATE_WAIT_FOR_ENCODING = "wait-for-encoding";
const STATE_WAIT_FOR_BITMAP = "wait-for-bitmap";
const STATE_BITMAP = "bitmap";

let glyphs = Array(256).fill().map(() => []);
let state = STATE_WAIT_FOR_ENCODING;
let currentGlyph = null;

const bdf = readFileSync("u_vga16.bdf", "utf8").split("\n");
for (let line of bdf) {
	if (state == STATE_WAIT_FOR_ENCODING) {
		if (line.startsWith("ENCODING")) {
			currentGlyph = line.trim().split(" ")[1];
			state = STATE_WAIT_FOR_BITMAP;
		}
	} else if (state == STATE_WAIT_FOR_BITMAP) {
		if (line.startsWith("BITMAP")) {
			glyphs[currentGlyph] = [];
			state = STATE_BITMAP;
		}
	} else if (state == STATE_BITMAP) {
		if (line.startsWith("ENDCHAR")) {
			state = STATE_WAIT_FOR_ENCODING;
		} else {
			glyphs[currentGlyph].push(parseInt(line.trim(), 16));
		}
	}
}

let memory = new Uint8Array(256*16);
for (let glyph in glyphs) {
	if (glyph <= 255) {
		for (let y in glyphs[glyph]) {
			memory[parseInt(glyph)*16 + parseInt(y)] = glyphs[glyph][y];
		}
	}
}

let textmemory = "";
for (let i = 0; i < memory.length; i++) {
	textmemory += memory[i].toString(2) + "\n";
}

writeFileSync("font.mem", textmemory);
