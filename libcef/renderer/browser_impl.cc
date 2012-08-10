// Copyright (c) 2012 The Chromium Embedded Framework Authors.
// Portions copyright (c) 2011 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "libcef/renderer/browser_impl.h"

#include <string>
#include <vector>

#include "libcef/common/cef_messages.h"
#include "libcef/common/content_client.h"
#include "libcef/common/process_message_impl.h"
#include "libcef/common/response_manager.h"
#include "libcef/renderer/content_renderer_client.h"
#include "libcef/renderer/dom_document_impl.h"
#include "libcef/renderer/thread_util.h"
#include "libcef/renderer/webkit_glue.h"

#include "base/string16.h"
#include "base/string_util.h"
#include "base/utf_string_conversions.h"
#include "content/public/renderer/document_state.h"
#include "content/public/renderer/navigation_state.h"
#include "content/public/renderer/render_view.h"
#include "net/http/http_util.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/platform/WebString.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/platform/WebURL.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/WebDataSource.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/WebDocument.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/WebFrame.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/WebNode.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/WebScriptSource.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/WebSecurityPolicy.h"
#include "third_party/WebKit/Source/WebKit/chromium/public/WebView.h"
#include "webkit/glue/webkit_glue.h"

using WebKit::WebFrame;
using WebKit::WebScriptSource;
using WebKit::WebString;
using WebKit::WebURL;
using WebKit::WebView;

namespace {

const int64 kInvalidBrowserId = -1;
const int64 kInvalidFrameId = -1;

}  // namespace


// CefBrowserImpl static methods.
// -----------------------------------------------------------------------------

// static
CefRefPtr<CefBrowserImpl> CefBrowserImpl::GetBrowserForView(
    content::RenderView* view) {
  return CefContentRendererClient::Get()->GetBrowserForView(view);
}

// static
CefRefPtr<CefBrowserImpl> CefBrowserImpl::GetBrowserForMainFrame(
    WebKit::WebFrame* frame) {
  return CefContentRendererClient::Get()->GetBrowserForMainFrame(frame);
}


// CefBrowser methods.
// -----------------------------------------------------------------------------

CefRefPtr<CefBrowserHost> CefBrowserImpl::GetHost() {
  NOTREACHED() << "GetHost cannot be called from the render process";
  return NULL;
}

bool CefBrowserImpl::CanGoBack() {
  CEF_REQUIRE_RT_RETURN(false);

  return webkit_glue::CanGoBackOrForward(render_view()->GetWebView(), -1);
}

void CefBrowserImpl::GoBack() {
  CEF_REQUIRE_RT_RETURN_VOID();

  webkit_glue::GoBackOrForward(render_view()->GetWebView(), -1);
}

bool CefBrowserImpl::CanGoForward() {
  CEF_REQUIRE_RT_RETURN(false);

  return webkit_glue::CanGoBackOrForward(render_view()->GetWebView(), 1);
}

void CefBrowserImpl::GoForward() {
  CEF_REQUIRE_RT_RETURN_VOID();

  webkit_glue::GoBackOrForward(render_view()->GetWebView(), 1);
}

bool CefBrowserImpl::IsLoading() {
  CEF_REQUIRE_RT_RETURN(false);

  if (render_view()->GetWebView() && render_view()->GetWebView()->mainFrame())
    return render_view()->GetWebView()->mainFrame()->isLoading();
  return false;
}

void CefBrowserImpl::Reload() {
  CEF_REQUIRE_RT_RETURN_VOID();

  if (render_view()->GetWebView() && render_view()->GetWebView()->mainFrame())
    render_view()->GetWebView()->mainFrame()->reload(false);
}

void CefBrowserImpl::ReloadIgnoreCache() {
  CEF_REQUIRE_RT_RETURN_VOID();

  if (render_view()->GetWebView() && render_view()->GetWebView()->mainFrame())
    render_view()->GetWebView()->mainFrame()->reload(true);
}

