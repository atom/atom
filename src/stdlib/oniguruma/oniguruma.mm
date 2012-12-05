#import <node.h>
#import <v8.h>
#import "onig-scanner.h"

using namespace v8;

void Init(Handle<Object> target) {
  OnigScanner::Init(target);
}

NODE_MODULE(oniguruma, Init)