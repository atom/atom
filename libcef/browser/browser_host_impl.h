// Copyright (c) 2012 The Chromium Embedded Framework Authors.
// Portions copyright (c) 2011 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_BROWSER_HOST_IMPL_H_
#define CEF_LIBCEF_BROWSER_BROWSER_HOST_IMPL_H_
#pragma once

#include <map>
#include <queue>
#include <string>
#include <vector>

#include "include/cef_browser.h"
#include "include/cef_client.h"
#include "include/cef_frame.h"
#include "libcef/browser/frame_host_impl.h"
#include "libcef/browser/javascript_dialog_creator.h"
#include "libcef/browser/menu_creator.h"
#include "libcef/common/response_manager.h"

#include "base/memory/scoped_ptr.h"
#include "base/string16.h"
#include "base/synchronization/lock.h"
#include "content/public/browser/notification_observer.h"
#include "content/public/browser/notification_registrar.h"
#include "content/public/browser/web_contents.h"
#include "content/public/browser/web_contents_delegate.h"
#include "content/public/browser/web_contents_observer.h"
#include "net/url_request/url_request_context_getter.h"

namespace content {
struct NativeWebKeyboardEvent;
}

namespace net {
class URLRequest;
}

struct Cef_Request_Params;
struct Cef_Response_Params;
struct CefNavigateParams;
class SiteInstance;

