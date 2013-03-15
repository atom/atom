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

  OnigRegexp *m_regex;

  IMPLEMENT_REFCOUNTING(OnigRegexpUserData);
};

OnigRegExp::OnigRegExp() : CefV8Handler() {
}

void OnigRegExp::CreateContextBinding(CefRefPtr<CefV8Context> context) {
  const char* methodNames[] = { "search", "test", "buildOnigRegExp" };

  CefRefPtr<CefV8Value> nativeObject = CefV8Value::CreateObject(NULL);
  int arrayLength = sizeof(methodNames) / sizeof(const char *);
  for (int i = 0; i < arrayLength; i++) {
    const char *functionName = methodNames[i];
    CefRefPtr<CefV8Value> function = CefV8Value::CreateFunction(functionName, this);
    nativeObject->SetValue(functionName, function, V8_PROPERTY_ATTRIBUTE_NONE);
  }

  CefRefPtr<CefV8Value> global = context->GetGlobal();
  global->SetValue("$onigRegExp", nativeObject, V8_PROPERTY_ATTRIBUTE_NONE);
}

bool OnigRegExp::Execute(const CefString& name,
                            CefRefPtr<CefV8Value> object,
                            const CefV8ValueList& arguments,
                            CefRefPtr<CefV8Value>& retval,
                            CefString& exception) {

  @autoreleasepool {
    if (name == "search") {
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
      CefRefPtr<CefV8Value> pattern = arguments[0];
      CefRefPtr<OnigRegExpUserData> userData = new OnigRegExpUserData(pattern);
      if (!userData->m_regex) {
        exception = std::string("Failed to create OnigRegExp from pattern '") + pattern->GetStringValue().ToString() + "'";
      }
      retval = CefV8Value::CreateObject(NULL);
      retval->SetUserData((CefRefPtr<CefBase>)userData);
      return true;
    }

    return false;
  }
}

} // namespace v8_extensions