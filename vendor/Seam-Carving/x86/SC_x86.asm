format PE GUI 4.0 DLL as '8bf'
entry DllEntryPoint
include 'encoding\win1251.inc'
include 'win32w.inc'

CLSCTX_LOCAL_SERVER =4
ProcessImageFileName=27

DelimiterWidth=8
BufSize       =4096;

section '.rsrc' readable writeable executable

include 'Photoshop.inc'
include '../Resources.inc'
include '../Imports.inc'
include '../CorelDraw.inc'
include '../OpenGL.inc'

data export
    export 0,FilterEntry,'S'
end data

data fixups
end data

DllEntryPoint: ;hinstDLL,fdwReason,lpvReserved
  mov eax,[esp+4]
  mov [hInstance],eax
  mov eax,TRUE
ret 12

;esi - CarvingData
;ebp - MaxWidth
align 32
Redraw:
  mov eax,ebp
  shr eax,4
  mov edi,[output.Data]
  mov ecx,[input.PixelCount]
  xor edx,edx
  cmp [ChannelCount],3
  sete dl
  cmp [transposed],0
  jne .transposed
    mov [output.Width],eax
    @@:movsd        ;here may be bug with RGB, but I hope no
       sub edi,edx
       add esi,12
       dec ecx
    jne @b
  jmp .UpdateWindow
  .transposed:
    mov [output.Height],eax
    mov eax,[RowSize]
    lea ebx,[esi+16]
    lea ecx,[esi+eax]
    @@:movsd
       sub edi,edx
       lea esi,[esi+eax-4]
       cmp esi,[input.Mask]
       jb @b
       mov esi,ebx
       add ebx,16
       cmp ebx,ecx
    jb @b
  .UpdateWindow:
  mov    esi,[CarvingData]
  invoke InvalidateRect,[hwnds.DrawArea],0,0
ret

;esi - CarvingData
;eax - offset in row (x-coordinate shl 4)
;edx - offset in CarvingData array
;ebp - MaxWidth
align 32
CalcCosts:
  pushad
  lea       ebx,[edx+16]
  lea       edi,[edx-16]
  cmp       eax,ebp
  cmovnc    ebx,edx
  cmp       eax,16
  cmovc     edi,edx
  sub       edx,ecx
  add       ecx,edx
  movd      xmm5,[esi+ebx]
  movd      xmm1,[esi+edi]
  movq      xmm2,qword[int_4_4]
  psubb     xmm5,xmm1
  punpcklbw xmm5,xmm5
  psraw     xmm5,8
  pmaddwd   xmm5,xmm5
  phaddd    xmm5,xmm5
  paddd     xmm5,xmm2
  psrld     xmm5,2
  movd      xmm0,[esi+edx]
  movd      xmm1,[esi+ebx]
  pshufd    xmm0,xmm0,0
  pinsrd    xmm1,[esi+edi],1
  movzx     edi,byte[esi+ecx+TCarvingData.mask]
  psubb     xmm0,xmm1
  movq      xmm3,qword[andmask+edi*8]
  movq      xmm4,qword[ormask+edi*8]
  punpcklbw xmm0,xmm0
  psraw     xmm0,8
  pshufd    xmm5,xmm5,0
  pmaddwd   xmm0,xmm0
  phaddd    xmm0,xmm0
  paddd     xmm0,xmm2
  psrld     xmm0,2
  paddd     xmm0,xmm5
  pand      xmm0,xmm3
  por       xmm0,xmm4
  packusdw  xmm0,xmm0
  movd      edi,xmm5
  movd      dword[esi+ecx+TCarvingData.costl],xmm0
  mov       [esi+ecx+TCarvingData.costu],di
  popad
ret

