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
    int index = 0;
    return BuildCaptureTree(result, index);
  }

  CefRefPtr<CefV8Value> BuildCaptureTree(OnigResult *result, int &index) {
    int currentIndex = index++;
    int startPosition = [result locationAt:currentIndex];
    int endPosition = startPosition + [result lengthAt:currentIndex];
    
    CefRefPtr<CefV8Value> tree = CefV8Value::CreateArray();    
    int i = 0;    
    tree->SetValue(i++, CefV8Value::CreateInt(currentIndex));
    tree->SetValue(i++, CefV8Value::CreateInt(startPosition));
    tree->SetValue(i++, CefV8Value::CreateInt(endPosition));

    while (index < [result count] && [result locationAt:index] < endPosition) {
      if ([result lengthAt:index] == 0) {
        index++;
      } else {
        tree->SetValue(i++, BuildCaptureTree(result, index));
      }
    }
    
    if (currentIndex == 0) {
      CefRefPtr<CefV8Value> tuple = CefV8Value::CreateArray();
      tuple->SetValue(0, CefV8Value::CreateString([[result stringAt:0] UTF8String]));
      tuple->SetValue(1, tree);
      return tuple;
    } else {
      return tree;
    }
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
    return true;
  }
  else if (name == "search") {
    CefRefPtr<CefV8Value> string = arguments[0];
    CefRefPtr<CefV8Value> index = arguments.size() > 1 ? arguments[1] : CefV8Value::CreateInt(0);
    OnigRegexpUserData *userData = (OnigRegexpUserData *)object->GetUserData().get();
    retval = userData->Search(string, index);
    return true;
  }
  else if (name == "getCaptureTree") {
    CefRefPtr<CefV8Value> string = arguments[0];
    CefRefPtr<CefV8Value> index = arguments.size() > 1 ? arguments[1] : CefV8Value::CreateInt(0);
    OnigRegexpUserData *userData = (OnigRegexpUserData *)object->GetUserData().get();
    retval = userData->GetCaptureTree(string, index);
    return true;
  }
  else if (name == "getCaptureCount") {
    OnigRegexpUserData *userData = (OnigRegexpUserData *)object->GetUserData().get();
    retval = userData->CaptureCount();
    return true;
  }

  return false;
}

