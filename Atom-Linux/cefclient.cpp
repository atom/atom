// Copyright (c) 2010 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "cefclient.h"
#include <stdio.h>
#include <cstdlib>
#include <sstream>
#include <string>
#include "include/cef_app.h"
#include "include/cef_browser.h"
#include "include/cef_command_line.h"
#include "include/cef_frame.h"
#include "include/cef_runnable.h"
#include "include/cef_web_plugin.h"
#include "include/cef_web_urlrequest.h"
#include "cefclient_switches.h"
#include "client_handler.h"
#include "string_util.h"
#include "util.h"

namespace {

void UIT_InvokeScript(CefRefPtr<CefBrowser> browser) {
  REQUIRE_UI_THREAD();

  CefRefPtr<CefFrame> frame = browser->GetMainFrame();
  CefRefPtr<CefV8Context> v8Context = frame->GetV8Context();
  CefString url = frame->GetURL();

  if (!v8Context.get()) {
    frame->ExecuteJavaScript("alert('Failed to get V8 context!');", url, 0);
  } else if (v8Context->Enter()) {
    CefRefPtr<CefV8Value> globalObj = v8Context->GetGlobal();
    CefRefPtr<CefV8Value> evalFunc = globalObj->GetValue("eval");

    CefRefPtr<CefV8Value> arg0 = CefV8Value::CreateString("1+2");

    CefV8ValueList args;
    args.push_back(arg0);

    CefRefPtr<CefV8Value> retVal;
    CefRefPtr<CefV8Exception> exception;
    if (evalFunc->ExecuteFunctionWithContext(v8Context, globalObj, args, retVal,
                                             exception, false)) {
      if (retVal.get()) {
        frame->ExecuteJavaScript(
            std::string("alert('InvokeScript returns ") +
            retVal->GetStringValue().ToString() + "!');",
            url, 0);
      } else {
        frame->ExecuteJavaScript(
            std::string("alert('InvokeScript returns exception: ") +
            exception->GetMessage().ToString() + "!');",
            url, 0);
      }
    } else {
      frame->ExecuteJavaScript("alert('Failed to execute function!');", url, 0);
    }

    v8Context->Exit();
  } else {
    frame->ExecuteJavaScript("alert('Failed to enter into V8 context!');",
        url, 0);
  }
}

void UIT_RunPluginInfoTest(CefRefPtr<CefBrowser> browser) {
  std::string html = "<html><head><title>Plugin Info Test</title></head><body>";

  // Find the flash plugin first to test that get by name works.
  std::string flash_name;
  CefRefPtr<CefWebPluginInfo> info = CefGetWebPluginInfo("Shockwave Flash");
  if (info.get()) {
    flash_name = info->GetName();
    html += "\n<b>Flash is installed!</b>"
            "<br/>Name: " + flash_name +
            "\n<br/>Description: " + info->GetDescription().ToString() +
            "\n<br/>Version: " + info->GetVersion().ToString() +
            "\n<br/>Path: " + info->GetPath().ToString();
  }

  if (!flash_name.empty()) {
    html += "\n<br/><br/><b>Other installed plugins:</b>";
  } else {
    html += "\n<b>Installed plugins:</b>";
  }

  // Display all other plugins.
  size_t count = CefGetWebPluginCount();
  for (size_t i = 0; i < count; ++i) {
    CefRefPtr<CefWebPluginInfo> info = CefGetWebPluginInfo(i);
    ASSERT(info.get());
    if (!flash_name.empty() && info->GetName() == flash_name)
      continue;

    html += "\n<br/><br/>Name: " + info->GetName().ToString() +
            "\n<br/>Description: " + info->GetDescription().ToString() +
            "\n<br/>Version: " + info->GetVersion().ToString() +
            "\n<br/>Path: " + info->GetPath().ToString();
  }

  html += "</body></html>";

  browser->GetMainFrame()->LoadString(html, "http://tests/plugin_info");
}

// Return the int representation of the specified string.
int GetIntValue(const CefString& str) {
  if (str.empty())
    return 0;

  std::string stdStr = str;
  return atoi(stdStr.c_str());
}


// ClientApp implementation.
class ClientApp : public CefApp,
                  public CefProxyHandler {
 public:
  ClientApp(cef_proxy_type_t proxy_type, const CefString& proxy_config)
    : proxy_type_(proxy_type),
      proxy_config_(proxy_config) {
  }

  // CefApp methods
  virtual CefRefPtr<CefProxyHandler> GetProxyHandler() OVERRIDE { return this; }

  // CefProxyHandler methods
  virtual void GetProxyForUrl(const CefString& url,
                              CefProxyInfo& proxy_info) OVERRIDE {
    proxy_info.proxyType = proxy_type_;
    if (!proxy_config_.empty())
      CefString(&proxy_info.proxyList) = proxy_config_;
  }

 protected:
  cef_proxy_type_t proxy_type_;
  CefString proxy_config_;

  IMPLEMENT_REFCOUNTING(ClientApp);
};

}  // namespace

