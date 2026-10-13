@echo off
cd /d "%~dp0"
setlocal

set NASM="C:\Users\pc\Downloads\nasm-3.02-win64\nasm-3.02\nasm.exe"
set CC="C:\Users\pc\Downloads\i686-elf-tools-windows\bin\i686-elf-gcc.exe"
set OBJCOPY="C:\Users\pc\Downloads\i686-elf-tools-windows\bin\i686-elf-objcopy.exe"
set QEMU="C:\Program Files\qemu\qemu-system-i386.exe"

taskkill /F /IM qemu-system-i386.exe >nul 2>nul

echo [1/6] Compiling boot.asm...
%NASM% -f bin boot.asm -o boot.bin
if errorlevel 1 ( echo ERROR boot & pause & exit /b 1 )

echo [2/6] Compiling stage2.asm...
%NASM% -f bin stage2.asm -o stage2.bin
if errorlevel 1 ( echo ERROR stage2 & pause & exit /b 1 )

echo [3/6] Compiling kernel_entry.asm...
%NASM% -f elf32 kernel_entry.asm -o kernel_entry.o
if errorlevel 1 ( echo ERROR kernel_entry & pause & exit /b 1 )

echo [4/6] Compiling kernel.c...
%CC% -c kernel.c -o kernel.o -std=gnu99 -ffreestanding -O2 -Wall -Wextra
if errorlevel 1 ( echo ERROR kernel.c & pause & exit /b 1 )

echo [5/6] Linking kernel...
%CC% -T linker.ld -o kernel.elf -ffreestanding -O2 -nostdlib kernel_entry.o kernel.o -lgcc
if errorlevel 1 ( echo ERROR link & pause & exit /b 1 )

%OBJCOPY% -O binary kernel.elf kernel.bin
if errorlevel 1 ( echo ERROR objcopy & pause & exit /b 1 )

echo [6/6] Preparing hdd.img...
if exist hdd.img del hdd.img
if exist hdd.img (
    echo ERROR: Cannot delete hdd.img. Close QEMU first!
    pause
    exit /b 1
)

powershell -Command "$f=[System.IO.File]::Create('hdd.img'); $f.SetLength(10485760); $f.Close()"

powershell -Command "$h=[System.IO.File]::OpenWrite('hdd.img'); $b=[System.IO.File]::ReadAllBytes('boot.bin'); $h.Write($b,0,$b.Length); $s=[System.IO.File]::ReadAllBytes('stage2.bin'); $h.Seek(512,'Begin'); $h.Write($s,0,$s.Length); $k=[System.IO.File]::ReadAllBytes('kernel.bin'); $h.Seek(33*512,'Begin'); $h.Write($k,0,$k.Length); $h.Close()"

echo Starting QEMU with VBE 1024x768x32...
%QEMU% -M pc -boot c -drive format=raw,file=hdd.img
pause
endlocal