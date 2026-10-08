format PE64 GUI 4.0 DLL as '8bf'
entry DllEntryPoint
include 'encoding\win1251.inc'
include 'win64w.inc'

prologue@proc equ static_rsp_prologue
epilogue@proc equ static_rsp_epilogue
close@proc equ static_rsp_close

CLSCTX_LOCAL_SERVER =4
ProcessImageFileName=27

DelimiterWidth=8
BufSize       =4096

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
  mov [hInstance],rcx
  mov eax,TRUE
ret

;r12 - RowSize
;rsi - CarvingData
;ebp - MaxWidth
align 32
proc Redraw
  mov eax,ebp
  shr eax,4
  mov rdi,[output.Data]
  mov ecx,[input.PixelCount]
  xor edx,edx
  cmp [ChannelCount],3
  sete dl
  cmp [transposed],0
  jne .transposed
    mov [output.Width],eax
    @@:movsd        ;here may be bug with RGB, but I hope no
       sub rdi,rdx
       add rsi,12
       dec ecx
    jne @b
  jmp .UpdateWindow
  .transposed:
    mov [output.Height],eax
    lea rbx,[rsi+16]
    lea rcx,[rsi+r12]
    @@:movsd
       sub rdi,rdx
       lea rsi,[rsi+r12-4]
       cmp rsi,[input.Mask]
       jb @b
       mov rsi,rbx
       add rbx,16
       cmp rbx,rcx
    jb @b
  .UpdateWindow:
  mov    rsi,[CarvingData]
  invoke InvalidateRect,[hwnds.DrawArea],0,0
  ret
endp

;r12 - RowSize
;rsi - CarvingData
;eax - offset in row (x-coordinate shl 4)
;edx - offset in CarvingData array
;ebp - MaxWidth
align 32
CalcCosts:
  lea       r8,[rdx+16]
  lea       r9,[rdx-16]
  cmp       eax,ebp
  mov       r10,rdx
  cmovnc    r8,rdx
  cmp       eax,16
  mov       r11,rdx
  cmovc     r9,rdx
  sub       r11,r12
  movd      xmm5,[rsi+r8]
  movd      xmm1,[rsi+r9]
  movq      xmm2,qword[int_4_4]
  psubb     xmm5,xmm1
  punpcklbw xmm5,xmm5
  psraw     xmm5,8
  pmaddwd   xmm5,xmm5
  phaddd    xmm5,xmm5
  paddd     xmm5,xmm2
  psrld     xmm5,2
  movd      xmm0,[rsi+r11]
  movd      xmm1,[rsi+r8]
  pshufd    xmm0,xmm0,0
  pinsrd    xmm1,[rsi+r9],1
  movzx     r9,byte[rsi+r10+TCarvingData.mask]
  psubb     xmm0,xmm1
  movq      xmm3,qword[andmask+r9*8]
  movq      xmm4,qword[ormask+r9*8]
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
  movd      r9d,xmm5
  movd      dword[rsi+r10+TCarvingData.costl],xmm0
  mov       [rsi+r10+TCarvingData.costu],r9w
ret