CefRefPtr<ClientHandler> g_handler;
CefRefPtr<CefCommandLine> g_command_line;

CefRefPtr<CefBrowser> AppGetBrowser() {
  if (!g_handler.get())
    return NULL;
  return g_handler->GetBrowser();
}

CefWindowHandle AppGetMainHwnd() {
  if (!g_handler.get())
    return NULL;
  return g_handler->GetMainHwnd();
}

void AppInitCommandLine(int argc, const char* const* argv) {
  g_command_line = CefCommandLine::CreateCommandLine();
#if defined(OS_WIN)
  g_command_line->InitFromString(::GetCommandLineW());
#else
  g_command_line->InitFromArgv(argc, argv);
#endif
}

// Returns the application command line object.
CefRefPtr<CefCommandLine> AppGetCommandLine() {
  return g_command_line;
}

// Returns the application settings based on command line arguments.
void AppGetSettings(CefSettings& settings, CefRefPtr<CefApp>& app) {
  ASSERT(g_command_line.get());
  if (!g_command_line.get())
    return;

  CefString str;

#if defined(OS_WIN)
  settings.multi_threaded_message_loop =
      g_command_line->HasSwitch(cefclient::kMultiThreadedMessageLoop);
#endif

  CefString(&settings.cache_path) =
      g_command_line->GetSwitchValue(cefclient::kCachePath);
  CefString(&settings.user_agent) =
      g_command_line->GetSwitchValue(cefclient::kUserAgent);
  CefString(&settings.product_version) =
      g_command_line->GetSwitchValue(cefclient::kProductVersion);
  CefString(&settings.locale) =
      g_command_line->GetSwitchValue(cefclient::kLocale);
  CefString(&settings.log_file) =
      g_command_line->GetSwitchValue(cefclient::kLogFile);

  {
    std::string str = g_command_line->GetSwitchValue(cefclient::kLogSeverity);
    bool invalid = false;
    if (!str.empty()) {
      if (str == cefclient::kLogSeverity_Verbose)
        settings.log_severity = LOGSEVERITY_VERBOSE;
      else if (str == cefclient::kLogSeverity_Info)
        settings.log_severity = LOGSEVERITY_INFO;
      else if (str == cefclient::kLogSeverity_Warning)
        settings.log_severity = LOGSEVERITY_WARNING;
      else if (str == cefclient::kLogSeverity_Error)
        settings.log_severity = LOGSEVERITY_ERROR;
      else if (str == cefclient::kLogSeverity_ErrorReport)
        settings.log_severity = LOGSEVERITY_ERROR_REPORT;
      else if (str == cefclient::kLogSeverity_Disable)
        settings.log_severity = LOGSEVERITY_DISABLE;
      else
        invalid = true;
    }
    if (str.empty() || invalid) {
#ifdef NDEBUG
      // Only log error messages and higher in release build.
      settings.log_severity = LOGSEVERITY_ERROR;
#endif
    }
  }

  {
    std::string str = g_command_line->GetSwitchValue(cefclient::kGraphicsImpl);
    if (!str.empty()) {
#if defined(OS_WIN)
      if (str == cefclient::kGraphicsImpl_Angle)
        settings.graphics_implementation = ANGLE_IN_PROCESS;
      else if (str == cefclient::kGraphicsImpl_AngleCmdBuffer)
        settings.graphics_implementation = ANGLE_IN_PROCESS_COMMAND_BUFFER;
      else
#endif
      if (str == cefclient::kGraphicsImpl_Desktop)
        settings.graphics_implementation = DESKTOP_IN_PROCESS;
      else if (str == cefclient::kGraphicsImpl_DesktopCmdBuffer)
        settings.graphics_implementation = DESKTOP_IN_PROCESS_COMMAND_BUFFER;
    }
  }

  settings.local_storage_quota = GetIntValue(
      g_command_line->GetSwitchValue(cefclient::kLocalStorageQuota));
  settings.session_storage_quota = GetIntValue(
      g_command_line->GetSwitchValue(cefclient::kSessionStorageQuota));

  CefString(&settings.javascript_flags) =
      g_command_line->GetSwitchValue(cefclient::kJavascriptFlags);

  CefString(&settings.pack_file_path) =
      g_command_line->GetSwitchValue(cefclient::kPackFilePath);
  CefString(&settings.locales_dir_path) =
      g_command_line->GetSwitchValue(cefclient::kLocalesDirPath);

  settings.pack_loading_disabled =
      g_command_line->HasSwitch(cefclient::kPackLoadingDisabled);

  // Retrieve command-line proxy configuration, if any.
  bool has_proxy = false;
  cef_proxy_type_t proxy_type = PROXY_TYPE_DIRECT;
  CefString proxy_config;

  if (g_command_line->HasSwitch(cefclient::kProxyType)) {
    std::string str = g_command_line->GetSwitchValue(cefclient::kProxyType);
    if (str == cefclient::kProxyType_Direct) {
      has_proxy = true;
      proxy_type = PROXY_TYPE_DIRECT;
    } else if (str == cefclient::kProxyType_Named ||
               str == cefclient::kProxyType_Pac) {
      proxy_config = g_command_line->GetSwitchValue(cefclient::kProxyConfig);
      if (!proxy_config.empty()) {
        has_proxy = true;
        proxy_type = (str == cefclient::kProxyType_Named?
                      PROXY_TYPE_NAMED:PROXY_TYPE_PAC_STRING);
      }
    }
  }

  if (has_proxy) {
    // Provide a ClientApp instance to handle proxy resolution.
    app = new ClientApp(proxy_type, proxy_config);
  }
}

