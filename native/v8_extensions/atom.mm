#import <Cocoa/Cocoa.h>
#import <dispatch/dispatch.h>

#import "atom.h"
#import "atom_application.h"
#import "util.h"


namespace v8_extensions {
  // IPC data translation functions: translate a V8 array to a List, and vice versa
  void TranslateList(CefRefPtr<CefV8Value> source, CefRefPtr<CefListValue> target);
  void TranslateList(CefRefPtr<CefListValue> source, CefRefPtr<CefV8Value> target);

  v8_extensions::Atom::Atom() : CefV8Handler() {
    NSString *filePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"v8_extensions/atom.js"];
    NSString *extensionCode = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    CefRegisterExtension("v8/atom", [extensionCode UTF8String], this);
  }

  bool v8_extensions::Atom::Execute(const CefString& name,
                              CefRefPtr<CefV8Value> object,
                              const CefV8ValueList& arguments,
                              CefRefPtr<CefV8Value>& retval,
                              CefString& exception) {
    CefRefPtr<CefBrowser> browser = CefV8Context::GetCurrentContext()->GetBrowser();

    if (name == "sendMessageToBrowserProcess") {
      if (arguments.size() == 0 || !arguments[0]->IsString()) {
        exception = "You must supply a message name";
        return false;
      }

      CefString name = arguments[0]->GetStringValue();
      CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(name);

      if (arguments.size() > 1 && arguments[1]->IsArray()) {
        TranslateList(arguments[1], message->GetArgumentList());
      }

      browser->SendProcessMessage(PID_BROWSER, message);
      return true;
    }
    if (name == "open") {
      CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create("open");
      CefRefPtr<CefListValue> messageArgs = message->GetArgumentList();
      if (arguments.size() >= 1) {
        messageArgs->SetSize(1);
        messageArgs->SetString(0, arguments[0]->GetStringValue());
      }
      browser->SendProcessMessage(PID_BROWSER, message);
      return true;
    }
    return false;
  };

  // Transfer a V8 value to a List index.
  void TranslateListValue(CefRefPtr<CefListValue> list, int index, CefRefPtr<CefV8Value> value) {
    if (value->IsArray()) {
      CefRefPtr<CefListValue> new_list = CefListValue::Create();
      TranslateList(value, new_list);
      list->SetList(index, new_list);
    } else if (value->IsString()) {
      list->SetString(index, value->GetStringValue());
    } else if (value->IsBool()) {
      list->SetBool(index, value->GetBoolValue());
    } else if (value->IsInt()) {
      list->SetInt(index, value->GetIntValue());
    } else if (value->IsDouble()) {
      list->SetDouble(index, value->GetDoubleValue());
    }
  }

  // Transfer a V8 array to a List.
  void TranslateList(CefRefPtr<CefV8Value> source, CefRefPtr<CefListValue> target) {
    ASSERT(source->IsArray());

    int arg_length = source->GetArrayLength();
    if (arg_length == 0)
      return;

    // Start with null types in all spaces.
    target->SetSize(arg_length);

    for (int i = 0; i < arg_length; ++i) {
      TranslateListValue(target, i, source->GetValue(i));
    }
  }

  // Transfer a List value to a V8 array index.
  void TranslateListValue(CefRefPtr<CefV8Value> list, int index, CefRefPtr<CefListValue> value) {
    CefRefPtr<CefV8Value> new_value;

    CefValueType type = value->GetType(index);
    switch (type) {
      case VTYPE_LIST: {
        CefRefPtr<CefListValue> list = value->GetList(index);
        new_value = CefV8Value::CreateArray(list->GetSize());
        TranslateList(list, new_value);
      } break;
      case VTYPE_BOOL:
        new_value = CefV8Value::CreateBool(value->GetBool(index));
        break;
      case VTYPE_DOUBLE:
        new_value = CefV8Value::CreateDouble(value->GetDouble(index));
        break;
      case VTYPE_INT:
        new_value = CefV8Value::CreateInt(value->GetInt(index));
        break;
      case VTYPE_STRING:
        new_value = CefV8Value::CreateString(value->GetString(index));
        break;
      default:
        break;
    }

    if (new_value.get()) {
      list->SetValue(index, new_value);
    } else {
      list->SetValue(index, CefV8Value::CreateNull());
    }
  }

  // Transfer a List to a V8 array.
  void TranslateList(CefRefPtr<CefListValue> source, CefRefPtr<CefV8Value> target) {
    ASSERT(target->IsArray());

    int arg_length = source->GetSize();
    if (arg_length == 0)
      return;

    for (int i = 0; i < arg_length; ++i) {
      TranslateListValue(target, i, source);
    }
  }
}
