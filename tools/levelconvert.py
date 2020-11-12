import json, glob, os, sys, math

ColDataPointerTypes = ["SIGNPOST", "STORY_DIALOG_TRIGGER"]; # list of object types whose extra data is a pointer
PrizeContainingTypes = ["PRIZE", "BRICKPRIZE"]; # list of object types whose extra data is an inventory type
FGControlTypes = ["COLUMN_DATA", "COLUMN_POINTER", "BLOCK_CONTENTS", "TELEPORT"];

SingleTypes = {
	"Bricks", "Prize", "Rock", "Spring", "Heart", "Money", "PickupBlock", "PushableBlock", "DoorTop", "DoorExit",
	"Lock1", "Lock2", "Lock3", "Lock4", "Key1", "Key2", "Key3", "Key4", "SmallHeart", "CeilingBarrier",
	"WoodArrowLeft", "WoodArrowDown", "WoodArrowUp", "WoodArrowRight", "MetalArrowLeft", "MetalArrowDown", "MetalArrowUp", "MetalArrowRight", "WoodCrate", "MetalCrate",
	"SmallBushTop", "BigBushUL", "TreetopUL",
	"BigFlower1", "BigFlower2", "BigFlower3", "BigFlower4",
	"Flower1A", "Flower1B", "Flower2A", "Flower2B", "Flower3A", "Flower3B", "Flower4A", "Flower4B"
}
RectTypes = {
	"Bricks", "Terrain", "StoneSingle", "Money", "SolidBlock", "PickupBlock",
	"WoodCrate", "MetalCrate", "CeilingBarrier",
	"Ice", "Ice2", "GrayBricks", "WaterMiddle",
	"Leaves", "BrickFence"
}
LineTypes = {
	"Bricks", "Terrain", "Prize", "Spring", "Ladder", "SmallBushTop", "PierTop", "WhiteFenceMiddle",
	"FloatingPlatform", "FloatingPlatformFallthrough", "Spikes", "Vine", "Vine2", "Vine3", "Fence", "WoodPlatformMiddle",
	"JungleBridge", "TallGrass", "Bomb", "Trunk"
}

def Hex(n):
	return '$%x' % n

def FindCommandFor(type, w, h, x, y):
	if w == 1 and h == 1 and type in SingleTypes:
		return "LSingle SingleEnum::%s, %d, %d" % (type, x, y)
	elif w <= 16 and h <= 16 and type in RectTypes:
		return "LRect RectEnum::%s, %d, %d, %d, %d" % (type, x, y, w-1, h-1)
	elif type in LineTypes:
		if w == 1 and h <= 16:
			return "LTall LineEnum::%s, %d, %d, %d" % (type, x, y, h-1)
		if h == 1 and w <= 16:
			return "LWide LineEnum::%s, %d, %d, %d" % (type, x, y, w-1)
		return "LBigRect LineEnum::%s, %d, %d, %d, %d" % (type, x, y, w-1, h-1)
	return None

# Return an array containing all rectangles in a layer, matching a given list of types
def FindType(Array, Types):
	return [x for x in Array if x.type in Types]

class Rect(object):
	def __init__(self, j, z=None):
		self.type = j['Id']
		self.x = j['X']
		self.y = j['Y']
		self.z = z
		if 'W' in j:
			self.w = j['W']
		else:
			self.w = 1
		if 'H' in j:
			self.h = j['H']
		else:
			self.h = 1
		self.xflip = 'XFlip' in j
		self.yflip = 'YFlip' in j
		self.extra = ''
		if 'Extra' in j:
			self.extra = j['Extra']

	def __repr__(self):
		return '%s %d,%d %dx%d' % (self.type, self.x, self.y, self.w, self.h)

	def overlaps(self, other):
		if self.x > (other.x+other.w-1):
			return False
		if (self.x+self.w-1) < other.x:
			return False
		if self.y > (other.y+other.h-1):
			return False
		if (self.y+self.h-1) < other.y:
			return False
		return True