align 32
SeamCarving: ;(Animate: boolean);stdcall;
  call [GetTickCount]
  pushad
    mov esi,[CarvingData]
    mov edi,[input.Mask]
    mov eax,[input.Width]
    mov edx,[input.Height]
    mov [output.Width],eax
    mov [output.Height],edx
    shl eax,4
    shl edx,4
    mov ebp,-1
    cmp [ChannelCount],4
    sbb ecx,ecx
    shl ecx,24
    sub ebp,ecx
    cmp [transposed],0
    jne .transposed
      mov  [RowSize],eax
      mov  ecx,[input.PixelCount]
      mov  ebx,ecx
      imul ebx,[ChannelCount]
      shl  ecx,2
      add  ebx,[input.Data]
      @@:sub ebx,[ChannelCount]
         mov eax,[edi+ecx-4]
         mov edx,[ebx]
         and eax,$201
         and edx,ebp
         add al,ah
         mov [esi+ecx*4-16+TCarvingData.color],edx
         mov [esi+ecx*4-16+TCarvingData.mask],al
         sub ecx,4
      jne @b
    jmp .Begin
    .transposed:
      mov  [RowSize],edx
      mov  ebx,[input.Data]
      sar  ecx,24
      add  ecx,4
      lea  eax,[esi+edx]
      mov  [esp-8],esi
      mov  [esp-4],eax
      @@:mov eax,[edi]
         add edi,4
         and eax,$201
         add al,ah
         mov [esi+TCarvingData.mask],al
         mov eax,[ebx]
         add ebx,ecx
         and eax,ebp
         mov [esi+TCarvingData.color],eax
         add esi,edx
         cmp esi,[input.Mask]
         jb @b
         add dword[esp-8],16
         mov esi,[esp-8]
         cmp esi,[esp-4]
      jb @b
    .Begin:
    shl    [NewSize],4
    mov    ebp,[RowSize]
    mov    esi,[CarvingData]
    sub    ebp,16
    mov    eax,ebp
    sub    eax,[NewSize]
    shl    eax,16
    invoke PostMessageW,[hwnds.ProgressBar],PBM_SETRANGE,0,eax

    mov    edx,ebp
    @@:lea       eax,[edx+16]
       lea       ebx,[edx-16]
       cmp       eax,ebp
       cmovnc    eax,edx
       cmp       edx,16
       cmovc     ebx,edx
       movd      xmm0,[esi+eax+TCarvingData.color]
       movd      xmm1,[esi+ebx+TCarvingData.color]
       movzx     ecx,byte[esi+edx+TCarvingData.mask]
       psubb     xmm0,xmm1
       punpcklbw xmm0,xmm0
       psraw     xmm0,8
       pmaddwd   xmm0,xmm0
       phaddd    xmm0,xmm0
       movd      eax,xmm0
       add       eax,4
       shr       eax,2
       and       eax,dword[andmask+ecx*8]
       or        eax,dword[ormask+ecx*8]
       mov       [esi+edx+TCarvingData.costu],ax
       sub       edx,16
    jns @b

    mov  edx,[input.PixelCount]
    xor  eax,eax
    shl  edx,4
    lea  ecx,[ebp+16]
    @@:sub   edx,16
       sub   eax,16
       cmovs eax,ebp
       call  CalcCosts
       cmp   edx,ecx
    jne @b

    add  esi,ecx
    neg  ecx
    @@:movzx eax,[esi+ecx+TCarvingData.costu]
       mov   [esi+ecx+TCarvingData.cost],eax
       add   ecx,16
    jne @b
    add     ebp,16
    mov     esi,[CarvingData]
    .Carve:
      sub   ebp,16
      mov   [MaxWidth],ebp
      mov   [MaxWidth+4],ebp
      mov   [MaxWidth+8],ebp
      mov   [MaxWidth+12],ebp
      mov   edi,[RowSize]
      add   edi,esi
      sub   ebp,32
      mov   [esp-4],ebp
      .row:movzx eax,word[edi+ebp+TCarvingData.costl+32]
           movzx ebx,word[edi+ebp+TCarvingData.costu+32]
           add   eax,[esi+ebp+TCarvingData.cost+16]
           add   ebx,[esi+ebp+TCarvingData.cost+32]
           mov   edx,-1
           cmp   ebx,eax
           cmovc eax,ebx
           adc   edx,0
           mov   [edi+ebp+TCarvingData.cost+32],eax
           mov   [edi+ebp+TCarvingData.parent+32],dl
           .col:movzx eax,word[edi+ebp+TCarvingData.costl+16]
                movzx ebx,word[edi+ebp+TCarvingData.costu+16]
                movzx ecx,word[edi+ebp+TCarvingData.costr+16]
                add   eax,[esi+ebp+TCarvingData.cost]
                add   ebx,[esi+ebp+TCarvingData.cost+16]
                add   ecx,[esi+ebp+TCarvingData.cost+32]
                mov   edx,-1
                cmp   ebx,eax
                cmovc eax,ebx
                adc   edx,0
                cmp   ecx,eax
                mov   ebx,1
                cmovc eax,ecx
                cmovc edx,ebx
                mov   [edi+ebp+TCarvingData.cost+16],eax
                mov   [edi+ebp+TCarvingData.parent+16],dl
                sub   ebp,16
           jns .col
           movzx eax,word[edi+TCarvingData.costu]
           movzx ebx,word[edi+TCarvingData.costr]
           add   eax,[esi+TCarvingData.cost]
           add   ebx,[esi+TCarvingData.cost+16]
           xor   edx,edx
           cmp   ebx,eax
           cmovc eax,ebx
           adc   edx,0
           mov   [edi+TCarvingData.cost],eax
           mov   [edi+TCarvingData.parent],dl
           mov   ecx,[RowSize]
           add   edi,ecx
           add   esi,ecx
           cmp   edi,[input.Mask]
           mov   ebp,[esp-4]
      jne .row

      add ebp,32
      mov ebx,ebp
      mov edx,-1
      @@:cmp   [esi+ebx+TCarvingData.cost],edx
         cmovc edx,[esi+ebx+TCarvingData.cost]
         cmovc eax,ebx
         sub   ebx,16
      jns @b

      mov edi,[Seam]
      @@:stosd
         movsx edx,byte[esi+eax+TCarvingData.parent]
         sub   esi,ecx
         shl   edx,4
         add   eax,edx
         cmp   esi,[CarvingData]
      jnc @b

      add  esi,ecx
      mov  ebx,[Seam]
      mov  edi,[input.PixelCount]
      shl  edi,4
      jmp .start
      .RecalcCosts:
        mov   eax,[ebx]
        cmp   ebp,eax
        jbe @f
          lea edx,[edi+eax]
          add edi,ebp
          .RemoveCarve:
              movdqa xmm0,[esi+edx+16]
              movdqa [esi+edx],xmm0
              add    edx,16
              cmp    edx,edi
          jne .RemoveCarve
          sub  edi,ebp
          lea  edx,[edi+eax]
          call CalcCosts
        @@:
        sub   eax,16
        js @f
          lea  edx,[edi+eax]
          call CalcCosts
        @@:
        add   ebx,4
        .start:
        sub   edi,ecx
      jne .RecalcCosts

      mov       edi,[ebx]
      mov       ecx,ebp
      movd      xmm0,edi
      sub       ecx,edi
      jbe @f
        .b3:movdqa xmm1,[esi+edi+16]
            movdqa [esi+edi],xmm1
            add    edi,16
            sub    ecx,16
        jne .b3
      @@:
      pxor      xmm3,xmm3
      pshufd    xmm0,xmm0,0
      paddd     xmm0,dqword[int_1_2_1_0]
      pminsd    xmm0,xmm3
      pslld     xmm0,4
      pmaxsd    xmm0,dqword[MaxWidth]
      movd      eax,xmm0
      pextrd    ebx,xmm0,1
      pextrd    ecx,xmm0,2
      pextrd    edx,xmm0,3
      movzx     edi,byte[esi+edx+TCarvingData.mask]
      movq      xmm3,qword[andmask+edi*8]
      movq      xmm4,qword[ormask+edi*8]
      movd      xmm0,[esi+ebx]
      pinsrd    xmm0,[esi+eax],1
      movd      xmm1,[esi+edx]
      pinsrd    xmm1,[esi+ecx],1
      movq      xmm2,qword[int_4_4]
      psubb     xmm0,xmm1
      punpcklbw xmm0,xmm0
      psraw     xmm0,8
      pmaddwd   xmm0,xmm0
      phaddd    xmm0,xmm0
      paddd     xmm0,xmm2
      psrld     xmm0,2
      pand      xmm0,xmm3
      por       xmm0,xmm4
      movd      ebx,xmm0
      pextrd    ecx,xmm0,1
      mov       [esi+eax+TCarvingData.costu],bx
      mov       [esi+edx+TCarvingData.costu],cx

      invoke    PostMessageW,[hwnds.ProgressBar],PBM_STEPIT,0,0
      cmp       dword[esp+36],0 ;Animate
      je @f
        call Redraw
      @@:

      cmp       ebp,[NewSize]
    jne .Carve
    shr     [NewSize],4
    call    [GetTickCount]
    sub     eax,[esp+28]
    cinvoke wsprintfW,Buf,fmt,eax
    mov     dword[Buf+eax*2],0
    invoke  SendMessageW,[hwnds.MainDlg],WM_SETTEXT,0,Buf
    invoke  PostMessageW,[hwnds.ProgressBar],PBM_SETPOS,0,0
    call    Redraw
    mov     [CarvingThread],0
    mov     dword[esp+36],1
    EnableControls:
    mov     edi,hwnds.DrawArea
    mov     esi,hwnds.len-2
    mov     ebx,[esp+36]
    @@:invoke EnableWindow,dword[edi+esi*4-4],ebx
       dec    esi
    jne @b
    invoke  RedrawWindow,[hwnds.MainDlg],0,0,RDW_INVALIDATE+RDW_INTERNALPAINT+RDW_ALLCHILDREN+RDW_UPDATENOW
  popad
