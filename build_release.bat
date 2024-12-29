@echo off

odin build . -out:escape.exe -strict-style -vet -no-bounds-check -o:speed -subsystem:windows