align 32
proc SeamCarving uses rbx rsi rdi rbp r12 r13,Animate
local StartTime:QWORD
  mov  [Animate],rcx
  call [GetTickCount]
  mov  [StartTime],rax

  mov r8d,[ChannelCount]
  mov rsi,[CarvingData]
  mov rdi,[input.Mask]
  mov eax,[input.Width]
  mov edx,[input.Height]
  mov r13d,[NewSize]
  mov [output.Width],eax
  mov [output.Height],edx
  shl eax,4
  shl edx,4
  mov r10,-1
  cmp r8,4
  sbb ecx,ecx
  shl ecx,24
  sub r10,rcx
  cmp [transposed],0
  jne .transposed
    mov  rbp,rax
    mov  ecx,[input.PixelCount]
    mov  ebx,ecx
    imul ebx,r8d
    shl  ecx,2
    add  rbx,[input.Data]
    @@:sub rbx,r8
       mov eax,[rdi+rcx-4]
       mov edx,[rbx]
       and eax,$201
       and rdx,r10
       add al,ah
       mov [rsi+rcx*4-16+TCarvingData.color],edx
       mov [rsi+rcx*4-16+TCarvingData.mask],al
       sub ecx,4
    jne @b
  jmp .Begin
  .transposed:
    mov  rbp,rdx
    mov  rbx,[input.Data]
    sar  ecx,24
    add  ecx,4
    lea  rax,[rsi+rdx]
    mov  r8,rsi
    mov  r9,rax
    @@:mov eax,[rdi]
       add rdi,4
       and eax,$201
       add al,ah
       mov [rsi+TCarvingData.mask],al
       mov eax,[rbx]
       add rbx,rcx
       and rax,r10
       mov [rsi+TCarvingData.color],eax
       add rsi,rdx
       cmp rsi,[input.Mask]
       jb @b
       add r8,16
       mov rsi,r8
       cmp rsi,r9
    jb @b
  .Begin:
  mov    r12,rbp
  mov    rsi,[CarvingData]
  sub    ebp,16
  mov    r9,rbp
  sub    r9,r13
  shl    r9,16
  shl    r13,4
  invoke PostMessageW,[hwnds.ProgressBar],PBM_SETRANGE,0,r9

  mov    edx,ebp
  @@:lea       eax,[edx+16]
     lea       ebx,[edx-16]
     cmp       eax,ebp
     cmovnc    eax,edx
     cmp       edx,16
     cmovc     ebx,edx
     movd      xmm0,[rsi+rax+TCarvingData.color]
     movd      xmm1,[rsi+rbx+TCarvingData.color]
     movzx     rcx,byte[rsi+rdx+TCarvingData.mask]
     psubb     xmm0,xmm1
     punpcklbw xmm0,xmm0
     psraw     xmm0,8
     pmaddwd   xmm0,xmm0
     phaddd    xmm0,xmm0
     movd      eax,xmm0
     add       eax,4
     shr       eax,2
     and       eax,dword[andmask+rcx*8]
     or        eax,dword[ormask+rcx*8]
     mov       [rsi+rdx+TCarvingData.costu],ax
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

  add  rsi,rcx
  neg  rcx
  @@:movzx eax,[rsi+rcx+TCarvingData.costu]
     mov   [rsi+rcx+TCarvingData.cost],eax
     add   rcx,16
  jne @b
  add     ebp,16
  mov     rsi,[CarvingData]
  .Carve:
    sub   ebp,16
    mov   [MaxWidth],ebp
    mov   [MaxWidth+4],ebp
    mov   [MaxWidth+8],ebp
    mov   [MaxWidth+12],ebp
    lea   rdi,[rsi+r12]
    lea   r8,[rbp-32]
    .row:movzx eax,word[rdi+r8+TCarvingData.costl+32]
         movzx ebx,word[rdi+r8+TCarvingData.costu+32]
         add   eax,[rsi+r8+TCarvingData.cost+16]
         add   ebx,[rsi+r8+TCarvingData.cost+32]
         mov   edx,-1
         cmp   ebx,eax
         cmovc eax,ebx
         adc   edx,0
         mov   [rdi+r8+TCarvingData.cost+32],eax
         mov   [rdi+r8+TCarvingData.parent+32],dl
         .col:movzx eax,word[rdi+r8+TCarvingData.costl+16]
              movzx ebx,word[rdi+r8+TCarvingData.costu+16]
              movzx ecx,word[rdi+r8+TCarvingData.costr+16]
              add   eax,[rsi+r8+TCarvingData.cost]
              add   ebx,[rsi+r8+TCarvingData.cost+16]
              add   ecx,[rsi+r8+TCarvingData.cost+32]
              mov   edx,-1
              cmp   ebx,eax
              cmovc eax,ebx
              adc   edx,0
              cmp   ecx,eax
              mov   ebx,1
              cmovc eax,ecx
              cmovc edx,ebx
              mov   [rdi+r8+TCarvingData.cost+16],eax
              mov   [rdi+r8+TCarvingData.parent+16],dl
              sub   r8,16
         jns .col
         movzx eax,word[rdi+TCarvingData.costu]
         movzx ebx,word[rdi+TCarvingData.costr]
         add   eax,[rsi+TCarvingData.cost]
         add   ebx,[rsi+TCarvingData.cost+16]
         xor   edx,edx
         cmp   ebx,eax
         cmovc eax,ebx
         adc   edx,0
         mov   [rdi+TCarvingData.cost],eax
         mov   [rdi+TCarvingData.parent],dl
         add   rdi,r12
         add   rsi,r12
         cmp   rdi,[input.Mask]
         lea   r8,[rbp-32]
    jne .row

    mov ebx,ebp
    mov edx,-1
    @@:cmp   [rsi+rbx+TCarvingData.cost],edx
       cmovc edx,[rsi+rbx+TCarvingData.cost]
       cmovc eax,ebx
       sub   ebx,16
    jns @b

    mov rdi,[Seam]
    @@:stosd
       movsx edx,byte[rsi+rax+TCarvingData.parent]
       sub   rsi,r12
       shl   edx,4
       add   eax,edx
       cmp   rsi,[CarvingData]
    jnc @b

    add  rsi,r12
    mov  rbx,[Seam]
    mov  edi,[input.PixelCount]
    shl  edi,4
    jmp .start
    .RecalcCosts:
      mov   eax,[rbx]
      cmp   ebp,eax
      jbe @f
        lea edx,[edi+eax]
        add edi,ebp
        .RemoveCarve:
            movdqa xmm0,[rsi+rdx+16]
            movdqa [rsi+rdx],xmm0
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
      add   rbx,4
      .start:
      sub   rdi,r12
    jne .RecalcCosts

    mov       edi,[rbx]
    mov       ecx,ebp
    movd      xmm0,edi
    sub       ecx,edi
    jbe @f
      .b3:movdqa xmm1,[rsi+rdi+16]
          movdqa [rsi+rdi],xmm1
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
    movzx     rdi,byte[rsi+rdx+TCarvingData.mask]
    movq      xmm3,qword[andmask+rdi*8]
    movq      xmm4,qword[ormask+rdi*8]
    movd      xmm0,[rsi+rbx]
    pinsrd    xmm0,[rsi+rax],1
    movd      xmm1,[rsi+rdx]
    pinsrd    xmm1,[rsi+rcx],1
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
    mov       [rsi+rax+TCarvingData.costu],bx
    mov       [rsi+rdx+TCarvingData.costu],cx

    invoke    PostMessageW,[hwnds.ProgressBar],PBM_STEPIT,0,0
    cmp       [Animate],0
    je @f
      call Redraw
    @@:

    cmp       rbp,r13
  jne .Carve

  call    [GetTickCount]
  sub     rax,[StartTime]
  invoke  wsprintfW,Buf,fmt,rax
  mov     dword[Buf+rax*2],0
  invoke  SendMessageW,[hwnds.MainDlg],WM_SETTEXT,0,Buf
  invoke  PostMessageW,[hwnds.ProgressBar],PBM_SETPOS,0,0
  call    Redraw
  mov     [CarvingThread],0
  mov     ebx,1
  call    EnableControls
  ret