void CefBrowserImpl::StopLoad() {
  CEF_REQUIRE_RT_RETURN_VOID();

  if (render_view()->GetWebView() && render_view()->GetWebView()->mainFrame())
    render_view()->GetWebView()->mainFrame()->stopLoading();
}

int CefBrowserImpl::GetIdentifier() {
  CEF_REQUIRE_RT_RETURN(0);

  return browser_window_id();
}

bool CefBrowserImpl::IsPopup() {
  CEF_REQUIRE_RT_RETURN(false);

  return is_popup_;
}

bool CefBrowserImpl::HasDocument() {
  CEF_REQUIRE_RT_RETURN(false);

  if (render_view()->GetWebView() && render_view()->GetWebView()->mainFrame())
    return !render_view()->GetWebView()->mainFrame()->document().isNull();
  return false;
}

CefRefPtr<CefFrame> CefBrowserImpl::GetMainFrame() {
  CEF_REQUIRE_RT_RETURN(NULL);

  if (render_view()->GetWebView() && render_view()->GetWebView()->mainFrame())
    return GetWebFrameImpl(render_view()->GetWebView()->mainFrame()).get();
  return NULL;
}

CefRefPtr<CefFrame> CefBrowserImpl::GetFocusedFrame() {
  CEF_REQUIRE_RT_RETURN(NULL);

  if (render_view()->GetWebView() &&
      render_view()->GetWebView()->focusedFrame()) {
    return GetWebFrameImpl(render_view()->GetWebView()->focusedFrame()).get();
  }
  return NULL;
}

CefRefPtr<CefFrame> CefBrowserImpl::GetFrame(int64 identifier) {
  CEF_REQUIRE_RT_RETURN(NULL);

  return GetWebFrameImpl(identifier).get();
}

CefRefPtr<CefFrame> CefBrowserImpl::GetFrame(const CefString& name) {
  CEF_REQUIRE_RT_RETURN(NULL);

  if (render_view()->GetWebView()) {
    WebFrame* frame =
        render_view()->GetWebView()->findFrameByName(name.ToString16());
    if (frame)
      return GetWebFrameImpl(frame).get();
  }

  return NULL;
}

size_t CefBrowserImpl::GetFrameCount() {
  CEF_REQUIRE_RT_RETURN(0);

  int count = 0;

  if (render_view()->GetWebView()) {
    WebFrame* main_frame = render_view()->GetWebView()->mainFrame();
    if (main_frame) {
      WebFrame* cur = main_frame;
      do {
        count++;
        cur = cur->traverseNext(true);
      } while (cur != main_frame);
    }
  }

  return count;
}

void CefBrowserImpl::GetFrameIdentifiers(std::vector<int64>& identifiers) {
  CEF_REQUIRE_RT_RETURN_VOID();

  if (render_view()->GetWebView()) {
    WebFrame* main_frame = render_view()->GetWebView()->mainFrame();
    if (main_frame) {
      WebFrame* cur = main_frame;
      do {
        identifiers.push_back(cur->identifier());
        cur = cur->traverseNext(true);
      } while (cur != main_frame);
    }
  }
}

void CefBrowserImpl::GetFrameNames(std::vector<CefString>& names) {
  CEF_REQUIRE_RT_RETURN_VOID();

  if (render_view()->GetWebView()) {
    WebFrame* main_frame = render_view()->GetWebView()->mainFrame();
    if (main_frame) {
      WebFrame* cur = main_frame;
      do {
        names.push_back(CefString(cur->name().utf8()));
        cur = cur->traverseNext(true);
      } while (cur != main_frame);
    }
  }
}

bool CefBrowserImpl::SendProcessMessage(CefProcessId target_process,
                                        CefRefPtr<CefProcessMessage> message) {
  DCHECK_EQ(PID_BROWSER, target_process);
  DCHECK(message.get());

  Cef_Request_Params params;
  CefProcessMessageImpl* impl =
      static_cast<CefProcessMessageImpl*>(message.get());
  if (impl->CopyTo(params)) {
    DCHECK(!params.name.empty());

    params.frame_id = -1;
    params.user_initiated = true;
    params.request_id = -1;
    params.expect_response = false;

    return Send(new CefHostMsg_Request(routing_id(), params));
  }

  return false;
}


