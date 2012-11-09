setlocal
set aiddir=%CD%\..\aid
set appdir=%CD%\..\aimsgui
%aiddir%\Nt\386\bin\emu.exe -r%aiddir% -c0 -g640x480 -f/fonts/vera/vera/vera.10.font -pmain=12000000 -pheap=12000000 -pimage=12000000 hostapp %appdir% load aimsgui/aimsgui -i %RANDOM% -s audio3
endlocal
