// WEBP4CDR27: safe per-window OLE adapter; no Corel document mutations.
// Based on the purpose/interface of fersatgit/WEBP4CDR, reimplemented in C++.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <ole2.h>
#include <shellapi.h>
#include <shlobj.h>
#include <wincodec.h>
#include <shlwapi.h>
#include <webp/decode.h>
#include <atomic>
#include <algorithm>
#include <memory>
#include <mutex>
#include <string>
#include <vector>
#include <map>
#include <limits>

namespace {
HMODULE moduleHandle;
const GUID PluginIID={0xb0580005,0x9aa4,0x44fd,{0x95,0x47,0x4f,0x91,0xeb,0x75,0x7a,0xc4}};
const GUID EventsIID={0xb05800c5,0x9aa4,0x44fd,{0x95,0x47,0x4f,0x91,0xeb,0x75,0x7a,0xc4}};
constexpr uint64_t MaxPixels=16ull*1024*1024, MaxInput=64ull*1024*1024;
constexpr unsigned MaxFiles=8, MaxWindows=256;
std::atomic<bool> enabled{false};
std::mutex tempLock;
std::wstring tempDirectory;
uint64_t tempBytes=0;
unsigned tempCount=0;
void note(const wchar_t* text) noexcept { OutputDebugStringW(text); }

// Outbound variants are owned; input VARIANT arguments are borrowed.
struct V { VARIANT v; V(){VariantInit(&v);} ~V(){VariantClear(&v);} V(const V&)=delete; };
template<class T> struct Ptr {
 T* p=nullptr; ~Ptr(){if(p)p->Release();} T** out(){return &p;} T* operator->(){return p;}
};
HRESULT call(IDispatch* p,const wchar_t* name,WORD flags,VARIANT* argument,VARIANT* result) {
 if(!p)return E_POINTER; LPOLESTR n=const_cast<LPOLESTR>(name); DISPID id;
 HRESULT hr=p->GetIDsOfNames(IID_NULL,&n,1,LOCALE_USER_DEFAULT,&id); if(FAILED(hr))return hr;
 DISPPARAMS dp={argument,nullptr,argument?1u:0u,0}; EXCEPINFO ex{}; UINT bad=0;
 hr=p->Invoke(id,IID_NULL,LOCALE_USER_DEFAULT,flags,&dp,result,&ex,&bad);
 SysFreeString(ex.bstrSource);SysFreeString(ex.bstrDescription);SysFreeString(ex.bstrHelpFile);return hr;
}
HRESULT property(IDispatch* p,const wchar_t* n,V& result) {return call(p,n,DISPATCH_PROPERTYGET,nullptr,&result.v);}
IDispatch* dispatch(V& v) {return v.v.vt==VT_DISPATCH?v.v.pdispVal:nullptr;}
bool isWebp(const std::wstring& s) {return s.size()>=5 && _wcsicmp(s.c_str()+s.size()-5,L".webp")==0;}

bool filesFrom(IDataObject* object,std::vector<std::wstring>& paths) {
 paths.clear();
 FORMATETC f={CF_HDROP,nullptr,DVASPECT_CONTENT,-1,TYMED_HGLOBAL}; STGMEDIUM m{};
 if(FAILED(object->GetData(&f,&m)))return false;
 // Also release the medium if a path/vector allocation throws.
 std::unique_ptr<STGMEDIUM,decltype(&ReleaseStgMedium)> lease(&m,ReleaseStgMedium);
 if(m.tymed!=TYMED_HGLOBAL || !m.hGlobal)return false;
 HDROP drop=static_cast<HDROP>(m.hGlobal); UINT count=DragQueryFileW(drop,0xFFFFFFFF,nullptr,0);
 bool ok=count>0 && count<=4096;
 for(UINT i=0;ok && i<count;++i){UINT n=DragQueryFileW(drop,i,nullptr,0);if(!n || n>32760){ok=false;break;}
  std::vector<wchar_t> b(n+1);if(DragQueryFileW(drop,i,b.data(),n+1)!=n){ok=false;break;}paths.emplace_back(b.data());}
 // CF_HDROP belongs to STGMEDIUM: ReleaseStgMedium exactly once, NEVER DragFinish.
 return ok;
}
struct Handle {HANDLE h=INVALID_HANDLE_VALUE;~Handle(){if(h!=INVALID_HANDLE_VALUE)CloseHandle(h);}};
bool temporaryName(std::wstring& path) {
 std::lock_guard<std::mutex> guard(tempLock);
 if(tempCount>=256 || tempBytes>=512ull*1024*1024)return false;
 if(tempDirectory.empty()){
  wchar_t base[32768];DWORD n=GetTempPathW(32768,base);if(!n || n>=32768)return false;
  GUID id;wchar_t token[40];if(FAILED(CoCreateGuid(&id)) || !StringFromGUID2(id,token,40))return false;
  tempDirectory=std::wstring(base)+L"WEBP4CDR27-"+token;
  if(!CreateDirectoryW(tempDirectory.c_str(),nullptr)){tempDirectory.clear();return false;}
 }
 GUID id;wchar_t token[40];if(FAILED(CoCreateGuid(&id)) || !StringFromGUID2(id,token,40))return false;
 path=tempDirectory+L"\\"+token+L".png";return true;
}
bool convertWebp(const std::wstring& path,std::wstring& png,uint64_t& pixelsUsed) {
 // Bound input, arithmetic, dimensions, animation and allocations before decoding.
 Handle file;file.h=CreateFileW(path.c_str(),GENERIC_READ,FILE_SHARE_READ,nullptr,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,nullptr);
 if(file.h==INVALID_HANDLE_VALUE)return false;LARGE_INTEGER size;
 if(!GetFileSizeEx(file.h,&size) || size.QuadPart<=0 || uint64_t(size.QuadPart)>MaxInput)return false;
 std::vector<uint8_t> input(size_t(size.QuadPart));DWORD got=0;
 if(!ReadFile(file.h,input.data(),DWORD(input.size()),&got,nullptr) || got!=input.size())return false;
 WebPBitstreamFeatures features{};
 if(WebPGetFeatures(input.data(),input.size(),&features)!=VP8_STATUS_OK || features.has_animation || features.width<=0 || features.height<=0)return false;
 uint64_t pixels=uint64_t(features.width)*uint64_t(features.height);
 if(pixels>MaxPixels || pixelsUsed>MaxPixels-pixels)return false;
 std::vector<uint8_t> bgra(size_t(pixels*4));
 if(!WebPDecodeBGRAInto(input.data(),input.size(),bgra.data(),bgra.size(),features.width*4))return false;
 Ptr<IWICImagingFactory> factory;Ptr<IWICBitmapEncoder> encoder;Ptr<IWICBitmapFrameEncode> frame;
 Ptr<IPropertyBag2> options;Ptr<IStream> stream;
 if(FAILED(CoCreateInstance(CLSID_WICImagingFactory,nullptr,CLSCTX_INPROC_SERVER,IID_IWICImagingFactory,reinterpret_cast<void**>(factory.out()))))return false;
 if(!temporaryName(png))return false;
 // A random session directory + exclusive creation prevents overwriting user files.
 HRESULT hr=SHCreateStreamOnFileEx(png.c_str(),STGM_CREATE|STGM_WRITE|STGM_SHARE_EXCLUSIVE,FILE_ATTRIBUTE_NORMAL,TRUE,nullptr,stream.out());
 if(SUCCEEDED(hr))hr=factory->CreateEncoder(GUID_ContainerFormatPng,nullptr,encoder.out());
 if(SUCCEEDED(hr))hr=encoder->Initialize(stream.p,WICBitmapEncoderNoCache);
 if(SUCCEEDED(hr))hr=encoder->CreateNewFrame(frame.out(),options.out());
 if(SUCCEEDED(hr))hr=frame->Initialize(options.p);
 if(SUCCEEDED(hr))hr=frame->SetSize(features.width,features.height);
 WICPixelFormatGUID format=GUID_WICPixelFormat32bppBGRA;
 if(SUCCEEDED(hr))hr=frame->SetPixelFormat(&format);
 if(SUCCEEDED(hr) && !IsEqualGUID(format,GUID_WICPixelFormat32bppBGRA))hr=E_FAIL;
 if(SUCCEEDED(hr))hr=frame->WritePixels(features.height,features.width*4,UINT(bgra.size()),bgra.data());
 if(SUCCEEDED(hr))hr=frame->Commit();if(SUCCEEDED(hr))hr=encoder->Commit();
 STATSTG stat{};if(SUCCEEDED(hr))hr=stream->Stat(&stat,STATFLAG_NONAME);
 // Release all WIC handles before deleting an unsuccessful file.
 if(frame.p){frame.p->Release();frame.p=nullptr;}if(encoder.p){encoder.p->Release();encoder.p=nullptr;}
 if(stream.p){stream.p->Release();stream.p=nullptr;}
 if(FAILED(hr)){DeleteFileW(png.c_str());png.clear();return false;}
 {std::lock_guard<std::mutex> guard(tempLock);if(tempBytes+stat.cbSize.QuadPart>512ull*1024*1024){DeleteFileW(png.c_str());png.clear();return false;}
  tempBytes+=stat.cbSize.QuadPart;++tempCount;}
 pixelsUsed+=pixels;return true;
}

class DataFiles final:public IDataObject {
 std::atomic<ULONG> refs{1};IDataObject* original;std::vector<std::wstring> paths;
public:
 DataFiles(IDataObject* o,std::vector<std::wstring> p):original(o),paths(std::move(p)){original->AddRef();}
 ~DataFiles(){original->Release();}
 HRESULT STDMETHODCALLTYPE QueryInterface(REFIID id,void** out) override {if(!out)return E_POINTER;*out=nullptr;
  if(id==IID_IUnknown || id==IID_IDataObject){*out=static_cast<IDataObject*>(this);AddRef();return S_OK;}return E_NOINTERFACE;}
 ULONG STDMETHODCALLTYPE AddRef() override{return ++refs;}
 ULONG STDMETHODCALLTYPE Release() override{ULONG n=--refs;if(!n)delete this;return n;}
 HRESULT STDMETHODCALLTYPE GetData(FORMATETC* f,STGMEDIUM* m) override {
  if(!f||!m)return E_POINTER;if(f->cfFormat!=CF_HDROP)return original->GetData(f,m);
  if(!(f->tymed&TYMED_HGLOBAL)||f->dwAspect!=DVASPECT_CONTENT||f->lindex!=-1)return DV_E_FORMATETC;
  size_t chars=1;for(auto& p:paths)chars+=p.size()+1;
  HGLOBAL mem=GlobalAlloc(GMEM_MOVEABLE|GMEM_ZEROINIT,sizeof(DROPFILES)+chars*sizeof(wchar_t));if(!mem)return E_OUTOFMEMORY;
  void* data=GlobalLock(mem);if(!data){GlobalFree(mem);return E_OUTOFMEMORY;}
  auto* header=static_cast<DROPFILES*>(data);header->pFiles=sizeof(DROPFILES);header->fWide=TRUE;
  wchar_t* next=reinterpret_cast<wchar_t*>(static_cast<char*>(data)+sizeof(DROPFILES));
  for(auto& p:paths){memcpy(next,p.c_str(),(p.size()+1)*sizeof(wchar_t));next+=p.size()+1;}
  GlobalUnlock(mem);*m={};m->tymed=TYMED_HGLOBAL;m->hGlobal=mem;return S_OK;
 }
 HRESULT STDMETHODCALLTYPE GetDataHere(FORMATETC* f,STGMEDIUM* m) override {return f&&f->cfFormat==CF_HDROP?DATA_E_FORMATETC:original->GetDataHere(f,m);}
 HRESULT STDMETHODCALLTYPE QueryGetData(FORMATETC* f) override {if(!f)return E_POINTER;return original->QueryGetData(f);}
 HRESULT STDMETHODCALLTYPE GetCanonicalFormatEtc(FORMATETC* a,FORMATETC* b) override{return original->GetCanonicalFormatEtc(a,b);}
 HRESULT STDMETHODCALLTYPE SetData(FORMATETC* a,STGMEDIUM* b,BOOL c) override{return original->SetData(a,b,c);}
 HRESULT STDMETHODCALLTYPE EnumFormatEtc(DWORD d,IEnumFORMATETC** e) override{return original->EnumFormatEtc(d,e);}
 HRESULT STDMETHODCALLTYPE DAdvise(FORMATETC* f,DWORD d,IAdviseSink* s,DWORD* c) override{return original->DAdvise(f,d,s,c);}
 HRESULT STDMETHODCALLTYPE DUnadvise(DWORD d) override{return original->DUnadvise(d);}
 HRESULT STDMETHODCALLTYPE EnumDAdvise(IEnumSTATDATA** e) override{return original->EnumDAdvise(e);}
};
class Target final:public IDropTarget {
 std::atomic<ULONG> refs{1};IDataObject* prepared=nullptr;IDataObject* incoming=nullptr;bool rejected=false;
 void clear(){if(prepared)prepared->Release();if(incoming)incoming->Release();prepared=nullptr;incoming=nullptr;rejected=false;}
 HRESULT prepare(IDataObject* data){clear();incoming=data;incoming->AddRef();
  if(!enabled)return S_OK;std::vector<std::wstring> paths;
  if(!filesFrom(data,paths))return S_OK;
  if(!std::any_of(paths.begin(),paths.end(),isWebp))return S_OK;
  if(paths.size()>MaxFiles){rejected=true;return DV_E_FORMATETC;}
  uint64_t pixels=0;std::vector<std::wstring> staged;
  for(auto& p:paths)if(isWebp(p)){std::wstring png;if(!convertWebp(p,png,pixels)){
    for(auto& made:staged)DeleteFileW(made.c_str());rejected=true;return DV_E_FORMATETC;
   }staged.push_back(png);p=png;}
  prepared=new DataFiles(data,std::move(paths));return S_OK;
 }
public:
 HWND window;IDropTarget* original;
 Target(HWND w,IDropTarget* o):window(w),original(o){original->AddRef();}
 ~Target(){clear();original->Release();}
 HRESULT STDMETHODCALLTYPE QueryInterface(REFIID id,void** out) override {if(!out)return E_POINTER;*out=nullptr;
  if(id==IID_IUnknown||id==IID_IDropTarget){*out=static_cast<IDropTarget*>(this);AddRef();return S_OK;}return E_NOINTERFACE;}
 ULONG STDMETHODCALLTYPE AddRef() override{return ++refs;}
 ULONG STDMETHODCALLTYPE Release() override{ULONG n=--refs;if(!n)delete this;return n;}
 HRESULT STDMETHODCALLTYPE DragEnter(IDataObject* o,DWORD keys,POINTL pt,DWORD* effect) override {if(!o||!effect)return E_POINTER;
  try{if(FAILED(prepare(o))){*effect=DROPEFFECT_NONE;return S_OK;}return original->DragEnter(prepared?prepared:o,keys,pt,effect);}
  catch(...){rejected=true;*effect=DROPEFFECT_NONE;return E_OUTOFMEMORY;}}
 HRESULT STDMETHODCALLTYPE DragOver(DWORD keys,POINTL pt,DWORD* effect) override {if(!effect)return E_POINTER;if(rejected){*effect=0;return S_OK;}return original->DragOver(keys,pt,effect);}
 HRESULT STDMETHODCALLTYPE DragLeave() override {HRESULT hr=rejected?S_OK:original->DragLeave();clear();return hr;}
 HRESULT STDMETHODCALLTYPE Drop(IDataObject* o,DWORD keys,POINTL pt,DWORD* effect) override {if(!o||!effect)return E_POINTER;
  try{if(o!=incoming){
    if(incoming && !rejected)original->DragLeave();
    if(FAILED(prepare(o))){*effect=0;clear();return S_OK;}
    HRESULT entered=original->DragEnter(prepared?prepared:o,keys,pt,effect);
    if(FAILED(entered) || !*effect){clear();return entered;}
   }
   if(rejected){*effect=0;clear();return S_OK;}HRESULT hr=original->Drop(prepared?prepared:o,keys,pt,effect);clear();return hr;
  }catch(...){*effect=0;clear();return E_OUTOFMEMORY;}}
};

std::mutex targetsLock;std::map<HWND,Target*> targets;
constexpr wchar_t IdentityProperty[]=L"WEBP4CDR27.TargetIdentity.v1";
HRESULT restoreOnThread(HWND hwnd);
HRESULT installOnThread(HWND hwnd) {
 if(!enabled)return E_ABORT;
 {std::lock_guard<std::mutex> g(targetsLock);if(targets.count(hwnd))return S_FALSE;if(targets.size()>=MaxWindows)return E_OUTOFMEMORY;}
 auto* original=static_cast<IDropTarget*>(GetPropW(hwnd,L"OleDropTargetInterface"));if(!original)return S_FALSE;
 auto release=[](Target* p){p->Release();};
 std::unique_ptr<Target,decltype(release)> holder(new Target(hwnd,original),release);
 Target* proxy=holder.get();
 // Allocate bookkeeping before changing the host's registration.
 {std::lock_guard<std::mutex> g(targetsLock);targets.emplace(hwnd,proxy);}
 HRESULT hr=E_FAIL;
 if(SetPropW(hwnd,IdentityProperty,proxy)) {
  hr=RevokeDragDrop(hwnd);
  if(SUCCEEDED(hr)){hr=RegisterDragDrop(hwnd,proxy);if(FAILED(hr))RegisterDragDrop(hwnd,original);}
 }
 if(FAILED(hr)){
  RemovePropW(hwnd,IdentityProperty);
  {std::lock_guard<std::mutex> g(targetsLock);targets.erase(hwnd);}return hr;
 }
 holder.release();
 if(!enabled)return restoreOnThread(hwnd);
 return S_OK;
}
HRESULT restoreOnThread(HWND hwnd) {
 Target* proxy=nullptr;{std::lock_guard<std::mutex> g(targetsLock);auto it=targets.find(hwnd);if(it==targets.end())return S_FALSE;proxy=it->second;}
 // Do not revoke a different add-on's handler installed after ours.
 if(GetPropW(hwnd,L"OleDropTargetInterface")!=static_cast<IDropTarget*>(proxy))return S_FALSE;
 HRESULT hr=RevokeDragDrop(hwnd);if(SUCCEEDED(hr)){
  hr=RegisterDragDrop(hwnd,proxy->original);
  if(FAILED(hr))RegisterDragDrop(hwnd,proxy); // Disabled proxy still forwards native drops.
 }
 if(SUCCEEDED(hr)){
  RemovePropW(hwnd,IdentityProperty);
  {std::lock_guard<std::mutex> g(targetsLock);targets.erase(hwnd);}proxy->Release();
 }return hr;
}
struct Request {HWND window;bool restore;std::atomic<int> state{0};HRESULT result=E_PENDING;};
std::mutex requestsLock;std::map<UINT_PTR,std::shared_ptr<Request>> requests;std::atomic<UINT_PTR> nextRequest{1};
UINT marshalMessage=0;
LRESULT CALLBACK marshalHook(int code,WPARAM wp,LPARAM lp) {
 if(code>=0){auto* message=reinterpret_cast<CWPSTRUCT*>(lp);if(message->message==marshalMessage){
  std::shared_ptr<Request> request;{std::lock_guard<std::mutex> g(requestsLock);auto it=requests.find(message->wParam);if(it!=requests.end())request=it->second;}
  if(request && request->window==message->hwnd){int expected=0;if(request->state.compare_exchange_strong(expected,1)){
   try{request->result=request->restore?restoreOnThread(request->window):installOnThread(request->window);}catch(...){request->result=E_OUTOFMEMORY;}
   request->state=2;
  }}
 }}return CallNextHookEx(nullptr,code,wp,lp);
}
HRESULT onWindowThread(HWND hwnd,bool restore) {
 DWORD pid=0;DWORD thread=GetWindowThreadProcessId(hwnd,&pid);if(!thread||pid!=GetCurrentProcessId())return E_INVALIDARG;
 if(thread==GetCurrentThreadId())return restore?restoreOnThread(hwnd):installOnThread(hwnd);
 auto request=std::make_shared<Request>();request->window=hwnd;request->restore=restore;UINT_PTR id=nextRequest++;
 {std::lock_guard<std::mutex> g(requestsLock);requests.emplace(id,request);}
 HHOOK hook=SetWindowsHookExW(WH_CALLWNDPROC,marshalHook,moduleHandle,thread);HRESULT hr=E_FAIL;
 if(hook){DWORD_PTR unused;SendMessageTimeoutW(hwnd,marshalMessage,id,0,SMTO_ABORTIFHUNG|SMTO_BLOCK,1000,&unused);
  if(request->state==2)hr=request->result;else{int queued=0;request->state.compare_exchange_strong(queued,3);hr=HRESULT_FROM_WIN32(ERROR_TIMEOUT);}
  UnhookWindowsHookEx(hook);
 }
 {std::lock_guard<std::mutex> g(requestsLock);requests.erase(id);}return hr;
}
void prune(){std::vector<Target*> dead;
 {std::lock_guard<std::mutex> g(targetsLock);for(auto it=targets.begin();it!=targets.end();){
  if(!IsWindow(it->first) || GetPropW(it->first,IdentityProperty)!=it->second){dead.push_back(it->second);it=targets.erase(it);}else ++it;
 }}for(auto* proxy:dead)proxy->Release();
}
void installWindow(IDispatch* window){if(!window)return;V handle;if(FAILED(property(window,L"Handle",handle)))return;
 uintptr_t raw=0;if(handle.v.vt==VT_I4)raw=static_cast<DWORD>(handle.v.lVal);else if(handle.v.vt==VT_I8)raw=static_cast<uintptr_t>(handle.v.llVal);
 if(raw)onWindowThread(reinterpret_cast<HWND>(raw),false);
}
struct VGPlugin:IDispatch {virtual HRESULT STDMETHODCALLTYPE OnLoad(IDispatch*)=0;virtual HRESULT STDMETHODCALLTYPE StartSession()=0;virtual HRESULT STDMETHODCALLTYPE StopSession()=0;virtual HRESULT STDMETHODCALLTYPE OnUnload()=0;};
class Plugin final:public VGPlugin {
 std::atomic<ULONG> refs{1};IDispatch* app=nullptr;LONG cookie=0;bool advised=false;
 void active(){prune();V window;if(SUCCEEDED(property(app,L"ActiveWindow",window)))installWindow(dispatch(window));}
public:
 HRESULT STDMETHODCALLTYPE QueryInterface(REFIID id,void** out) override {if(!out)return E_POINTER;*out=nullptr;
  if(id==IID_IUnknown||id==IID_IDispatch||id==PluginIID||id==EventsIID){*out=static_cast<VGPlugin*>(this);AddRef();return S_OK;}return E_NOINTERFACE;}
 ULONG STDMETHODCALLTYPE AddRef() override{return ++refs;}
 ULONG STDMETHODCALLTYPE Release() override{ULONG n=refs.load();while(n>1&&!refs.compare_exchange_weak(n,n-1)){}return refs.load();}
 HRESULT STDMETHODCALLTYPE GetTypeInfoCount(UINT* count) override{if(!count)return E_POINTER;*count=0;return S_OK;}
 HRESULT STDMETHODCALLTYPE GetTypeInfo(UINT,LCID,ITypeInfo**) override{return E_NOTIMPL;}
 HRESULT STDMETHODCALLTYPE GetIDsOfNames(REFIID,LPOLESTR*,UINT,LCID,DISPID*) override{return DISP_E_UNKNOWNNAME;}
 HRESULT STDMETHODCALLTYPE Invoke(DISPID id,REFIID,LCID,WORD,DISPPARAMS*,VARIANT*,EXCEPINFO*,UINT*) override {
  // Unrelated/zero-argument events never dereference DISPPARAMS.
  if(!enabled || !app || (id!=6 && id!=7 && id!=8 && id!=15))return S_OK;
  try{active();return S_OK;}catch(...){return E_FAIL;}
 }
 HRESULT STDMETHODCALLTYPE OnLoad(IDispatch* a) override {if(!a)return E_POINTER;if(app)return E_UNEXPECTED;app=a;app->AddRef();return S_OK;}
 HRESULT STDMETHODCALLTYPE StartSession() override {
  if(!app||advised)return E_UNEXPECTED;
  try{
   // OLE consumers may retain IDataObject after Drop; pin code until process exit.
   HMODULE pin; if(!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS|GET_MODULE_HANDLE_EX_FLAG_PIN,reinterpret_cast<LPCWSTR>(&marshalHook),&pin))return E_FAIL;
   marshalMessage=RegisterWindowMessageW(L"WEBP4CDR27.OLE.ThreadBridge.v1");if(!marshalMessage)return E_FAIL;
   VARIANT argument{};argument.vt=VT_DISPATCH;argument.pdispVal=this;V answer;
   HRESULT hr=call(app,L"AdviseEvents",DISPATCH_METHOD,&argument,&answer.v);if(FAILED(hr))return hr;
   if(answer.v.vt!=VT_I4)return E_FAIL;cookie=answer.v.lVal;advised=true;enabled=true;
   V windows;if(SUCCEEDED(property(app,L"Windows",windows)) && dispatch(windows)){V count;if(SUCCEEDED(property(dispatch(windows),L"Count",count)) && count.v.vt==VT_I4){
    for(LONG i=1;i<=count.v.lVal && i<=LONG(MaxWindows);++i){VARIANT index{};index.vt=VT_I4;index.lVal=i;V w;
     if(SUCCEEDED(call(dispatch(windows),L"Item",DISPATCH_PROPERTYGET,&index,&w.v)))installWindow(dispatch(w));}
   }}active();return S_OK;
  }catch(...){StopSession();return E_FAIL;}
 }
 HRESULT STDMETHODCALLTYPE StopSession() override {
  enabled=false;
  try{if(advised&&app){VARIANT arg{};arg.vt=VT_I4;arg.lVal=cookie;V ignored;call(app,L"UnadviseEvents",DISPATCH_METHOD,&arg,&ignored.v);advised=false;}
   std::vector<HWND> windows;{std::lock_guard<std::mutex> g(targetsLock);for(auto& kv:targets)windows.push_back(kv.first);}
   for(HWND w:windows)if(IsWindow(w))onWindowThread(w,true);prune();return S_OK;
  }catch(...){return E_FAIL;}
 }
 HRESULT STDMETHODCALLTYPE OnUnload() override {HRESULT hr=StopSession();if(app){app->Release();app=nullptr;}return hr;}
} plugin;
} // namespace
extern "C" __declspec(dllexport) int WINAPI AttachPlugin(void** out){if(!out)return 0;*out=static_cast<VGPlugin*>(&plugin);return 256;}
extern "C" __declspec(dllexport) int WINAPI DecoderVersion(){return WebPGetDecoderVersion();}
BOOL WINAPI DllMain(HINSTANCE module,DWORD reason,LPVOID){if(reason==DLL_PROCESS_ATTACH){moduleHandle=module;DisableThreadLibraryCalls(module);}return TRUE;}
