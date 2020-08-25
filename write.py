#!/usr/bin/env python3
# Import lxbuildenv to integrate the deps/ directory
import os,os.path,shutil,sys,subprocess
sys.path.insert(0, os.path.dirname(__file__))
import lxbuildenv

from litex.tools.remote.comm_usb import CommUSB
from math import floor
import argparse
import sys

CSR_VGA_FB = 0x00003800
CSR_VGA_FB_PAGE = 0x00003004
FRAMEBUFFER_WIDTH = 80
FRAMEBUFFER_HEIGHT = 30

def print_string(client, x, y, string):
	for char in string:
		if char == "\n":
			y += 1
			x = 0
		else:
			address = y * FRAMEBUFFER_WIDTH + x
			page = floor(address / 512)
			offset = address % 512
			
			client.write(CSR_VGA_FB_PAGE, page)
			client.write(CSR_VGA_FB + offset*4, ord(char))
			
			x += 1
		
		if x >= FRAMEBUFFER_WIDTH - 1:
			y += 1
			x = 0
		
		if y >= FRAMEBUFFER_HEIGHT - 1:
			y = 0
	
	return (x, y)

def fill(client, char):
	print_string(client, 0, 0, char * (FRAMEBUFFER_WIDTH * FRAMEBUFFER_HEIGHT))

def clear(client):
	fill(client, " ")

def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("string", nargs="*")
	parser.add_argument("-x", default=0, type=int, help="x position, default 0")
	parser.add_argument("-y", default=0, type=int, help="y position, default 0")
	parser.add_argument("-c", "--clear", action="store_true", help="clear the screen")
	args = parser.parse_args()
	
	client = CommUSB()
	client.open()
	
	if args.clear:
		clear(client)
	elif args.string:
		string = " ".join(args.string)
		print_string(client, args.x, args.y, string)
	else:
		x = args.x
		y = args.y
		for line in sys.stdin:
			x, y = print_string(client, x, y, line)
	
	client.close()

if __name__ == "__main__":
	main()