endp

;ebx - enable flag
proc EnableControls
  mov     rdi,hwnds.DrawArea
  mov     esi,hwnds.len-3
  @@:invoke EnableWindow,dword[rdi+rsi*8],ebx
     dec    esi
  jns @b
  invoke  RedrawWindow,[hwnds.MainDlg],0,0,RDW_INVALIDATE+RDW_INTERNALPAINT+RDW_ALLCHILDREN+RDW_UPDATENOW
  ret
endp

align 32
proc UpdateRegions
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
endp

align 32
;Draws circle with BrushSize radius in a input.Mask RGBA-array
;rax - pointer to POINT struct with coordinate of center
;ebp - color
Circle: ;(var Center: TPoint;color: integer);register;
   movdqa   [rsp-40],xmm6
   movdqa   [rsp-24],xmm7
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

   cvtpi2ps xmm6,[rax]
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

   mov      edx,3
   mov      eax,[BrushSize]
   sub      edx,eax
   sub      edx,eax
   lea      eax,[eax*4+6]
   mov      ecx,6
   .b:movdqa xmm0,xmm6
      shufps xmm0,xmm5,11100100b
      call   .DrawLine
      movdqa xmm0,xmm5
      shufps xmm0,xmm6,11100100b
      call   .DrawLine
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
   movdqa   xmm6,[rsp-40]
   movdqa   xmm7,[rsp-24]
ret

align 32
.DrawLine:
  pextrd   r8d,xmm0,2
  pextrd   r9d,xmm0,3
  add      r8,[input.Mask]
  add      r9,[input.Mask]
  movdqa   xmm3,xmm0
  pxor     xmm2,xmm2
  pmaxsd   xmm0,xmm2
  pminsd   xmm0,xmm4
  pextrd   r10,xmm0,1
  phsubd   xmm0,xmm0
  pextrd   r11,xmm0,0
  movdqa   xmm2,xmm4  
  add      r8,r10
  add      r9,r10
  movsxd   r11,r11d
  psubd    xmm2,xmm3
  pand     xmm2,dqword[signmask]
  pcmpgtd  xmm2,xmm4
  movmskps r10,xmm2
  jmp      [.jmptable+r10*2]
  align 8
  .jmptable dq .both,.bottom,.top,.exit
  .both:
    add r11,4
    mov [r8+r11-4],ebp
    mov [r9+r11-4],ebp
  jle .both
  ret
  .top:
    add r11,4
    mov [r8+r11-4],ebp
  jle .top
  ret
  .bottom:
    add r11,4
    mov [r9+r11-4],ebp
  jle .bottom
  .exit:
ret