def ExportLevel(filename):
	print("Converting %s" % filename)
	level_file = open(filename+'.json')
	level_text = level_file.read()
	level_file.close()
	level_json = json.loads(level_text)

	# Strip that slash off
	slash = filename.rfind('\\')
	if slash == -1:
		slash = filename.rfind('/')
	if slash != -1:
		without_dir = filename[slash+1:]
	else:
		without_dir = filename
	print(without_dir)

	FG = []
	for z in range(len(level_json["Layers"][0]["Data"])):
		FG.append(Rect(level_json["Layers"][0]["Data"][z], z))
	SP = [Rect(x) for x in level_json["Layers"][1]["Data"]]
	CT = [Rect(x) for x in level_json["Layers"][2]["Data"]]

	Header = level_json['Header']
	Config = None
	if 'Config' in level_json:
		Config = level_json['Config']

	if len(SP) > 84:
		print("Too many sprites! You have "+(len(SP)-84)+" too many.")
		return False

	Width = level_json['Meta']['Width']
	Height = level_json['Meta']['Height']

	# Find boundaries
	# a b c d e f g h i j k l m n o L
	# 0|1|2|3|4|5|6|7|8|9|A|B|C|D|E|F
	Boundaries = 0;
	def SetBoundaryAt(Screen):
		if Screen < 1 or Screen > 16:
			return
		Bit = 1 << (16-Screen)
		return Boundaries | Bit

	HScreens = Width//16
	VScreens = Height//15
	UseLinks = VScreens > 1

	ManualScreenLinks = FindType(CT, ["SCREEN_LINK"]);
	ManualScreenList = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
	UseManualScreenLinks = len(ManualScreenLinks) > 0;

	for R in ManualScreenLinks:
		Args = R.extra.split(',')
		Top = Args[1]
		Bottom = Args[2]
		ThisScreen = R.x // 16
		TopScreen = 0
		BottomScreen = 0

		# Search for links
		for R2 in ManualScreenLinks:
			Name = R2.extra.split(',')[0]
			if Name == Top:
				TopScreen = ((R2.x//16) - ThisScreen) & 15
			if Name == Bottom:
				BottomScreen = ((R2.x//16) - ThisScreen) & 15
		ManualScreenList[ThisScreen] = (TopScreen<<4) | BottomScreen

	# Find all scroll locks
	for R in CT:
		if R.type == "SCROLL_LOCK":
			Screen = (R.x//16) + (R.y//15)*HScreens
			if (R.x&15) == 15:
				Boundaries = SetBoundaryAt(Screen+1)
			else:
				Boundaries = SetBoundaryAt(Screen)

	# Rearrange level into a big horizontal strip
	# To do: allow the user to skip certain screens
	if VScreens > 1:
		for List in [FG, SP, CT]:
			for R in List:
				V = R.y // 15
				R.x += V*Width
				R.y %= 15

	# Find player start position
	StartX = 0
	StartY = 0
	FacingLeft = 0
	PlayerPos = FindType(CT, ["PLAYER_START_L", "PLAYER_START_R"])
	if len(PlayerPos):
		StartX = PlayerPos[0].x
		StartY = PlayerPos[0].y
		if PlayerPos[0].type == "PLAYER_START_L":
			FacingLeft = 64

	# Merge FG control types into FG
	FG.extend(FindType(CT, FGControlTypes))

	# Sort by X position first
	FG = sorted(FG, key=lambda r: r.x)
	SP = sorted(SP, key=lambda r: r.x)
	CT = sorted(CT, key=lambda r: r.x)

	# Open the output file
	outfile = open(filename + ".s", "w")
	outfile.write(".segment \"LevelData\"\n")
	outfile.write(without_dir+":\n")

	# write music, start X, screens and Y position
	# .d.mmmmm
	#  | +++++- music
	#  +------- if 1, player starts facing left
	outfile.write("  .byt MusicTracks::"+Header['Music']+"|"+str(FacingLeft)+"\n");
	outfile.write("  .byt "+str(StartX)+"\n");
	outfile.write("  .byt "+Hex((((Width//16)-1)<<4) | (StartY-1))+"\n");

	# write sprite graphics slots
	for i in range(4):
		outfile.write("  .byt GraphicsUpload::"+Header['SpriteGFX'][i]+"\n");

	# write pointers to the foreground and sprite data
	outfile.write("  .addr "+without_dir+"Data\n");
	outfile.write("  .addr "+without_dir+"Sprite\n");
 
	# write background
	outfile.write("  .byt "+Hex(Header['BGColor'])+" ; background\n");

	# write graphics upload list
	for i in Header['GFXUpload']:
		outfile.write("  .byt GraphicsUpload::"+i+"\n");
	outfile.write("  .byt 255 ;end\n")

	# write boundaries
	if UseLinks or UseManualScreenLinks:
		Boundaries |= 1
	outfile.write("  .byt $%.2x, $%.2x ; boundaries\n" % (Boundaries>>8, Boundaries&255));

	# write links if used
	if UseManualScreenLinks:
		# to do, allow runs of the same link
		for i in range(16):
			outfile.write(format("  .byt $%.2x, $%.2x ; link\n" % (0, ManualScreenList[i])))
	elif UseLinks:
		for i in range(VScreens):
			Up = ((-HScreens)&15)<<4
			Down = HScreens
			if i == 0:
				Up = 0
			if i == VScreens-1:
				Down = 0
			outfile.write("  .byt $%.2x, $%.2x ; link\n" % ((HScreens-1)&15, Up|Down))
		if HScreens*VScreens != 16: # Fill out any unused screens
			outfile.write("  .byt $%.2x, $00\n" % (16-(HScreens*VScreens)-1)&15)

	# Do the data section
	outfile.write('\n%sData:\n' % without_dir)

	# Rearrange foreground layer
	for i in range(len(FG)):
		r1 = FG[i]
		for j in range(i):
			r2 = FG[j]
			if r1.z and r2.z and r1.overlaps(r2) and r1.z < r2.z:
				FG[i], FG[j] = FG[j], FG[i]

	# Write all level FG commands
	LastX = 0
	for R in FG:
		# Adjust the X position
		XDifference = R.x - LastX;
		if XDifference == 16:
			outfile.write('  LXPlus16\n')
			XDifference = 0
		elif XDifference < 32 and XDifference >= 16:
			outfile.write('  LXPlus16\n')
			XDifference -= 16
		elif XDifference == -16:
			outfile.write('  LXMinus16\n')
			XDifference = 0
		elif XDifference >= 16 or XDifference < 0:
			outfile.write('  LSetX %d\n' % R.x)
			XDifference = 0
		LastX = R.x

		# Control layer types that got merged into the FG layer get written too
		if R.type in FGControlTypes:
			outfile.write('  LSetX %d\n' % R.x)
			XDifference = 0
			if R.type == "BLOCK_CONTENTS" or R.type == "COLUMN_DATA":
				outfile.write("  LWriteCol  %s\n" % R.extra)
			elif R.type == "COLUMN_POINTER":
				outfile.write("  LWriteCol  <%s, >%s\n" % (R.extra, R.extra))
		else:
			Command = FindCommandFor(R.type, R.w, R.h, XDifference, R.y)
			if Command == None:
				print("No command found for %s of size %i, %i" % (R[R.type], R[R.w], R[R.h]))
			outfile.write("  %s\n" % Command)

		# Add extra data
		if R.extra:
			Dashes = R.extra.split('-')
			Commas = R.extra.split(',')
			if R.type == "MINE_TRACK_BRAKES":
				outfile.write("  LWriteCol "+R.extra+"\n");
			elif R.type == "CLONER":
				outfile.write("  LWriteCol Enemy::"+R.extra+"\n");
			elif R.type == "CLONE_SWITCH":
				for R2 in CT:
					if R2.type == "TELEPORT_DESTINATION":
						if R2.extra == R.extra:
							outfile.write("  LWriteCol %d\n" % R2.x)
			elif R.type in PrizeContainingTypes:
				outfile.write("  LWriteCol InventoryItem::%s\n" % R.extra)
			elif R.type in ColDataPointerTypes:
				outfile.write("  LWriteCol <%s, >%s\n" % (R.extra, R.extra))

			elif R.type in ["TELEPORT", "DOOR", "TELEPORTER"]:
				if len(Dashes) == 2: # A-B, two paired doors
					Found = False
					for R2 in FG:
						IsTeleporter = R2.type == "TELEPORTER"
						if R2.type == "DOOR" or IsTeleporter:
							Dashes2 = R2.extra.split('-')
							if len(Dashes2) == 2 and Dashes2[0] == Dashes[1]:
								outfile.write("  LWriteCol "+str(R2.y-int(IsTeleporter))+", "+str(R2.x)+"\n")
								Found = True
					if not Found:
						for R2 in CT:
							if R2.type == "TELEPORT_DESTINATION":
								if R2.extra == Dashes[1]:
									outfile.write("  LWriteCol %d, %d\n" % (R2.y, R2.x))
									Found = True
					if not Found:
						print("Destination door %s not found" % Dashes[1])
				elif len(Commas) == 2: # X, Y
					outfile.write("  LWriteCol %s,%s\n" % (Commas[0], Commas[1]))
				elif len(Commas) == 3: # X, Y, Level
					outfile.write("  LWriteCol $10|"+Commas[0]+", "+Commas[1]+", LevelId::"+Commas[2]+"\n")
				elif R.extra[0] == "*": # script
					outfile.write("  LWriteCol $20, <"+R.extra[1:]+", >"+R.extra[1:]+"\n")
				elif len(Commas) == 1 and len(Dashes) == 1:
					outfile.write("  LWriteCol $21, LevelId::"+R.extra+"\n")
				else:
					print("Bad door data: "+R.extra)

	# Write background changes
	BGChanges = FindType(CT, ["BACKGROUND"])
	for i in range(len(BGChanges)):
		NextX = HScreens*VScreens
		ThisX = BGChanges[i].x//16
		if i != len(BGChanges)-1:
			NextX = BGChanges[i+1].x // 16
		if BGChanges[i].extra:
			outfile.write("  .byt LSpecialCmd, LevelSpecialConfig::MAKE_BACKGROUNDS, $%.2x, LevelBackgroundId::%s\n" % ((ThisX<<4)|(NextX-ThisX-1), BGChanges[i].extra))
	for R in FindType(CT, ["LEVEL_EFFECT"]):
		outfile.write("  .byt LSpecialCmd, LevelSpecialConfig::%s\n" % R.extra)
	outfile.write("  LFinished\n\n")

	# Write the list of sprites
	outfile.write(".segment \"LevelSpriteData\"\n")
	outfile.write("%sSprite:\n" % without_dir)

	for sprite in SP:
		if sprite.extra:
			outfile.write("  LSpr Enemy::%-20s %i, %3i, %3i, %s\n" % (sprite.type+",", int(sprite.xflip), sprite.x, sprite.y, sprite.extra))
		else:
			outfile.write("  LSpr Enemy::%-20s %i, %3i, %3i\n" % (sprite.type+",", int(sprite.xflip), sprite.x, sprite.y))
	outfile.write("  .byt 255 ; end\n")
	outfile.close()
	return True

if len(sys.argv) != 2:
	print("Do one of the following:")
	print("levelconvert.py level.json")
	print("levelconvert.py directory_name")
	print("levelconvert.py generate_table")
else:
	if sys.argv[1].lower() == 'generate_table':
		ListSingleTypes = list(SingleTypes)
		ListRectTypes = list(RectTypes)
		ListLineTypes = list(LineTypes)

		table_file = open('src/levelcommandtable.s', 'w')
		table_file.write('; This is automatically generated. Edit "levelconvert.py" instead\n')
		table_file.write('.include "blockenum.s"\n\n')
		table_file.write(".segment \"CODE\"\n")

		index = 0

		table_file.write(".export FirstSingleType, SingleTypeList\n")
		table_file.write("FirstSingleType = %d\n" % index)
		table_file.write("SingleTypeList:\n")
		for i in ListSingleTypes:
			table_file.write("  .byt Block::%s\n" % i)
			index += 1

		table_file.write(".export FirstRectType, SimpleRectList\n")
		table_file.write("FirstRectType = %d\n" % index)
		table_file.write("SimpleRectList:\n")
		for i in ListRectTypes:
			table_file.write("  .byt Block::%s\n" % i)
			index += 1

		table_file.write(".export FirstWideType, FirstTallType, FirstBigRectType, LineTypeList\n")
		table_file.write("FirstWideType = %d\n" % index)
		table_file.write("LineTypeList:\n")
		for i in ListLineTypes:
			table_file.write("  .byt Block::%s\n" % i)
			index += 1

		# How many command IDs to use up on line commands
		LineCommandCount = int(math.ceil(len(ListLineTypes)/16))

		table_file.write("FirstTallType = %d\n" % index)
		index += LineCommandCount

		table_file.write("FirstBigRectType = %d\n" % index)
		index += LineCommandCount

		table_file.close()

		# -----------------------------

		enum_file = open('src/levelcommandenum.s', 'w')
		enum_file.write('; This is automatically generated. Edit "levelconvert.py" instead\n')

		enum_file.write(".enum SingleEnum\n")
		for i in ListSingleTypes:
			enum_file.write("  %s\n" % i)
		enum_file.write(".endenum\n")

		enum_file.write(".enum RectEnum\n")
		for i in ListRectTypes:
			enum_file.write("  %s\n" % i)
		enum_file.write(".endenum\n")

		enum_file.write(".enum LineEnum\n")
		for i in ListLineTypes:
			enum_file.write("  %s\n" % i)
		enum_file.write(".endenum\n")

		enum_file.close()
	elif os.path.isdir(sys.argv[1]):
		for f in glob.glob(sys.argv[1]+"/*.json"):
			basename = os.path.splitext(f)[0]
			need = False
			if not os.path.exists(basename+".s"):
				need = True
			else:
				src = os.path.getmtime(basename+".json")
				dst = os.path.getmtime(basename+".s")
				if src > dst:
					need = True
			if need:
				ExportLevel(basename)
	elif os.path.isfile(sys.argv[1]):
		basename = os.path.splitext(sys.argv[1])[0]
		ExportLevel(basename)
	else:
		print("'%s' not a file or directory" % sys.argv[1])