// CefBrowserImpl public methods.
// -----------------------------------------------------------------------------

CefBrowserImpl::CefBrowserImpl(content::RenderView* render_view)
    : content::RenderViewObserver(render_view),
      browser_window_id_(kInvalidBrowserId),
      is_popup_(false),
      last_focused_frame_id_(kInvalidFrameId) {
  response_manager_.reset(new CefResponseManager);
}

CefBrowserImpl::~CefBrowserImpl() {
}

void CefBrowserImpl::LoadRequest(const CefMsg_LoadRequest_Params& params) {
  CefRefPtr<CefFrameImpl> framePtr = GetWebFrameImpl(params.frame_id);
  if (!framePtr.get())
    return;

  WebFrame* web_frame = framePtr->web_frame();

  WebKit::WebURLRequest request(params.url);

  // DidCreateDataSource checks for this value.
  request.setRequestorID(-1);

  if (!params.method.empty())
    request.setHTTPMethod(ASCIIToUTF16(params.method));

  if (params.referrer.is_valid()) {
    WebString referrer = WebKit::WebSecurityPolicy::generateReferrerHeader(
        static_cast<WebKit::WebReferrerPolicy>(params.referrer_policy),
        params.url,
        WebString::fromUTF8(params.referrer.spec()));
    if (!referrer.isEmpty())
      request.setHTTPHeaderField(WebString::fromUTF8("Referer"), referrer);
  }

  if (params.first_party_for_cookies.is_valid())
    request.setFirstPartyForCookies(params.first_party_for_cookies);

  if (!params.headers.empty()) {
    for (net::HttpUtil::HeadersIterator i(params.headers.begin(),
                                          params.headers.end(), "\n");
         i.GetNext(); ) {
      request.addHTTPHeaderField(WebString::fromUTF8(i.name()),
                                 WebString::fromUTF8(i.values()));
    }
  }

  if (params.upload_data.get()) {
    string16 method = request.httpMethod();
    if (method == ASCIIToUTF16("GET") || method == ASCIIToUTF16("HEAD"))
      request.setHTTPMethod(ASCIIToUTF16("POST"));

    if (request.httpHeaderField(ASCIIToUTF16("Content-Type")).length() == 0) {
      request.setHTTPHeaderField(
          ASCIIToUTF16("Content-Type"),
          ASCIIToUTF16("application/x-www-form-urlencoded"));
    }

    WebKit::WebHTTPBody body;
    body.initialize();

    std::vector<net::UploadData::Element>* elements =
        params.upload_data->elements();
    std::vector<net::UploadData::Element>::const_iterator it =
        elements->begin();
    for (; it != elements->end(); ++it) {
      const net::UploadData::Element& element = *it;
      if (element.type() == net::UploadData::TYPE_BYTES) {
        WebKit::WebData data;
        data.assign(std::string(element.bytes().begin(),
                                element.bytes().end()).c_str(),
                    element.bytes().size());
        body.appendData(data);
      } else if (element.type() == net::UploadData::TYPE_FILE) {
        body.appendFile(webkit_glue::FilePathToWebString(element.file_path()));
      } else {
        NOTREACHED();
      }
    }

    request.setHTTPBody(body);
  }

  web_frame->loadRequest(request);
}