align 32
proc DrawAreaProc uses rbx rdi rsi rbp,wnd,msg,wParam,lParam
local FirstLine: DQWORD,SecondLine: DQWORD
  mov    ebx,ecx
  mov    rsi,r8
  mov    rdi,r9
  cmp edx,WM_ERASEBKGND
  je .WM_ERASEBKGND
  cmp edx,WM_PAINT
  je .WM_PAINT
  cmp edx,WM_MOUSEWHEEL
  je .WM_MOUSEWHEEL
  cmp edx,WM_MBUTTONUP
  je .WM_MBUTTONUP
  cmp edx,WM_LBUTTONUP
  je .WM_LBUTTONUP
  cmp edx,WM_LBUTTONDOWN
  je .WM_LBUTTONDOWN
  cmp edx,WM_MBUTTONDOWN
  je .WM_MBUTTONDOWN
  cmp edx,WM_RBUTTONDOWN
  je .WM_RBUTTONDOWN
  cmp edx,WM_MOUSEMOVE
  je .WM_MOUSEMOVE
  cmp edx,WM_CREATE
  je .WM_CREATE
  cmp edx,WM_DESTROY
  je .WM_DESTROY
  call [DefWindowProcW]
  ret
   .WM_MOUSEWHEEL:test r8,MK_CONTROL
                  je @f
                    mov      ecx,[MousePos.x]
                    sar      esi,16
                    sub      ecx,[DelimRect.right]
                    cvtsi2ss xmm0,esi
                    sar      ecx,31
                    mulss    xmm0,[flt_rcp_512] ;/512
                    and      ecx,input-output
                    addss    xmm0,[matrix+40]   ;+1.0
                    pshufd   xmm1,xmm0,0
                    mulss    xmm0,[output.Scale+rcx]
                    comiss   xmm0,[MaxScale]
                    ja .WM_ERASEBKGND
                      cvtpi2ps xmm2,[MousePos]
                      cvtsi2ss xmm3,[output.ClientRect.left+rcx]
                      movaps   xmm4,dqword[output.x+rcx]
                      subps    xmm2,xmm4
                      subss    xmm2,xmm3
                      xorps    xmm2,dqword[chsmaskf]
                      mulps    xmm1,xmm2
                      subps    xmm1,xmm2
                      xorps    xmm1,dqword[chsmaskf]
                      subps    xmm4,xmm1
                      movq     qword[output.x+rcx],xmm4
                      movss    [output.Scale+rcx],xmm0
                      jmp      .GenCircle
                  @@:
                  shr    r8d,31
                  lea    rdx,[r8*4-2]
                  sub    [BrushSize],edx
                  cmovns r8d,[BrushSize]
                  mov    [BrushSize],r8d
                  jmp    .GenCircle
    .WM_MBUTTONUP:
    .WM_LBUTTONUP:call [ReleaseCapture]
                  mov  [DelimFlag],0
                  jmp  .WM_PAINT
  .WM_LBUTTONDOWN:invoke SetCapture,rcx
                  movsx  eax,di
                  sub    eax,[DelimRect.left]
                  cmp    eax,DelimiterWidth
                  setb   byte[DelimFlag]
  .WM_MBUTTONDOWN:
  .WM_RBUTTONDOWN:
    .WM_MOUSEMOVE:invoke SetFocus,ebx
                  movq   xmm0,[MousePos]
                  movsx  eax,di
                  sar    edi,16
                  mov    [MousePos.x],eax
                  mov    [MousePos.y],edi
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
                    mov    ecx,esi
                    sar    eax,31
                    and    ecx,MK_MBUTTON+MK_CONTROL
                    and    eax,input-output
                    cmp    ecx,MK_MBUTTON+MK_CONTROL
                    jne @f
                      movq     xmm1,[MousePos]
                      psubd    xmm1,xmm0
                      cvtdq2ps xmm1,xmm1
                      addps    xmm1,dqword[output.x+rax]
                      movq     qword[output.x+rax],xmm1
                      jmp .SetStdCursor
                    @@:
                    test   eax,eax
                    je .SetStdCursor
                      mov  rax,MousePos
                      cmp  esi,MK_LBUTTON
                      push qword .SetStdCursor
                      mov  ebp,00FF00h
                      je   Circle
                      cmp  esi,MK_RBUTTON
                      mov  ebp,0000FFh
                      je   Circle
                      xor  ebp,ebp
                      cmp  esi,MK_MBUTTON
                      je   Circle
                      add  rsp,8
                  .SetStdCursor:
                    invoke SetCursor,[StdCursor]
                    jmp .WM_PAINT
                  .SetHSizeCursor:
                    invoke SetCursor,[HSizeCursor]
        .WM_PAINT:invoke   glDisable,GL_SCISSOR_TEST
                  invoke   glRasterPos2i,0,0
                  pxor     xmm2,xmm2
                  pxor     xmm3,xmm3
                  pxor     xmm4,xmm4
                  cvtsi2ss xmm5,[output.ClientRect.bottom]
                  subss    xmm4,xmm5
                  invoke   glBitmap,0,0,float xmm2,float xmm3,float xmm2,float xmm4,0
                  movss    xmm0,[flt_16]
                  invoke   glPixelZoom,float xmm0,float xmm0
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
                  invoke   glPixelZoom,float [output.Scale],float eax
                  invoke   glRasterPos2i,0,0
                  cvtsi2ss xmm5,[output.Height]
                  cvtsi2ss xmm4,[output.ClientRect.left]
                  mulss    xmm5,[output.Scale]
                  addss    xmm4,[output.x]
                  subss    xmm5,[output.y]
                  xorps    xmm2,xmm2
                  xorps    xmm3,xmm3
                  invoke   glBitmap,0,0,xmm2,xmm3,float xmm4,float xmm5,0
                  mov      eax,[ChannelCount]
                  add      eax,GL_RGB-3
                  invoke   glDrawPixels,[input.Width],[output.Height],eax,GL_UNSIGNED_BYTE,[output.Data]

                  mov      eax,[input.ClientRect.right]
                  sub      eax,[input.ClientRect.left]
                  invoke   glScissor,0,0,eax,[input.ClientRect.bottom]
                  mov      eax,[input.Scale]
                  xor      eax,80000000h
                  invoke   glPixelZoom,float[input.Scale],float eax
                  invoke   glRasterPos2i,0,0
                  cvtsi2ss xmm4,[input.Height]
                  xorps    xmm0,xmm0
                  mulss    xmm4,[input.Scale]
                  subss    xmm4,[input.y]
                  invoke   glBitmap,0,0,float xmm0,float xmm0,float[input.x],float xmm4,0
                  mov      eax,[ChannelCount]
                  add      eax,GL_RGB-3
                  invoke   glDrawPixels,[input.Width],[input.Height],eax,GL_UNSIGNED_BYTE,[input.Data]

                  invoke   glEnable,GL_COLOR_LOGIC_OP
                  invoke   glLogicOp,GL_OR
                  invoke   glDrawPixels,[input.Width],[input.Height],GL_RGBA,GL_UNSIGNED_BYTE,[input.Mask]
                  invoke   glDisable,GL_COLOR_LOGIC_OP

                  cvtsi2ss xmm0,[MousePos.x]
                  cvtsi2ss xmm1,[MousePos.y]
                  xorps    xmm2,xmm2
                  call     [glTranslatef]
                  invoke   glCallList,1
                  pxor     xmm0,xmm0
                  psubd    xmm0,dqword[MousePos]
                  cvtdq2ps xmm0,xmm0
                  pshufd   xmm1,xmm0,1
                  xorps    xmm2,xmm2
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

                  movdqa   [FirstLine],xmm0
                  movdqa   [SecondLine],xmm1
                  invoke   glBegin,GL_LINES
                  invoke   glVertex2f,float dword[FirstLine],float dword[FirstLine+4]
                  invoke   glVertex2f,float dword[FirstLine+8],float dword[FirstLine+12]
                  invoke   glVertex2f,float dword[SecondLine],float dword[SecondLine+4]
                  invoke   glVertex2f,float dword[SecondLine+8],float dword[SecondLine+12]
                  call     [glEnd]

                  invoke   SwapBuffers,[DC]
                  invoke   ValidateRect,[hwnds.DrawArea],0
   .WM_ERASEBKGND:xor      eax,eax
                  ret
       .WM_CREATE:invoke    GetDC,rcx
                  mov       [DC],rax
                  invoke    ChoosePixelFormat,rax,pfd
                  invoke    SetPixelFormat,[DC],rax,pfd
                  invoke    wglCreateContext,[DC]
                  mov       [RC],rax
                  invoke    wglMakeCurrent,[DC],rax
                  invoke    glColor3i,7FFFFFFFh,0,7FFFFFFFh
                  invoke    glEnable,GL_LINE_STIPPLE
                  invoke    glLineStipple,1,9999h
                  invoke    glLineWidth,float[flt_2]
                  invoke    GetSysColor,COLOR_BTNFACE
                  movd      xmm0,eax
                  punpcklbw xmm0,xmm0
                  punpcklwd xmm0,xmm0
                  psrld     xmm0,24
                  cvtdq2ps  xmm0,xmm0
                  mulps     xmm0,dqword[flt_rcp_255]
                  pshufd    xmm1,xmm0,1
                  pshufd    xmm2,xmm0,2
                  pshufd    xmm3,xmm0,3
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
                  mov       ebx,64
                  @@:fld  st0
                     fsincos
                     fmul  st0,st3
                     fstp  dword[rsp-8]
                     fmul  st0,st2
                     fstp  dword[rsp-4]
                     fadd  st0,st2
                     movss xmm0,[rsp-8]
                     movss xmm1,[rsp-4]
                     call  [glVertex2f]
                     dec   ebx
                  jne @b
                  fninit
                  call      [glEnd]
                  push      qword .WM_PAINT
                  jmp       [glEndList]
      .WM_DESTROY:invoke wglDeleteContext,[RC]
                  invoke DeleteDC,[DC]
  ret
