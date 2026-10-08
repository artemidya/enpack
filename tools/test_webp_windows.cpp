// Native Windows fake-host regression tests. No CorelDRAW installed/claimed.
#include "../src/webp4cdr/webp4cdr.cpp"
#include <cstdio>
#include <cstdlib>
#include <thread>
#define CHECK(x) do {if(!(x)){fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#x);exit(1);}}while(0)
struct Empty final:IDataObject {
 ULONG refs=1;
 HRESULT STDMETHODCALLTYPE QueryInterface(REFIID id,void** p) override {if(!p)return E_POINTER;*p=nullptr;if(id==IID_IUnknown||id==IID_IDataObject){*p=this;AddRef();return S_OK;}return E_NOINTERFACE;}
 ULONG STDMETHODCALLTYPE AddRef() override{return ++refs;} ULONG STDMETHODCALLTYPE Release() override{auto n=--refs;if(!n)delete this;return n;}
 HRESULT STDMETHODCALLTYPE GetData(FORMATETC*,STGMEDIUM*) override{return DV_E_FORMATETC;}
 HRESULT STDMETHODCALLTYPE GetDataHere(FORMATETC*,STGMEDIUM*) override{return E_NOTIMPL;}
 HRESULT STDMETHODCALLTYPE QueryGetData(FORMATETC* f) override{return f&&f->cfFormat==CF_HDROP?S_OK:DV_E_FORMATETC;}
 HRESULT STDMETHODCALLTYPE GetCanonicalFormatEtc(FORMATETC*,FORMATETC*) override{return E_NOTIMPL;}
 HRESULT STDMETHODCALLTYPE SetData(FORMATETC*,STGMEDIUM*,BOOL) override{return E_NOTIMPL;}
 HRESULT STDMETHODCALLTYPE EnumFormatEtc(DWORD,IEnumFORMATETC**) override{return E_NOTIMPL;}
 HRESULT STDMETHODCALLTYPE DAdvise(FORMATETC*,DWORD,IAdviseSink*,DWORD*) override{return OLE_E_ADVISENOTSUPPORTED;}
 HRESULT STDMETHODCALLTYPE DUnadvise(DWORD) override{return OLE_E_ADVISENOTSUPPORTED;}
 HRESULT STDMETHODCALLTYPE EnumDAdvise(IEnumSTATDATA**) override{return OLE_E_ADVISENOTSUPPORTED;}
};
IDataObject* data(std::vector<std::wstring> paths){auto* empty=new Empty;auto* result=new DataFiles(empty,std::move(paths));empty->Release();return result;}
struct NativeTarget final:IDropTarget {
 std::atomic<ULONG> refs{1};int enters=0,drops=0,leaves=0;std::vector<std::wstring> received;POINTL position{};
 HRESULT STDMETHODCALLTYPE QueryInterface(REFIID id,void** p) override {if(!p)return E_POINTER;*p=nullptr;if(id==IID_IUnknown||id==IID_IDropTarget){*p=this;AddRef();return S_OK;}return E_NOINTERFACE;}
 ULONG STDMETHODCALLTYPE AddRef() override{return ++refs;}ULONG STDMETHODCALLTYPE Release() override{auto n=--refs;if(!n)delete this;return n;}
 HRESULT STDMETHODCALLTYPE DragEnter(IDataObject* o,DWORD,POINTL p,DWORD* effect) override{++enters;position=p;CHECK(filesFrom(o,received));*effect=DROPEFFECT_COPY;return S_OK;}
 HRESULT STDMETHODCALLTYPE DragOver(DWORD,POINTL,DWORD* effect) override{*effect=DROPEFFECT_COPY;return S_OK;}
 HRESULT STDMETHODCALLTYPE DragLeave() override{++leaves;return S_OK;}
 HRESULT STDMETHODCALLTYPE Drop(IDataObject* o,DWORD,POINTL p,DWORD* effect) override{++drops;position=p;CHECK(filesFrom(o,received));*effect=DROPEFFECT_COPY;return S_OK;}
};
struct Window final:IDispatch {
 ULONG refs=1;HWND window;explicit Window(HWND h):window(h){}
 HRESULT STDMETHODCALLTYPE QueryInterface(REFIID id,void** p) override {if(!p)return E_POINTER;*p=nullptr;if(id==IID_IUnknown||id==IID_IDispatch){*p=this;AddRef();return S_OK;}return E_NOINTERFACE;}
 ULONG STDMETHODCALLTYPE AddRef() override{return ++refs;}ULONG STDMETHODCALLTYPE Release() override{auto n=--refs;if(!n)delete this;return n;}
 HRESULT STDMETHODCALLTYPE GetTypeInfoCount(UINT* p) override{*p=0;return S_OK;}
 HRESULT STDMETHODCALLTYPE GetTypeInfo(UINT,LCID,ITypeInfo**) override{return E_NOTIMPL;}
 HRESULT STDMETHODCALLTYPE GetIDsOfNames(REFIID,LPOLESTR* n,UINT,LCID,DISPID* id) override {if(wcscmp(*n,L"Handle"))return DISP_E_UNKNOWNNAME;*id=1;return S_OK;}
 HRESULT STDMETHODCALLTYPE Invoke(DISPID id,REFIID,LCID,WORD,DISPPARAMS*,VARIANT* v,EXCEPINFO*,UINT*) override {if(id!=1)return E_FAIL;v->vt=VT_I4;v->lVal=LONG(reinterpret_cast<UINT_PTR>(window));return S_OK;}
};
struct App final:IDispatch {
 ULONG refs=1;int subscriptions=0;HWND window=nullptr;
 HRESULT STDMETHODCALLTYPE QueryInterface(REFIID id,void** p) override {if(!p)return E_POINTER;*p=nullptr;if(id==IID_IUnknown||id==IID_IDispatch){*p=this;AddRef();return S_OK;}return E_NOINTERFACE;}
 ULONG STDMETHODCALLTYPE AddRef() override{return ++refs;}ULONG STDMETHODCALLTYPE Release() override{return --refs;}
 HRESULT STDMETHODCALLTYPE GetTypeInfoCount(UINT* p) override{*p=0;return S_OK;}
 HRESULT STDMETHODCALLTYPE GetTypeInfo(UINT,LCID,ITypeInfo**) override{return E_NOTIMPL;}
 HRESULT STDMETHODCALLTYPE GetIDsOfNames(REFIID,LPOLESTR* n,UINT,LCID,DISPID* id) override {
  if(!wcscmp(*n,L"AdviseEvents"))*id=1;else if(!wcscmp(*n,L"UnadviseEvents"))*id=2;else if(!wcscmp(*n,L"Windows"))*id=3;else if(!wcscmp(*n,L"ActiveWindow"))*id=4;else return DISP_E_UNKNOWNNAME;return S_OK;}
 HRESULT STDMETHODCALLTYPE Invoke(DISPID id,REFIID,LCID,WORD,DISPPARAMS* dp,VARIANT* v,EXCEPINFO*,UINT*) override {
  if(id==1){CHECK(dp->cArgs==1&&dp->rgvarg[0].vt==VT_DISPATCH);void* sink=nullptr;CHECK(SUCCEEDED(dp->rgvarg[0].pdispVal->QueryInterface(EventsIID,&sink)));static_cast<IDispatch*>(sink)->Release();++subscriptions;v->vt=VT_I4;v->lVal=17;return S_OK;}
  if(id==2){CHECK(dp->rgvarg[0].lVal==17);--subscriptions;return S_OK;}if(id==4&&window){v->vt=VT_DISPATCH;v->pdispVal=new Window(window);return S_OK;}return E_FAIL;
 }
};
void checkPng(const std::wstring& path){
 Ptr<IWICImagingFactory> factory;Ptr<IWICBitmapDecoder> decoder;Ptr<IWICBitmapFrameDecode> frame;Ptr<IWICFormatConverter> converter;
 CHECK(SUCCEEDED(CoCreateInstance(CLSID_WICImagingFactory,nullptr,CLSCTX_INPROC_SERVER,IID_IWICImagingFactory,reinterpret_cast<void**>(factory.out()))));
 CHECK(SUCCEEDED(factory->CreateDecoderFromFilename(path.c_str(),nullptr,GENERIC_READ,WICDecodeMetadataCacheOnLoad,decoder.out())));
 CHECK(SUCCEEDED(decoder->GetFrame(0,frame.out())));UINT w=0,h=0;CHECK(SUCCEEDED(frame->GetSize(&w,&h)));CHECK(w==4&&h==4);
 CHECK(SUCCEEDED(factory->CreateFormatConverter(converter.out())));CHECK(SUCCEEDED(converter->Initialize(frame.p,GUID_WICPixelFormat32bppBGRA,WICBitmapDitherTypeNone,nullptr,0,WICBitmapPaletteTypeCustom)));
 BYTE pixels[64]{};CHECK(SUCCEEDED(converter->CopyPixels(nullptr,16,64,pixels)));CHECK(pixels[0]==20&&pixels[1]==40&&pixels[2]==200&&pixels[3]==96);
 CHECK(pixels[4]==200&&pixels[5]==40&&pixels[6]==20&&pixels[7]==255);
}
void loadedSmoke(const wchar_t* file,bool webp,const std::wstring& fixtures){
 HMODULE dll=LoadLibraryW(file);if(!dll)fprintf(stderr,"LoadLibrary error %lu\n",GetLastError());CHECK(dll);
 auto attach=reinterpret_cast<int(WINAPI*)(void**)>(GetProcAddress(dll,"AttachPlugin"));CHECK(attach);CHECK(attach(nullptr)==0);
 VGPlugin* p=nullptr;CHECK(attach(reinterpret_cast<void**>(&p))==256&&p);UINT count=99;CHECK(p->GetTypeInfoCount(&count)==S_OK&&count==0);
 CHECK(p->OnLoad(nullptr)==E_POINTER);CHECK(FAILED(p->StartSession()));CHECK(p->StopSession()==S_OK);CHECK(p->OnUnload()==S_OK);
 if(webp){auto version=reinterpret_cast<int(WINAPI*)()>(GetProcAddress(dll,"DecoderVersion"));CHECK(version&&version()==0x010600);App app;
  HWND window=CreateWindowW(L"STATIC",L"Delivered binary",WS_OVERLAPPEDWINDOW,0,0,80,80,nullptr,nullptr,nullptr,nullptr);CHECK(window);auto* native=new NativeTarget;CHECK(RegisterDragDrop(window,native)==S_OK);app.window=window;
  CHECK(p->OnLoad(&app)==S_OK);CHECK(p->StartSession()==S_OK);CHECK(app.subscriptions==1);
  auto* installed=static_cast<IDropTarget*>(GetPropW(window,L"OleDropTargetInterface"));CHECK(installed&&installed!=static_cast<IDropTarget*>(native));
  IDataObject* files=data({fixtures+L"\\alpha.webp"});DWORD effect=1;POINTL point{20,30};CHECK(installed->DragEnter(files,0,point,&effect)==S_OK&&effect==1);CHECK(native->received.size()==1);auto png=native->received[0];checkPng(png);
  CHECK(installed->Drop(files,0,point,&effect)==S_OK&&native->drops==1);files->Release();
  CHECK(p->Invoke(1,IID_NULL,0,DISPATCH_METHOD,nullptr,nullptr,nullptr,nullptr)==S_OK);CHECK(p->StopSession()==S_OK);CHECK(p->OnUnload()==S_OK);CHECK(app.refs==1&&app.subscriptions==0);
  CHECK(GetPropW(window,L"OleDropTargetInterface")==static_cast<IDropTarget*>(native));RevokeDragDrop(window);DestroyWindow(window);CHECK(native->refs==1);native->Release();
  DeleteFileW(png.c_str());RemoveDirectoryW(png.substr(0,png.find_last_of(L"\\")).c_str());}
 FreeLibrary(dll);
}
void filterSmoke(const wchar_t* file){HMODULE dll=LoadLibraryW(file);CHECK(dll);auto entry=reinterpret_cast<void(WINAPI*)(short,void*,void*,short*)>(GetProcAddress(dll,"S"));CHECK(entry);
 short result=99;entry(-1,nullptr,nullptr,&result);CHECK(result==1);entry(99,nullptr,nullptr,&result);CHECK(result==1);entry(0,nullptr,nullptr,&result);CHECK(result==0);entry(3,nullptr,nullptr,&result);CHECK(result==1);entry(0,nullptr,nullptr,nullptr);FreeLibrary(dll);}