CefRefPtr<CefFrameImpl> CefBrowserImpl::GetWebFrameImpl(
    WebKit::WebFrame* frame) {
  DCHECK(frame);
  int64 frame_id = frame->identifier();

  // Frames are re-used between page loads. Only add the frame to the map once.
  FrameMap::const_iterator it = frames_.find(frame_id);
  if (it != frames_.end())
    return it->second;

  CefRefPtr<CefFrameImpl> framePtr(new CefFrameImpl(this, frame));
  frames_.insert(std::make_pair(frame_id, framePtr));

  int64 parent_id = frame->parent() == NULL ?
      kInvalidFrameId : frame->parent()->identifier();
  string16 name = frame->name();

  // Notify the browser that the frame has been identified.
  Send(new CefHostMsg_FrameIdentified(routing_id(), frame_id, parent_id, name));

  return framePtr;
}

CefRefPtr<CefFrameImpl> CefBrowserImpl::GetWebFrameImpl(int64 frame_id) {
  if (frame_id == kInvalidFrameId) {
    if (render_view()->GetWebView() && render_view()->GetWebView()->mainFrame())
      return GetWebFrameImpl(render_view()->GetWebView()->mainFrame());
    return NULL;
  }

  // Check if we already know about the frame.
  FrameMap::const_iterator it = frames_.find(frame_id);
  if (it != frames_.end())
    return it->second;

  if (render_view()->GetWebView()) {
    // Check if the frame exists but we don't know about it yet.
    WebFrame* main_frame = render_view()->GetWebView()->mainFrame();
    if (main_frame) {
      WebFrame* cur = main_frame;
      do {
        if (cur->identifier() == frame_id)
          return GetWebFrameImpl(cur);
        cur = cur->traverseNext(true);
      } while (cur != main_frame);
    }
  }

  return NULL;
}

void CefBrowserImpl::AddFrameObject(int64 frame_id,
                                    CefTrackNode* tracked_object) {
  CefRefPtr<CefTrackManager> manager;

  if (!frame_objects_.empty()) {
    FrameObjectMap::const_iterator it = frame_objects_.find(frame_id);
    if (it != frame_objects_.end())
      manager = it->second;
  }

  if (!manager.get()) {
    manager = new CefTrackManager();
    frame_objects_.insert(std::make_pair(frame_id, manager));
  }

  manager->Add(tracked_object);
}


// RenderViewObserver methods.
// -----------------------------------------------------------------------------

void CefBrowserImpl::OnDestruct() {
  // Notify that the browser window has been destroyed.
  CefRefPtr<CefApp> app = CefContentClient::Get()->application();
  if (app.get()) {
    CefRefPtr<CefRenderProcessHandler> handler =
        app->GetRenderProcessHandler();
    if (handler.get())
      handler->OnBrowserDestroyed(this);
  }

  response_manager_.reset(NULL);

  CefContentRendererClient::Get()->OnBrowserDestroyed(this);
}

void CefBrowserImpl::DidStartProvisionalLoad(WebKit::WebFrame* frame) {
  // Send the frame creation notification if necessary.
  GetWebFrameImpl(frame);
}

void CefBrowserImpl::FrameDetached(WebFrame* frame) {
  int64 frame_id = frame->identifier();

  {
    // Remove the frame from the map.
    FrameMap::iterator it = frames_.find(frame_id);
    DCHECK(it != frames_.end());
    it->second->Detach();
    frames_.erase(it);
  }

  if (!frame_objects_.empty()) {
    // Remove any tracked objects associated with the frame.
    FrameObjectMap::iterator it = frame_objects_.find(frame_id);
    if (it != frame_objects_.end())
      frame_objects_.erase(it);
  }

  // Notify the browser that the frame has detached.
  Send(new CefHostMsg_FrameDetached(routing_id(), frame_id));
}

