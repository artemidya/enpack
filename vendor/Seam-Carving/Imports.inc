data import
  library ntdll,'NTDLL.DLL',\
          kernel,'KERNEL32.DLL',\
          user,'USER32.DLL',\
          ole,'OLE32.dll',\
          gdi,'GDI32.DLL',\
          comctl,'COMCTL32.DLL',\
          OpenGL,'OPENGL32.DLL'

  import ntdll,\
         NtQueryInformationProcess,'NtQueryInformationProcess'

  import kernel,\
         GetModuleHandleW,'GetModuleHandleW',\
         FindResourceW,'FindResourceW',\
         LoadResource,'LoadResource',\
         LockResource,'LockResource',\
         GetTickCount,'GetTickCount',\
         VirtualAlloc,'VirtualAlloc',\
         VirtualFree,'VirtualFree',\
         CreateThread,'CreateThread',\
         TerminateThread,'TerminateThread'

  import user,\
         DialogBoxParamW,'DialogBoxParamW',\
         EnableWindow,'EnableWindow',\
         GetSystemMetrics,'GetSystemMetrics',\
         GetClientRect,'GetClientRect',\
         MoveWindow,'MoveWindow',\
         PostMessageW,'PostMessageW',\
         SendMessageW,'SendMessageW',\
         GetDlgItem,'GetDlgItem',\
         MessageBoxW,'MessageBoxW',\
         RedrawWindow,'RedrawWindow',\
         GetDC,'GetDC',\
         SetCapture,'SetCapture',\
         SetFocus,'SetFocus',\
         ReleaseCapture,'ReleaseCapture',\
         SetCursor,'SetCursor',\
         GetSysColor,'GetSysColor',\
         ValidateRect,'ValidateRect',\
         InvalidateRect,'InvalidateRect',\
         SetWindowLongW,'SetWindowLongW',\
         SetWindowLongPtrW,'SetWindowLongPtrW',\
         LoadCursorW,'LoadCursorW',\
         EndDialog,'EndDialog',\
         DefWindowProcW,'DefWindowProcW',\
         wsprintfW,'wsprintfW'

  import ole,\
         CoInitialize,'CoInitialize',\
         CLSIDFromProgID,'CLSIDFromProgID',\
         CoCreateInstance,'CoCreateInstance'

  import gdi,\
         ChoosePixelFormat,'ChoosePixelFormat',\
         SetPixelFormat,'SetPixelFormat',\
         DeleteObject,'DeleteObject',\
         DeleteDC,'DeleteDC',\
         SwapBuffers,'SwapBuffers'

  import comctl,\
         InitCommonControls,'InitCommonControls'

  import OpenGL,\
         wglMakeCurrent,'wglMakeCurrent',\
         wglCreateContext,'wglCreateContext',\
         wglDeleteContext,'wglDeleteContext',\
         glColor3i,'glColor3i',\
         glEnable,'glEnable',\
         glEnd,'glEnd',\
         glEndList,'glEndList',\
         glDisable,'glDisable',\
         glLineStipple,'glLineStipple',\
         glLineWidth,'glLineWidth',\
         glClearColor,'glClearColor',\
         glPixelStorei,'glPixelStorei',\
         glGenLists,'glGenLists',\
         glNewList,'glNewList',\
         glBegin,'glBegin',\
         glVertex2f,'glVertex2f',\
         glRasterPos2i,'glRasterPos2i',\
         glBitmap,'glBitmap',\
         glPixelZoom,'glPixelZoom',\
         glDrawPixels,'glDrawPixels',\
         glScissor,'glScissor',\
         glClear,'glClear',\
         glLogicOp,'glLogicOp',\
         glTranslatef,'glTranslatef',\
         glCallList,'glCallList',\
         glLoadMatrixf,'glLoadMatrixf',\
         glViewport,'glViewport'
end data