endp

align 32
proc DialogProc uses rbx rdi rsi rbp,wnd,msg,wParam,lParam
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
  ret
  .WM_GETMINMAXINFO:mov [r9+MINMAXINFO.ptMinTrackSize.x],512
                    mov [r9+MINMAXINFO.ptMinTrackSize.y],256
                    ret
        .WM_COMMAND:mov eax,r8d
                    shr eax,16
                    cmp ax,BN_CLICKED
                    je .BN_CLICKED
                    cmp ax,EN_CHANGE
                    je .EN_CHANGE
                    ret
                    .BN_CLICKED:movzx r8,r8w
                                jmp   [.jmptable+r8*8-24]
                                align 8
                                .jmptable dq .Aplpy,.Ok,.Transpose,.Animate
                                    .Aplpy:xor    ebx,ebx
                                           call   EnableControls
                                           invoke SendMessageW,[hwnds.AnimationCheckBox],BM_GETCHECK,0,0
                                           invoke CreateThread,0,4096,SeamCarving,eax,0,0
                                           mov    [CarvingThread],rax
                                           ret
                                       .Ok:invoke EndDialog,rcx,1
                                           ret
                                .Transpose:xor    [transposed],1
                                           mov    ebx,[transposed]
                                           mov    eax,ebx
                                           neg    eax
                                           and    eax,20 ;lenght('по ширине')*2+2
                                           add    eax,TransposeButtonText
                                           invoke SendMessageW,[hwnds.ButtonTranspose],WM_SETTEXT,0,eax
                                           mov    ebx,[input.Width+rbx*4]
                                           dec    ebx
                                           mov    [NewSize],ebx
                                           lea    r9,[rbx+30000h]
                                           invoke SendMessageW,[hwnds.UpDown],UDM_SETRANGE,0,r9
                                           invoke SendMessageW,[hwnds.UpDown],UDM_SETPOS,0,rbx
                                           invoke InvalidateRect,[hwnds.DrawArea],0,0
                                  .Animate:ret
                     .EN_CHANGE:invoke SendMessageW,[hwnds.UpDown],UDM_GETPOS,0,0
                                mov    [NewSize],eax
                                invoke SendMessageW,[hwnds.UpDown],UDM_SETPOS,0,eax
                                invoke InvalidateRect,[hwnds.DrawArea],0,0
                                ret
         .WM_NOTIFY:cmp [r9+NM_UPDOWN.hdr.code],UDN_DELTAPOS
                    jne @f
                      mov    edx,[r9+NM_UPDOWN.iPos]
                      mov    [NewSize],edx
                      invoke InvalidateRect,[hwnds.DrawArea],0,0
                    @@:
                    ret
     .WM_INITDIALOG:mov    [hwnds.MainDlg],rcx
                    mov    rax,[BackTex]
                    mov    r10d,[BackHeight]
                    .row:mov edx,[BackWidth]
                         mov ebx,r10d
                         and ebx,1
                         .col:mov r11d,[Pal+rbx*4]
                              mov [rax],r11d
                              xor ebx,1
                              add rax,4
                              dec edx
                         jne .col
                         dec r10
                    jne .row
                    invoke   MoveWindow,rcx,[rect.left],[rect.top],[rect.right],[rect.bottom],0
                    invoke   GetClientRect,[hwnds.MainDlg],rect
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

                    mov      ebx,hwnds.len-2
                    @@:invoke GetDlgItem,[hwnds.MainDlg],ebx
                       mov    [hwnds+rbx*8+8],rax
                       dec    ebx
                    jne @b
                    invoke   LoadCursorW,0,IDC_ARROW
                    mov      [StdCursor],rax
                    invoke   LoadCursorW,0,IDC_SIZEWE
                    mov      [HSizeCursor],rax
                    mov      r9d,[transposed]
                    neg      r9
                    and      r9,20 ;lenght('по ширине')*2+2
                    add      r9,TransposeButtonText
                    invoke   SendMessageW,[hwnds.ButtonTranspose],WM_SETTEXT,0,r9
                    invoke   PostMessageW,[hwnds.ProgressBar],PBM_SETSTEP,16,0
                    invoke   SendMessageW,[hwnds.UpDown],UDM_SETBUDDY,[hwnds.Edit],0
                    mov      r9d,[transposed]
                    mov      r9d,[input.Width+r9*4]
                    add      r9,2FFFFh
                    invoke   SendMessageW,[hwnds.UpDown],UDM_SETRANGE,0,r9
                    invoke   SendMessageW,[hwnds.UpDown],UDM_SETPOS,0,[NewSize]
                    invoke   SendMessageW,[hwnds.UpDown],UDM_GETPOS,0,0
                    mov      [NewSize],eax
                    invoke   GetClientRect,[hwnds.MainDlg],rect
                    invoke   SetWindowLongPtrW,[hwnds.DrawArea],GWLP_WNDPROC,DrawAreaProc
                    invoke   SendMessageW,[hwnds.DrawArea],WM_CREATE,0,0
           .WM_SIZE:mov      esi,[rect.right]
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
                    mov      eax,1
                    ret
          .WM_CLOSE:invoke EndDialog,rcx,0
                    invoke TerminateThread,[CarvingThread],0
                    ret
