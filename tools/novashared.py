# Code shared between different Python utilities for this game

aliases = {}

import_list = set()

# Helper functions
def separateFirstWord(text, lowercaseFirst=True):
	space = text.find(" ")
	command = text
	arg = ""
	if space >= 0:
		command = text[0:space]
		arg = text[space+1:]
	if lowercaseFirst:
		command = command.lower()
	return (command, arg)

def parseNumber(number):
	if number in aliases:
		return parseNumber(aliases[number])
	if number.startswith("$"):
		return int(number[1:], 16)
	return int(number)

def parseMetatileTile(tile, default_base):
	""" Parse the nametable value for one tile """
	value = default_base

	if tile.find(":") >= 0: # Base override
		split = tile.split(":")
		value = parseNumber(split[0])
		tile = split[1]
	value = value//32      # Divide by the bytes per tile to get tile number

	if tile.endswith("_"): # No-op separator
		tile = tile[:-1]

	# Read the tile number in the format of x,y starting from the specified base
	if tile.find(",") >= 0:
		split = [parseNumber(s) for s in tile.split(",")]
		value += split[0]+split[1]*16
	else:
		value += parseNumber(tile)
	return value