// Implementation of CefBrowser.
//
// WebContentsDelegate: Interface for handling WebContents delegations. There is
// a one-to-one relationship between CefBrowserHostImpl and WebContents
// instances.
//
// WebContentsObserver: Interface for observing WebContents notifications and
// IPC messages. There is a one-to-one relationship between WebContents and
// RenderViewHost instances. IPC messages received by the RenderViewHost will be
// forwarded to this WebContentsObserver implementation via WebContents. IPC
// messages sent using CefBrowserHostImpl::Send() will be forwarded to the
// RenderViewHost (after posting to the UI thread if necessary). Use
// WebContentsObserver::routing_id() when sending IPC messages.
//
// NotificationObserver: Interface for observing post-processed notifications.
class CefBrowserHostImpl : public CefBrowserHost,
                           public CefBrowser,
                           public content::WebContentsDelegate,
                           public content::WebContentsObserver,
                           public content::NotificationObserver {
 public:
  // Used for handling the response to command messages.
  class CommandResponseHandler : public virtual CefBase {
   public:
     virtual void OnResponse(const std::string& response) =0;
  };

  virtual ~CefBrowserHostImpl() {}

  // Create a new CefBrowserHostImpl instance.
  static CefRefPtr<CefBrowserHostImpl> Create(
      const CefWindowInfo& window_info,
      const CefBrowserSettings& settings,
      CefRefPtr<CefClient> client,
      content::WebContents* web_contents,
      CefWindowHandle opener);

  // Returns the browser associated with the specified RenderViewHost.
  static CefRefPtr<CefBrowserHostImpl> GetBrowserForHost(
      const content::RenderViewHost* host);
  // Returns the browser associated with the specified WebContents.
  static CefRefPtr<CefBrowserHostImpl> GetBrowserForContents(
      content::WebContents* contents);
  // Returns the browser associated with the specified URLRequest.
  static CefRefPtr<CefBrowserHostImpl> GetBrowserForRequest(
      net::URLRequest* request);
  // Returns the browser associated with the specified routing IDs.
  static CefRefPtr<CefBrowserHostImpl> GetBrowserByRoutingID(
      int render_process_id, int render_view_id);
  // Returns the browser associated with the specified child process ID.
  static CefRefPtr<CefBrowserHostImpl> GetBrowserByChildID(
      int render_process_id);

  // CefBrowserHost methods.
  virtual CefRefPtr<CefBrowser> GetBrowser() OVERRIDE;
  virtual void CloseBrowser() OVERRIDE;
  virtual void ParentWindowWillClose() OVERRIDE;
  virtual void SetFocus(bool enable) OVERRIDE;
  virtual CefWindowHandle GetWindowHandle() OVERRIDE;
  virtual CefWindowHandle GetOpenerWindowHandle() OVERRIDE;
  virtual CefRefPtr<CefClient> GetClient() OVERRIDE;
  virtual CefString GetDevToolsURL(bool http_scheme) OVERRIDE;
  virtual double GetZoomLevel() OVERRIDE;
  virtual void SetZoomLevel(double zoomLevel) OVERRIDE;

  // CefBrowser methods.
  virtual CefRefPtr<CefBrowserHost> GetHost() OVERRIDE;
  virtual bool CanGoBack() OVERRIDE;
  virtual void GoBack() OVERRIDE;
  virtual bool CanGoForward() OVERRIDE;
  virtual void GoForward() OVERRIDE;
  virtual bool IsLoading() OVERRIDE;
  virtual void Reload() OVERRIDE;
  virtual void ReloadIgnoreCache() OVERRIDE;
  virtual void StopLoad() OVERRIDE;
  virtual int GetIdentifier() OVERRIDE;
  virtual bool IsPopup() OVERRIDE;
  virtual bool HasDocument() OVERRIDE;
  virtual CefRefPtr<CefFrame> GetMainFrame() OVERRIDE;
  virtual CefRefPtr<CefFrame> GetFocusedFrame() OVERRIDE;
  virtual CefRefPtr<CefFrame> GetFrame(int64 identifier) OVERRIDE;
  virtual CefRefPtr<CefFrame> GetFrame(const CefString& name) OVERRIDE;
  virtual size_t GetFrameCount() OVERRIDE;
  virtual void GetFrameIdentifiers(std::vector<int64>& identifiers) OVERRIDE;
  virtual void GetFrameNames(std::vector<CefString>& names) OVERRIDE;
  virtual bool SendProcessMessage(
      CefProcessId target_process,
      CefRefPtr<CefProcessMessage> message) OVERRIDE;

  // Set the unique identifier for this browser.
  void SetUniqueId(int unique_id);

  // Destroy the browser members. This method should only be called after the
  // native browser window is not longer processing messages.
  void DestroyBrowser();

  // Returns the native view for the WebContents.
  gfx::NativeView GetContentView() const;

  // Returns a pointer to the WebContents.
  content::WebContents* GetWebContents() const;

  // Returns the browser-specific request context.
  net::URLRequestContextGetter* GetRequestContext();

  // Returns the frame associated with the specified URLRequest.
  CefRefPtr<CefFrame> GetFrameForRequest(net::URLRequest* request);

  // Navigate as specified by the |params| argument.
  void Navigate(const CefNavigateParams& params);

  // Load the specified request.
  void LoadRequest(int64 frame_id, CefRefPtr<CefRequest> request);

  // Load the specified URL.
  void LoadURL(int64 frame_id, const std::string& url);

  // Load the specified string.
  void LoadString(int64 frame_id, const CefString& string,
                  const CefString& url);

  // Send a command to the renderer for execution.
  void SendCommand(int64 frame_id, const CefString& command,
                   CefRefPtr<CefResponseManager::Handler> responseHandler);

  // Send code to the renderer for execution.
  void SendCode(int64 frame_id, bool is_javascript, const CefString& code,
                const CefString& script_url, int script_start_line,
                CefRefPtr<CefResponseManager::Handler> responseHandler);

  // Open the specified text in the default text editor.
  bool ViewText(const std::string& text);

  // Handler for URLs involving external protocols.
  void HandleExternalProtocol(const GURL& url);

  // Returns true if this browser matches the specified ID values. If
  // |render_view_id| is 0 any browser with the specified |render_process_id|
  // will match.
  bool HasIDMatch(int render_process_id, int render_view_id);

  // Thread safe accessors.
  const CefBrowserSettings& settings() const { return settings_; }
  CefRefPtr<CefClient> client() const { return client_; }
  int unique_id() const { return unique_id_; }

  // Returns the URL that is currently loading (or loaded) in the main frame.
  GURL GetLoadingURL();

#if defined(OS_WIN)
  static void RegisterWindowClass();
#endif

  void OnSetFocus(cef_focus_source_t source);

 private:
  // content::WebContentsDelegate methods.
  virtual content::WebContents* OpenURLFromTab(
      content::WebContents* source,
      const content::OpenURLParams& params) OVERRIDE;
  virtual void LoadingStateChanged(content::WebContents* source) OVERRIDE;
  virtual void CloseContents(content::WebContents* source) OVERRIDE;
  virtual bool TakeFocus(bool reverse) OVERRIDE;
  virtual void WebContentsFocused(content::WebContents* contents) OVERRIDE;
  virtual bool HandleContextMenu(const content::ContextMenuParams& params)
      OVERRIDE;
  virtual bool PreHandleKeyboardEvent(
      const content::NativeWebKeyboardEvent& event,
      bool* is_keyboard_shortcut) OVERRIDE;
  virtual void HandleKeyboardEvent(
      const content::NativeWebKeyboardEvent& event) OVERRIDE;
  virtual bool ShouldCreateWebContents(
      content::WebContents* web_contents,
      int route_id,
      WindowContainerType window_container_type,
      const string16& frame_name,
      const GURL& target_url) OVERRIDE;
  virtual void WebContentsCreated(content::WebContents* source_contents,
                                  int64 source_frame_id,
                                  const GURL& target_url,
                                  content::WebContents* new_contents) OVERRIDE;
  virtual void DidNavigateMainFramePostCommit(
      content::WebContents* tab) OVERRIDE;
  virtual content::JavaScriptDialogCreator* GetJavaScriptDialogCreator()
      OVERRIDE;
  virtual void RunFileChooser(
      content::WebContents* tab,
      const content::FileChooserParams& params) OVERRIDE;
  virtual void UpdatePreferredSize(content::WebContents* source,
                                   const gfx::Size& pref_size) OVERRIDE;
  virtual void RequestMediaAccessPermission(
      content::WebContents* web_contents,
      const content::MediaStreamRequest* request,
      const content::MediaResponseCallback& callback) OVERRIDE;

  // content::WebContentsObserver methods.
  virtual void RenderViewCreated(
      content::RenderViewHost* render_view_host) OVERRIDE;
  virtual void RenderViewDeleted(
      content::RenderViewHost* render_view_host) OVERRIDE;
  virtual void RenderViewReady() OVERRIDE;
  virtual void RenderViewGone(base::TerminationStatus status) OVERRIDE;
  virtual void DidCommitProvisionalLoadForFrame(
      int64 frame_id,
      bool is_main_frame,
      const GURL& url,
      content::PageTransition transition_type,
      content::RenderViewHost* render_view_host) OVERRIDE;
  virtual void DidFailProvisionalLoad(
      int64 frame_id,
      bool is_main_frame,
      const GURL& validated_url,
      int error_code,
      const string16& error_description,
      content::RenderViewHost* render_view_host) OVERRIDE;
  virtual void DocumentAvailableInMainFrame() OVERRIDE;
  virtual void DidFinishLoad(int64 frame_id,
                             const GURL& validated_url,
                             bool is_main_frame) OVERRIDE;
  virtual void DidFailLoad(int64 frame_id,
                           const GURL& validated_url,
                           bool is_main_frame,
                           int error_code,
                           const string16& error_description) OVERRIDE;
  virtual void PluginCrashed(const FilePath& plugin_path) OVERRIDE;
  virtual bool OnMessageReceived(const IPC::Message& message) OVERRIDE;
  // Override to provide a thread safe implementation.
  virtual bool Send(IPC::Message* message) OVERRIDE;

  // content::WebContentsObserver::OnMessageReceived() message handlers.
  void OnFrameIdentified(int64 frame_id, int64 parent_frame_id, string16 name);
  void OnLoadingURLChange(const GURL& pending_url);
  void OnRequest(const Cef_Request_Params& params);
  void OnResponse(const Cef_Response_Params& params);
  void OnResponseAck(int request_id);

  // content::NotificationObserver methods.
  virtual void Observe(int type,
                       const content::NotificationSource& source,
                       const content::NotificationDetails& details) OVERRIDE;

  CefBrowserHostImpl(const CefWindowInfo& window_info,
                     const CefBrowserSettings& settings,
                     CefRefPtr<CefClient> client,
                     content::WebContents* web_contents,
                     CefWindowHandle opener);

  // Initialize settings based on the specified RenderViewHost.
  void SetRenderViewHost(content::RenderViewHost* rvh);

  // Updates and returns an existing frame or creates a new frame. Pass
  // CefFrameHostImpl::kUnspecifiedFrameId for |parent_frame_id| if unknown.
  CefRefPtr<CefFrame> GetOrCreateFrame(int64 frame_id,
                                       int64 parent_frame_id,
                                       bool is_main_frame,
                                       string16 frame_name,
                                       const GURL& frame_url);
  // Remove the reference to the frame and mark it as detached.
  void DetachFrame(int64 frame_id);
  // Remove the references to all frames and mark them as detached.
  void DetachAllFrames();
  // Set the frame that currently has focus.
  void SetFocusedFrame(int64 frame_id);

#if defined(OS_WIN)
  static LPCTSTR GetWndClass();
  static LRESULT CALLBACK WndProc(HWND hwnd, UINT message,
                                  WPARAM wParam, LPARAM lParam);
#endif

  // Create the window.
  bool PlatformCreateWindow();
  // Sends a message via the OS to close the native browser window.
  // DestroyBrowser will be called after the native window has closed.
  void PlatformCloseWindow();
  // Resize the window to the given dimensions.
  void PlatformSizeTo(int width, int height);
  // Return the handle for this window.
  CefWindowHandle PlatformGetWindowHandle();
  // Open the specified text in the default text editor.
  bool PlatformViewText(const std::string& text);
  // Forward the keyboard event to the application or frame window to allow
  // processing of shortcut keys.
  void PlatformHandleKeyboardEvent(
      const content::NativeWebKeyboardEvent& event);
  // Invoke platform specific file open chooser.
  void PlatformRunFileChooser(
      content::WebContents* contents,
      const content::FileChooserParams& params,
      std::vector<FilePath>& files);
  // Invoke platform specific handling for the external protocol.
  void PlatformHandleExternalProtocol(const GURL& url);

  void OnAddressChange(CefRefPtr<CefFrame> frame,
                       const GURL& url);
  void OnLoadStart(CefRefPtr<CefFrame> frame,
                   const GURL& url,
                   content::PageTransition transition_type);
  void OnLoadError(CefRefPtr<CefFrame> frame,
                   const GURL& url,
                   int error_code,
                   const string16& error_description);
  void OnLoadEnd(CefRefPtr<CefFrame> frame,
                 const GURL& url);

  CefWindowInfo window_info_;
  CefBrowserSettings settings_;
  CefRefPtr<CefClient> client_;
  scoped_ptr<content::WebContents> web_contents_;
  CefWindowHandle opener_;

  // Unique ids used for routing communication to/from the renderer. We keep a
  // copy of them as member variables so that we can locate matching browsers in
  // a thread safe manner. All access must be protected by the state lock.
  int render_process_id_;
  int render_view_id_;

  // Unique id for the browser.
  int unique_id_;

  // True if the browser has received the page title for the current load.
  bool received_page_title_;

  // Used when creating a new popup window.
  CefWindowInfo pending_window_info_;
  CefBrowserSettings pending_settings_;
  CefRefPtr<CefClient> pending_client_;

  // Volatile state information. All access must be protected by the state lock.
  base::Lock state_lock_;
  bool is_loading_;
  bool can_go_back_;
  bool can_go_forward_;
  bool has_document_;
  GURL loading_url_;
  CefString devtools_url_http_;
  CefString devtools_url_chrome_;

  // Messages we queue while waiting for the RenderView to be ready. We queue
  // them here instead of in the RenderProcessHost to ensure that they're sent
  // after the CefRenderViewObserver has been created on the renderer side.
  std::queue<IPC::Message*> queued_messages_;
  bool queue_messages_;

  // Map of unique frame ids to CefFrameHostImpl references.
  typedef std::map<int64, CefRefPtr<CefFrameHostImpl> > FrameMap;
  FrameMap frames_;
  // The unique frame id currently identified as the main frame.
  int64 main_frame_id_;
  // The unique frame id currently identified as the focused frame.
  int64 focused_frame_id_;
  // Used when no other frame exists. Provides limited functionality.
  CefRefPtr<CefFrameHostImpl> placeholder_frame_;

  // True if currently in the OnSetFocus callback. Only accessed on the UI
  // thread.
  bool is_in_onsetfocus_;

  // True if the focus is currently on an editable field on the page. Only
  // accessed on the UI thread.
  bool focus_on_editable_field_;

  // Used for managing notification subscriptions.
  scoped_ptr<content::NotificationRegistrar> registrar_;

  // Used for proxying cookie requests.
  scoped_refptr<net::URLRequestContextGetter> request_context_proxy_;

  // Manages response registrations.
  scoped_ptr<CefResponseManager> response_manager_;

  // Used for creating and managing JavaScript dialogs.
  scoped_ptr<CefJavaScriptDialogCreator> dialog_creator_;

  // Used for creating and managing context menus.
  scoped_ptr<CefMenuCreator> menu_creator_;

  IMPLEMENT_REFCOUNTING(CefBrowserHostImpl);
  DISALLOW_EVIL_CONSTRUCTORS(CefBrowserHostImpl);
};

#endif  // CEF_LIBCEF_BROWSER_BROWSER_HOST_IMPL_H_
