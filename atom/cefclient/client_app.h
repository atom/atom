// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_TESTS_CEFCLIENT_CLIENT_APP_H_
#define CEF_TESTS_CEFCLIENT_CLIENT_APP_H_
#pragma once

#include <map>
#include <set>
#include <string>
#include <utility>
#include <vector>
#include "include/cef_app.h"

class ClientApp : public CefApp,
                  public CefBrowserProcessHandler,
                  public CefProxyHandler,
                  public CefRenderProcessHandler {
 public:
  // Interface for renderer delegates. All RenderDelegates must be returned via
  // CreateRenderDelegates. Do not perform work in the RenderDelegate
  // constructor.
  class RenderDelegate : public virtual CefBase {
   public:
    // Called when WebKit is initialized. Used to register V8 extensions.
    virtual void OnWebKitInitialized(CefRefPtr<ClientApp> app) {
    };

    // Called when a V8 context is created. Used to create V8 window bindings
    // and set message callbacks. RenderDelegates should check for unique URLs
    // to avoid interfering with each other.
    virtual void OnContextCreated(CefRefPtr<ClientApp> app,
                                  CefRefPtr<CefBrowser> browser,
                                  CefRefPtr<CefFrame> frame,
                                  CefRefPtr<CefV8Context> context) {
    };

    // Called when a V8 context is released. Used to clean up V8 window
    // bindings. RenderDelegates should check for unique URLs to avoid
    // interfering with each other.
    virtual void OnContextReleased(CefRefPtr<ClientApp> app,
                                   CefRefPtr<CefBrowser> browser,
                                   CefRefPtr<CefFrame> frame,
                                   CefRefPtr<CefV8Context> context) {
    };

    // Called when the focused node in a frame has changed.
    virtual void OnFocusedNodeChanged(CefRefPtr<ClientApp> app,
                                      CefRefPtr<CefBrowser> browser,
                                      CefRefPtr<CefFrame> frame,
                                      CefRefPtr<CefDOMNode> node) {
    }

    // Called when a process message is received. Return true if the message was
    // handled and should not be passed on to other handlers. RenderDelegates
    // should check for unique message names to avoid interfering with each
    // other.
    virtual bool OnProcessMessageReceived(
        CefRefPtr<ClientApp> app,
        CefRefPtr<CefBrowser> browser,
        CefProcessId source_process,
        CefRefPtr<CefProcessMessage> message) {
      return false;
    }
  };

  typedef std::set<CefRefPtr<RenderDelegate> > RenderDelegateSet;

  ClientApp();

  // Set the proxy configuration. Should only be called during initialization.
  void SetProxyConfig(cef_proxy_type_t proxy_type,
                      const CefString& proxy_config) {
    proxy_type_ = proxy_type;
    proxy_config_ = proxy_config;
  }

  // Set a JavaScript callback for the specified |message_name| and |browser_id|
  // combination. Will automatically be removed when the associated context is
  // released. Callbacks can also be set in JavaScript using the
  // app.setMessageCallback function.
  void SetMessageCallback(const std::string& message_name,
                          int browser_id,
                          CefRefPtr<CefV8Context> context,
                          CefRefPtr<CefV8Value> function);

  // Removes the JavaScript callback for the specified |message_name| and
  // |browser_id| combination. Returns true if a callback was removed. Callbacks
  // can also be removed in JavaScript using the app.removeMessageCallback
  // function.
  bool RemoveMessageCallback(const std::string& message_name,
                             int browser_id);

 private:
  // Creates all of the RenderDelegate objects. Implemented in
  // client_app_delegates.
  static void CreateRenderDelegates(RenderDelegateSet& delegates);

  // Registers custom schemes. Implemented in client_app_delegates.
  static void RegisterCustomSchemes(CefRefPtr<CefSchemeRegistrar> registrar,
                                    std::vector<CefString>& cookiable_schemes);

  // CefApp methods.
  virtual void OnRegisterCustomSchemes(
      CefRefPtr<CefSchemeRegistrar> registrar) OVERRIDE {
    RegisterCustomSchemes(registrar, cookieable_schemes_);
  }
  virtual CefRefPtr<CefBrowserProcessHandler> GetBrowserProcessHandler()
      OVERRIDE { return this; }
  virtual CefRefPtr<CefRenderProcessHandler> GetRenderProcessHandler()
      OVERRIDE { return this; }

  // CefBrowserProcessHandler methods.
  virtual CefRefPtr<CefProxyHandler> GetProxyHandler() OVERRIDE { return this; }
  virtual void OnContextInitialized();

  // CefProxyHandler methods.
  virtual void GetProxyForUrl(const CefString& url,
                              CefProxyInfo& proxy_info) OVERRIDE;

  // CefRenderProcessHandler methods.
  virtual void OnWebKitInitialized() OVERRIDE;
  virtual void OnContextCreated(CefRefPtr<CefBrowser> browser,
                                CefRefPtr<CefFrame> frame,
                                CefRefPtr<CefV8Context> context) OVERRIDE;
  virtual void OnContextReleased(CefRefPtr<CefBrowser> browser,
                                 CefRefPtr<CefFrame> frame,
                                 CefRefPtr<CefV8Context> context) OVERRIDE;
  virtual void OnFocusedNodeChanged(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefFrame> frame,
                                    CefRefPtr<CefDOMNode> node) OVERRIDE;
  virtual bool OnProcessMessageReceived(
      CefRefPtr<CefBrowser> browser,
      CefProcessId source_process,
      CefRefPtr<CefProcessMessage> message) OVERRIDE;

  // Proxy configuration.
  cef_proxy_type_t proxy_type_;
  CefString proxy_config_;

  // Map of message callbacks.
  typedef std::map<std::pair<std::string, int>,
                   std::pair<CefRefPtr<CefV8Context>, CefRefPtr<CefV8Value> > >
                   CallbackMap;
  CallbackMap callback_map_;

  // Set of supported RenderDelegates.
  RenderDelegateSet render_delegates_;

  // Schemes that will be registered with the global cookie manager.
  std::vector<CefString> cookieable_schemes_;

  IMPLEMENT_REFCOUNTING(ClientApp);
};

#endif  // CEF_TESTS_CEFCLIENT_CLIENT_APP_H_
