#!/usr/bin/make -f
#
# Makefile for NES game
# Copyright 2011-2015 Damian Yerrick
# Modified by NovaSquirrel
#
# Copying and distribution of this file, with or without
# modification, are permitted in any medium without royalty
# provided the copyright notice and this notice are preserved.
# This file is offered as-is, without any warranty.
#

# These are used in the title of the NES program and the zip file.
title = action53platformer
version = 0.01

# Space-separated list of assembly language files that make up the
# PRG ROM.  If it gets too long for one line, you can add a backslash
# (the \ character) at the end of the line and continue on the next.
objlist = main init bg player leveldata levelcommandtable \
pads ppuclear mapper chrram bankcalltable memory blockdata blockcode \
levelload leveldraw global scrolling

AS65 = ca65
LD65 = ld65
CFLAGS65 = -g
objdir = obj/nes
srcdir = src
imgdir = tilesets

#EMU := "/C/Program Files/Nintendulator/Nintendulator.exe"
EMU := fceux
DEBUGEMU := ~/.wine/drive_c/Program\ Files\ \(x86\)/FCEUX/fceux.exe
# other options for EMU are start (Windows) or xdg--open (Linux)

# Occasionally, you need to make "build tools", or programs that run
# on a PC that convert, compress, or otherwise translate PC data
# files into the format that the NES program expects.  Some people
# write their build tools in C or C++; others prefer to write them in
# Perl, PHP, or Python.  This program doesn't use any C build tools,
# but if yours does, it might include definitions of variables that
# Make uses to call a C compiler.
CC = gcc
CFLAGS = -std=gnu99 -Wall -DNDEBUG -O

# Windows needs .exe suffixed to the names of executables; UNIX does
# not.  COMSPEC will be set to the name of the shell on Windows and
# not defined on UNIX.  Also the Windows Python installer puts
# py.exe in the path, but not python3.exe, which confuses MSYS Make.
ifdef COMSPEC
DOTEXE:=.exe
PY:=py
else
DOTEXE:=
PY:=python3
endif

# Pseudo-targets
.PHONY: run debug dist zip clean

run: $(title).nes
	$(EMU) $<
all: $(title).nes

# Rule to create or update the distribution zipfile by adding all
# files listed in zip.in.  Actually the zipfile depends on every
# single file in zip.in, but currently we use changes to the compiled
# program, makefile, and README as a heuristic for when something was
# changed.  It won't see changes to docs or tools, but usually when
# docs changes, README also changes, and when tools changes, the
# makefile changes.
dist: zip
zip: $(title)-$(version).zip
$(title)-$(version).zip: zip.in $(title).nes $(titlealt).nes README.md CHANGES.txt $(objdir)/index.txt
	zip -9 -u $@ -@ < $<

# Build zip.in from the list of files in the Git tree
zip.in:
	git ls-files | grep -e "^[^.]" > $@
	echo zip.in >> $@

$(objdir)/index.txt: makefile
	echo Files produced by build tools go here, but caulk goes where? > $@

clean:
	-rm $(objdir)/*.o $(objdir)/*.s $(objdir)/*.chr

# Rules for PRG ROM

objlisto = $(foreach o,$(objlist),$(objdir)/$(o).o)
objlistalto = $(foreach o,$(objlistalt),$(objdir)/$(o).o)
levels := $(wildcard levels/*.json)

map.txt $(title).nes: linker.cfg $(objlisto)
	$(LD65) -o $(title).nes --dbgfile $(title).dbg -m map.txt -C $^

$(objdir)/%.o: $(srcdir)/%.s $(srcdir)/nes.inc $(srcdir)/global.inc $(srcdir)/mapper.inc
	$(AS65) $(CFLAGS65) $< -o $@

$(objdir)/%.o: $(objdir)/%.s
	$(AS65) $(CFLAGS65) $< -o $@

# Files that depend on .incbin'd files
$(objdir)/chrram.o: $(objdir)/bggfx.chr $(objdir)/spritegfx.chr

# This is an example of how to call a lookup table generator at
# build time.  mktables.py itself is not included because the demo
# has no music engine, but it's available online at
# http://wiki.nesdev.com/w/index.php/APU_period_table
$(objdir)/ntscPeriods.s: tools/mktables.py
	$< period $@

# Rules for CHR RAM

$(objdir)/%.chr: $(imgdir)/%.png
	$(PY) tools/pilbmp2nes.py $< $@

$(objdir)/%16.chr: $(imgdir)/%.png
	$(PY) tools/pilbmp2nes.py -H 16 $< $@

$(srcdir)/levelcommandtable.s: tools/levelconvert.py
	$(PY) tools/levelconvert.py generate_table
$(srcdir)/leveldata.s: $(srcdir)/levelcommandtable.s tools/levelconvert.py $(levels) $(srcdir)/blockenum.s
	$(PY) tools/levelconvert.py levels
$(srcdir)/blockcode.s: $(srcdir)/blockenum.s
$(srcdir)/blockenum.s: tools/blocks.txt tools/makeblocks.py
	$(PY) tools/makeblocks.py
$(srcdir)/blockdata.s: $(srcdir)/blockenum.s
$(objdir)/player.o: $(srcdir)/blockenum.s