LRESULT CALLBACK workerWnd(HWND h,UINT m,WPARAM w,LPARAM l){if(m==WM_CLOSE){RevokeDragDrop(h);DestroyWindow(h);PostQuitMessage(0);return 0;}return DefWindowProcW(h,m,w,l);}
int wmain(int argc,wchar_t** argv){
 CHECK(argc==3);CHECK(SUCCEEDED(OleInitialize(nullptr)));moduleHandle=GetModuleHandleW(nullptr);
 std::wstring fixtures=argv[1],deliverables=argv[2];
 loadedSmoke((deliverables+L"\\WEBP4CDRx64.cpg").c_str(),true,fixtures);loadedSmoke((deliverables+L"\\Bleedsx64.cpg").c_str(),false,fixtures);filterSmoke((deliverables+L"\\SC_x64.8bf").c_str());
 App app;CHECK(plugin.OnLoad(&app)==S_OK);CHECK(plugin.StartSession()==S_OK);CHECK(plugin.Invoke(6,IID_NULL,0,DISPATCH_METHOD,nullptr,nullptr,nullptr,nullptr)==S_OK);CHECK(app.subscriptions==1);
 auto* native=new NativeTarget;auto* proxy=new Target(nullptr,native);
 auto* input=data({fixtures+L"\\alpha.webp",L"C:\\unchanged.png"});DWORD effect=DROPEFFECT_COPY;POINTL point{123,456};
 CHECK(proxy->DragEnter(input,0,point,&effect)==S_OK&&effect==DROPEFFECT_COPY);CHECK(native->enters==1&&native->received.size()==2);CHECK(native->received[1]==L"C:\\unchanged.png");
 std::wstring png=native->received[0];CHECK(!isWebp(png));checkPng(png);CHECK(proxy->Drop(input,0,point,&effect)==S_OK);CHECK(native->drops==1&&native->received[0]==png&&native->position.x==123);input->Release();
 input=data({L"C:\\non-webp.cdr"});effect=1;CHECK(proxy->DragEnter(input,0,point,&effect)==S_OK);CHECK(native->received[0]==L"C:\\non-webp.cdr");CHECK(proxy->DragLeave()==S_OK);input->Release();
 for(auto bad:{L"broken.webp",L"animated.webp",L"missing.webp"}){input=data({fixtures+L"\\"+bad});int before=native->enters;effect=1;CHECK(proxy->DragEnter(input,0,point,&effect)==S_OK&&effect==0);CHECK(native->enters==before);CHECK(proxy->Drop(input,0,point,&effect)==S_OK&&effect==0);input->Release();}
 input=data(std::vector<std::wstring>(9,fixtures+L"\\alpha.webp"));effect=1;CHECK(proxy->DragEnter(input,0,point,&effect)==S_OK&&effect==0);proxy->DragLeave();input->Release();
 uint64_t used=MaxPixels;std::wstring out;CHECK(!convertWebp(fixtures+L"\\alpha.webp",out,used));CHECK(proxy->DragEnter(nullptr,0,point,&effect)==E_POINTER);CHECK(proxy->DragOver(0,point,nullptr)==E_POINTER);
 proxy->Release();CHECK(native->refs==1);native->Release();
 HWND a=CreateWindowW(L"STATIC",L"A",WS_OVERLAPPEDWINDOW,0,0,80,80,nullptr,nullptr,nullptr,nullptr),b=CreateWindowW(L"STATIC",L"B",WS_OVERLAPPEDWINDOW,0,0,80,80,nullptr,nullptr,nullptr,nullptr);CHECK(a&&b);
 auto* na=new NativeTarget;auto* nb=new NativeTarget;CHECK(RegisterDragDrop(a,na)==S_OK);CHECK(RegisterDragDrop(b,nb)==S_OK);
 CHECK(onWindowThread(a,false)==S_OK);CHECK(onWindowThread(b,false)==S_OK);CHECK(onWindowThread(a,false)==S_FALSE);CHECK(targets[a]!=targets[b]);CHECK(targets[a]->original==na&&targets[b]->original==nb);
 CHECK(onWindowThread(a,true)==S_OK);CHECK(GetPropW(a,L"OleDropTargetInterface")==static_cast<IDropTarget*>(na));CHECK(onWindowThread(b,true)==S_OK);CHECK(targets.empty());
 RevokeDragDrop(a);RevokeDragDrop(b);DestroyWindow(a);DestroyWindow(b);CHECK(na->refs==1&&nb->refs==1);na->Release();nb->Release();
 // Thread-affinity bridge: real OLE registration on another STA; no WndProc replacement.
 HANDLE ready=CreateEventW(nullptr,TRUE,FALSE,nullptr);std::atomic<HWND> other{nullptr};
 std::thread thread([&]{CHECK(SUCCEEDED(OleInitialize(nullptr)));WNDCLASSW c{};c.lpfnWndProc=workerWnd;c.lpszClassName=L"WEBP27TestWindow";c.hInstance=moduleHandle;RegisterClassW(&c);
  HWND h=CreateWindowW(c.lpszClassName,L"C",WS_OVERLAPPEDWINDOW,0,0,80,80,nullptr,nullptr,moduleHandle,nullptr);auto* n=new NativeTarget;CHECK(RegisterDragDrop(h,n)==S_OK);other=h;SetEvent(ready);
  MSG m;while(GetMessageW(&m,nullptr,0,0)>0){TranslateMessage(&m);DispatchMessageW(&m);}CHECK(n->refs==1);n->Release();OleUninitialize();});
 CHECK(WaitForSingleObject(ready,5000)==WAIT_OBJECT_0);CHECK(onWindowThread(other,false)==S_OK);CHECK(onWindowThread(other,true)==S_OK);CHECK(requests.empty());PostMessageW(other,WM_CLOSE,0,0);thread.join();CloseHandle(ready);
 CHECK(plugin.StopSession()==S_OK);CHECK(plugin.StopSession()==S_OK);CHECK(plugin.OnUnload()==S_OK);CHECK(app.refs==1&&app.subscriptions==0&&targets.empty());
 // Only test-generated temporary files; production never deletes files still used by host.
 WIN32_FIND_DATAW found{};HANDLE search=FindFirstFileW((tempDirectory+L"\\*").c_str(),&found);if(search!=INVALID_HANDLE_VALUE){do{if(!(found.dwFileAttributes&FILE_ATTRIBUTE_DIRECTORY))DeleteFileW((tempDirectory+L"\\"+found.cFileName).c_str());}while(FindNextFileW(search,&found));FindClose(search);}RemoveDirectoryW(tempDirectory.c_str());
 OleUninitialize();puts("PASS: native loader/exports, event lifecycle, WebP+alpha/WIC, malformed/missing/animated/quota, mixed files, two windows, restore/refcounts, cross-STA bridge. No CorelDRAW UI/geometry tested.");return 0;
}