// Returns the application browser settings based on command line arguments.
void AppGetBrowserSettings(CefBrowserSettings& settings) {
  ASSERT(g_command_line.get());
  if (!g_command_line.get())
    return;

  settings.drag_drop_disabled =
      g_command_line->HasSwitch(cefclient::kDragDropDisabled);
  settings.load_drops_disabled =
      g_command_line->HasSwitch(cefclient::kLoadDropsDisabled);
  settings.history_disabled =
      g_command_line->HasSwitch(cefclient::kHistoryDisabled);
  settings.remote_fonts_disabled =
      g_command_line->HasSwitch(cefclient::kRemoteFontsDisabled);

  CefString(&settings.default_encoding) =
      g_command_line->GetSwitchValue(cefclient::kDefaultEncoding);

  settings.encoding_detector_enabled =
      g_command_line->HasSwitch(cefclient::kEncodingDetectorEnabled);
  settings.javascript_disabled =
      g_command_line->HasSwitch(cefclient::kJavascriptDisabled);
  settings.javascript_open_windows_disallowed =
      g_command_line->HasSwitch(cefclient::kJavascriptOpenWindowsDisallowed);
  settings.javascript_close_windows_disallowed =
      g_command_line->HasSwitch(cefclient::kJavascriptCloseWindowsDisallowed);
  settings.javascript_access_clipboard_disallowed =
      g_command_line->HasSwitch(
          cefclient::kJavascriptAccessClipboardDisallowed);
  settings.dom_paste_disabled =
      g_command_line->HasSwitch(cefclient::kDomPasteDisabled);
  settings.caret_browsing_enabled =
      g_command_line->HasSwitch(cefclient::kCaretBrowsingDisabled);
  settings.java_disabled =
      g_command_line->HasSwitch(cefclient::kJavaDisabled);
  settings.plugins_disabled =
      g_command_line->HasSwitch(cefclient::kPluginsDisabled);
  settings.universal_access_from_file_urls_allowed =
      g_command_line->HasSwitch(cefclient::kUniversalAccessFromFileUrlsAllowed);
  settings.file_access_from_file_urls_allowed =
      g_command_line->HasSwitch(cefclient::kFileAccessFromFileUrlsAllowed);
  settings.web_security_disabled =
      g_command_line->HasSwitch(cefclient::kWebSecurityDisabled);
  settings.xss_auditor_enabled =
      g_command_line->HasSwitch(cefclient::kXssAuditorEnabled);
  settings.image_load_disabled =
      g_command_line->HasSwitch(cefclient::kImageLoadingDisabled);
  settings.shrink_standalone_images_to_fit =
      g_command_line->HasSwitch(cefclient::kShrinkStandaloneImagesToFit);
  settings.site_specific_quirks_disabled =
      g_command_line->HasSwitch(cefclient::kSiteSpecificQuirksDisabled);
  settings.text_area_resize_disabled =
      g_command_line->HasSwitch(cefclient::kTextAreaResizeDisabled);
  settings.page_cache_disabled =
      g_command_line->HasSwitch(cefclient::kPageCacheDisabled);
  settings.tab_to_links_disabled =
      g_command_line->HasSwitch(cefclient::kTabToLinksDisabled);
  settings.hyperlink_auditing_disabled =
      g_command_line->HasSwitch(cefclient::kHyperlinkAuditingDisabled);
  settings.user_style_sheet_enabled =
      g_command_line->HasSwitch(cefclient::kUserStyleSheetEnabled);

  CefString(&settings.user_style_sheet_location) =
      g_command_line->GetSwitchValue(cefclient::kUserStyleSheetLocation);

  settings.author_and_user_styles_disabled =
      g_command_line->HasSwitch(cefclient::kAuthorAndUserStylesDisabled);
  settings.local_storage_disabled =
      g_command_line->HasSwitch(cefclient::kLocalStorageDisabled);
  settings.databases_disabled =
      g_command_line->HasSwitch(cefclient::kDatabasesDisabled);
  settings.application_cache_disabled =
      g_command_line->HasSwitch(cefclient::kApplicationCacheDisabled);
  settings.webgl_disabled =
      g_command_line->HasSwitch(cefclient::kWebglDisabled);
  settings.accelerated_compositing_enabled =
      g_command_line->HasSwitch(cefclient::kAcceleratedCompositingEnabled);
  settings.threaded_compositing_enabled =
      g_command_line->HasSwitch(cefclient::kThreadedCompositingEnabled);
  settings.accelerated_layers_disabled =
      g_command_line->HasSwitch(cefclient::kAcceleratedLayersDisabled);
  settings.accelerated_video_disabled =
      g_command_line->HasSwitch(cefclient::kAcceleratedVideoDisabled);
  settings.accelerated_2d_canvas_disabled =
      g_command_line->HasSwitch(cefclient::kAcceledated2dCanvasDisabled);
  settings.accelerated_painting_disabled =
      g_command_line->HasSwitch(cefclient::kAcceleratedPaintingDisabled);
  settings.accelerated_filters_disabled =
      g_command_line->HasSwitch(cefclient::kAcceleratedFiltersDisabled);
  settings.accelerated_plugins_disabled =
      g_command_line->HasSwitch(cefclient::kAcceleratedPluginsDisabled);
  settings.developer_tools_disabled =
      g_command_line->HasSwitch(cefclient::kDeveloperToolsDisabled);
  settings.fullscreen_enabled =
      g_command_line->HasSwitch(cefclient::kFullscreenEnabled);
}

