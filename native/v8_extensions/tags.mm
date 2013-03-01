#import "tags.h"
#import <Cocoa/Cocoa.h>

namespace v8_extensions {

  Tags::Tags() : CefV8Handler() {
  }

  void Tags::CreateContextBinding(CefRefPtr<CefV8Context> context) {
    const char* methodNames[] = { "find", "getAllTagsAsync" };

    CefRefPtr<CefV8Value> nativeObject = CefV8Value::CreateObject(NULL);
    int arrayLength = sizeof(methodNames) / sizeof(const char *);
    for (int i = 0; i < arrayLength; i++) {
      const char *functionName = methodNames[i];
      CefRefPtr<CefV8Value> function = CefV8Value::CreateFunction(functionName, this);
      nativeObject->SetValue(functionName, function, V8_PROPERTY_ATTRIBUTE_NONE);
    }

    CefRefPtr<CefV8Value> global = context->GetGlobal();
    global->SetValue("$tags", nativeObject, V8_PROPERTY_ATTRIBUTE_NONE);
  }

  CefRefPtr<CefV8Value> Tags::ParseEntry(tagEntry entry) {
    CefRefPtr<CefV8Value> tagEntry = CefV8Value::CreateObject(NULL);
    tagEntry->SetValue("name", CefV8Value::CreateString(entry.name), V8_PROPERTY_ATTRIBUTE_NONE);
    tagEntry->SetValue("file", CefV8Value::CreateString(entry.file), V8_PROPERTY_ATTRIBUTE_NONE);
    if (entry.address.pattern) {
      tagEntry->SetValue("pattern", CefV8Value::CreateString(entry.address.pattern), V8_PROPERTY_ATTRIBUTE_NONE);
    }
    return tagEntry;
  }

  bool Tags::Execute(const CefString& name,
                    CefRefPtr<CefV8Value> object,
                    const CefV8ValueList& arguments,
                    CefRefPtr<CefV8Value>& retval,
                    CefString& exception) {

    @autoreleasepool {
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
            entries.push_back(ParseEntry(entry));
            while (tagsFindNext(tagFile, &entry) == TagSuccess) {
              entries.push_back(ParseEntry(entry));
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

      if (name == "getAllTagsAsync") {
        std::string path = arguments[0]->GetStringValue().ToString();
        CefRefPtr<CefV8Value> callback = arguments[1];
        CefRefPtr<CefV8Context> context = CefV8Context::GetCurrentContext();

        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(queue, ^{
          tagFileInfo info;
          tagFile* tagFile;
          tagFile = tagsOpen(path.c_str(), &info);
          std::vector<tagEntry> entries;

          if (info.status.opened) {
            tagEntry entry;
            while (tagsNext(tagFile, &entry) == TagSuccess) {
              entry.name = strdup(entry.name);
              entry.file = strdup(entry.file);
              if (entry.address.pattern) {
                entry.address.pattern = strdup(entry.address.pattern);
              }
              entries.push_back(entry);
            }
            tagsClose(tagFile);
          }

          dispatch_queue_t mainQueue = dispatch_get_main_queue();
          dispatch_async(mainQueue, ^{
            context->Enter();
            CefRefPtr<CefV8Value> v8Tags = CefV8Value::CreateArray(entries.size());
            for (int i = 0; i < entries.size(); i++) {
              v8Tags->SetValue(i, ParseEntry(entries[i]));
              free((void*)entries[i].name);
              free((void*)entries[i].file);
              if (entries[i].address.pattern) {
                free((void*)entries[i].address.pattern);
              }
            }
            CefV8ValueList callbackArgs;
            callbackArgs.push_back(v8Tags);
            callback->ExecuteFunction(callback, callbackArgs);
            context->Exit();
          });
        });
        return true;
      }

      return false;
    }
  }

}