void CefBrowserImpl::FocusedNodeChanged(const WebKit::WebNode& node) {
  // Notify the handler.
  CefRefPtr<CefApp> app = CefContentClient::Get()->application();
  if (app.get()) {
    CefRefPtr<CefRenderProcessHandler> handler =
        app->GetRenderProcessHandler();
    if (handler.get()) {
      if (node.isNull()) {
        handler->OnFocusedNodeChanged(this, GetFocusedFrame(), NULL);
      } else {
        const WebKit::WebDocument& document = node.document();
        if (!document.isNull()) {
          WebKit::WebFrame* frame = document.frame();
          CefRefPtr<CefDOMDocumentImpl> documentImpl =
              new CefDOMDocumentImpl(this, frame);
          handler->OnFocusedNodeChanged(this,
              GetWebFrameImpl(frame).get(),
              documentImpl->GetOrCreateNode(node));
          documentImpl->Detach();
        }
      }
    }
  }

  // TODO(cef): This method is being used as a work-around for identifying frame
  // focus changes. The ideal approach would be implementating delegation from
  // ChromeClientImpl::focusedFrameChanged().

  WebFrame* focused_frame = NULL;

  // Try to identify the focused frame from the node.
  if (!node.isNull()) {
    const WebKit::WebDocument& document = node.document();
    if (!document.isNull())
      focused_frame = document.frame();
  }

  if (focused_frame == NULL && render_view()->GetWebView()) {
    // Try to identify the global focused frame.
    focused_frame = render_view()->GetWebView()->focusedFrame();
  }

  int64 frame_id = kInvalidFrameId;
  if (focused_frame != NULL)
    frame_id = focused_frame->identifier();

  // Don't send a message if the focused frame has not changed.
  if (frame_id == last_focused_frame_id_)
    return;

  last_focused_frame_id_ = frame_id;
  Send(new CefHostMsg_FrameFocusChange(routing_id(), frame_id));
}

void CefBrowserImpl::DidCreateDataSource(WebKit::WebFrame* frame,
                                         WebKit::WebDataSource* ds) {
  const WebKit::WebURLRequest& request = ds->request();
  if (request.requestorID() == -1) {
    // Mark the request as browser-initiated so
    // RenderViewImpl::decidePolicyForNavigation won't attempt to fork it.
    content::DocumentState* document_state =
        content::DocumentState::FromDataSource(ds);
    document_state->set_navigation_state(
        content::NavigationState::CreateBrowserInitiated(-1, -1,
            content::PAGE_TRANSITION_LINK));
  }

  if (frame->parent() == 0) {
    GURL url = ds->request().url();
    if (!url.is_empty()) {
      // Notify that the loading URL has changed.
      Send(new CefHostMsg_LoadingURLChange(routing_id(), url));
    }
  }
}

bool CefBrowserImpl::OnMessageReceived(const IPC::Message& message) {
  bool handled = true;
  IPC_BEGIN_MESSAGE_MAP(CefBrowserImpl, message)
    IPC_MESSAGE_HANDLER(CefMsg_UpdateBrowserWindowId,
                        OnUpdateBrowserWindowId)
    IPC_MESSAGE_HANDLER(CefMsg_Request, OnRequest)
    IPC_MESSAGE_HANDLER(CefMsg_Response, OnResponse)
    IPC_MESSAGE_HANDLER(CefMsg_ResponseAck, OnResponseAck)
    IPC_MESSAGE_HANDLER(CefMsg_LoadRequest, LoadRequest)
    IPC_MESSAGE_UNHANDLED(handled = false)
  IPC_END_MESSAGE_MAP()
  return handled;
}


// RenderViewObserver::OnMessageReceived message handlers.
// -----------------------------------------------------------------------------

void CefBrowserImpl::OnUpdateBrowserWindowId(int window_id, bool is_popup) {
  // This message should only be sent one time.
  DCHECK(browser_window_id_ == kInvalidBrowserId);

  browser_window_id_ = window_id;
  is_popup_ = is_popup;

  // Notify that the browser window has been created.
  CefRefPtr<CefApp> app = CefContentClient::Get()->application();
  if (app.get()) {
    CefRefPtr<CefRenderProcessHandler> handler =
        app->GetRenderProcessHandler();
    if (handler.get())
      handler->OnBrowserCreated(this);
  }
}