ret 4

align 32
UpdateRegions:
  mov      eax,[DelimRect.left]
  mov      edx,[DelimRect.right]
  mov      [input.ClientRect.right],eax
  mov      [output.ClientRect.left],edx
  cvtpi2ps xmm0,qword[output.ClientRect.right]
  movq     xmm1,qword[flt_2]
  divps    xmm1,xmm0
  movss    [matrix],xmm1
  pextrd   eax,xmm1,1
  mov      [matrix+20],eax
  invoke   glLoadMatrixf,matrix
  invoke   glViewport,0,0,[output.ClientRect.right],[output.ClientRect.bottom]
ret

align 16
DrawLine:
  pushad
  pextrd   esi,xmm0,2
  pextrd   edi,xmm0,3
  add      esi,[input.Mask]
  add      edi,[input.Mask]
  movdqa   xmm3,xmm0
  pxor     xmm2,xmm2
  pmaxsd   xmm0,xmm2
  pminsd   xmm0,xmm4
  pextrd   eax,xmm0,1
  phsubd   xmm0,xmm0
  pextrd   ebx,xmm0,0
  movdqa   xmm2,xmm4  
  add      esi,eax
  add      edi,eax
  psubd    xmm2,xmm3
  pand     xmm2,dqword[signmask]
  pcmpgtd  xmm2,xmm4
  movmskps edx,xmm2
  jmp      [.jmptable+edx]
  .both:
    add ebx,4
    mov [esi+ebx-4],ebp
    mov [edi+ebx-4],ebp
  jle .both
  popad
  ret
  .top:
    add ebx,4
    mov [esi+ebx-4],ebp
  jle .top
  popad
  ret
  .bottom:
    add ebx,4
    mov [edi+ebx-4],ebp
  jle .bottom
  .exit:
  popad
ret
align 4
.jmptable dd .both,.bottom,.top,.exit

align 32
Circle: ;(var Center: TPoint;color: integer);register;
   movq     xmm4,qword[input.Width]
   pshufd   xmm4,xmm4,01010000b
   movd     xmm7,[input.Width]
   mov      ecx,1
   pinsrd   xmm7,ecx,1
   pshufd   xmm7,xmm7,0101b
   pslld    xmm7,2
   movd     xmm2,[BrushSize]
   pshufd   xmm2,xmm2,0

   pmulld   xmm4,xmm7
   psubd    xmm4,xmm7

   cvtpi2ps xmm6,[eax]
   movq     xmm0,qword[input.x]
   movd     xmm1,[input.Scale]
   movd     xmm3,[input.Height]
   shufps   xmm1,xmm1,0
   pshufd   xmm3,xmm3,1
   subps    xmm6,xmm0
   divps    xmm6,xmm1
   cvtps2dq xmm6,xmm6
   paddd    xmm6,xmm3

   movdqa   xmm1,dqword[chsmaski]
   pshufd   xmm6,xmm6,01010000b
   pmulld   xmm6,xmm7
   movdqa   xmm5,xmm6

   pxor     xmm7,xmm1
   psubd    xmm7,xmm1
   pmulld   xmm2,xmm7
   psubd    xmm5,xmm2

   push     ebp
   mov      ebp,edx
   mov      edx,3
   mov      eax,[BrushSize]
   sub      edx,eax
   sub      edx,eax
   lea      eax,[eax*4+6]
   mov      ecx,6
   .b:movdqa xmm0,xmm6
      shufps xmm0,xmm5,11100100b
      call   DrawLine
      movdqa xmm0,xmm5
      shufps xmm0,xmm6,11100100b
      call   DrawLine
      add    edx,ecx
      jle @f
         sub   edx,eax
         paddd xmm5,xmm7
         add   edx,10
         sub   eax,4
      @@:
      add   ecx,4
      psubd xmm6,xmm7
      cmp   ecx,eax
    jle .b
    pop     ebp
ret

