// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

// This file is shared by cefclient and cef_unittests so don't include using
// a qualified path.
#include "client_app.h"  // NOLINT(build/include)

#include <string>

#include "include/cef_cookie.h"
#include "include/cef_process_message.h"
#include "include/cef_task.h"
#include "include/cef_v8.h"
#include "util.h"  // NOLINT(build/include)

namespace {

// Forward declarations.
void SetList(CefRefPtr<CefV8Value> source, CefRefPtr<CefListValue> target);
void SetList(CefRefPtr<CefListValue> source, CefRefPtr<CefV8Value> target);

// Transfer a V8 value to a List index.
void SetListValue(CefRefPtr<CefListValue> list, int index,
                  CefRefPtr<CefV8Value> value) {
  if (value->IsArray()) {
    CefRefPtr<CefListValue> new_list = CefListValue::Create();
    SetList(value, new_list);
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
void SetList(CefRefPtr<CefV8Value> source, CefRefPtr<CefListValue> target) {
  ASSERT(source->IsArray());

  int arg_length = source->GetArrayLength();
  if (arg_length == 0)
    return;

  // Start with null types in all spaces.
  target->SetSize(arg_length);

  for (int i = 0; i < arg_length; ++i)
    SetListValue(target, i, source->GetValue(i));
}

// Transfer a List value to a V8 array index.
void SetListValue(CefRefPtr<CefV8Value> list, int index,
                  CefRefPtr<CefListValue> value) {
  CefRefPtr<CefV8Value> new_value;

  CefValueType type = value->GetType(index);
  switch (type) {
    case VTYPE_LIST: {
      CefRefPtr<CefListValue> list = value->GetList(index);
      new_value = CefV8Value::CreateArray(list->GetSize());
      SetList(list, new_value);
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
void SetList(CefRefPtr<CefListValue> source, CefRefPtr<CefV8Value> target) {
  ASSERT(target->IsArray());

  int arg_length = source->GetSize();
  if (arg_length == 0)
    return;

  for (int i = 0; i < arg_length; ++i)
    SetListValue(target, i, source);
}


// Handles the native implementation for the client_app extension.
class ClientAppExtensionHandler : public CefV8Handler {
 public:
  explicit ClientAppExtensionHandler(CefRefPtr<ClientApp> client_app)
    : client_app_(client_app) {
  }

  virtual bool Execute(const CefString& name,
                       CefRefPtr<CefV8Value> object,
                       const CefV8ValueList& arguments,
                       CefRefPtr<CefV8Value>& retval,
                       CefString& exception) {
    bool handled = false;

    if (name == "sendMessage") {
      // Send a message to the browser process.
      if ((arguments.size() == 1 || arguments.size() == 2) &&
          arguments[0]->IsString()) {
        CefRefPtr<CefBrowser> browser =
            CefV8Context::GetCurrentContext()->GetBrowser();
        ASSERT(browser.get());

        CefString name = arguments[0]->GetStringValue();
        if (!name.empty()) {
          CefRefPtr<CefProcessMessage> message =
              CefProcessMessage::Create(name);

          // Translate the arguments, if any.
          if (arguments.size() == 2 && arguments[1]->IsArray())
            SetList(arguments[1], message->GetArgumentList());

          browser->SendProcessMessage(PID_BROWSER, message);
          handled = true;
        }
      }
    } else if (name == "setMessageCallback") {
      // Set a message callback.
      if (arguments.size() == 2 && arguments[0]->IsString() &&
          arguments[1]->IsFunction()) {
        std::string name = arguments[0]->GetStringValue();
        CefRefPtr<CefV8Context> context = CefV8Context::GetCurrentContext();
        int browser_id = context->GetBrowser()->GetIdentifier();
        client_app_->SetMessageCallback(name, browser_id, context,
                                        arguments[1]);
        handled = true;
      }
    }  else if (name == "removeMessageCallback") {
      // Remove a message callback.
      if (arguments.size() == 1 && arguments[0]->IsString()) {
        std::string name = arguments[0]->GetStringValue();
        CefRefPtr<CefV8Context> context = CefV8Context::GetCurrentContext();
        int browser_id = context->GetBrowser()->GetIdentifier();
        bool removed = client_app_->RemoveMessageCallback(name, browser_id);
        retval = CefV8Value::CreateBool(removed);
        handled = true;
      }
    }

    if (!handled)
      exception = "Invalid method arguments";

    return true;
  }

 private:
  CefRefPtr<ClientApp> client_app_;

  IMPLEMENT_REFCOUNTING(ClientAppExtensionHandler);
};

}  // namespace


ClientApp::ClientApp()
    : proxy_type_(PROXY_TYPE_DIRECT) {
  CreateRenderDelegates(render_delegates_);

  // Default schemes that support cookies.
  cookieable_schemes_.push_back("http");
  cookieable_schemes_.push_back("https");
}

void ClientApp::SetMessageCallback(const std::string& message_name,
                                 int browser_id,
                                 CefRefPtr<CefV8Context> context,
                                 CefRefPtr<CefV8Value> function) {
  ASSERT(CefCurrentlyOn(TID_RENDERER));

  callback_map_.insert(
      std::make_pair(std::make_pair(message_name, browser_id),
                     std::make_pair(context, function)));
}

bool ClientApp::RemoveMessageCallback(const std::string& message_name,
                                    int browser_id) {
  ASSERT(CefCurrentlyOn(TID_RENDERER));

  CallbackMap::iterator it =
      callback_map_.find(std::make_pair(message_name, browser_id));
  if (it != callback_map_.end()) {
    callback_map_.erase(it);
    return true;
  }

  return false;
}

void ClientApp::OnContextInitialized() {
  // Register cookieable schemes with the global cookie manager.
  CefRefPtr<CefCookieManager> manager = CefCookieManager::GetGlobalManager();
  ASSERT(manager.get());
  manager->SetSupportedSchemes(cookieable_schemes_);
}

void ClientApp::GetProxyForUrl(const CefString& url,
                               CefProxyInfo& proxy_info) {
  proxy_info.proxyType = proxy_type_;
  if (!proxy_config_.empty())
    CefString(&proxy_info.proxyList) = proxy_config_;
}

void ClientApp::OnWebKitInitialized() {
  // Register the client_app extension.
  std::string app_code =
    "var app;"
    "if (!app)"
    "  app = {};"
    "(function() {"
    "  app.sendMessage = function(name, arguments) {"
    "    native function sendMessage();"
    "    return sendMessage(name, arguments);"
    "  };"
    "  app.setMessageCallback = function(name, callback) {"
    "    native function setMessageCallback();"
    "    return setMessageCallback(name, callback);"
    "  };"
    "  app.removeMessageCallback = function(name) {"
    "    native function removeMessageCallback();"
    "    return removeMessageCallback(name);"
    "  };"
    "})();";
  CefRegisterExtension("v8/app", app_code,
      new ClientAppExtensionHandler(this));

  // Execute delegate callbacks.
  RenderDelegateSet::iterator it = render_delegates_.begin();
  for (; it != render_delegates_.end(); ++it)
    (*it)->OnWebKitInitialized(this);
}

void ClientApp::OnContextCreated(CefRefPtr<CefBrowser> browser,
                               CefRefPtr<CefFrame> frame,
                               CefRefPtr<CefV8Context> context) {
  // Execute delegate callbacks.
  RenderDelegateSet::iterator it = render_delegates_.begin();
  for (; it != render_delegates_.end(); ++it)
    (*it)->OnContextCreated(this, browser, frame, context);
}

void ClientApp::OnContextReleased(CefRefPtr<CefBrowser> browser,
                                CefRefPtr<CefFrame> frame,
                                CefRefPtr<CefV8Context> context) {
  // Execute delegate callbacks.
  RenderDelegateSet::iterator it = render_delegates_.begin();
  for (; it != render_delegates_.end(); ++it)
    (*it)->OnContextReleased(this, browser, frame, context);

  // Remove any JavaScript callbacks registered for the context that has been
  // released.
  if (!callback_map_.empty()) {
    CallbackMap::iterator it = callback_map_.begin();
    for (; it != callback_map_.end();) {
      if (it->second.first->IsSame(context))
        callback_map_.erase(it++);
      else
        ++it;
    }
  }
}

void ClientApp::OnFocusedNodeChanged(CefRefPtr<CefBrowser> browser,
                                     CefRefPtr<CefFrame> frame,
                                     CefRefPtr<CefDOMNode> node) {
  // Execute delegate callbacks.
  RenderDelegateSet::iterator it = render_delegates_.begin();
  for (; it != render_delegates_.end(); ++it)
    (*it)->OnFocusedNodeChanged(this, browser, frame, node);
}

bool ClientApp::OnProcessMessageReceived(
    CefRefPtr<CefBrowser> browser,
    CefProcessId source_process,
    CefRefPtr<CefProcessMessage> message) {
  ASSERT(source_process == PID_BROWSER);

  bool handled = false;

  // Execute delegate callbacks.
  RenderDelegateSet::iterator it = render_delegates_.begin();
  for (; it != render_delegates_.end() && !handled; ++it) {
    handled = (*it)->OnProcessMessageReceived(this, browser, source_process,
                                              message);
  }

  if (handled)
    return true;

  // Execute the registered JavaScript callback if any.
  if (!callback_map_.empty()) {
    CefString message_name = message->GetName();
    CallbackMap::const_iterator it = callback_map_.find(
        std::make_pair(message_name.ToString(),
                       browser->GetIdentifier()));
    if (it != callback_map_.end()) {
      // Enter the context.
      it->second.first->Enter();

      CefV8ValueList arguments;

      // First argument is the message name.
      arguments.push_back(CefV8Value::CreateString(message_name));

      // Second argument is the list of message arguments.
      CefRefPtr<CefListValue> list = message->GetArgumentList();
      CefRefPtr<CefV8Value> args = CefV8Value::CreateArray(list->GetSize());
      SetList(list, args);
      arguments.push_back(args);

      // Execute the callback.
      CefRefPtr<CefV8Value> retval =
          it->second.second->ExecuteFunction(NULL, arguments);
      if (retval.get()) {
        if (retval->IsBool())
          handled = retval->GetBoolValue();
      }

      // Exit the context.
      it->second.first->Exit();
    }
  }

  return handled;
}
