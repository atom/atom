#import <Cocoa/Cocoa.h>
#import <iostream>
#import "CocoaOniguruma/OnigRegexp.h"
#import "include/cef_base.h"
#import "include/cef_v8.h"
#import "onig_reg_exp.h"

namespace v8_extensions {

extern NSString *stringFromCefV8Value(const CefRefPtr<CefV8Value>& value);

class OnigRegExpUserData : public CefBase {
public:
  OnigRegExpUserData(CefRefPtr<CefV8Value> source) {
    NSString *sourceString = [NSString stringWithUTF8String:source->GetStringValue().ToString().c_str()];
    m_regex = [[OnigRegexp compile:sourceString] retain];
  }

  ~OnigRegExpUserData() {
    [m_regex release];
  }

  CefRefPtr<CefV8Value> Search(CefRefPtr<CefV8Value> string, CefRefPtr<CefV8Value> index) {
    OnigResult *result = [m_regex search:stringFromCefV8Value(string) start:index->GetIntValue()];

    if ([result count] == 0) return CefV8Value::CreateNull();

    CefRefPtr<CefV8Value> resultArray = CefV8Value::CreateArray(result.count);
    CefRefPtr<CefV8Value> indicesArray = CefV8Value::CreateArray(result.count);

    for (int i = 0; i < [result count]; i++) {
      resultArray->SetValue(i, CefV8Value::CreateString([[result stringAt:i] UTF8String]));
      indicesArray->SetValue(i, CefV8Value::CreateInt([result locationAt:i]));
    }

    resultArray->SetValue("index", CefV8Value::CreateInt([result locationAt:0]), V8_PROPERTY_ATTRIBUTE_NONE);
    resultArray->SetValue("indices", indicesArray, V8_PROPERTY_ATTRIBUTE_NONE);

    return resultArray;
  }
  
  CefRefPtr<CefV8Value> Test(CefRefPtr<CefV8Value> string, CefRefPtr<CefV8Value> index) {
    OnigResult *result = [m_regex search:stringFromCefV8Value(string) start:index->GetIntValue()];
    return CefV8Value::CreateBool(result);
  }
  
  CefRefPtr<CefV8Value> GetCaptureIndices(CefRefPtr<CefV8Value> string, CefRefPtr<CefV8Value> index) {
    OnigResult *result = [m_regex search:stringFromCefV8Value(string) start:index->GetIntValue()];
    if ([result count] == 0) return CefV8Value::CreateNull();
    return BuildCaptureIndices(result);
  }

  CefRefPtr<CefV8Value> BuildCaptureIndices(OnigResult *result) {
    CefRefPtr<CefV8Value> array = CefV8Value::CreateArray(result.count * 3);
    int i = 0;

    int resultCount = [result count];
    for (int index = 0; index < resultCount; index++) {
      int captureLength = [result lengthAt:index];
      int captureStart = [result locationAt:index];
      if (captureLength == 0) continue;
      array->SetValue(i++, CefV8Value::CreateInt(index));
      array->SetValue(i++, CefV8Value::CreateInt(captureStart));
      array->SetValue(i++, CefV8Value::CreateInt(captureStart + captureLength));
    }
    
    return array;
  }

  CefRefPtr<CefV8Value> CaptureCount() {
    return CefV8Value::CreateInt([m_regex captureCount]);
  }

  OnigRegexp *m_regex;

  IMPLEMENT_REFCOUNTING(OnigRegexpUserData);
};

OnigRegExp::OnigRegExp() : CefV8Handler() {
  NSString *filePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"v8_extensions/onig_reg_exp.js"];
  NSString *extensionCode = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
  CefRegisterExtension("v8/onig-reg-exp", [extensionCode UTF8String], this);
}

bool OnigRegExp::Execute(const CefString& name,
                            CefRefPtr<CefV8Value> object,
                            const CefV8ValueList& arguments,
                            CefRefPtr<CefV8Value>& retval,
                            CefString& exception) {

  if (name == "captureIndices") {
    CefRefPtr<CefV8Value> string = arguments[0];
    CefRefPtr<CefV8Value> index = arguments[1];
    CefRefPtr<CefV8Value> regexes = arguments[2];
    
    int bestIndex = -1;
    CefRefPtr<CefV8Value> captureIndicesForBestIndex;
    CefRefPtr<CefV8Value> captureIndices;
    
    retval = CefV8Value::CreateObject(NULL);
    for (int i = 0; i < regexes->GetArrayLength(); i++) {
      OnigRegExpUserData *userData = (OnigRegExpUserData *)regexes->GetValue(i)->GetUserData().get();
      captureIndices = userData->GetCaptureIndices(string, index);
      if (captureIndices->IsNull()) continue;
      
      if (bestIndex == -1 || captureIndices->GetValue(1)->GetIntValue() < captureIndicesForBestIndex->GetValue(1)->GetIntValue()) {
          bestIndex = i;
        captureIndicesForBestIndex = captureIndices;
        if (captureIndices->GetValue(1)->GetIntValue() == 0) break; // If the match starts at 0, just use it!
      }
    }

    if (bestIndex != -1) {
      retval->SetValue("index", CefV8Value::CreateInt(bestIndex), V8_PROPERTY_ATTRIBUTE_NONE);
      retval->SetValue("captureIndices", captureIndicesForBestIndex, V8_PROPERTY_ATTRIBUTE_NONE);
    }
    
    return true;

  }
  else if (name == "getCaptureIndices") {
    CefRefPtr<CefV8Value> string = arguments[0];
    CefRefPtr<CefV8Value> index = arguments.size() > 1 ? arguments[1] : CefV8Value::CreateInt(0);
    OnigRegExpUserData *userData = (OnigRegExpUserData *)object->GetUserData().get();
    retval = userData->GetCaptureIndices(string, index);
    return true;
  }
  else if (name == "search") {
    CefRefPtr<CefV8Value> string = arguments[0];
    CefRefPtr<CefV8Value> index = arguments.size() > 1 ? arguments[1] : CefV8Value::CreateInt(0);
    OnigRegExpUserData *userData = (OnigRegExpUserData *)object->GetUserData().get();
    retval = userData->Search(string, index);
    return true;
  }
  else if (name == "test") {
    CefRefPtr<CefV8Value> string = arguments[0];
    CefRefPtr<CefV8Value> index = arguments.size() > 1 ? arguments[1] : CefV8Value::CreateInt(0);
    OnigRegExpUserData *userData = (OnigRegExpUserData *)object->GetUserData().get();
    retval = userData->Test(string, index);
    return true;    
  }
  else if (name == "buildOnigRegExp") {
    CefRefPtr<CefBase> userData = new OnigRegExpUserData(arguments[0]);
    retval = CefV8Value::CreateObject(NULL);
    retval->SetUserData(userData);
    return true;
  }
  else if (name == "getCaptureCount") {
    OnigRegExpUserData *userData = (OnigRegExpUserData *)object->GetUserData().get();
    retval = userData->CaptureCount();
    return true;
  }

  return false;
}

} // namespace v8_extensions