align 32
DrawAreaProc:
  mov eax,[esp+8]
  cmp eax,WM_ERASEBKGND
  je .WM_ERASEBKGND
  cmp eax,WM_PAINT
  je .WM_PAINT
  cmp eax,WM_MOUSEWHEEL
  je .WM_MOUSEWHEEL
  cmp eax,WM_MBUTTONUP
  je .WM_MBUTTONUP
  cmp eax,WM_LBUTTONUP
  je .WM_LBUTTONUP
  cmp eax,WM_LBUTTONDOWN
  je .WM_LBUTTONDOWN
  cmp eax,WM_MBUTTONDOWN
  je .WM_MBUTTONDOWN
  cmp eax,WM_RBUTTONDOWN
  je .WM_RBUTTONDOWN
  cmp eax,WM_MOUSEMOVE
  je .WM_MOUSEMOVE
  cmp eax,WM_CREATE
  je .WM_CREATE
  cmp eax,WM_DESTROY
  je .WM_DESTROY
  jmp [DefWindowProcW]
   .WM_MOUSEWHEEL:mov  eax,[esp+12]
                  test eax,MK_CONTROL
                  je @f
                    mov      ecx,[MousePos.x]
                    sar      eax,16
                    sub      ecx,[DelimRect.right]
                    cvtsi2ss xmm0,eax
                    sar      ecx,31
                    mulss    xmm0,[flt_rcp_512] ;/512
                    and      ecx,sizeof.TPreview
                    addss    xmm0,[matrix+40]   ;+1.0
                    pshufd   xmm1,xmm0,0
                    mulss    xmm0,[output.Scale+ecx]
                    comiss   xmm0,[MaxScale]
                    ja .WM_ERASEBKGND
                      cvtpi2ps xmm2,[MousePos]
                      cvtsi2ss xmm3,[output.ClientRect.left+ecx]
                      movaps   xmm4,dqword[output.x+ecx]
                      subps    xmm2,xmm4
                      subss    xmm2,xmm3
                      xorps    xmm2,dqword[chsmaskf]
                      mulps    xmm1,xmm2
                      subps    xmm1,xmm2
                      xorps    xmm1,dqword[chsmaskf]
                      subps    xmm4,xmm1
                      movq     qword[output.x+ecx],xmm4
                      movss    [output.Scale+ecx],xmm0
                      jmp      .GenCircle
                  @@:
                  shr    eax,31
                  lea    edx,[eax*4-2]
                  sub    [BrushSize],edx
                  cmovns eax,[BrushSize]
                  mov    [BrushSize],eax
                  jmp    .GenCircle
    .WM_MBUTTONUP:
    .WM_LBUTTONUP:call [ReleaseCapture]
                  mov  [DelimFlag],0
                  jmp  .WM_PAINT
  .WM_LBUTTONDOWN:invoke SetCapture,dword[esp+4]
                  movsx  eax,word[esp+16]
                  sub    eax,[DelimRect.left]
                  cmp    eax,DelimiterWidth
                  setb   byte[DelimFlag]
  .WM_MBUTTONDOWN:
  .WM_RBUTTONDOWN:
    .WM_MOUSEMOVE:invoke SetFocus,dword[esp+4]
                  movq   xmm0,[MousePos]
                  movsx  eax,word[esp+16]
                  movsx  edx,word[esp+18]
                  mov    [MousePos.x],eax
                  mov    [MousePos.y],edx
                  cmp    [DelimFlag],0
                  je @f
                    xor   edx,edx
                    sub   eax,DelimiterWidth/2
                    cmovs eax,edx
                    mov   edx,[rect.right]
                    sub   edx,DelimiterWidth
                    cmp   eax,edx
                    cmova eax,edx
                    mov   [DelimRect.left],eax
                    add   eax,DelimiterWidth
                    mov   [DelimRect.right],eax
                    call  UpdateRegions
                    jmp .WM_PAINT
                  @@:
                  sub    eax,[DelimRect.left]
                  cmp    eax,DelimiterWidth
                  jb .SetHSizeCursor
                    mov    ecx,[esp+12]
                    sar    eax,31
                    and    ecx,MK_MBUTTON+MK_CONTROL
                    and    eax,sizeof.TPreview
                    cmp    ecx,MK_MBUTTON+MK_CONTROL
                    jne @f
                      movq     xmm1,[MousePos]
                      psubd    xmm1,xmm0
                      cvtdq2ps xmm1,xmm1
                      addps    xmm1,dqword[output.x+eax]
                      movq     qword[output.x+eax],xmm1
                      jmp .SetStdCursor
                    @@:
                    test   eax,eax
                    je .SetStdCursor
                      mov  ecx,[esp+12]
                      mov  eax,MousePos
                      cmp  ecx,MK_LBUTTON
                      push dword .SetStdCursor
                      mov  edx,00FF00h
                      je   Circle
                      cmp  ecx,MK_RBUTTON
                      mov  edx,0000FFh
                      je   Circle
                      xor  edx,edx
                      cmp  ecx,MK_MBUTTON
                      je   Circle
                      add  esp,4
                  .SetStdCursor:
                    invoke SetCursor,[StdCursor]
                    jmp .WM_PAINT
                  .SetHSizeCursor:
                    invoke SetCursor,[HSizeCursor]
        .WM_PAINT:invoke   glDisable,GL_SCISSOR_TEST
                  invoke   glRasterPos2i,0,0
                  cvtsi2ss xmm0,[output.ClientRect.bottom]
                  movd     eax,xmm0
                  xor      eax,80000000h
                  invoke   glBitmap,0,0,0,0,0,eax,0
                  invoke   glPixelZoom,16.0,16.0
                  invoke   glDrawPixels,[BackWidth],[BackHeight],GL_RGBA,GL_UNSIGNED_BYTE,[BackTex]
                  invoke   glEnable,GL_SCISSOR_TEST

                  invoke   glScissor,[DelimRect.left],0,DelimiterWidth,[DelimRect.bottom]
                  invoke   glClear,GL_COLOR_BUFFER_BIT

                  cvtsi2ss xmm0,[output.Width]
                  mulss    xmm0,[output.Scale]
                  addss    xmm0,[output.x]
                  cvtss2si eax,xmm0
                  invoke   glScissor,[output.ClientRect.left],0,eax,[output.ClientRect.bottom]
                  mov      eax,[output.Scale]
                  xor      eax,80000000h
                  invoke   glPixelZoom,[output.Scale],eax
                  invoke   glRasterPos2i,0,0
                  cvtsi2ss xmm1,[output.Height]
                  cvtsi2ss xmm0,[output.ClientRect.left]
                  mulss    xmm1,[output.Scale]
                  addss    xmm0,[output.x]
                  subss    xmm1,[output.y]
                  movd     eax,xmm0
                  movd     edx,xmm1
                  invoke   glBitmap,0,0,0,0,eax,edx,0;eax,edx,0
                  mov      eax,[ChannelCount]
                  add      eax,GL_RGB-3
                  invoke   glDrawPixels,[input.Width],[output.Height],eax,GL_UNSIGNED_BYTE,[output.Data]

                  mov      eax,[input.ClientRect.right]
                  sub      eax,[input.ClientRect.left]
                  invoke   glScissor,0,0,eax,[input.ClientRect.bottom]
                  mov      eax,[input.Scale]
                  xor      eax,80000000h
                  invoke   glPixelZoom,[input.Scale],eax
                  invoke   glRasterPos2i,0,0
                  cvtsi2ss xmm0,[input.Height]
                  mulss    xmm0,[input.Scale]
                  subss    xmm0,[input.y]
                  movd     eax,xmm0
                  invoke   glBitmap,0,0,0,0,[input.x],eax,0
                  mov      eax,[ChannelCount]
                  add      eax,GL_RGB-3
                  invoke   glDrawPixels,[input.Width],[input.Height],eax,GL_UNSIGNED_BYTE,[input.Data]

                  invoke   glEnable,GL_COLOR_LOGIC_OP
                  invoke   glLogicOp,GL_OR
                  invoke   glDrawPixels,[input.Width],[input.Height],GL_RGBA,GL_UNSIGNED_BYTE,[input.Mask]
                  invoke   glDisable,GL_COLOR_LOGIC_OP

                  cvtpi2ps xmm0,qword[MousePos]
                  movd     eax,xmm0
                  pextrd   edx,xmm0,1
                  invoke   glTranslatef,eax,edx,0
                  sub      esp,12
                  xor      dword[esp],80000000h
                  xor      dword[esp+4],80000000h
                  invoke   glCallList,1
                  call     [glTranslatef]

                  movd     xmm3,[input.Scale]
                  pshufd   xmm1,dqword[input.Width],01010000b
                  pshufd   xmm2,dqword[NewSize],0
                  pshufd   xmm0,dqword[input.x],00010001b
                  cvtdq2ps xmm1,xmm1
                  cvtdq2ps xmm2,xmm2
                  shufps   xmm3,xmm3,0
                  addsubps xmm1,xmm2
                  xorps    xmm4,xmm4
                  mulps    xmm1,dqword[flt_05]
                  cvtpi2ps xmm4,qword[input.ClientRect.right]
                  mulps    xmm1,xmm3
                  xorps    xmm5,xmm5
                  shufps   xmm1,xmm1,01110010b
                  addsubps xmm0,xmm1

                  cmp      [transposed],0
                  movdqa   xmm1,xmm0
                  je @f
                    shufps   xmm0,xmm4,11001010b
                    shufps   xmm1,xmm4,11000000b
                    pshufd   xmm0,xmm0,01110010b
                    pshufd   xmm1,xmm1,01110010b
                    jmp      .DrawLines
                  @@:
                    shufps   xmm0,xmm4,11010101b
                    shufps   xmm1,xmm4,11011111b
                    pshufd   xmm0,xmm0,11011000b
                    pshufd   xmm1,xmm1,11011000b
                  .DrawLines:

                  sub      esp,32
                  movdqu   [esp],xmm0
                  movdqu   [esp+16],xmm1
                  invoke   glBegin,GL_LINES
                  call     [glVertex2f]
                  call     [glVertex2f]
                  call     [glVertex2f]
                  call     [glVertex2f]
                  call     [glEnd]

                  invoke   SwapBuffers,[DC]
                  invoke   ValidateRect,[hwnds.DrawArea],0
   .WM_ERASEBKGND:xor      eax,eax
                  ret 16
       .WM_CREATE:invoke    GetDC,[hwnds.DrawArea]
                  mov       [DC],eax
                  invoke    ChoosePixelFormat,eax,pfd
                  invoke    SetPixelFormat,[DC],eax,pfd
                  invoke    wglCreateContext,[DC]
                  mov       [RC],eax
                  invoke    wglMakeCurrent,[DC],eax
                  invoke    glColor3i,7FFFFFFFh,0,7FFFFFFFh
                  invoke    glEnable,GL_LINE_STIPPLE
                  invoke    glLineStipple,1,9999h
                  invoke    glLineWidth,2.0
                  invoke    GetSysColor,COLOR_BTNFACE
                  movd      xmm0,eax
                  punpcklbw xmm0,xmm0
                  punpcklwd xmm0,xmm0
                  psrld     xmm0,24
                  cvtdq2ps  xmm0,xmm0
                  mulps     xmm0,dqword[flt_rcp_255]
                  sub       esp,16
                  movups    [esp],xmm0
                  call      [glClearColor]
                  invoke    glPixelStorei,GL_UNPACK_ALIGNMENT,1
                  invoke    glGenLists,1
                  .GenCircle:
                  invoke    glNewList,1,GL_COMPILE
                  invoke    glBegin,GL_LINE_STRIP
                  fninit
                  fld       [delta]
                  fild      [BrushSize]
                  fmul      [input.Scale]
                  fldz
                  mov       ecx,64
                  mov       eax,[glVertex2f]
                  @@:sub  esp,12
                     fld  st0
                     fsincos
                     mov  [esp],eax
                     fmul st0,st3
                     fstp dword[esp+4]
                     fmul st0,st2
                     fstp dword[esp+8]
                     fadd st0,st2
                  loop @b
                  fninit
                  mov       dword[esp+63*12],@f
                  jmp       [glVertex2f]
                  @@:
                  call      [glEnd]
                  push      dword .WM_PAINT
                  jmp       [glEndList]
      .WM_DESTROY:invoke wglDeleteContext,[RC]
                  invoke DeleteDC,[DC]
