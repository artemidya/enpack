set fasmpath=D:\Program Files\FASM
set include=%fasmpath%\include

"%fasmpath%\fasm.exe" WEBP4CDRx86.asm WEBP4CDRx86.obj

..\link\link.exe /DEBUG:NONE /NOIMPLIB /NOEXP /ENTRY:start /MACHINE:X86 /DLL /EXPORT:AttachPlugin /OPT:REF /MERGE:data=.text /MERGE:.flat=.text /MERGE:.data=.text /MERGE:.rdata=.text /MERGE:.pdata=.text /SECTION:.text,ERW /FILEALIGN:512  /RELEASE /SUBSYSTEM:WINDOWS /libpath:"lib" kernel32.lib user32.lib shell32.lib ole32.lib oleaut32.lib ucrt.lib vcruntime.lib libwebp.lib WEBP4CDRx86.obj /OUT:"WEBP4CDRx86.cpg"

del WEBP4CDRx86.obj
pause