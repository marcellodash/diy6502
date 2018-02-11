@echo Building firmware01 ...
@..\..\beeb_projects\beebasm -i top_firmware01.asm -v > build\firmware01.txt

@copy build\firmware01.rom "E:\p4\eeprommer\Release\firmware01.rom"

@pause
