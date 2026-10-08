data resource
  ;FASM has no support for named entries, so I make it by hand
  root@resource dd 0,%t,0,010001h
                dd 80000000h+strpipl-root@resource,80000000h+pipl-root@resource
                dd RT_DIALOG,80000000h+dialogs-root@resource
           pipl dd 0,%t,0,000001h
                dd 80000000h+strpipl-root@resource,80000000h+$+4-root@resource
                dd 0,%t,0,10000h
                dd 0,pipldata-root@resource
        dialogs dd 0,%t,0,10000h
                dd 1,80000000h+$+4-root@resource
                dd 0,%t,0,10000h
                dd 0,MainDlg-root@resource

  strpipl du 4,'PIPL'
  align 4

  dialog MainDlg,'',0,0,0,0,DS_MODALFRAME+WS_MAXIMIZEBOX+WS_MINIMIZEBOX+WS_POPUP+WS_VISIBLE+WS_CAPTION+WS_SYSMENU+WS_THICKFRAME
   dialogitem 'STATIC'           ,''                                                                 ,1,  11,77, 385, 172, SS_LEFT+WS_CHILD+WS_VISIBLE+WS_GROUP
   dialogitem 'STATIC'           ,'                                                         Анимация',2,   1, 1, 409,  21, SS_LEFT+SS_CENTERIMAGE+WS_CHILD+WS_VISIBLE+WS_TABSTOP
   dialogitem 'BUTTON'           ,'Применить'                                                        ,3, 295, 4,  50,  11, BS_PUSHBUTTON+WS_CHILD+WS_VISIBLE+WS_TABSTOP
   dialogitem 'BUTTON'           ,'OK'                                                               ,4, 355, 4,  50,  11, BS_DEFPUSHBUTTON+WS_CHILD+WS_VISIBLE+WS_DISABLED+WS_TABSTOP
   dialogitem 'BUTTON'           ,''                                                                 ,5,   3, 2,  41,  11, BS_PUSHBUTTON+BS_FLAT+WS_CHILD+WS_VISIBLE+WS_TABSTOP
   dialogitem 'BUTTON'           ,''                                                                 ,6,  87, 1,  10,  14, BS_AUTOCHECKBOX+WS_CHILD+WS_VISIBLE+WS_TABSTOP
   dialogitem 'msctls_progress32',''                                                                 ,7, 135, 1,  10,  13, WS_CHILD+WS_VISIBLE+WS_TABSTOP
   dialogitem 'EDIT'             ,''                                                                 ,8,  47, 6,  25,  14, ES_LEFT+ES_NUMBER+WS_CHILD+WS_VISIBLE+WS_BORDER+WS_TABSTOP
   dialogitem 'msctls_updown32'  ,''                                                                 ,9,  71, 1,  10,  13, UDS_SETBUDDYINT+UDS_ARROWKEYS+UDS_NOTHOUSANDS+WS_CHILD+WS_VISIBLE+WS_TABSTOP
  enddialog

  resdata pipldata
   PIPL PIKindProperty,kFilter,\
     PINameProperty,'Seam Carving',\
     PICategoryProperty,'tiny filters',\
     PIVersionProperty,40000h,\
     PIWin32X86CodeProperty,'S',\
     PIImageModesProperty,supportsCMYKColor+supportsRGBColor
  endres
end data
