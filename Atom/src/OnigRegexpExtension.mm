#import "OnigRegexpExtension.h"
#import "include/cef_base.h"
#import "include/cef_v8.h"
#import "CocoaOniguruma/OnigRegexp.h"
#import <Cocoa/Cocoa.h>
#import <iostream>

extern NSString *stringFromCefV8Value(const CefRefPtr<CefV8Value>& value);

class OnigRegexpUserData : public CefBase {
public:
  OnigRegexpUserData(CefRefPtr<CefV8Value> source) {
    NSString *sourceString = [NSString stringWithUTF8String:source->GetStringValue().ToString().c_str()];
    m_regex = [[OnigRegexp compile:sourceString] retain];
  }
  
  ~OnigRegexpUserData() {
    [m_regex release];
  }

  CefRefPtr<CefV8Value> Search(CefRefPtr<CefV8Value> string, CefRefPtr<CefV8Value> index) {
    OnigResult *result = [m_regex search:stringFromCefV8Value(string) start:index->GetIntValue()];

    if ([result count] == 0) return CefV8Value::CreateNull();
    
    CefRefPtr<CefV8Value> resultArray = CefV8Value::CreateArray();
    CefRefPtr<CefV8Value> indicesArray = CefV8Value::CreateArray();
    
    for (int i = 0; i < [result count]; i++) {
      resultArray->SetValue(i, CefV8Value::CreateString([[result stringAt:i] UTF8String]));
      indicesArray->SetValue(i, CefV8Value::CreateInt([result locationAt:i]));
    }
    
    resultArray->SetValue("index", CefV8Value::CreateInt([result locationAt:0]), V8_PROPERTY_ATTRIBUTE_NONE);
    resultArray->SetValue("indices", indicesArray, V8_PROPERTY_ATTRIBUTE_NONE);

    return resultArray;
  }
  
  CefRefPtr<CefV8Value> GetCaptureTree(CefRefPtr<CefV8Value> string, CefRefPtr<CefV8Value> index) {    
    OnigResult *result = [m_regex search:stringFromCefV8Value(string) start:index->GetIntValue()];
    if ([result count] == 0) return CefV8Value::CreateNull();    
    return BuildCaptureTree(result);
  }

  CefRefPtr<CefV8Value> BuildCaptureTree(OnigResult *result) {
    int currentIndex = 0;
    return BuildCaptureTree(result, currentIndex);
  }
  
  CefRefPtr<CefV8Value> BuildCaptureTree(OnigResult *result, int &currentIndex) {
    int index = currentIndex++;
    NSString *text = [result stringAt:index];
    int startPosition = [result locationAt:index];
    int endPosition = startPosition + [text length];
    
    CefRefPtr<CefV8Value> childCaptures;
    
    while (currentIndex < [result count] && [result locationAt:currentIndex] < endPosition) {
      if ([result lengthAt:currentIndex] == 0) continue;        
      if (!childCaptures.get()) childCaptures = CefV8Value::CreateArray();
      childCaptures->SetValue(childCaptures->GetArrayLength(), BuildCaptureTree(result));
    }
    
    CefRefPtr<CefV8Value> tree = CefV8Value::CreateObject(NULL, NULL);
    tree->SetValue("index", CefV8Value::CreateInt(index), V8_PROPERTY_ATTRIBUTE_NONE);
    tree->SetValue("text", CefV8Value::CreateString([text UTF8String]), V8_PROPERTY_ATTRIBUTE_NONE);
    tree->SetValue("position", CefV8Value::CreateInt(startPosition), V8_PROPERTY_ATTRIBUTE_NONE);
    if (childCaptures.get()) tree->SetValue("captures", childCaptures, V8_PROPERTY_ATTRIBUTE_NONE);
    return tree;
  }
  
  CefRefPtr<CefV8Value> CaptureCount() {
    return CefV8Value::CreateInt([m_regex captureCount]);
  }
  
  OnigRegexp *m_regex;
  
  IMPLEMENT_REFCOUNTING(OnigRegexpUserData);
};

OnigRegexpExtension::OnigRegexpExtension() : CefV8Handler() {  
  NSString *filePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"src/stdlib/onig-reg-exp-extension.js"];
  NSString *extensionCode = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
  CefRegisterExtension("v8/oniguruma", [extensionCode UTF8String], this);
}

bool OnigRegexpExtension::Execute(const CefString& name,
                            CefRefPtr<CefV8Value> object,
                            const CefV8ValueList& arguments,
                            CefRefPtr<CefV8Value>& retval,
                            CefString& exception) {
  if (name == "buildOnigRegExp") {    
    CefRefPtr<CefBase> userData = new OnigRegexpUserData(arguments[0]);
    retval = CefV8Value::CreateObject(userData, NULL);
  }
  else if (name == "search") {
    CefRefPtr<CefV8Value> string = arguments[0];
    CefRefPtr<CefV8Value> index = arguments.size() > 1 ? arguments[1] : CefV8Value::CreateInt(0);
    OnigRegexpUserData *userData = (OnigRegexpUserData *)object->GetUserData().get();
    retval = userData->Search(string, index);
  }
  else if (name == "getCaptureCount") {
    OnigRegexpUserData *userData = (OnigRegexpUserData *)object->GetUserData().get();
    retval = userData->CaptureCount();
  }
  return true;
}