endp

align 32
proc FilterEntry uses rbx rsi rdi rbp,selector,FilterRecordPtr,data,result
  mov     rbp,rdx
  mov     word[r9],0
  mov     [result],r9
  jmp     [.jmptable+rcx*8]
  align 8
  .jmptable dq .filterSelectorAbout,.filterSelectorParameters,.filterSelectorPrepare,.filterSelectorStart,.filterSelectorContinue,.filterSelectorFinish
       .filterSelectorStart:movd      xmm0,[rbp+FilterRecord.wholeSize]
                            movzx     ecx,[rbp+FilterRecord.wholeSize.v]
                            movzx     edx,[rbp+FilterRecord.wholeSize.h]
                            cmp       ecx,4
                            mov       rax,errHeight
                            jb        .filterError
                            cmp       edx,4
                            mov       rax,errWidth
                            jb        .filterError
                            movzx     eax,[rbp+FilterRecord.planes]
                            mov       [ChannelCount],eax
                            dec       eax
                            shl       eax,16
                            pxor      xmm1,xmm1
                            pshuflw   xmm3,xmm0,01001111b
                            imul      edx,ecx
                            pshuflw   xmm0,xmm0,11001101b
                            mov       [input.PixelCount],edx
                            mov       dword[rbp+FilterRecord.inLoPlane],eax
                            mov       dword[rbp+FilterRecord.outLoPlane],eax
                            movq      [rbp+FilterRecord.inRect],xmm3
                            movq      [rbp+FilterRecord.outRect],xmm3
                            movq      [rbp+FilterRecord.maskRect],xmm1
                            movd      [NewSize],xmm0
                            movq      qword[input.Width],xmm0
                            movq      qword[output.Width],xmm0
                            call      [rbp+FilterRecord.advanceState]
                            mov       rax,[rbp+FilterRecord.inData]
                            mov       rcx,[rbp+FilterRecord.outData]
                            mov       rdx,[rbp+FilterRecord.platformData]
                            mov       rdx,[rdx]
                            mov       [input.Data],rax
                            mov       [output.Data],rcx
                            mov       [hwnds.Parent],rdx
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
                            lea       edx,[eax+edx*2]
                            mov       [MemSize],edx
                            invoke    VirtualAlloc,0,edx,MEM_COMMIT,PAGE_READWRITE
                            mov       rcx,rax
                            test      rax,rax
                            mov       [CarvingData],rax
                            mov       rax,errNoMem
                            je .filterError
                            mov       edx,[input.PixelCount]
                            shl       edx,2
                            lea       rcx,[rcx+rdx*4]
                            mov       [input.Mask],rcx
                            add       rcx,rdx
                            mov       [Seam],rcx
                            add       rcx,rdx
                            mov       [BackTex],rcx
                            call      [InitCommonControls]
                            invoke    NtQueryInformationProcess,-1,ProcessImageFileName,Buf,BufSize,DC
                            mov       rax,[DC]
                            movdqu    xmm0,dqword[Buf+rax-26]
                            pcmpeqb   xmm0,dqword[CorelDRW]
                            pmovmskb  eax,xmm0
                            inc       ax
                            jne .NoCorel
                              invoke   CoInitialize,eax
                              invoke   GetModuleHandleW,0
                              mov      rbx,rax
                              invoke   FindResourceW,rbx,1,RT_VERSION
                              invoke   LoadResource,rbx,rax
                              invoke   LockResource,rax
                              movzx    eax,byte[rax+50]
                              mov      ecx,10
                              div      cl
                              add      ax,'00'
                              shl      eax,8
                              shr      ax,8
                              mov      [CorelVersion],eax
                              invoke   CLSIDFromProgID,CorelProgID,CorelCLSID
                              test     eax,eax
                              mov      rax,errNoCorel
                              jne .filterError
                              invoke   CoCreateInstance,CorelCLSID,0,CLSCTX_LOCAL_SERVER,IID_IVGApplication,CorelApp
                              cominvk  CorelApp,Get_AppWindow,AppWindow
                              test     eax,eax
                              mov      rax,errSecondInstance
                              jne .filterError
                              cominvk  AppWindow,Get_Handle,DC
                              cominvk  AppWindow,Release
                              mov      rax,[DC]
                              cmp      rax,[hwnds.Parent]
                              mov      rax,errSecondInstance
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
                              sbb      rax,rax
                              inc      rax
                              mov      [transposed],eax
                              neg      rax
                              movzx    eax,[rbp+FilterRecord.wholeSize.h+rax*2]
                              cvtsi2sd xmm0,eax
                              mulsd    xmm0,xmm1
                              cvtsd2si eax,xmm0
                              mov      [NewSize],eax
                              cominvk  Selection,Release
                              call     ShowFilterDialog
                              test     eax,eax
                              je @f
                                cominvk  Shape,GetPosition,ShapePos.X,ShapePos.Y
                                movapd   xmm0,[ShapeSize]
                                cvtpi2pd xmm1,qword[input.Width]
                                cvtpi2pd xmm2,qword[output.Width]
                                mulpd    xmm1,xmm0
                                divpd    xmm1,xmm2
                                movhlps  xmm2,xmm1
                                cominvk  Shape,SetSize,float xmm1,float xmm2
                                cominvk  CorelApp,Get_ActiveLayer,Layer
                                movsd    xmm2,[ShapePos.Y]
                                subsd    xmm2,[ShapeSize.Height]
                                cominvk  Layer,CreateRectangle2,float[ShapePos.X],float xmm2,float[ShapeSize.Width],float[ShapeSize.Height],0,0,0,0,Rectangle
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
                            xor       eax,eax
                            mov       [rbp+FilterRecord.inRect],rax
                            mov       [rbp+FilterRecord.outRect],rax
                            mov       [rbp+FilterRecord.maskRect],rax
       .filterSelectorAbout:
  .filterSelectorParameters:
    .filterSelectorContinue:ret
     .filterSelectorPrepare:mov  eax,1
                            cpuid
                            and  ecx,000000010000000001000000001b ;SSE4.1,SSSE3,SSE3
                            and  edx,110000000001000000000000001b ;SSE,SSE2,CMOV,FPU
                            mov  rax,[rbp+FilterRecord.platformData]
                            add  dl,dl
                            mov  rax,[rax]
                            or   ecx,edx
                            mov  [hwnds.Parent],rax
                            mov  rax,errCPUNotSupported
                            cmp  ecx,110000010001000001000000011b
                            je @f
               .filterError:invoke MessageBoxW,[hwnds.Parent],rax,0,0 ;rax - pointer to error string
                            mov    rax,[result]
                            mov    word[rax],1
      .filterSelectorFinish:invoke TerminateThread,[CarvingThread],0
                            invoke DeleteObject,[StdCursor]
                            invoke DeleteObject,[HSizeCursor]
                            invoke VirtualFree,[CarvingData],[MemSize],MEM_DECOMMIT
                         @@:ret