ret 16

align 32
DialogProc: ; hwnddlg,msg,wparam,lparam
  mov edx,[esp+8]
  xor eax,eax
  cmp edx,WM_COMMAND
  je .WM_COMMAND
  cmp edx,WM_NOTIFY
  je .WM_NOTIFY
  cmp edx,WM_GETMINMAXINFO
  je .WM_GETMINMAXINFO
  cmp edx,WM_SIZE
  je .WM_SIZE
  cmp edx,WM_INITDIALOG
  je .WM_INITDIALOG
  cmp edx,WM_CLOSE
  je .WM_CLOSE
  ret 16
  .WM_GETMINMAXINFO:mov edx,[esp+16]
                    mov [edx+MINMAXINFO.ptMinTrackSize.x],512
                    mov [edx+MINMAXINFO.ptMinTrackSize.y],256
                    ret 16
        .WM_COMMAND:cmp word[esp+14],BN_CLICKED
                    je .BN_CLICKED
                    cmp word[esp+14],EN_CHANGE
                    je .EN_CHANGE
                    ret 16
                    .BN_CLICKED:movzx eax,word[esp+12]
                                jmp   [.jmptable+eax*4-12]
                                align 4
                                .jmptable dd .Aplpy,.Ok,.Transpose,.Animate
                                    .Aplpy:push    0
                                           push    @f
                                           pushad
                                           jmp     EnableControls
                                           @@:
                                           invoke  SendMessageW,[hwnds.AnimationCheckBox],BM_GETCHECK,0,0
                                           invoke  CreateThread,0,4096,SeamCarving,eax,0,0
                                           mov     [CarvingThread],eax
                                           ret 16
                                       .Ok:invoke EndDialog,[esp+8],1
                                           ret 16
                                .Transpose:push   ebx
                                           xor    [transposed],1
                                           mov    ebx,[transposed]
                                           mov    eax,ebx
                                           neg    eax
                                           and    eax,20 ;lenght('по ширине')*2+2
                                           add    eax,TransposeButtonText
                                           invoke SendMessageW,[hwnds.ButtonTranspose],WM_SETTEXT,0,eax
                                           mov    ebx,[input.Width+ebx*4]
                                           dec    ebx
                                           mov    [NewSize],ebx
                                           lea    eax,[ebx+30000h]
                                           invoke SendMessageW,[hwnds.UpDown],UDM_SETRANGE,0,eax
                                           invoke SendMessageW,[hwnds.UpDown],UDM_SETPOS,0,ebx
                                           pop    ebx
                                           invoke InvalidateRect,[hwnds.DrawArea],0,0
                                  .Animate:ret 16
                     .EN_CHANGE:invoke SendMessageW,[hwnds.UpDown],UDM_GETPOS,0,0
                                mov    [NewSize],eax
                                invoke SendMessageW,[hwnds.UpDown],UDM_SETPOS,0,eax
                                invoke InvalidateRect,[hwnds.DrawArea],0,0
                                ret 16
         .WM_NOTIFY:mov edx,[esp+16]
                    cmp [edx+NM_UPDOWN.hdr.code],UDN_DELTAPOS
                    jne @f
                      mov    edx,[edx+NM_UPDOWN.iPos]
                      mov    [NewSize],edx
                      invoke InvalidateRect,[hwnds.DrawArea],0,0
                    @@:
                    ret 16
     .WM_INITDIALOG:pushad
                    mov    edi,[esp+36]
                    mov    [hwnds.MainDlg],edi
                    mov    eax,[BackTex]
                    mov    ecx,[BackHeight]
                    .row:mov edx,[BackWidth]
                         mov ebx,ecx
                         and ebx,1
                         .col:mov esi,[Pal+ebx*4]
                              mov [eax],esi
                              xor ebx,1
                              add eax,4
                              dec edx
                         jne .col
                    loop .row
                    invoke   MoveWindow,edi,[rect.left],[rect.top],[rect.right],[rect.bottom],0
                    invoke   GetClientRect,edi,rect
                    mov      eax,[rect.right]
                    shr      eax,1
                    sub      eax,-DelimiterWidth/2
                    mov      [DelimRect.left],eax
                    add      eax,DelimiterWidth
                    mov      [DelimRect.right],eax
                    mov      eax,[rect.bottom]
                    sub      eax,30
                    mov      [DelimRect.bottom],eax
                    cvtdq2ps xmm0,[DelimRect]
                    cvtpi2ps xmm1,qword[input.Width]
                    shufps   xmm0,xmm0,11001100b
                    movaps   xmm3,xmm0
                    divps    xmm0,xmm1
                    movss    xmm2,xmm0
                    shufps   xmm0,xmm0,1
                    minss    xmm0,xmm2
                    minss    xmm0,[MaxScale]
                    movss    [input.Scale],xmm0
                    movss    [output.Scale],xmm0

                    shufps   xmm0,xmm0,0
                    mulps    xmm0,xmm1
                    xorps    xmm0,dqword[chsmaskf]
                    subps    xmm3,xmm0
                    mulps    xmm3,dqword[flt_05]
                    movq     qword[input.x],xmm3
                    movq     qword[output.x],xmm3

                    mov    esi,hwnds.len-2
                    @@:invoke GetDlgItem,edi,esi
                       mov    [hwnds+esi*4+4],eax
                       dec    esi
                    jne @b
                    invoke   LoadCursorW,0,IDC_ARROW
                    mov      [StdCursor],eax
                    invoke   LoadCursorW,0,IDC_SIZEWE
                    mov      [HSizeCursor],eax
                    mov      eax,[transposed]
                    neg      eax
                    and      eax,20 ;lenght('по ширине')*2+2
                    add      eax,TransposeButtonText
                    invoke   SendMessageW,[hwnds.ButtonTranspose],WM_SETTEXT,0,eax
                    invoke   PostMessageW,[hwnds.ProgressBar],PBM_SETSTEP,16,0
                    invoke   SendMessageW,[hwnds.UpDown],UDM_SETBUDDY,[hwnds.Edit],0
                    mov      eax,[transposed]
                    mov      eax,[input.Width+eax*4]
                    add      eax,2FFFFh
                    invoke   SendMessageW,[hwnds.UpDown],UDM_SETRANGE,0,eax
                    invoke   SendMessageW,[hwnds.UpDown],UDM_SETPOS,0,[NewSize]
                    invoke   SendMessageW,[hwnds.UpDown],UDM_GETPOS,0,0
                    mov      [NewSize],eax
                    invoke   GetClientRect,edi,rect
                    invoke   SetWindowLongW,[hwnds.DrawArea],GWL_WNDPROC,DrawAreaProc
                    invoke   SendMessageW,[hwnds.DrawArea],WM_CREATE,0,0
                    popad
           .WM_SIZE:pushad
                    mov      esi,[rect.right]
                    invoke   GetClientRect,[hwnds.MainDlg],rect
                    sub      [rect.bottom],30
                    mov      ebx,[rect.right]
                    mov      edi,[rect.bottom]
                    mov      eax,[DelimRect.left]
                    mov      [DelimRect.bottom],edi
                    mul      ebx
                    cvtsi2ss xmm0,eax
                    cvtsi2ss xmm1,esi
                    divss    xmm0,xmm1
                    cvtss2si eax,xmm0
                    mov      [DelimRect.left],eax
                    add      eax,DelimiterWidth
                    mov      [DelimRect.right],eax
                    invoke   MoveWindow,[hwnds.Panel],0,edi,ebx,30,0
                    invoke   MoveWindow,[hwnds.DrawArea],0,0,ebx,edi,0
                    invoke   MoveWindow,[hwnds.UpDown],125,edi,20,25,0
                    sub      ebx,115
                    add      edi,2
                    invoke   MoveWindow,[hwnds.Edit],80,edi,43,25,0
                    add      edi,3
                    invoke   MoveWindow,[hwnds.ButtonOK],ebx,edi,110,20,0
                    sub      ebx,115
                    invoke   MoveWindow,[hwnds.ButtonApply],ebx,edi,110,20,0
                    sub      ebx,240
                    invoke   MoveWindow,[hwnds.ProgressBar],232,edi,ebx,20,0
                    invoke   MoveWindow,[hwnds.ButtonTranspose],3,edi,72,20,0
                    add      edi,3
                    invoke   MoveWindow,[hwnds.AnimationCheckBox],155,edi,14,14,0
                    movdqa   xmm0,[rect]
                    movdqa   [input.ClientRect],xmm0
                    movdqa   [output.ClientRect],xmm0
                    call     UpdateRegions
                    invoke   RedrawWindow,[hwnds.MainDlg],0,0,RDW_INVALIDATE+RDW_INTERNALPAINT+RDW_ALLCHILDREN+RDW_UPDATENOW
                    popad
                    mov      eax,1
                    ret 16
          .WM_CLOSE:invoke TerminateThread,[CarvingThread],0
                    invoke EndDialog,dword[esp+8],0
