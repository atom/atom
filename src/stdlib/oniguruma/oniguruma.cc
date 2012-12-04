#include <node.h>
#include <v8.h>
#include <string>

using namespace v8;

class OnigScanner : public node::ObjectWrap {
 public:
  static void Init(Handle<Object> target);

 private:
  OnigScanner();
  ~OnigScanner();

  static Handle<Value> New(const Arguments& args);
  static Handle<Value> FindNextMatch(const   Arguments& args);

  std::string _regex;
};

OnigScanner::OnigScanner() {};
OnigScanner::~OnigScanner() {};

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
  OnigScanner* scanner = new OnigScanner();
  std::string regex = std::string(*v8::String::Utf8Value(args[0]));
  scanner->_regex = regex;
  scanner->Wrap(args.This());
  return args.This();
}

Handle<Value> OnigScanner::FindNextMatch(const Arguments& args) {
  HandleScope scope;
  OnigScanner* scanner = node::ObjectWrap::Unwrap<OnigScanner>(args.This());
  return scope.Close(v8::String::New(scanner->_regex.c_str()));
}

void Init(Handle<Object> target) {
  OnigScanner::Init(target);
}

NODE_MODULE(oniguruma, Init)