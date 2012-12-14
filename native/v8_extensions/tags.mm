#import "tags.h"
#import "readtags.h"
#import <Cocoa/Cocoa.h>

namespace v8_extensions {

Tags::Tags() : CefV8Handler() {
  NSString *filePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"v8_extensions/tags.js"];
  NSString *extensionCode = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
  CefRegisterExtension("v8/tags", [extensionCode UTF8String], this);
}

bool Tags::Execute(const CefString& name,
                  CefRefPtr<CefV8Value> object,
                  const CefV8ValueList& arguments,
                  CefRefPtr<CefV8Value>& retval,
                  CefString& exception) {

  if (name == "find") {
    std::string path = arguments[0]->GetStringValue().ToString();
    std::string tag = arguments[1]->GetStringValue().ToString();
    tagFileInfo info;
    tagFile* tagFile;
    tagFile = tagsOpen(path.c_str(), &info);
    if (info.status.opened) {
      tagEntry entry;
      std::vector<CefRefPtr<CefV8Value>> entries;
      if (tagsFind(tagFile, &entry, tag.c_str(), TAG_FULLMATCH | TAG_OBSERVECASE) == TagSuccess) {
        CefRefPtr<CefV8Value> tagEntry = CefV8Value::CreateObject(NULL);
        tagEntry->SetValue("name", CefV8Value::CreateString(entry.name), V8_PROPERTY_ATTRIBUTE_NONE);
        tagEntry->SetValue("file", CefV8Value::CreateString(entry.file), V8_PROPERTY_ATTRIBUTE_NONE);
        if (entry.kind) {
          tagEntry->SetValue("kind", CefV8Value::CreateString(entry.kind), V8_PROPERTY_ATTRIBUTE_NONE);
        }
        if (entry.address.pattern) {
          tagEntry->SetValue("pattern", CefV8Value::CreateString(entry.address.pattern), V8_PROPERTY_ATTRIBUTE_NONE);
        }
        entries.push_back(tagEntry);

        while (tagsFindNext(tagFile, &entry) == TagSuccess) {
          tagEntry = CefV8Value::CreateObject(NULL);
          tagEntry->SetValue("name", CefV8Value::CreateString(entry.name), V8_PROPERTY_ATTRIBUTE_NONE);
          tagEntry->SetValue("file", CefV8Value::CreateString(entry.file), V8_PROPERTY_ATTRIBUTE_NONE);
          if (entry.kind) {
            tagEntry->SetValue("kind", CefV8Value::CreateString(entry.kind), V8_PROPERTY_ATTRIBUTE_NONE);
          }
          if (entry.address.pattern) {
            tagEntry->SetValue("pattern", CefV8Value::CreateString(entry.address.pattern), V8_PROPERTY_ATTRIBUTE_NONE);
          }
          entries.push_back(tagEntry);
        }
      }

      retval = CefV8Value::CreateArray(entries.size());
      for (int i = 0; i < entries.size(); i++) {
        retval->SetValue(i, entries[i]);
      }
      tagsClose(tagFile);
    }
    return true;
  }

  return false;
}

}