ret 16

align 32
FilterEntry: ;selector: word; FilterRecordPtr: PFilterRecord; data: pdword;res: pword
  pushad
  mov     ebp,[esp+40]
  mov     eax,[esp+48]
  movzx   edx,word[esp+36]
  mov     word[eax],0
  jmp     [.jmptable+edx*4]
  align 4
  .jmptable dd .filterSelectorAbout,.filterSelectorParameters,.filterSelectorPrepare,.filterSelectorStart,.filterSelectorContinue,.filterSelectorFinish
       .filterSelectorStart:movd      xmm0,[ebp+FilterRecord.wholeSize]
                            movzx     ecx,[ebp+FilterRecord.wholeSize.v]
                            movzx     edx,[ebp+FilterRecord.wholeSize.h]
                            cmp       ecx,4
                            mov       eax,errHeight
                            jb        .filterError
                            cmp       edx,4
                            mov       eax,errWidth
                            jb        .filterError
                            movzx     eax,[ebp+FilterRecord.planes]
                            mov       [ChannelCount],eax
                            dec       eax
                            shl       eax,16
                            pxor      xmm1,xmm1
                            pshuflw   xmm3,xmm0,01001111b
                            imul      edx,ecx
                            pshuflw   xmm0,xmm0,11001101b
                            mov       [input.PixelCount],edx
                            mov       dword[ebp+FilterRecord.inLoPlane],eax
                            mov       dword[ebp+FilterRecord.outLoPlane],eax
                            movq      [ebp+FilterRecord.inRect],xmm3
                            movq      [ebp+FilterRecord.outRect],xmm3
                            movq      [ebp+FilterRecord.maskRect],xmm1
                            movd      [NewSize],xmm0
                            movq      qword[input.Width],xmm0
                            movq      qword[output.Width],xmm0
                            call      [ebp+FilterRecord.advanceState]
                            mov       eax,[ebp+FilterRecord.inData]
                            mov       ecx,[ebp+FilterRecord.outData]
                            mov       edx,[ebp+FilterRecord.platformData]
                            mov       edx,[edx]
                            mov       [input.Data],eax
                            mov       [output.Data],ecx
                            mov       [hwnds.Parent],edx

                            invoke    GetSystemMetrics,SM_CXSCREEN
                            shr       eax,1
                            mov       [rect.right],eax
                            shr       eax,1
                            mov       [rect.left],eax
                            shr       eax,2
                            mov       [BackWidth],eax
                            invoke    GetSystemMetrics,SM_CYSCREEN
                            shr       eax,1
                            mov       [rect.bottom],eax
                            shr       eax,1
                            mov       [rect.top],eax
                            shr       eax,2
                            mov       [BackHeight],eax
                            mul       [BackWidth]
                            mov       ebx,eax
                            imul      eax,[input.PixelCount],24 ;sizeof(CarvingData[0])+sizeof(input.Mask[0])+sizeof(Seam[0])
                            lea       eax,[eax+ebx*4]
                            mov       edx,[input.Width]
                            add       edx,[input.Height]
                            lea       eax,[eax+edx*2]
                            mov       [MemSize],eax
                            invoke    VirtualAlloc,0,eax,MEM_COMMIT,PAGE_READWRITE
                            mov       ecx,eax
                            test      eax,eax
                            mov       [CarvingData],eax
                            mov       eax,errNoMem
                            je .filterError
                            mov       edx,[input.PixelCount]
                            shl       edx,2
                            lea       ecx,[ecx+edx*4]
                            mov       [input.Mask],ecx
                            add       ecx,edx
                            mov       [Seam],ecx
                            add       ecx,edx
                            mov       [BackTex],ecx
                            call      [InitCommonControls]
                            invoke    NtQueryInformationProcess,-1,ProcessImageFileName,Buf,BufSize,DC
                            mov       eax,[DC]
                            movdqu    xmm0,dqword[Buf+eax-26]
                            pcmpeqb   xmm0,dqword[CorelDRW]
                            pmovmskb  eax,xmm0
                            inc       ax
                            jne .NoCorel
                              invoke   CoInitialize,eax
                              invoke   GetModuleHandleW,0
                              mov      ebx,eax
                              invoke   FindResourceW,ebx,1,RT_VERSION
                              invoke   LoadResource,ebx,eax
                              invoke   LockResource,eax
                              movzx    eax,byte[eax+50]
                              aam
                              add      ax,'00'
                              rol      ax,8
                              shl      eax,8
                              shr      ax,8
                              mov      [CorelVersion],eax
                              invoke   CLSIDFromProgID,CorelProgID,CorelCLSID
                              test     eax,eax
                              mov      eax,errNoCorel
                              jne .filterError
                              invoke   CoCreateInstance,CorelCLSID,0,CLSCTX_LOCAL_SERVER,IID_IVGApplication,CorelApp
                              cominvk  CorelApp,Get_AppWindow,AppWindow
                              test     eax,eax
                              mov      eax,errSecondInstance
                              jne .filterError
                              cominvk  AppWindow,Get_Handle,DC
                              cominvk  AppWindow,Release
                              mov      eax,[DC]
                              cmp      eax,[hwnds.Parent]
                              mov      eax,errSecondInstance
                              jne .filterError
                              cominvk  CorelApp,Get_ActiveSelectionRange,Selection
                              cominvk  Selection,Get_FirstShape,Shape
                              cominvk  Shape,GetSize,ShapeSize.Width,ShapeSize.Height
                              cominvk  Shape,Get_OriginalWidth,ShapePos.X
                              cominvk  Shape,Get_OriginalHeight,ShapePos.Y
                              movapd   xmm0,[ShapeSize]
                              divpd    xmm0,[ShapePos]
                              pshufd   xmm1,xmm0,01001110b
                              divpd    xmm0,xmm1
                              movhlps  xmm1,xmm0
                              comisd   xmm0,xmm1
                              minsd    xmm1,xmm0
                              sbb      eax,eax
                              inc      eax
                              mov      [transposed],eax
                              neg      eax
                              movzx    eax,[ebp+FilterRecord.wholeSize.h+eax*2]
                              cvtsi2sd xmm0,eax
                              mulsd    xmm0,xmm1
                              cvtsd2si eax,xmm0
                              mov      [NewSize],eax
                              cominvk  Selection,Release
                              call     ShowFilterDialog
                              je @f
                                cominvk  Shape,GetPosition,ShapePos.X,ShapePos.Y
                                movapd   xmm0,[ShapeSize]
                                cvtpi2pd xmm1,qword[input.Width]
                                cvtpi2pd xmm2,qword[output.Width]
                                mulpd    xmm0,xmm1
                                divpd    xmm0,xmm2
                                sub      esp,16
                                movupd   [esp],xmm0
                                cominvk  Shape,SetSize
                                cominvk  CorelApp,Get_ActiveLayer,Layer
                                movapd   xmm0,[ShapeSize]
                                movapd   xmm1,[ShapePos]
                                xorpd    xmm2,xmm2
                                push     Rectangle
                                sub      esp,48
                                movupd   [esp],xmm1
                                xorpd    xmm0,dqword[chsmaskf]
                                addsubpd xmm1,xmm0
                                movupd   [esp+16],xmm1
                                movupd   [esp+32],xmm2
                                cominvk  Layer,CreateRectangle
                                cominvk  Rectangle,Get_Outline,Outline
                                cominvk  Outline,SetNoOutline
                                cominvk  Shape,AddToPowerClip,[Rectangle],0
                                cominvk  Outline,Release
                                cominvk  Rectangle,Release
                                cominvk  Layer,Release
                              @@:
                              cominvk  Shape,Release
                              cominvk  CorelApp,Release
                              jmp .exit
                            .NoCorel:
                              call     ShowFilterDialog
                            .exit:
                            pxor      xmm0,xmm0
                            movq      [ebp+FilterRecord.inRect],xmm0
                            movq      [ebp+FilterRecord.outRect],xmm0
                            movq      [ebp+FilterRecord.maskRect],xmm0
       .filterSelectorAbout:
  .filterSelectorParameters:
    .filterSelectorContinue:popad
                            ret
     .filterSelectorPrepare:mov  eax,1
                            cpuid
                            and  ecx,000000010000000001000000001b ;SSE4.1,SSSE3,SSE3
                            and  edx,110000000001000000000000001b ;SSE,SSE2,CMOV,FPU
                            mov  eax,[ebp+FilterRecord.platformData]
                            add  dl,dl
                            mov  eax,[eax]
                            or   ecx,edx
                            mov  [hwnds.Parent],eax
                            mov  eax,errCPUNotSupported
                            cmp  ecx,110000010001000001000000011b
                            je @f
               .filterError:invoke MessageBoxW,[hwnds.Parent],eax,0,0 ;eax - pointer to error string
                            mov    eax,[esp+48]
                            mov    word[eax],1
      .filterSelectorFinish:invoke TerminateThread,[CarvingThread],0
                            invoke DeleteObject,[StdCursor]
                            invoke DeleteObject,[HSizeCursor]
                            invoke VirtualFree,[CarvingData],[MemSize],MEM_DECOMMIT
                         @@:popad
                            ret

