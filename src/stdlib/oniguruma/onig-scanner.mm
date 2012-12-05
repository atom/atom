#import <Cocoa/Cocoa.h>
#import <node.h>
#import <v8.h>
#import <string>
#import <vector>

#import "CocoaOniguruma/OnigRegexp.h"
#import "onig-scanner.h"

using namespace v8;

OnigScanner::OnigScanner(Handle<Array> sources) {
  int length = sources->Length();
  regExps.resize(length);
  cachedResults.resize(length);

  for (int i = 0; i < length; i++) {
    String::Utf8Value utf8Value(sources->Get(i));
    NSString *sourceString = [NSString stringWithUTF8String:*utf8Value];
    regExps[i] = [[OnigRegexp compile:sourceString] retain];
  }
};

OnigScanner::~OnigScanner() {
  for (std::vector<OnigRegexp *>::iterator iter = regExps.begin(); iter < regExps.end(); iter++) {
    [*iter release];
  }
  for (std::vector<OnigResult *>::iterator iter = cachedResults.begin(); iter < cachedResults.end(); iter++) {
    [*iter release];
  }
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
  OnigScanner* scanner = new OnigScanner(Local<Array>::Cast(args[0]));
  scanner->Wrap(args.This());
  return args.This();
}

Handle<Value> OnigScanner::FindNextMatch(const Arguments& args) {
  HandleScope scope;
  OnigScanner* scanner = node::ObjectWrap::Unwrap<OnigScanner>(args.This());
  return scope.Close(scanner->FindNextMatch(Local<String>::Cast(args[0]), Local<Number>::Cast(args[1])));
}

Handle<Value> OnigScanner::FindNextMatch(Handle<String> v8String, Handle<Number> v8StartLocation) {
  String::Utf8Value utf8Value(v8String);
  std::string string(*utf8Value);
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
    Local<Object> result = Object::New();
    result->Set(String::NewSymbol("index"), Number::New(bestIndex));
    result->Set(String::NewSymbol("captureIndices"), CaptureIndicesForMatch(bestResult));
    return result;
  }
  else {
    return Null();
  }
}

void OnigScanner::ClearCachedResults() {
  maxCachedIndex = -1;
  for (std::vector<OnigResult *>::iterator iter = cachedResults.begin(); iter < cachedResults.end(); iter++) {
    [*iter release];
    *iter = NULL;
  }
}

Handle<Value> OnigScanner::CaptureIndicesForMatch(OnigResult *result) {
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