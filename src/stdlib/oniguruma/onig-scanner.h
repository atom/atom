#import <node.h>
#import <v8.h>
#import <string>
#import <vector>

using namespace v8;

@class OnigResult, OnigRegexp;

class OnigScanner : public node::ObjectWrap {
 public:
  static void Init(Handle<Object> target);

 private:
  OnigScanner(Handle<Array> sources);
  ~OnigScanner();

  static Handle<Value> New(const Arguments& args);
  static Handle<Value> FindNextMatch(const Arguments& args);

  Handle<Value> FindNextMatch(Handle<String> v8String, Handle<Number> v8StartLocation);
  Handle<Value> CaptureIndicesForMatch(OnigResult *result);
  void ClearCachedResults();

  std::vector<OnigRegexp *> regExps;
  std::string lastMatchedString;
  std::vector<OnigResult *> cachedResults;
  int maxCachedIndex;
  int lastStartLocation;
};