ShowFilterDialog:
  invoke   DialogBoxParamW,[hInstance],1,[hwnds.Parent],DialogProc,0
  test     eax,eax
  jne @f
    mov  ecx,[input.PixelCount]
    mov  esi,[input.Data]
    mov  edi,[output.Data]
    imul ecx,[ChannelCount]
    add  ecx,3
    shr  ecx,2
    rep  movsd
    test eax,eax
  @@:
ret

struct TCarvingData
  color   rd 1
  costu   rw 1
  costl   rw 1
  costr   rw 1
  parent  rb 1
  mask    rb 1
  cost    rd 1
ends

struct TPreview
  ClientRect    RECT
  x             rd 1
  y             rd 1
  Scale         rd 1
  PixelCount    rd 1
  Width         rd 1
  Height        rd 1
  Mask          rd 1
  Data          rd 1
ends

align 16
Pal                   dd 0FFFFFFh,707070h
BrushSize             dd 10
MaxScale              dd 12.0
flt_rcp_512           dd 0.001953125 ;1/512
delta                 dd 0.09973310011396169010992518677078 ;2*PI/63
TransposeButtonText   du 'по ширине',0,'по высоте',0
CorelProgID           du 'CorelDRAW.Application.'
CorelVersion          dd 0
                      dw 0
