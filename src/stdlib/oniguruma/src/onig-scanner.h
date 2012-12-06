#import <node.h>
#import <v8.h>
#import <string>
#import <vector>

using namespace v8;

class OnigRegExp;
class OnigResult;

class OnigScanner : public node::ObjectWrap {
  public:
    static void Init(Handle<Object> target);

  private:
    static Handle<Value> New(const Arguments& args);
    static Handle<Value> FindNextMatch(const Arguments& args);
    OnigScanner(Handle<Array> sources);
    ~OnigScanner();

    Handle<Value> FindNextMatch(Handle<String> v8String, Handle<Number> v8StartLocation);
    Handle<Value> CaptureIndicesForMatch(OnigResult *result);
    void ClearCachedResults();

    std::vector<OnigRegExp *> regExps;
    std::vector<OnigResult *> cachedResults;
    std::string lastMatchedString;
    int maxCachedIndex;
    int lastStartLocation;
};