void CefBrowserImpl::OnRequest(const Cef_Request_Params& params) {
  bool success = false;
  std::string response;
  bool expect_response_ack = false;

  if (params.user_initiated) {
    // Give the user a chance to handle the request.
    CefRefPtr<CefApp> app = CefContentClient::Get()->application();
    if (app.get()) {
      CefRefPtr<CefRenderProcessHandler> handler =
          app->GetRenderProcessHandler();
      if (handler.get()) {
        CefRefPtr<CefProcessMessageImpl> message(
            new CefProcessMessageImpl(const_cast<Cef_Request_Params*>(&params),
                                      false, true));
        success = handler->OnProcessMessageReceived(this, PID_BROWSER,
                                                    message.get());
        message->Detach(NULL);
      }
    }
  } else if (params.name == "execute-code") {
    // Execute code.
    CefRefPtr<CefFrameImpl> framePtr = GetWebFrameImpl(params.frame_id);
    if (framePtr.get()) {
      WebFrame* web_frame = framePtr->web_frame();
      if (web_frame) {
        DCHECK_EQ(params.arguments.GetSize(), (size_t)4);

        bool is_javascript = false;
        string16 code, script_url;
        int script_start_line = 0;

        params.arguments.GetBoolean(0, &is_javascript);
        params.arguments.GetString(1, &code);
        DCHECK(!code.empty());
        params.arguments.GetString(2, &script_url);
        params.arguments.GetInteger(3, &script_start_line);
        DCHECK_GE(script_start_line, 0);

        if (is_javascript) {
          web_frame->executeScript(
              WebScriptSource(code,
                              GURL(UTF16ToUTF8(script_url)),
                              script_start_line));
          success = true;
        } else {
          // TODO(cef): implement support for CSS code.
          NOTIMPLEMENTED();
        }
      }
    }
  } else if (params.name == "execute-command") {
    // Execute command.
    CefRefPtr<CefFrameImpl> framePtr = GetWebFrameImpl(params.frame_id);
    if (framePtr.get()) {
      WebFrame* web_frame = framePtr->web_frame();
      if (web_frame) {
        DCHECK_EQ(params.arguments.GetSize(), (size_t)1);

        string16 command;

        params.arguments.GetString(0, &command);
        DCHECK(!command.empty());

        if (LowerCaseEqualsASCII(command, "getsource")) {
          response = web_frame->contentAsMarkup().utf8();
          success = true;
        } else if (LowerCaseEqualsASCII(command, "gettext")) {
          response = UTF16ToUTF8(webkit_glue::DumpDocumentText(web_frame));
          success = true;
        } else if (web_frame->executeCommand(command)) {
          success = true;
        }
      }
    }
  } else if (params.name == "load-string") {
    // Load a string.
    CefRefPtr<CefFrameImpl> framePtr = GetWebFrameImpl(params.frame_id);
    if (framePtr.get()) {
      WebFrame* web_frame = framePtr->web_frame();
      if (web_frame) {
        DCHECK_EQ(params.arguments.GetSize(), (size_t)2);

        string16 string, url;

        params.arguments.GetString(0, &string);
        params.arguments.GetString(1, &url);

        web_frame->loadHTMLString(UTF16ToUTF8(string), GURL(UTF16ToUTF8(url)));
      }
    }
  } else {
    // Invalid request.
    NOTREACHED();
  }

  if (params.expect_response) {
    DCHECK_GE(params.request_id, 0);

    // Send a response to the browser.
    Cef_Response_Params response_params;
    response_params.request_id = params.request_id;
    response_params.success = success;
    response_params.response = response;
    response_params.expect_response_ack = expect_response_ack;
    Send(new CefHostMsg_Response(routing_id(), response_params));
  }
}

void CefBrowserImpl::OnResponse(const Cef_Response_Params& params) {
  response_manager_->RunHandler(params);
  if (params.expect_response_ack)
    Send(new CefHostMsg_ResponseAck(routing_id(), params.request_id));
}

void CefBrowserImpl::OnResponseAck(int request_id) {
  response_manager_->RunAckHandler(request_id);
}