fmt                   du 'Время выполнения %i мс',0
errCPUNotSupported    du 'Процессор не поддерживается. Требуется поддержка SSE4.1, SSSE3, SSE3, SSE2, SSE, CMOV, FPU.',0
errNoCorel            du 'CorelDraw не зарегистрирован в системе.',0
errSecondInstance     du 'Вероятно запущен второй экземпляр CorelDraw - завершите его.',0
errWidth              du 'Минимальная ширина изображения 4 пикселя.',0
errHeight             du 'Минимальная высота изображения 4 пикселя.',0
errNoMem              du 'Недостаточно оперативной памяти',0
align 16
int_4_4               dd 4,4
flt_2                 dd 2.0,-2.0
andmask               dq $FFFF0000FFFF,0,$FFFF0000FFFF
ormask                dq 0,0,$FFFF0000FFFF
int_1_2_1_0           dd -1,-2,1,0
CorelDRW              du 'CorelDRW'
matrix                dd  1.0,0.0,0.0,0.0,\
                        0.0,1.0,0.0,0.0,\
                        0.0,0.0,1.0,0.0,\
                       -1.0,1.0,0.0,1.0
flt_05                dd 0.5,0.5,0.5,0.5
chsmaskf              dd 0,80000000h,0,80000000h
signmask              dd 0,0,7FFFFFFFh,7FFFFFFFh
chsmaski              dd 0,-1,0,-1
flt_rcp_255           dd 0.0039215686274509803921568627451,0.0039215686274509803921568627451,0.0039215686274509803921568627451,0.0039215686274509803921568627451
pfd                   PIXELFORMATDESCRIPTOR sizeof.PIXELFORMATDESCRIPTOR,1,PFD_DRAW_TO_WINDOW+PFD_SUPPORT_OPENGL+PFD_DOUBLEBUFFER,PFD_TYPE_RGBA,32
DC                    rd 1
RC                    rd 1
CorelCLSID            rq 2
MaxWidth              rd 4
RowSize               rd 1
ChannelCount          rd 1
BackWidth             rd 1
BackHeight            rd 1
output                TPreview
input                 TPreview
rect                  RECT
DelimRect             RECT
Buf                   rb BufSize
ShapeSize:
  .Width   rq 1
  .Height  rq 1
ShapePos:
  .X       rq 1
  .Y       rq 1
MousePos              POINT
StdCursor             rd 1
HSizeCursor           rd 1
NewSize               rd 1
hwnds:
  .Parent            rd 1
  .MainDlg           rd 1
  .DrawArea          rd 1
  .Panel             rd 1
  .ButtonApply       rd 1
  .ButtonOK          rd 1
  .ButtonTranspose   rd 1
  .AnimationCheckBox rd 1
  .ProgressBar       rd 1
  .Edit              rd 1
  .UpDown            rd 1
  .len=($-hwnds)/4
hInstance             rd 1
CorelApp              IVGApplication
AppWindow             IVGAppWindow
Selection             IVGShapeRange
Shape                 IVGShape
Rectangle             IVGShape
Layer                 IVGLayer
Outline               IVGOutline
transposed            rd 1
BackTex               rd 1
MemSize               rd 1
Seam                  rd 1
CarvingData           rd 1
CarvingThread         rd 1
DelimFlag             rd 1