static void ExecuteGetSource(CefRefPtr<CefFrame> frame) {
  // Retrieve the current page source and display.
  std::string source = frame->GetSource();
  source = StringReplace(source, "<", "&lt;");
  source = StringReplace(source, ">", "&gt;");
  std::stringstream ss;
  ss << "<html><body>Source:<pre>" << source << "</pre></body></html>";
  frame->LoadString(ss.str(), "http://tests/getsource");
}

void RunGetSourceTest(CefRefPtr<CefBrowser> browser) {
  // Execute the GetSource() call on the UI thread.
  CefPostTask(TID_UI,
      NewCefRunnableFunction(&ExecuteGetSource, browser->GetMainFrame()));
}

static void ExecuteGetText(CefRefPtr<CefFrame> frame) {
  std::string text = frame->GetText();
  text = StringReplace(text, "<", "&lt;");
  text = StringReplace(text, ">", "&gt;");
  std::stringstream ss;
  ss << "<html><body>Text:<pre>" << text << "</pre></body></html>";
  frame->LoadString(ss.str(), "http://tests/gettext");
}

void RunGetTextTest(CefRefPtr<CefBrowser> browser) {
  // Execute the GetText() call on the UI thread.
  CefPostTask(TID_UI,
      NewCefRunnableFunction(&ExecuteGetText, browser->GetMainFrame()));
}

