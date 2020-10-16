#!/usr/bin/env python3
from novashared import *

# Globals
default_palette = 0
default_base = 0
block = None
all_blocks = []
all_classes = set()
all_interaction_procs = set()
all_interaction_sets = []

# Read and process the file
with open("tools/blocks.txt") as f:
    text = [s.rstrip() for s in f.readlines()]

def saveBlock():
	if block == None:
		return
	if block['interaction'] != {}:
		# If there is already a interaction set that matches, use that one
		# otherwise add a new one
		if block['interaction'] not in all_interaction_sets:
			all_interaction_sets.append(block['interaction'])
		block['interaction_set'] = all_interaction_sets.index(block['interaction']) + 1 # + 1 because zero is no interaction

	all_blocks.append(block)

for line in text:
	if not len(line):
		continue
	if line.startswith("#"): # comment
		continue
	if line.startswith("+"): # new block
		saveBlock()
		# Reset to prepare for the new block
		priority = False
		block = {"name": line[1:], "solid": False, "solid_top": False, "palette": 0, \
		  "tiles": [], "interaction": {}, "interaction_set": 0, "class": "None", "autotile": None}
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

	elif word == "when": #Behaviors
		arg = arg.split(", ")

		# Aliases for selecting multiple interaction types at once
		if arg[0] == "Touch":
			arg[0] = ("InsideBody", "InsideHead", "Above", "Below", "Side")
		elif arg[0] == "SolidCheck":
			arg[0] = ("InsideHead", "Above", "Below", "Side", "ActorTopBottom", "ActorSide")
		elif arg[0] == "PlayerSolidCheck":
			arg[0] = ("InsideHead", "Above", "Below", "Side")
		elif arg[0] == "ActorSolidCheck":
			arg[0] = ("ActorTopBottom", "ActorSide")
		elif arg[0] == "Inside":
			arg[0] = ("InsideBody", "InsideHead")
		else:
			arg[0] = (arg[0],)
		for i in arg[0]:
			block["interaction"][i] = arg[1]
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

# Generate the output that's actually usable in the game
outfile = open("src/blockdata.s", "w")

outfile.write('; This is automatically generated. Edit "blocks.txt" instead\n')
outfile.write('.include "blockenum.s"\n\n')
outfile.write('.export BlockTopLeft, BlockTopRight, BlockBottomLeft, BlockBottomRight\n')
outfile.write('.export BlockPalette, BlockFlags\n')
outfile.write('.import %s\n' % str(", ".join(all_interaction_procs)))
outfile.write('\n.segment "BlockGraphicData"\n\n')

# Block appearance information
corners = ["TopLeft", "TopRight", "BottomLeft", "BottomRight"]
for corner, cornername in enumerate(corners):
	outfile.write(".proc Block%s\n" % cornername)
	for b in all_blocks:
		outfile.write('  .byt $%.2x ; %s\n' % (b['tiles'][corner], b['name']))
	outfile.write(".endproc\n\n")

palette_four_times = ["%00000000", "%01010101", "%10101010", "%11111111"]
outfile.write(".proc BlockPalette\n")
for b in all_blocks:
	outfile.write('  .byt %s ; %s\n' % (palette_four_times[b['palette']], b['name']))
outfile.write(".endproc\n\n")

# Write block interaction information
outfile.write('.segment "BlockInteraction"\n\n')

outfile.write('.proc BlockFlags\n')
for b in all_blocks:
	outfile.write('  .byt %d, $%x|BlockClass::%s ; %s\n' % (b['interaction_set'], \
	  b['solid'] * 0x80 + b['solid_top'] * 0x40, b['class'], b['name']))
outfile.write('.endproc\n\n')

outfile.write(".proc BlockNothing\n  rts\n.endproc\n\n")

print("Interaction sets: %d" % len(all_interaction_sets))

# Write all interaction type tables corresponding to each interaction set
interaction_types = ["Above", "Below", "Side", "InsideHead", "InsideBody", "ActorInside", "ActorTopBottom", "ActorSide"]
for interaction in interaction_types:
	outfile.write(".export BlockInteraction%s\n" % interaction)
	outfile.write(".proc BlockInteraction%s\n" % interaction)
	outfile.write('  .addr .loword(BlockNothing)\n') # Empty interaction set
	for b in all_interaction_sets:
		if interaction in b:
			outfile.write('  .addr .loword(%s)\n' % b[interaction])
		else:
			outfile.write('  .addr .loword(BlockNothing)\n')
	outfile.write(".endproc\n\n")

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

outfile.close()

# Generate the enum in a separate file
outfile = open("src/blockenum.s", "w")
outfile.write('; This is automatically generated. Edit "blocks.txt" instead\n')
outfile.write('.enum Block\n')
for i, b in enumerate(all_blocks):
	outfile.write('  %s = %d\n' % (b['name'], i*2))
outfile.write('.endenum\n\n')

# Generate the class enum
outfile.write('.enum BlockClass\n')
outfile.write('  None\n')
for b in all_classes:
	outfile.write('  %s\n' % b)
outfile.write('.endenum\n\n')

outfile.close()
