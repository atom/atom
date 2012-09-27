#import <Cocoa/Cocoa.h>
#import <iostream>
#import "CocoaOniguruma/OnigRegexp.h"
#import "include/cef_base.h"
#import "include/cef_v8.h"
#import "onig_scanner.h"

namespace v8_extensions {
  
extern NSString *stringFromCefV8Value(const CefRefPtr<CefV8Value>& value);
using namespace std;
  
class OnigScannerUserData : public CefBase {
  public:  
  OnigScannerUserData(CefRefPtr<CefV8Value> sources) {    
    int length = sources->GetArrayLength();
    
    regExps.resize(length);
    for (int i = 0; i < length; i++) {      
      NSString *sourceString = stringFromCefV8Value(sources->GetValue(i));
      regExps[i] = [[OnigRegexp compile:sourceString] retain];
    }
  }
  
  ~OnigScannerUserData() {
  }
  
  CefRefPtr<CefV8Value> CaptureIndicesForMatch(OnigResult *result) {
    CefRefPtr<CefV8Value> array = CefV8Value::CreateArray([result count] * 3);
    int i = 0;
    int resultCount = [result count];
    for (int index = 0; index < resultCount; index++) {
      int captureLength = [result lengthAt:index];
      int captureStart = [result locationAt:index];
      
      array->SetValue(i++, CefV8Value::CreateInt(index));
      array->SetValue(i++, CefV8Value::CreateInt(captureStart));
      array->SetValue(i++, CefV8Value::CreateInt(captureStart + captureLength));
    }
        
    return array;  
  }
  
  CefRefPtr<CefV8Value> FindNextMatch(CefRefPtr<CefV8Value> v8String, CefRefPtr<CefV8Value> v8StartLocation) {
    NSString *string = stringFromCefV8Value(v8String);
    int startLocation = v8StartLocation->GetIntValue();

    int bestIndex = -1;
    int bestLocation = NULL;
    OnigResult *bestResult = NULL;

    vector<OnigRegexp *>::iterator iter = regExps.begin();
    int index = 0;

    while (iter < regExps.end()) {
      OnigRegexp *regExp = *iter;
      OnigResult *result = [regExp search:string start:startLocation];
      
      if ([result count] > 0) {        
        int location = [result locationAt:0];
        if (bestIndex == -1 || location < bestLocation) {
          bestLocation = location;
          bestResult = result;
          bestIndex = index;
        }
        
        if (location == startLocation) break;
      }
      
      iter++;
      index++;
    }
            
    if (bestIndex >= 0) {
      CefRefPtr<CefV8Value> result = CefV8Value::CreateObject(NULL);
      result->SetValue("index", CefV8Value::CreateInt(bestIndex), V8_PROPERTY_ATTRIBUTE_NONE);
      result->SetValue("captureIndices", CaptureIndicesForMatch(bestResult), V8_PROPERTY_ATTRIBUTE_NONE);
      return result;
    } else {
      return CefV8Value::CreateNull();  
    }
  }
  
  protected:
  std::vector<OnigRegexp *> regExps;
  
  IMPLEMENT_REFCOUNTING(OnigRegexpUserData);
};

OnigScanner::OnigScanner() : CefV8Handler() {
  NSString *filePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"v8_extensions/onig_scanner.js"];
  NSString *extensionCode = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
  CefRegisterExtension("v8/onig-scanner", [extensionCode UTF8String], this);
}

  
bool OnigScanner::Execute(const CefString& name,
                         CefRefPtr<CefV8Value> object,
                         const CefV8ValueList& arguments,
                         CefRefPtr<CefV8Value>& retval,
                         CefString& exception) {
  if (name == "findNextMatch") {
    OnigScannerUserData *userData = (OnigScannerUserData *)object->GetUserData().get();
    retval = userData->FindNextMatch(arguments[0], arguments[1]);
    return true;
  }
  else if (name == "buildScanner") {
    retval = CefV8Value::CreateObject(NULL);
    retval->SetUserData(new OnigScannerUserData(arguments[0]));
    return true;
  }
  
  return false;
}  

} // namespace v8_extensions