void RunRequestTest(CefRefPtr<CefBrowser> browser) {
  // Create a new request
  CefRefPtr<CefRequest> request(CefRequest::CreateRequest());

  // Set the request URL
  request->SetURL("http://tests/request");

  // Add post data to the request.  The correct method and content-
  // type headers will be set by CEF.
  CefRefPtr<CefPostDataElement> postDataElement(
      CefPostDataElement::CreatePostDataElement());
  std::string data = "arg1=val1&arg2=val2";
  postDataElement->SetToBytes(data.length(), data.c_str());
  CefRefPtr<CefPostData> postData(CefPostData::CreatePostData());
  postData->AddElement(postDataElement);
  request->SetPostData(postData);

  // Add a custom header
  CefRequest::HeaderMap headerMap;
  headerMap.insert(
      std::make_pair("X-My-Header", "My Header Value"));
  request->SetHeaderMap(headerMap);

  // Load the request
  browser->GetMainFrame()->LoadRequest(request);
}

void RunJavaScriptExecuteTest(CefRefPtr<CefBrowser> browser) {
  browser->GetMainFrame()->ExecuteJavaScript(
      "alert('JavaScript execute works!');", "about:blank", 0);
}

void RunJavaScriptInvokeTest(CefRefPtr<CefBrowser> browser) {
  if (CefCurrentlyOn(TID_UI)) {
    UIT_InvokeScript(browser);
  } else {
    // Execute on the UI thread.
    CefPostTask(TID_UI, NewCefRunnableFunction(&UIT_InvokeScript, browser));
  }
}

void RunPopupTest(CefRefPtr<CefBrowser> browser) {
  browser->GetMainFrame()->ExecuteJavaScript(
      "window.open('http://www.google.com');", "about:blank", 0);
}

void RunLocalStorageTest(CefRefPtr<CefBrowser> browser) {
  browser->GetMainFrame()->LoadURL("http://tests/localstorage");
}

void RunAccelerated2DCanvasTest(CefRefPtr<CefBrowser> browser) {
  browser->GetMainFrame()->LoadURL(
      "http://mudcu.be/labs/JS1k/BreathingGalaxies.html");
}

void RunAcceleratedLayersTest(CefRefPtr<CefBrowser> browser) {
  browser->GetMainFrame()->LoadURL(
      "http://webkit.org/blog-files/3d-transforms/poster-circle.html");
}

void RunWebGLTest(CefRefPtr<CefBrowser> browser) {
  browser->GetMainFrame()->LoadURL(
      "http://webglsamples.googlecode.com/hg/field/field.html");
}

void RunHTML5VideoTest(CefRefPtr<CefBrowser> browser) {
  browser->GetMainFrame()->LoadURL(
      "http://www.youtube.com/watch?v=siOHh0uzcuY&html5=True");
}

void RunXMLHTTPRequestTest(CefRefPtr<CefBrowser> browser) {
  browser->GetMainFrame()->LoadURL("http://tests/xmlhttprequest");
}

void RunWebURLRequestTest(CefRefPtr<CefBrowser> browser) {
  class RequestClient : public CefWebURLRequestClient {
   public:
    explicit RequestClient(CefRefPtr<CefBrowser> browser) : browser_(browser) {}

    virtual void OnStateChange(CefRefPtr<CefWebURLRequest> requester,
                               RequestState state) {
      REQUIRE_UI_THREAD();
      if (state == WUR_STATE_DONE) {
        buffer_ = StringReplace(buffer_, "<", "&lt;");
        buffer_ = StringReplace(buffer_, ">", "&gt;");
        std::stringstream ss;
        ss << "<html><body>Source:<pre>" << buffer_ << "</pre></body></html>";

        browser_->GetMainFrame()->LoadString(ss.str(),
            "http://tests/weburlrequest");
      }
    }

    virtual void OnRedirect(CefRefPtr<CefWebURLRequest> requester,
                            CefRefPtr<CefRequest> request,
                            CefRefPtr<CefResponse> response) {
      REQUIRE_UI_THREAD();
    }

    virtual void OnHeadersReceived(CefRefPtr<CefWebURLRequest> requester,
                                   CefRefPtr<CefResponse> response) {
      REQUIRE_UI_THREAD();
    }

    virtual void OnProgress(CefRefPtr<CefWebURLRequest> requester,
                            uint64 bytesSent, uint64 totalBytesToBeSent) {
      REQUIRE_UI_THREAD();
    }

    virtual void OnData(CefRefPtr<CefWebURLRequest> requester,
                        const void* data, int dataLength) {
      REQUIRE_UI_THREAD();
      buffer_.append(static_cast<const char*>(data), dataLength);
    }

    virtual void OnError(CefRefPtr<CefWebURLRequest> requester,
                         ErrorCode errorCode) {
      REQUIRE_UI_THREAD();
      std::stringstream ss;
      ss << "Load failed with error code " << errorCode;
      browser_->GetMainFrame()->LoadString(ss.str(),
          "http://tests/weburlrequest");
    }

   protected:
    CefRefPtr<CefBrowser> browser_;
    std::string buffer_;

    IMPLEMENT_REFCOUNTING(CefWebURLRequestClient);
  };

  CefRefPtr<CefRequest> request(CefRequest::CreateRequest());
  request->SetURL("http://www.google.com");

  CefRefPtr<CefWebURLRequestClient> client(new RequestClient(browser));
  CefRefPtr<CefWebURLRequest> requester(
      CefWebURLRequest::CreateWebURLRequest(request, client));
}

