
INCLUDE "firmware.asm"

SAVE "build/firmware.rom", &8000, &10000
; (image is 32K, even though my current circuit only accesses the second half of it)
