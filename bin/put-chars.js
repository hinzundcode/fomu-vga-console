"use strict";
const { execSync } = require("child_process");

const CSR_VGA_FB = 0x00003800;
const CSR_VGA_FB_PAGE = 0x00003004;
const FRAMEBUFFER_WIDTH = 80;
const FRAMEBUFFER_HEIGHT = 30;

function printHelp() {
	console.log("Usage:");
	console.log("\tnode put-chars.js Hello World")
	console.log("\tnode put-chars.js -x 10 -y 10 Test")
	console.log("\tnode put-chars.js --clear");
	process.exit(0);
}

function printString(x, y, string) {
	let address = y * FRAMEBUFFER_WIDTH + x;

	for (let i = 0; i < string.length; i++) {
		let page = Math.floor(address / 512);
		let offset = address % 512;
		execSync(`wishbone-tool ${CSR_VGA_FB_PAGE} ${page}`);
		execSync(`wishbone-tool ${CSR_VGA_FB + offset*4} ${string.charCodeAt(i)}`)
		address++;
	}
}

let x = 0;
let y = 0;
let string = "";

if (process.argv.length == 2) {
	printHelp();
	process.exit(0);
}

for (let i = 2; i < process.argv.length; i++) {
	let arg = process.argv[i];
	
	if (arg == "--help" || arg == "-h") {
		printHelp();
		process.exit(0);
	} else if (arg == "--clear" || arg == "-c") {
		printString(0, 0, " ".repeat(FRAMEBUFFER_WIDTH*FRAMEBUFFER_HEIGHT));
		process.exit(0);
	} else if (arg == "-x") {
		x = parseInt(process.argv[i+1]);
		i++;
	} else if (arg == "-y") {
		y = parseInt(process.argv[i+1]);
		i++;
	} else {
		if (string != "") string += " ";
		string += arg;
	}
}

printString(x, y, string);