void RunDOMAccessTest(CefRefPtr<CefBrowser> browser) {
  class Listener : public CefDOMEventListener {
   public:
    Listener() {}
    virtual void HandleEvent(CefRefPtr<CefDOMEvent> event) {
      CefRefPtr<CefDOMDocument> document = event->GetDocument();
      ASSERT(document.get());

      std::stringstream ss;

      CefRefPtr<CefDOMNode> button = event->GetTarget();
      ASSERT(button.get());
      std::string buttonValue = button->GetElementAttribute("value");
      ss << "You clicked the " << buttonValue.c_str() << " button. ";

      if (document->HasSelection()) {
        std::string startName, endName;

        // Determine the start name by first trying to locate the "id" attribute
        // and then defaulting to the tag name.
        {
          CefRefPtr<CefDOMNode> node = document->GetSelectionStartNode();
          if (!node->IsElement())
            node = node->GetParent();
          if (node->IsElement() && node->HasElementAttribute("id"))
            startName = node->GetElementAttribute("id");
          else
            startName = node->GetName();
        }

        // Determine the end name by first trying to locate the "id" attribute
        // and then defaulting to the tag name.
        {
          CefRefPtr<CefDOMNode> node = document->GetSelectionEndNode();
          if (!node->IsElement())
            node = node->GetParent();
          if (node->IsElement() && node->HasElementAttribute("id"))
            endName = node->GetElementAttribute("id");
          else
            endName = node->GetName();
        }

        ss << "The selection is from " <<
            startName.c_str() << ":" << document->GetSelectionStartOffset() <<
            " to " <<
            endName.c_str() << ":" << document->GetSelectionEndOffset();
      } else {
        ss << "Nothing is selected.";
      }

      // Update the description.
      CefRefPtr<CefDOMNode> desc = document->GetElementById("description");
      ASSERT(desc.get());
      CefRefPtr<CefDOMNode> text = desc->GetFirstChild();
      ASSERT(text.get());
      ASSERT(text->IsText());
      text->SetValue(ss.str());
    }

    IMPLEMENT_REFCOUNTING(Listener);
  };

  class Visitor : public CefDOMVisitor {
   public:
    Visitor() {}
    virtual void Visit(CefRefPtr<CefDOMDocument> document) {
      // Register an click listener for the button.
      CefRefPtr<CefDOMNode> button = document->GetElementById("button");
      ASSERT(button.get());
      button->AddEventListener("click", new Listener(), false);
    }

    IMPLEMENT_REFCOUNTING(Visitor);
  };

  // The DOM visitor will be called after the path is loaded.
  CefRefPtr<CefClient> client = browser->GetClient();
  static_cast<ClientHandler*>(client.get())->AddDOMVisitor(
      "http://tests/domaccess", new Visitor());

  browser->GetMainFrame()->LoadURL("http://tests/domaccess");
}

void RunDragDropTest(CefRefPtr<CefBrowser> browser) {
  browser->GetMainFrame()->LoadURL("http://html5demos.com/drag");
}

void RunModalDialogTest(CefRefPtr<CefBrowser> browser) {
  browser->GetMainFrame()->LoadURL("http://tests/modalmain");
}

void RunPluginInfoTest(CefRefPtr<CefBrowser> browser) {
  if (CefCurrentlyOn(TID_UI)) {
    UIT_RunPluginInfoTest(browser);
  } else {
    // Execute on the UI thread.
    CefPostTask(TID_UI,
        NewCefRunnableFunction(&UIT_RunPluginInfoTest, browser));
  }
}