endp

proc ShowFilterDialog
  invoke   DialogBoxParamW,[hInstance],1,[hwnds.Parent],DialogProc,0
  test     eax,eax
  jne @f
    mov  ecx,[input.PixelCount]
    mov  rsi,[input.Data]
    mov  rdi,[output.Data]
    imul ecx,[ChannelCount]
    add  ecx,3
    shr  ecx,2
    rep  movsd
  @@:
  ret
endp

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
  Mask          rq 1
  Data          rq 1
ends

align 16
Pal                   dd 0FFFFFFh,707070h
BrushSize             dd 10
MaxScale              dd 12.0
flt_rcp_512           dd 0.001953125 ;1/512
delta                 dd 0.09973310011396169010992518677078 ;2*PI/63
flt_16                dd 16.0
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
CarvingThread         rq 1
DC                    rq 1
RC                    rq 1
CorelCLSID            rq 2
MaxWidth              rd 4
output                TPreview
StdCursor             rq 1
input                 TPreview
HSizeCursor           rq 1
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
hInstance             rq 1
CorelApp              IVGApplication
AppWindow             IVGAppWindow
Selection             IVGShapeRange
Shape                 IVGShape
Rectangle             IVGShape
Layer                 IVGLayer
Outline               IVGOutline
CarvingData           rq 1
Seam                  rq 1
BackTex               rq 1
hwnds:
  .Parent            rq 1
  .MainDlg           rq 1
  .DrawArea          rq 1
  .Panel             rq 1
  .ButtonApply       rq 1
  .ButtonOK          rq 1
  .ButtonTranspose   rq 1
  .AnimationCheckBox rq 1
  .ProgressBar       rq 1
  .Edit              rq 1
  .UpDown            rq 1
  .len=($-hwnds)/8
transposed            rd 1
MemSize               rd 1
NewSize               rd 1
ChannelCount          rd 1
DelimFlag             rd 1
BackWidth             rd 1
BackHeight            rd 1