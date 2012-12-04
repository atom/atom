#include <node.h>
#include <v8.h>

using namespace v8;

class OnigScanner : public node::ObjectWrap {
 public:
  static void Init(v8::Handle<v8::Object> target);

 private:
  OnigScanner();
  ~OnigScanner();

  static v8::Handle<v8::Value> New(const v8::Arguments& args);
  static v8::Handle<v8::Value> FindNextMatch(const v8::Arguments& args);
};

OnigScanner::OnigScanner() {};
OnigScanner::~OnigScanner() {};

void OnigScanner::Init(Handle<Object> target) {
  // Prepare constructor template
  Local<FunctionTemplate> tpl = FunctionTemplate::New(OnigScanner::New);
  tpl->SetClassName(String::NewSymbol("OnigScanner"));
  tpl->InstanceTemplate()->SetInternalFieldCount(1);
  tpl->PrototypeTemplate()->Set(String::NewSymbol("findNextMatch"), FunctionTemplate::New(OnigScanner::FindNextMatch)->GetFunction());

  Persistent<Function> constructor = Persistent<Function>::New(tpl->GetFunction());
  target->Set(String::NewSymbol("OnigScanner"), constructor);
}

Handle<Value> OnigScanner::New(const Arguments& args) {
  HandleScope scope;
  OnigScanner* scanner = new OnigScanner();
  scanner->Wrap(args.This());
  return args.This();
}

static v8::Handle<v8::Value> FindNextMatch(const v8::Arguments& args) {
  HandleScope scope;
  OnigScanner* scanner = node::ObjectWrap::Unwrap<OnigScanner>(args.This());
  return scope.Close(Number::New(42));
}

void Init(Handle<Object> target) {
  OnigScanner::Init(target);
}

NODE_MODULE(oniguruma, Init)