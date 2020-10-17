#!/usr/bin/env python3
from novashared import *

# Globals
default_palette = 0
default_base = 0
block = None
blocks_for_interaction_type = {}
all_classes = set()
all_interaction_procs = set()

# Read and process the file
with open("tools/blocks.txt") as f:
    text = [s.rstrip() for s in f.readlines()]

def saveBlock():
	if block == None:
		return
	if block['interaction_type'] not in blocks_for_interaction_type:
		blocks_for_interaction_type[block['interaction_type']] = []
	blocks_for_interaction_type[block['interaction_type']].append(block)

for line in text:
	if not len(line):
		continue
	if line.startswith("#"): # comment
		continue
	if line.startswith("+"): # new block
		saveBlock()
		# Reset to prepare for the new block
		priority = False
		block = {"name": line[1:], "solid": False, "solid_top": False, "palette": default_palette, \
		  "tiles": [], "interaction_routine": None, "interaction_type": "", "class": "None", "autotile": None}
		continue
	word, arg = separateFirstWord(line)
	# Miscellaneous directives
	if word == "alias":
		name, value = separateFirstWord(arg)
		aliases[name] = value

	# Tile info shared with several blocks
	elif word == "base":
		default_base = parseNumber(arg)
	elif word == "palette":
		default_palette = parseNumber(arg)
		block['palette'] = default_palette

	elif word == "when": #Behaviors
		arg = arg.split(", ")
		block['interaction_type'] = arg[0]
		block['interaction_routine'] = arg[1]
		all_interaction_procs.add(arg[1])
	elif word == "autotile":
		block["autotile"] = arg
		all_interaction_procs.add(arg)
	elif word == "class":
		block["class"] = arg
		all_classes.add(arg)

	# Specifying tiles and tile attributes
	elif word == "solid":
		block["solid"] = True
	elif word == "solid_top":
		block["solid_top"] = True
	elif word == "t": # add tiles
		split = arg.split(" ")
		for tile in split:
			block["tiles"].append(parseMetatileTile(tile, default_base))
	elif word == "q": # add four tiles at once
		tile = parseMetatileTile(arg, default_base)
		block["tiles"] = [tile, tile+1, tile+16, tile+17]

# Save the last one
saveBlock()

# Process all the interaction types
all_blocks = []
id = 0
firstlast_interactions = ''
for interaction_type in sorted(blocks_for_interaction_type.keys()): # Will put "" first	
	if len(interaction_type):
		firstlast_interactions += 'BlockFirst%s = %d\n' % (interaction_type, id)
	for block in blocks_for_interaction_type[interaction_type]:
		all_blocks.append(block)
		id += 1
	if len(interaction_type):
		firstlast_interactions += 'BlockLast%s = %d\n' % (interaction_type, id-1)

# Generate the output that's actually usable in the game
outfile = open("src/blockdata.s", "w")

outfile.write('; This is automatically generated. Edit "blocks.txt" instead\n')
outfile.write('.include "blockenum.s"\n\n')
outfile.write('.export BlockTopLeft, BlockTopRight, BlockBottomLeft, BlockBottomRight\n')
outfile.write('.export BlockPalette, BlockFlags\n')
outfile.write('.import %s\n' % str(", ".join(all_interaction_procs)))
outfile.write('\n.segment "BlockData"\n\n')

# Block appearance information
corners = ["TopLeft", "TopRight", "BottomLeft", "BottomRight"]
for corner, cornername in enumerate(corners):
	outfile.write(".proc Block%s\n" % cornername)
	for b in all_blocks:
		outfile.write('  .byt $%.2x ; %s\n' % (b['tiles'][corner], b['name']))
	outfile.write(".endproc\n\n")

# Palette is separate on the NES
palette_four_times = ["%00000000", "%01010101", "%10101010", "%11111111"]
outfile.write(".proc BlockPalette\n")
for b in all_blocks:
	outfile.write('  .byt %s ; %s\n' % (palette_four_times[b['palette']], b['name']))
outfile.write(".endproc\n\n")

outfile.write('.proc BlockFlags\n')
for b in all_blocks:
	outfile.write('  .byt $%x|BlockClass::%s ; %s\n' % (b['solid'] * 0x80 + b['solid_top'] * 0x40, b['class'], b['name']))
outfile.write('.endproc\n\n')

# Write all interaction type tables
for interaction, blocks in blocks_for_interaction_type.items():
	if not len(interaction):
		continue
	outfile.write(".export BlockInteraction%s\n" % interaction)
	outfile.write(".proc BlockInteraction%s\n" % interaction)
	for b in blocks:
		outfile.write('  .addr (%s-1)\n' % b['interaction_routine'])
	outfile.write(".endproc\n\n")

"""
# Write all the autotile settings
outfile.write('.segment "LevelDecompress"\n\n')

outfile.write('.export BlockAutotile\n')
outfile.write('.proc BlockAutotile\n')
for b in all_blocks:
	if b['autotile']:
		outfile.write('  .addr .loword(%s - 1)\n' % b['autotile'])
	else:
		outfile.write('  .addr 0\n')
outfile.write('.endproc\n\n')
"""

outfile.close()

# Generate the enum in a separate file
outfile = open("src/blockenum.s", "w")
outfile.write('; This is automatically generated. Edit "blocks.txt" instead\n')
outfile.write('.enum Block\n')
for i, b in enumerate(all_blocks):
	outfile.write('  %s = %d\n' % (b['name'], i))
outfile.write('.endenum\n\n')

# Generate the class enum
outfile.write('.enum BlockClass\n')
outfile.write('  None\n')
for b in all_classes:
	outfile.write('  %s\n' % b)
outfile.write('.endenum\n\n')

# First and last items in the ranges for interactions
outfile.write(firstlast_interactions+"\n")

outfile.close()
