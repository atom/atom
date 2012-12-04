#import <Cocoa/Cocoa.h>
#import <node.h>
#import <v8.h>
#import <string>
#import <vector>

#import "CocoaOniguruma/OnigRegexp.h"

using namespace v8;

class OnigScannerUserData  {
  public:
  OnigScannerUserData(Handle<Array> sources) {
    int length = sources->Length();
    regExps.resize(length);
    cachedResults.resize(length);

    for (int i = 0; i < length; i++) {
      const char *value = *String::Utf8Value(sources->Get(i));
      NSString *sourceString = [NSString stringWithUTF8String:value];
      regExps[i] = [[OnigRegexp compile:sourceString] retain];
    }
  }

  ~OnigScannerUserData() {
    for (std::vector<OnigRegexp *>::iterator iter = regExps.begin(); iter < regExps.end(); iter++) {
      [*iter release];
    }
    for (std::vector<OnigResult *>::iterator iter = cachedResults.begin(); iter < cachedResults.end(); iter++) {
      [*iter release];
    }
  }

  Handle<Value> FindNextMatch(Handle<String> v8String, Handle<Number> v8StartLocation) {
    std::string string(*String::Utf8Value(v8String));
    int startLocation = v8StartLocation->Value();
    int bestIndex = -1;
    int bestLocation = NULL;
    OnigResult *bestResult = NULL;

    bool useCachedResults = (string == lastMatchedString && startLocation >= lastStartLocation);
    lastStartLocation = startLocation;

    if (!useCachedResults) {
      ClearCachedResults();
      lastMatchedString = string;
    }

    std::vector<OnigRegexp *>::iterator iter = regExps.begin();
    int index = 0;
    while (iter < regExps.end()) {
      OnigRegexp *regExp = *iter;

      bool useCachedResult = false;
      OnigResult *result = NULL;

      // In Oniguruma, \G is based on the start position of the match, so the result
      // changes based on the start position. So it can't be cached.
      BOOL containsBackslashG = [regExp.expression rangeOfString:@"\\G"].location != NSNotFound;
      if (useCachedResults && index <= maxCachedIndex && ! containsBackslashG) {
        result = cachedResults[index];
        useCachedResult = (result == NULL || [result locationAt:0] >= startLocation);
      }

      if (!useCachedResult) {
        result = [regExp search:[NSString stringWithUTF8String:string.c_str()] start:startLocation];
        cachedResults[index] = [result retain];
        maxCachedIndex = index;
      }

      if ([result count] > 0) {
        int location = [result locationAt:0];
        if (bestIndex == -1 || location < bestLocation) {
          bestLocation = location;
          bestResult = result;
          bestIndex = index;
        }

        if (location == startLocation) {
          break;
        }
      }

      iter++;
      index++;
    }

    if (bestIndex >= 0) {
      Local<Object> result;
      result->Set(String::NewSymbol("index"), Number::New(bestIndex));
      result->Set(String::NewSymbol("captureIndices"), CaptureIndicesForMatch(bestResult));
      return result;
    }
    else {
      return Null();
    }
  }

  void ClearCachedResults() {
    maxCachedIndex = -1;
    for (std::vector<OnigResult *>::iterator iter = cachedResults.begin(); iter < cachedResults.end(); iter++) {
      [*iter release];
      *iter = NULL;
    }
  }

  Handle<Value> CaptureIndicesForMatch(OnigResult *result) {
    Local<Array> array = Array::New([result count] * 3);
    int i = 0;
    int resultCount = [result count];
    for (int index = 0; index < resultCount; index++) {
      int captureLength = [result lengthAt:index];
      int captureStart = [result locationAt:index];

      array->Set(i++, Number::New(index));
      array->Set(i++, Number::New(captureStart));
      array->Set(i++, Number::New(captureStart + captureLength));
    }

    return array;
  }

  protected:
  std::vector<OnigRegexp *> regExps;
  std::string lastMatchedString;
  std::vector<OnigResult *> cachedResults;
  int maxCachedIndex;
  int lastStartLocation;
};

class OnigScanner : public node::ObjectWrap {
 public:
  static void Init(Handle<Object> target);

 private:
  OnigScanner(OnigScannerUserData userData);
  ~OnigScanner();

  static Handle<Value> New(const Arguments& args);
  static Handle<Value> FindNextMatch(const   Arguments& args);

  OnigScannerUserData userData_;
};

OnigScanner::OnigScanner(OnigScannerUserData userData) : userData_(userData){
};

OnigScanner::~OnigScanner() {
  printf("If you see this, it means OnigScanner is being deconstructed\n");
};

void OnigScanner::Init(Handle<Object> target) {
  // Prepare constructor template
  Local<FunctionTemplate> tpl = FunctionTemplate::New(OnigScanner::New);
  tpl->SetClassName(v8::String::NewSymbol("OnigScanner"));
  tpl->InstanceTemplate()->SetInternalFieldCount(1);
  tpl->PrototypeTemplate()->Set(v8::String::NewSymbol("findNextMatch"), FunctionTemplate::New(OnigScanner::FindNextMatch)->GetFunction());

  Persistent<Function> constructor = Persistent<Function>::New(tpl->GetFunction());
  target->Set(v8::String::NewSymbol("OnigScanner"), constructor);
}

Handle<Value> OnigScanner::New(const Arguments& args) {
  HandleScope scope;
  OnigScanner* scanner = new OnigScanner(OnigScannerUserData(Local<Array>::Cast(args[0])));
  scanner->Wrap(args.This());
  return args.This();
}

Handle<Value> OnigScanner::FindNextMatch(const Arguments& args) {
  HandleScope scope;
  OnigScanner* scanner = node::ObjectWrap::Unwrap<OnigScanner>(args.This());
  return scope.Close(scanner->userData_.FindNextMatch(Local<String>::Cast(args[0]), Local<Number>::Cast(args[1])));
}

void Init(Handle<Object> target) {
  OnigScanner::Init(target);
}

NODE_MODULE(oniguruma, Init)