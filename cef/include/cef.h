// Copyright (c) 2011 Marshall A. Greenblatt. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//    * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//    * Neither the name of Google Inc. nor the name Chromium Embedded
// Framework nor the names of its contributors may be used to endorse
// or promote products derived from this software without specific prior
// written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// ---------------------------------------------------------------------------
//
// The contents of this file must follow a specific format in order to
// support the CEF translator tool. See the translator.README.txt file in the
// tools directory for more information.
//


#ifndef _CEF_H
#define _CEF_H

#include <map>
#include <string>
#include <vector>
#include "internal/cef_build.h"
#include "internal/cef_ptr.h"
#include "internal/cef_types_wrappers.h"

///
// Bring in platform-specific definitions.
#if defined(OS_WIN)
#include "internal/cef_win.h"
#elif defined(OS_MACOSX)
#include "internal/cef_mac.h"
#elif defined(OS_LINUX)
#include "internal/cef_linux.h"
#endif

class CefApp;
class CefBrowser;
class CefClient;
class CefContentFilter;
class CefCookieVisitor;
class CefDOMDocument;
class CefDOMEvent;
class CefDOMEventListener;
class CefDOMNode;
class CefDOMVisitor;
class CefDownloadHandler;
class CefDragData;
class CefFrame;
class CefPostData;
class CefPostDataElement;
class CefRequest;
class CefResponse;
class CefSchemeHandler;
class CefSchemeHandlerFactory;
class CefStorageVisitor;
class CefStreamReader;
class CefStreamWriter;
class CefTask;
class CefV8Context;
class CefV8Handler;
class CefV8Value;
class CefWebURLRequest;
class CefWebURLRequestClient;

///
// This function should be called on the main application thread to initialize
// CEF when the application is started. The |application| parameter may be
// empty. A return value of true indicates that it succeeded and false indicates
// that it failed.
///
/*--cef(revision_check,optional_param=application)--*/
bool CefInitialize(const CefSettings& settings, CefRefPtr<CefApp> application);

///
// This function should be called on the main application thread to shut down
// CEF before the application exits.
///
/*--cef()--*/
void CefShutdown();

///
// Perform a single iteration of CEF message loop processing. This function is
// used to integrate the CEF message loop into an existing application message
// loop. Care must be taken to balance performance against excessive CPU usage.
// This function should only be called on the main application thread and only
// if CefInitialize() is called with a CefSettings.multi_threaded_message_loop
// value of false. This function will not block.
///
/*--cef()--*/
void CefDoMessageLoopWork();

///
// Run the CEF message loop. Use this function instead of an application-
// provided message loop to get the best balance between performance and CPU
// usage. This function should only be called on the main application thread and
// only if CefInitialize() is called with a
// CefSettings.multi_threaded_message_loop value of false. This function will
// block until a quit message is received by the system.
///
/*--cef()--*/
void CefRunMessageLoop();

///
// Quit the CEF message loop that was started by calling CefRunMessageLoop().
// This function should only be called on the main application thread and only
// if CefRunMessageLoop() was used.
///
/*--cef()--*/
void CefQuitMessageLoop();

///
// Register a new V8 extension with the specified JavaScript extension code and
// handler. Functions implemented by the handler are prototyped using the
// keyword 'native'. The calling of a native function is restricted to the scope
// in which the prototype of the native function is defined. This function may
// be called on any thread.
// 
// Example JavaScript extension code:
// <pre>
//   // create the 'example' global object if it doesn't already exist.
//   if (!example)
//     example = {};
//   // create the 'example.test' global object if it doesn't already exist.
//   if (!example.test)
//     example.test = {};
//   (function() {
//     // Define the function 'example.test.myfunction'.
//     example.test.myfunction = function() {
//       // Call CefV8Handler::Execute() with the function name 'MyFunction'
//       // and no arguments.
//       native function MyFunction();
//       return MyFunction();
//     };
//     // Define the getter function for parameter 'example.test.myparam'.
//     example.test.__defineGetter__('myparam', function() {
//       // Call CefV8Handler::Execute() with the function name 'GetMyParam'
//       // and no arguments.
//       native function GetMyParam();
//       return GetMyParam();
//     });
//     // Define the setter function for parameter 'example.test.myparam'.
//     example.test.__defineSetter__('myparam', function(b) {
//       // Call CefV8Handler::Execute() with the function name 'SetMyParam'
//       // and a single argument.
//       native function SetMyParam();
//       if(b) SetMyParam(b);
//     });
//
//     // Extension definitions can also contain normal JavaScript variables
//     // and functions.
//     var myint = 0;
//     example.test.increment = function() {
//       myint += 1;
//       return myint;
//     };
//   })();
// </pre>
// Example usage in the page:
// <pre>
//   // Call the function.
//   example.test.myfunction();
//   // Set the parameter.
//   example.test.myparam = value;
//   // Get the parameter.
//   value = example.test.myparam;
//   // Call another function.
//   example.test.increment();
// </pre>
///
/*--cef(optional_param=handler)--*/
bool CefRegisterExtension(const CefString& extension_name,
                          const CefString& javascript_code,
                          CefRefPtr<CefV8Handler> handler);

///
// Register a custom scheme. This method should not be called for the built-in
// HTTP, HTTPS, FILE, FTP, ABOUT and DATA schemes.
// 
// If |is_standard| is true the scheme will be treated as a standard scheme.
// Standard schemes are subject to URL canonicalization and parsing rules as
// defined in the Common Internet Scheme Syntax RFC 1738 Section 3.1 available
// at http://www.ietf.org/rfc/rfc1738.txt
// 
// In particular, the syntax for standard scheme URLs must be of the form:
// <pre>
//  [scheme]://[username]:[password]@[host]:[port]/[url-path]
// </pre>
// Standard scheme URLs must have a host component that is a fully qualified
// domain name as defined in Section 3.5 of RFC 1034 [13] and Section 2.1 of RFC
// 1123. These URLs will be canonicalized to "scheme://host/path" in the
// simplest case and "scheme://username:password@host:port/path" in the most
// explicit case. For example, "scheme:host/path" and "scheme:///host/path" will
// both be canonicalized to "scheme://host/path". The origin of a standard
// scheme URL is the combination of scheme, host and port (i.e.,
// "scheme://host:port" in the most explicit case).
// 
// For non-standard scheme URLs only the "scheme:" component is parsed and
// canonicalized. The remainder of the URL will be passed to the handler as-is.
// For example, "scheme:///some%20text" will remain the same. Non-standard
// scheme URLs cannot be used as a target for form submission.
// 
// If |is_local| is true the scheme will be treated as local (i.e., with the
// same security rules as those applied to "file" URLs). Normal pages cannot
// link to or access local URLs. Also, by default, local URLs can only perform
// XMLHttpRequest calls to the same URL (origin + path) that originated the
// request. To allow XMLHttpRequest calls from a local URL to other URLs with
// the same origin set the CefSettings.file_access_from_file_urls_allowed value
// to true. To allow XMLHttpRequest calls from a local URL to all origins set
// the CefSettings.universal_access_from_file_urls_allowed value to true.
// 
// If |is_display_isolated| is true the scheme will be treated as display-
// isolated. This means that pages cannot display these URLs unless they are
// from the same scheme. For example, pages in another origin cannot create
// iframes or hyperlinks to URLs with this scheme.
// 
// This function may be called on any thread. It should only be called once
// per unique |scheme_name| value. If |scheme_name| is already registered or if
// an error occurs this method will return false.
///
/*--cef()--*/
bool CefRegisterCustomScheme(const CefString& scheme_name,
                             bool is_standard,
                             bool is_local,
                             bool is_display_isolated);

///
// Register a scheme handler factory for the specified |scheme_name| and
// optional |domain_name|. An empty |domain_name| value for a standard scheme
// will cause the factory to match all domain names. The |domain_name| value
// will be ignored for non-standard schemes. If |scheme_name| is a built-in
// scheme and no handler is returned by |factory| then the built-in scheme
// handler factory will be called. If |scheme_name| is a custom scheme the
// CefRegisterCustomScheme() function should be called for that scheme.
// This function may be called multiple times to change or remove the factory
// that matches the specified |scheme_name| and optional |domain_name|.
// Returns false if an error occurs. This function may be called on any thread.
///
/*--cef(optional_param=domain_name,optional_param=factory)--*/
bool CefRegisterSchemeHandlerFactory(const CefString& scheme_name,
                                    const CefString& domain_name,
                                    CefRefPtr<CefSchemeHandlerFactory> factory);

///
// Clear all registered scheme handler factories. Returns false on error. This
// function may be called on any thread.
///
/*--cef()--*/
bool CefClearSchemeHandlerFactories();

///
// Add an entry to the cross-origin access whitelist.
//
// The same-origin policy restricts how scripts hosted from different origins
// (scheme + domain + port) can communicate. By default, scripts can only access
// resources with the same origin. Scripts hosted on the HTTP and HTTPS schemes
// (but no other schemes) can use the "Access-Control-Allow-Origin" header to
// allow cross-origin requests. For example, https://source.example.com can make
// XMLHttpRequest requests on http://target.example.com if the
// http://target.example.com request returns an "Access-Control-Allow-Origin:
// https://source.example.com" response header.
// 
// Scripts in separate frames or iframes and hosted from the same protocol and
// domain suffix can execute cross-origin JavaScript if both pages set the
// document.domain value to the same domain suffix. For example,
// scheme://foo.example.com and scheme://bar.example.com can communicate using
// JavaScript if both domains set document.domain="example.com".
// 
// This method is used to allow access to origins that would otherwise violate
// the same-origin policy. Scripts hosted underneath the fully qualified
// |source_origin| URL (like http://www.example.com) will be allowed access to
// all resources hosted on the specified |target_protocol| and |target_domain|.
// If |allow_target_subdomains| is true access will also be allowed to all
// subdomains of the target domain.
//
// This method cannot be used to bypass the restrictions on local or display
// isolated schemes. See the comments on CefRegisterCustomScheme for more
// information.
//
// This function may be called on any thread. Returns false if |source_origin|
// is invalid or the whitelist cannot be accessed.
///
/*--cef()--*/
bool CefAddCrossOriginWhitelistEntry(const CefString& source_origin,
                                     const CefString& target_protocol,
                                     const CefString& target_domain,
                                     bool allow_target_subdomains);

///
// Remove an entry from the cross-origin access whitelist. Returns false if
// |source_origin| is invalid or the whitelist cannot be accessed.
///
/*--cef()--*/
bool CefRemoveCrossOriginWhitelistEntry(const CefString& source_origin,
                                        const CefString& target_protocol,
                                        const CefString& target_domain,
                                        bool allow_target_subdomains);

///
// Remove all entries from the cross-origin access whitelist. Returns false if
// the whitelist cannot be accessed.
///
/*--cef()--*/
bool CefClearCrossOriginWhitelist();

typedef cef_thread_id_t CefThreadId;

///
// CEF maintains multiple internal threads that are used for handling different
// types of tasks. The UI thread creates the browser window and is used for all
// interaction with the WebKit rendering engine and V8 JavaScript engine (The
// UI thread will be the same as the main application thread if CefInitialize()
// is called with a CefSettings.multi_threaded_message_loop value of false.) The
// IO thread is used for handling schema and network requests. The FILE thread
// is used for the application cache and other miscellaneous activities. This
// function will return true if called on the specified thread.
///
/*--cef()--*/
bool CefCurrentlyOn(CefThreadId threadId);

///
// Post a task for execution on the specified thread. This function may be
// called on any thread.
///
/*--cef()--*/
bool CefPostTask(CefThreadId threadId, CefRefPtr<CefTask> task);

///
// Post a task for delayed execution on the specified thread. This function may
// be called on any thread.
///
/*--cef()--*/
bool CefPostDelayedTask(CefThreadId threadId, CefRefPtr<CefTask> task,
                        long delay_ms);

///
// Parse the specified |url| into its component parts.
// Returns false if the URL is empty or invalid.
///
/*--cef()--*/
bool CefParseURL(const CefString& url,
                 CefURLParts& parts);

///
// Creates a URL from the specified |parts|, which must contain a non-empty
// spec or a non-empty host and path (at a minimum), but not both.
// Returns false if |parts| isn't initialized as described.
///
/*--cef()--*/
bool CefCreateURL(const CefURLParts& parts,
                  CefString& url);

///
// Visit all cookies. The returned cookies are ordered by longest path, then by
// earliest creation date. Returns false if cookies cannot be accessed.
///
/*--cef()--*/
bool CefVisitAllCookies(CefRefPtr<CefCookieVisitor> visitor);

///
// Visit a subset of cookies. The results are filtered by the given url scheme,
// host, domain and path. If |includeHttpOnly| is true HTTP-only cookies will
// also be included in the results. The returned cookies are ordered by longest
// path, then by earliest creation date. Returns false if cookies cannot be
// accessed.
///
/*--cef()--*/
bool CefVisitUrlCookies(const CefString& url, bool includeHttpOnly,
                        CefRefPtr<CefCookieVisitor> visitor);

///
// Sets a cookie given a valid URL and explicit user-provided cookie attributes.
// This function expects each attribute to be well-formed. It will check for
// disallowed characters (e.g. the ';' character is disallowed within the cookie
// value attribute) and will return false without setting the cookie if such
// characters are found. This method must be called on the IO thread.
///
/*--cef()--*/
bool CefSetCookie(const CefString& url, const CefCookie& cookie);

///
// Delete all cookies that match the specified parameters. If both |url| and
// |cookie_name| are specified all host and domain cookies matching both values
// will be deleted. If only |url| is specified all host cookies (but not domain
// cookies) irrespective of path will be deleted. If |url| is empty all cookies
// for all hosts and domains will be deleted. Returns false if a non-empty
// invalid URL is specified or if cookies cannot be accessed. This method must
// be called on the IO thread.
///
/*--cef(optional_param=url,optional_param=cookie_name)--*/
bool CefDeleteCookies(const CefString& url, const CefString& cookie_name);

///
// Sets the directory path that will be used for storing cookie data. If |path|
// is empty data will be stored in memory only. By default the cookie path is
// the same as the cache path. Returns false if cookies cannot be accessed.
///
/*--cef(optional_param=path)--*/
bool CefSetCookiePath(const CefString& path);


typedef cef_storage_type_t CefStorageType;

///
// Visit storage of the specified type. If |origin| is non-empty only data
// matching that origin will be visited. If |key| is non-empty only data
// matching that key will be visited. Otherwise, all data for the storage
// type will be visited. Origin should be of the form scheme://domain. If no
// origin is specified only data currently in memory will be returned. Returns
// false if the storage cannot be accessed.
///
/*--cef(optional_param=origin,optional_param=key)--*/
bool CefVisitStorage(CefStorageType type, const CefString& origin,
                     const CefString& key,
                     CefRefPtr<CefStorageVisitor> visitor);

///
// Sets storage of the specified type, origin, key and value. Returns false if
// storage cannot be accessed. This method must be called on the UI thread.
///
/*--cef()--*/
bool CefSetStorage(CefStorageType type, const CefString& origin,
                   const CefString& key, const CefString& value);

///
// Deletes all storage of the specified type. If |origin| is non-empty only data
// matching that origin will be cleared. If |key| is non-empty only data
// matching that key will be cleared. Otherwise, all data for the storage type
// will be cleared. Returns false if storage cannot be accessed. This method
// must be called on the UI thread.
///
/*--cef(optional_param=origin,optional_param=key)--*/
bool CefDeleteStorage(CefStorageType type, const CefString& origin,
                      const CefString& key);

///
// Sets the directory path that will be used for storing data of the specified
// type. Currently only the ST_LOCALSTORAGE type is supported by this method.
// If |path| is empty data will be stored in memory only. By default the storage
// path is the same as the cache path. Returns false if the storage cannot be
// accessed.
///
/*--cef(optional_param=path)--*/
bool CefSetStoragePath(CefStorageType type, const CefString& path);


///
// Interface defining the reference count implementation methods. All framework
// classes must extend the CefBase class.
///
class CefBase
{
public:
  ///
  // The AddRef method increments the reference count for the object. It should
  // be called for every new copy of a pointer to a given object. The resulting
  // reference count value is returned and should be used for diagnostic/testing
  // purposes only.
  ///
  virtual int AddRef() =0;

  ///
  // The Release method decrements the reference count for the object. If the
  // reference count on the object falls to 0, then the object should free
  // itself from memory.  The resulting reference count value is returned and
  // should be used for diagnostic/testing purposes only.
  ///
  virtual int Release() =0;

  ///
  // Return the current number of references.
  ///
  virtual int GetRefCt() =0;

protected:
  virtual ~CefBase() {}
};


///
// Class that implements atomic reference counting.
///
class CefRefCount
{
public:
  CefRefCount() : refct_(0) {}
  
  ///
  // Atomic reference increment.
  ///
  int AddRef() {
    return CefAtomicIncrement(&refct_);
  }

  ///
  // Atomic reference decrement. Delete the object when no references remain.
  ///
  int Release() {
    return CefAtomicDecrement(&refct_);
  }

  ///
  // Return the current number of references.
  ///
  int GetRefCt() { return refct_; }

private:
  long refct_;
};

///
// Macro that provides a reference counting implementation for classes extending
// CefBase.
///
#define IMPLEMENT_REFCOUNTING(ClassName)            \
  public:                                           \
    int AddRef() { return refct_.AddRef(); }        \
    int Release() {                                 \
      int retval = refct_.Release();                \
      if(retval == 0)                               \
        delete this;                                \
      return retval;                                \
    }                                               \
    int GetRefCt() { return refct_.GetRefCt(); }    \
  private:                                          \
    CefRefCount refct_;

///
// Macro that provides a locking implementation. Use the Lock() and Unlock()
// methods to protect a section of code from simultaneous access by multiple
// threads. The AutoLock class is a helper that will hold the lock while in
// scope.
///
#define IMPLEMENT_LOCKING(ClassName)                              \
  public:                                                         \
    class AutoLock {                                              \
    public:                                                       \
      AutoLock(ClassName* base) : base_(base) { base_->Lock(); }  \
      ~AutoLock() { base_->Unlock(); }                            \
    private:                                                      \
      ClassName* base_;                                           \
    };                                                            \
    void Lock() { critsec_.Lock(); }                              \
    void Unlock() { critsec_.Unlock(); }                          \
  private:                                                        \
    CefCriticalSection critsec_;


///
// Implement this interface for task execution. The methods of this class may
// be called on any thread.
///
/*--cef(source=client)--*/
class CefTask : public virtual CefBase
{
public:
  ///
  // Method that will be executed. |threadId| is the thread executing the call.
  ///
  /*--cef()--*/
  virtual void Execute(CefThreadId threadId) =0;
};


///
// Interface to implement for visiting cookie values. The methods of this class
// will always be called on the IO thread.
///
/*--cef(source=client)--*/
class CefCookieVisitor : public virtual CefBase
{
public:
  ///
  // Method that will be called once for each cookie. |count| is the 0-based
  // index for the current cookie. |total| is the total number of cookies.
  // Set |deleteCookie| to true to delete the cookie currently being visited.
  // Return false to stop visiting cookies. This method may never be called if
  // no cookies are found.
  ///
  /*--cef()--*/
  virtual bool Visit(const CefCookie& cookie, int count, int total,
                     bool& deleteCookie) =0;
};


///
// Interface to implement for visiting storage. The methods of this class will
// always be called on the UI thread.
///
/*--cef(source=client)--*/
class CefStorageVisitor : public virtual CefBase
{
public:
  ///
  // Method that will be called once for each key/value data pair in storage.
  // |count| is the 0-based index for the current pair. |total| is the total
  // number of pairs. Set |deleteData| to true to delete the pair currently
  // being visited. Return false to stop visiting pairs. This method may never
  // be called if no data is found.
  ///
  /*--cef()--*/
  virtual bool Visit(CefStorageType type, const CefString& origin,
                     const CefString& key, const CefString& value, int count,
                     int total, bool& deleteData) =0;
};


///
// Class used to represent a browser window. The methods of this class may be
// called on any thread unless otherwise indicated in the comments.
///
/*--cef(source=library)--*/
class CefBrowser : public virtual CefBase
{
public:
  typedef cef_key_type_t KeyType;
  typedef cef_mouse_button_type_t MouseButtonType;
  typedef cef_paint_element_type_t PaintElementType;

  ///
  // Create a new browser window using the window parameters specified by
  // |windowInfo|. All values will be copied internally and the actual window
  // will be created on the UI thread. This method call will not block.
  ///
  /*--cef(optional_param=url)--*/
  static bool CreateBrowser(CefWindowInfo& windowInfo,
                            CefRefPtr<CefClient> client,
                            const CefString& url,
                            const CefBrowserSettings& settings);

  ///
  // Create a new browser window using the window parameters specified by
  // |windowInfo|. This method should only be called on the UI thread.
  ///
  /*--cef(optional_param=url)--*/
  static CefRefPtr<CefBrowser> CreateBrowserSync(CefWindowInfo& windowInfo,
                                            CefRefPtr<CefClient> client,
                                            const CefString& url,
                                            const CefBrowserSettings& settings);

  ///
  // Call this method before destroying a contained browser window. This method
  // performs any internal cleanup that may be needed before the browser window
  // is destroyed.
  ///
  /*--cef()--*/
  virtual void ParentWindowWillClose() =0;

  ///
  // Closes this browser window.
  ///
  /*--cef()--*/
  virtual void CloseBrowser() =0;

  ///
  // Returns true if the browser can navigate backwards.
  ///
  /*--cef()--*/
  virtual bool CanGoBack() =0;
  ///
  // Navigate backwards.
  ///
  /*--cef()--*/
  virtual void GoBack() =0;
  ///
  // Returns true if the browser can navigate forwards.
  ///
  /*--cef()--*/
  virtual bool CanGoForward() =0;
  ///
  // Navigate forwards.
  ///
  /*--cef()--*/
  virtual void GoForward() =0;
  ///
  // Reload the current page.
  ///
  /*--cef()--*/
  virtual void Reload() =0;
  ///
  // Reload the current page ignoring any cached data.
  ///
  /*--cef()--*/
  virtual void ReloadIgnoreCache() =0;
  ///
  // Stop loading the page.
  ///
  /*--cef()--*/
  virtual void StopLoad() =0;

  ///
  // Set focus for the browser window. If |enable| is true focus will be set to
  // the window. Otherwise, focus will be removed.
  ///
  /*--cef()--*/
  virtual void SetFocus(bool enable) =0;

  ///
  // Retrieve the window handle for this browser.
  ///
  /*--cef()--*/
  virtual CefWindowHandle GetWindowHandle() =0;

  ///
  // Retrieve the window handle of the browser that opened this browser. Will
  // return NULL for non-popup windows. This method can be used in combination
  // with custom handling of modal windows.
  ///
  /*--cef()--*/
  virtual CefWindowHandle GetOpenerWindowHandle() =0;
  
  ///
  // Returns true if the window is a popup window.
  ///
  /*--cef()--*/
  virtual bool IsPopup() =0;

  // Returns true if a document has been loaded in the browser.
  /*--cef()--*/
  virtual bool HasDocument() =0;

  ///
  // Returns the client for this browser.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefClient> GetClient() =0;

  ///
  // Returns the main (top-level) frame for the browser window.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefFrame> GetMainFrame() =0;

  ///
  // Returns the focused frame for the browser window. This method should only
  // be called on the UI thread.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefFrame> GetFocusedFrame() =0;

  ///
  // Returns the frame with the specified name, or NULL if not found. This
  // method should only be called on the UI thread.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefFrame> GetFrame(const CefString& name) =0;

  ///
  // Returns the names of all existing frames. This method should only be called
  // on the UI thread.
  ///
  /*--cef()--*/
  virtual void GetFrameNames(std::vector<CefString>& names) =0;

  ///
  // Search for |searchText|. |identifier| can be used to have multiple searches
  // running simultaniously. |forward| indicates whether to search forward or
  // backward within the page. |matchCase| indicates whether the search should
  // be case-sensitive. |findNext| indicates whether this is the first request
  // or a follow-up.
  ///
  /*--cef()--*/
  virtual void Find(int identifier, const CefString& searchText,
                    bool forward, bool matchCase, bool findNext) =0;

  ///
  // Cancel all searches that are currently going on.
  ///
  /*--cef()--*/
  virtual void StopFinding(bool clearSelection) =0;

  ///
  // Get the zoom level.
  ///
  /*--cef()--*/
  virtual double GetZoomLevel() =0;

  ///
  // Change the zoom level to the specified value.
  ///
  /*--cef()--*/
  virtual void SetZoomLevel(double zoomLevel) =0;

  ///
  // Clear the back/forward browsing history.
  ///
  /*--cef()--*/
  virtual void ClearHistory() =0;

  ///
  // Open developer tools in its own window.
  ///
  /*--cef()--*/
  virtual void ShowDevTools() =0;

  ///
  // Explicitly close the developer tools window if one exists for this browser
  // instance.
  ///
  /*--cef()--*/
  virtual void CloseDevTools() =0;

  ///
  // Returns true if window rendering is disabled.
  ///
  /*--cef()--*/
  virtual bool IsWindowRenderingDisabled() =0;

  ///
  // Get the size of the specified element. This method should only be called on
  // the UI thread.
  ///
  /*--cef()--*/
  virtual bool GetSize(PaintElementType type, int& width, int& height) =0;

  ///
  // Set the size of the specified element. This method is only used when window
  // rendering is disabled.
  ///
  /*--cef()--*/
  virtual void SetSize(PaintElementType type, int width, int height) =0;

  ///
  // Returns true if a popup is currently visible. This method should only be
  // called on the UI thread.
  ///
  /*--cef()--*/
  virtual bool IsPopupVisible() =0;

  ///
  // Hide the currently visible popup, if any.
  ///
  /*--cef()--*/
  virtual void HidePopup() =0;

  ///
  // Invalidate the |dirtyRect| region of the view. This method is only used
  // when window rendering is disabled and will result in a call to
  // HandlePaint(). 
  ///
  /*--cef()--*/
  virtual void Invalidate(const CefRect& dirtyRect) =0;

  ///
  // Get the raw image data contained in the specified element without
  // performing validation. The specified |width| and |height| dimensions must
  // match the current element size. On Windows |buffer| must be width*height*4
  // bytes in size and represents a BGRA image with an upper-left origin. This
  // method should only be called on the UI thread.
  ///
  /*--cef()--*/
  virtual bool GetImage(PaintElementType type, int width, int height,
                        void* buffer) =0;

  ///
  // Send a key event to the browser.
  ///
  /*--cef()--*/
  virtual void SendKeyEvent(KeyType type, int key, int modifiers, bool sysChar,
                            bool imeChar) =0;  

  ///
  // Send a mouse click event to the browser. The |x| and |y| coordinates are
  // relative to the upper-left corner of the view.
  ///
  /*--cef()--*/
  virtual void SendMouseClickEvent(int x, int y, MouseButtonType type,
                                   bool mouseUp, int clickCount) =0;

  ///
  // Send a mouse move event to the browser. The |x| and |y| coordinates are
  // relative to the upper-left corner of the view.
  ///
  /*--cef()--*/
  virtual void SendMouseMoveEvent(int x, int y, bool mouseLeave) =0;

  ///
  // Send a mouse wheel event to the browser. The |x| and |y| coordinates are
  // relative to the upper-left corner of the view.
  ///
  /*--cef()--*/
  virtual void SendMouseWheelEvent(int x, int y, int delta) =0;

  ///
  // Send a focus event to the browser.
  ///
  /*--cef()--*/
  virtual void SendFocusEvent(bool setFocus) =0;

  ///
  // Send a capture lost event to the browser.
  ///
  /*--cef()--*/
  virtual void SendCaptureLostEvent() =0;
};


///
// Class used to represent a frame in the browser window. The methods of this
// class may be called on any thread unless otherwise indicated in the comments.
///
/*--cef(source=library)--*/
class CefFrame : public virtual CefBase
{
public:
  ///
  // Execute undo in this frame.
  ///
  /*--cef()--*/
  virtual void Undo() =0;
  ///
  // Execute redo in this frame.
  ///
  /*--cef()--*/
  virtual void Redo() =0;
  ///
  // Execute cut in this frame.
  ///
  /*--cef()--*/
  virtual void Cut() =0;
  ///
  // Execute copy in this frame.
  ///
  /*--cef()--*/
  virtual void Copy() =0;
  ///
  // Execute paste in this frame.
  ///
  /*--cef()--*/
  virtual void Paste() =0;
  ///
  // Execute delete in this frame.
  ///
  /*--cef(capi_name=del)--*/
  virtual void Delete() =0;
  ///
  // Execute select all in this frame.
  ///
  /*--cef()--*/
  virtual void SelectAll() =0;

  ///
  // Execute printing in the this frame.  The user will be prompted with the
  // print dialog appropriate to the operating system.
  ///
  /*--cef()--*/
  virtual void Print() =0;

  ///
  // Save this frame's HTML source to a temporary file and open it in the
  // default text viewing application.
  ///
  /*--cef()--*/
  virtual void ViewSource() =0;

  ///
  // Returns this frame's HTML source as a string. This method should only be
  // called on the UI thread.
  ///
  /*--cef()--*/
  virtual CefString GetSource() =0;

  ///
  // Returns this frame's display text as a string. This method should only be
  // called on the UI thread.
  ///
  /*--cef()--*/
  virtual CefString GetText() =0;

  ///
  // Load the request represented by the |request| object.
  ///
  /*--cef()--*/
  virtual void LoadRequest(CefRefPtr<CefRequest> request) =0;

  ///
  // Load the specified |url|.
  ///
  /*--cef()--*/
  virtual void LoadURL(const CefString& url) =0;

  ///
  // Load the contents of |string| with the optional dummy target |url|.
  ///
  /*--cef()--*/
  virtual void LoadString(const CefString& string,
                          const CefString& url) =0;

  ///
  // Load the contents of |stream| with the optional dummy target |url|.
  ///
  /*--cef()--*/
  virtual void LoadStream(CefRefPtr<CefStreamReader> stream,
                          const CefString& url) =0;

  ///
  // Execute a string of JavaScript code in this frame. The |script_url|
  // parameter is the URL where the script in question can be found, if any.
  // The renderer may request this URL to show the developer the source of the
  // error.  The |start_line| parameter is the base line number to use for error
  // reporting.
  ///
  /*--cef(optional_param=scriptUrl)--*/
  virtual void ExecuteJavaScript(const CefString& jsCode, 
                                 const CefString& scriptUrl,
                                 int startLine) =0;

  ///
  // Returns true if this is the main (top-level) frame.
  ///
  /*--cef()--*/
  virtual bool IsMain() =0;

  ///
  // Returns true if this is the focused frame. This method should only be
  // called on the UI thread.
  ///
  /*--cef()--*/
  virtual bool IsFocused() =0;

  ///
  // Returns the name for this frame. If the frame has an assigned name (for
  // example, set via the iframe "name" attribute) then that value will be
  // returned. Otherwise a unique name will be constructed based on the frame
  // parent hierarchy. The main (top-level) frame will always have an empty name
  // value.
  ///
  /*--cef()--*/
  virtual CefString GetName() =0;

  ///
  // Returns the globally unique identifier for this frame. This method should
  // only be called on the UI thread.
  ///
  /*--cef()--*/
  virtual long long GetIdentifier() =0;

  ///
  // Returns the parent of this frame or NULL if this is the main (top-level)
  // frame. This method should only be called on the UI thread.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefFrame> GetParent() =0;

  ///
  // Returns the URL currently loaded in this frame. This method should only be
  // called on the UI thread.
  ///
  /*--cef()--*/
  virtual CefString GetURL() =0;

  ///
  // Returns the browser that this frame belongs to.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefBrowser> GetBrowser() =0;

  ///
  // Visit the DOM document.
  ///
  /*--cef()--*/
  virtual void VisitDOM(CefRefPtr<CefDOMVisitor> visitor) =0;

  ///
  // Get the V8 context associated with the frame. This method should only be
  // called on the UI thread.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefV8Context> GetV8Context() =0;
};


///
// Implement this interface to handle proxy resolution events.
///
/*--cef(source=client)--*/
class CefProxyHandler : public virtual CefBase
{
public:
  ///
  // Called to retrieve proxy information for the specified |url|.
  ///
  /*--cef()--*/
  virtual void GetProxyForUrl(const CefString& url,
                              CefProxyInfo& proxy_info) {}
};


///
// Implement this interface to provide handler implementations.
///
/*--cef(source=client,no_debugct_check)--*/
class CefApp : public virtual CefBase
{
public:
  ///
  // Return the handler for proxy events. If not handler is returned the default
  // system handler will be used.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefProxyHandler> GetProxyHandler() { return NULL; }
};


///
// Implement this interface to handle events related to browser life span. The
// methods of this class will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefLifeSpanHandler : public virtual CefBase
{
public:
  ///
  // Called before a new popup window is created. The |parentBrowser| parameter
  // will point to the parent browser window. The |popupFeatures| parameter will
  // contain information about the style of popup window requested. Return false
  // to have the framework create the new popup window based on the parameters
  // in |windowInfo|. Return true to cancel creation of the popup window. By
  // default, a newly created popup window will have the same client and
  // settings as the parent window. To change the client for the new window
  // modify the object that |client| points to. To change the settings for the
  // new window modify the |settings| structure.
  ///
  /*--cef(optional_param=url)--*/
  virtual bool OnBeforePopup(CefRefPtr<CefBrowser> parentBrowser,
                             const CefPopupFeatures& popupFeatures,
                             CefWindowInfo& windowInfo,
                             const CefString& url,
                             CefRefPtr<CefClient>& client,
                             CefBrowserSettings& settings) { return false; }

  ///
  // Called after a new window is created.
  ///
  /*--cef()--*/
  virtual void OnAfterCreated(CefRefPtr<CefBrowser> browser) {}

  ///
  // Called when a modal window is about to display and the modal loop should
  // begin running. Return false to use the default modal loop implementation or
  // true to use a custom implementation.
  ///
  /*--cef()--*/
  virtual bool RunModal(CefRefPtr<CefBrowser> browser) { return false; }

  ///
  // Called when a window has recieved a request to close. Return false to
  // proceed with the window close or true to cancel the window close. If this
  // is a modal window and a custom modal loop implementation was provided in
  // RunModal() this callback should be used to restore the opener window to a
  // usable state.
  ///
  /*--cef()--*/
  virtual bool DoClose(CefRefPtr<CefBrowser> browser) { return false; }

  ///
  // Called just before a window is closed. If this is a modal window and a
  // custom modal loop implementation was provided in RunModal() this callback
  // should be used to exit the custom modal loop.
  ///
  /*--cef()--*/
  virtual void OnBeforeClose(CefRefPtr<CefBrowser> browser) {}
};


///
// Implement this interface to handle events related to browser load status. The
// methods of this class will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefLoadHandler : public virtual CefBase
{
public:
  typedef cef_handler_errorcode_t ErrorCode;

  ///
  // Called when the browser begins loading a frame. The |frame| value will
  // never be empty -- call the IsMain() method to check if this frame is the
  // main frame. Multiple frames may be loading at the same time. Sub-frames may
  // start or continue loading after the main frame load has ended. This method
  // may not be called for a particular frame if the load request for that frame
  // fails.
  ///
  /*--cef()--*/
  virtual void OnLoadStart(CefRefPtr<CefBrowser> browser,
                           CefRefPtr<CefFrame> frame) {}

  ///
  // Called when the browser is done loading a frame. The |frame| value will
  // never be empty -- call the IsMain() method to check if this frame is the
  // main frame. Multiple frames may be loading at the same time. Sub-frames may
  // start or continue loading after the main frame load has ended. This method
  // will always be called for all frames irrespective of whether the request
  // completes successfully.
  ///
  /*--cef()--*/
  virtual void OnLoadEnd(CefRefPtr<CefBrowser> browser,
                         CefRefPtr<CefFrame> frame,
                         int httpStatusCode) {}

  ///
  // Called when the browser fails to load a resource. |errorCode| is the error
  // code number and |failedUrl| is the URL that failed to load. To provide
  // custom error text assign the text to |errorText| and return true.
  // Otherwise, return false for the default error text. See
  // net\base\net_error_list.h for complete descriptions of the error codes.
  ///
  /*--cef()--*/
  virtual bool OnLoadError(CefRefPtr<CefBrowser> browser,
                           CefRefPtr<CefFrame> frame,
                           ErrorCode errorCode,
                           const CefString& failedUrl,
                           CefString& errorText) { return false; }
};


///
// Implement this interface to handle events related to browser requests. The
// methods of this class will be called on the thread indicated.
///
/*--cef(source=client)--*/
class CefRequestHandler : public virtual CefBase
{
public:
  typedef cef_handler_navtype_t NavType;

  ///
  // Called on the UI thread before browser navigation. Return true to cancel
  // the navigation or false to allow the navigation to proceed.
  ///
  /*--cef()--*/
  virtual bool OnBeforeBrowse(CefRefPtr<CefBrowser> browser,
                              CefRefPtr<CefFrame> frame,
                              CefRefPtr<CefRequest> request,
                              NavType navType,
                              bool isRedirect) { return false; }

  ///
  // Called on the IO thread before a resource is loaded.  To allow the resource
  // to load normally return false. To redirect the resource to a new url
  // populate the |redirectUrl| value and return false.  To specify data for the
  // resource return a CefStream object in |resourceStream|, use the |response|
  // object to set mime type, HTTP status code and optional header values, and
  // return false. To cancel loading of the resource return true. Any
  // modifications to |request| will be observed.  If the URL in |request| is
  // changed and |redirectUrl| is also set, the URL in |request| will be used.
  ///
  /*--cef()--*/
  virtual bool OnBeforeResourceLoad(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefRequest> request,
                                    CefString& redirectUrl,
                                    CefRefPtr<CefStreamReader>& resourceStream,
                                    CefRefPtr<CefResponse> response,
                                    int loadFlags) { return false; }

  ///
  // Called on the IO thread when a resource load is redirected. The |old_url|
  // parameter will contain the old URL. The |new_url| parameter will contain
  // the new URL and can be changed if desired.
  ///
  /*--cef()--*/
  virtual void OnResourceRedirect(CefRefPtr<CefBrowser> browser,
                                  const CefString& old_url,
                                  CefString& new_url) {}

  ///
  // Called on the UI thread after a response to the resource request is
  // received. Set |filter| if response content needs to be monitored and/or
  // modified as it arrives.
  ///
  /*--cef()--*/
  virtual void OnResourceResponse(CefRefPtr<CefBrowser> browser,
                                  const CefString& url,
                                  CefRefPtr<CefResponse> response,
                                  CefRefPtr<CefContentFilter>& filter) {}

  ///
  // Called on the IO thread to handle requests for URLs with an unknown
  // protocol component. Return true to indicate that the request should
  // succeed because it was handled externally. Set |allowOSExecution| to true
  // and return false to attempt execution via the registered OS protocol
  // handler, if any. If false is returned and either |allow_os_execution|
  // is false or OS protocol handler execution fails then the request will fail
  // with an error condition.
  // SECURITY WARNING: YOU SHOULD USE THIS METHOD TO ENFORCE RESTRICTIONS BASED
  // ON SCHEME, HOST OR OTHER URL ANALYSIS BEFORE ALLOWING OS EXECUTION.
  ///
  /*--cef()--*/
  virtual bool OnProtocolExecution(CefRefPtr<CefBrowser> browser,
                                   const CefString& url,
                                   bool& allowOSExecution) { return false; }

  ///
  // Called on the UI thread when a server indicates via the
  // 'Content-Disposition' header that a response represents a file to download.
  // |mimeType| is the mime type for the download, |fileName| is the suggested
  // target file name and |contentLength| is either the value of the
  // 'Content-Size' header or -1 if no size was provided. Set |handler| to the
  // CefDownloadHandler instance that will recieve the file contents. Return
  // true to download the file or false to cancel the file download.
  ///
  /*--cef()--*/
  virtual bool GetDownloadHandler(CefRefPtr<CefBrowser> browser,
                                  const CefString& mimeType,
                                  const CefString& fileName,
                                  int64 contentLength,
                                  CefRefPtr<CefDownloadHandler>& handler)
                                  { return false; }

  ///
  // Called on the IO thread when the browser needs credentials from the user.
  // |isProxy| indicates whether the host is a proxy server. |host| contains the
  // hostname and port number. Set |username| and |password| and return
  // true to handle the request. Return false to cancel the request.
  ///
  /*--cef(optional_param=realm)--*/
  virtual bool GetAuthCredentials(CefRefPtr<CefBrowser> browser,
                                  bool isProxy,
                                  const CefString& host,
                                  int port,
                                  const CefString& realm,
                                  const CefString& scheme,
                                  CefString& username,
                                  CefString& password) { return false; }
};


///
// Implement this interface to handle events related to browser display state.
// The methods of this class will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefDisplayHandler : public virtual CefBase
{
public:
  typedef cef_handler_statustype_t StatusType;

  ///
  // Called when the navigation state has changed.
  ///
  /*--cef()--*/
  virtual void OnNavStateChange(CefRefPtr<CefBrowser> browser,
                                bool canGoBack,
                                bool canGoForward) {}

  ///
  // Called when a frame's address has changed.
  ///
  /*--cef()--*/
  virtual void OnAddressChange(CefRefPtr<CefBrowser> browser,
                               CefRefPtr<CefFrame> frame,
                               const CefString& url) {}

  ///
  // Called when the size of the content area has changed.
  ///
  /*--cef()--*/
  virtual void OnContentsSizeChange(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefFrame> frame,
                                    int width,
                                    int height) {}

  ///
  // Called when the page title changes.
  ///
  /*--cef(optional_param=title)--*/
  virtual void OnTitleChange(CefRefPtr<CefBrowser> browser,
                             const CefString& title) {}

  ///
  // Called when the browser is about to display a tooltip. |text| contains the
  // text that will be displayed in the tooltip. To handle the display of the
  // tooltip yourself return true. Otherwise, you can optionally modify |text|
  // and then return false to allow the browser to display the tooltip.
  ///
  /*--cef(optional_param=text)--*/
  virtual bool OnTooltip(CefRefPtr<CefBrowser> browser,
                         CefString& text) { return false; }

  ///
  // Called when the browser receives a status message. |text| contains the text
  // that will be displayed in the status message and |type| indicates the
  // status message type.
  ///
  /*--cef(optional_param=value)--*/
  virtual void OnStatusMessage(CefRefPtr<CefBrowser> browser,
                               const CefString& value,
                               StatusType type) {}

  ///
  // Called to display a console message. Return true to stop the message from
  // being output to the console.
  ///
  /*--cef(optional_param=message,optional_param=source)--*/
  virtual bool OnConsoleMessage(CefRefPtr<CefBrowser> browser,
                                const CefString& message,
                                const CefString& source,
                                int line) { return false; }
};


///
// Implement this interface to handle events related to focus. The methods of
// this class will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefFocusHandler : public virtual CefBase
{
public:
  typedef cef_handler_focus_source_t FocusSource;

  ///
  // Called when the browser component is about to loose focus. For instance, if
  // focus was on the last HTML element and the user pressed the TAB key. |next|
  // will be true if the browser is giving focus to the next component and false
  // if the browser is giving focus to the previous component.
  ///
  /*--cef()--*/
  virtual void OnTakeFocus(CefRefPtr<CefBrowser> browser,
                           bool next) {}

  ///
  // Called when the browser component is requesting focus. |source| indicates
  // where the focus request is originating from. Return false to allow the
  // focus to be set or true to cancel setting the focus.
  ///
  /*--cef()--*/
  virtual bool OnSetFocus(CefRefPtr<CefBrowser> browser,
                          FocusSource source) { return false; }

  ///
  // Called when a new node in the the browser gets focus. The |node| value may
  // be empty if no specific node has gained focus. The node object passed to
  // this method represents a snapshot of the DOM at the time this method is
  // executed. DOM objects are only valid for the scope of this method. Do not
  // keep references to or attempt to access any DOM objects outside the scope
  // of this method.
  ///
  /*--cef(optional_param=frame,optional_param=node)--*/
  virtual void OnFocusedNodeChanged(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefFrame> frame,
                                    CefRefPtr<CefDOMNode> node) {}
};


///
// Implement this interface to handle events related to keyboard input. The
// methods of this class will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefKeyboardHandler : public virtual CefBase
{
public:
  typedef cef_handler_keyevent_type_t KeyEventType;

  ///
  // Called when the browser component receives a keyboard event. This method
  // is called both before the event is passed to the renderer and after
  // JavaScript in the page has had a chance to handle the event. |type| is the
  // type of keyboard event, |code| is the windows scan-code for the event,
  // |modifiers| is a set of bit- flags describing any pressed modifier keys and
  // |isSystemKey| is true if Windows considers this a 'system key' message (see
  // http://msdn.microsoft.com/en-us/library/ms646286(VS.85).aspx). If
  // |isAfterJavaScript| is true then JavaScript in the page has had a chance
  // to handle the event and has chosen not to. Only RAWKEYDOWN, KEYDOWN and
  // CHAR events will be sent with |isAfterJavaScript| set to true. Return
  // true if the keyboard event was handled or false to allow continued handling
  // of the event by the renderer.
  ///
  /*--cef()--*/
  virtual bool OnKeyEvent(CefRefPtr<CefBrowser> browser,
                          KeyEventType type,
                          int code,
                          int modifiers,
                          bool isSystemKey,
                          bool isAfterJavaScript) { return false; }
};


///
// Implement this interface to handle events related to browser context menus.
// The methods of this class will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefMenuHandler : public virtual CefBase
{
public:
  typedef cef_menu_id_t MenuId;

  ///
  // Called before a context menu is displayed. Return false to display the
  // default context menu or true to cancel the display.
  ///
  /*--cef()--*/
  virtual bool OnBeforeMenu(CefRefPtr<CefBrowser> browser,
                            const CefMenuInfo& menuInfo) { return false; }

  ///
  // Called to optionally override the default text for a context menu item.
  // |label| contains the default text and may be modified to substitute
  // alternate text.
  ///
  /*--cef()--*/
  virtual void GetMenuLabel(CefRefPtr<CefBrowser> browser,
                            MenuId menuId,
                            CefString& label) {}

  ///
  // Called when an option is selected from the default context menu. Return
  // false to execute the default action or true to cancel the action.
  ///
  /*--cef()--*/
  virtual bool OnMenuAction(CefRefPtr<CefBrowser> browser,
                            MenuId menuId) { return false; }
};


///
// Implement this interface to handle events related to printing. The methods of
// this class will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefPrintHandler : public virtual CefBase
{
public:
  ///
  // Called to allow customization of standard print options before the print
  // dialog is displayed. |printOptions| allows specification of paper size,
  // orientation and margins. Note that the specified margins may be adjusted if
  // they are outside the range supported by the printer. All units are in
  // inches. Return false to display the default print options or true to
  // display the modified |printOptions|.
  ///
  /*--cef()--*/
  virtual bool GetPrintOptions(CefRefPtr<CefBrowser> browser,
                               CefPrintOptions& printOptions) { return false; }

  ///
  // Called to format print headers and footers. |printInfo| contains platform-
  // specific information about the printer context. |url| is the URL if the
  // currently printing page, |title| is the title of the currently printing
  // page, |currentPage| is the current page number and |maxPages| is the total
  // number of pages. Six default header locations are provided by the
  // implementation: top left, top center, top right, bottom left, bottom center
  // and bottom right. To use one of these default locations just assign a
  // string to the appropriate variable. To draw the header and footer yourself
  // return true. Otherwise, populate the approprate variables and return false.
  ///
  /*--cef()--*/
  virtual bool GetPrintHeaderFooter(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefFrame> frame,
                                    const CefPrintInfo& printInfo,
                                    const CefString& url,
                                    const CefString& title,
                                    int currentPage,
                                    int maxPages,
                                    CefString& topLeft,
                                    CefString& topCenter,
                                    CefString& topRight,
                                    CefString& bottomLeft,
                                    CefString& bottomCenter,
                                    CefString& bottomRight) { return false; }
};


///
// Implement this interface to handle events related to find results. The
// methods of this class will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefFindHandler : public virtual CefBase
{
public:
  ///
  // Called to report find results returned by CefBrowser::Find(). |identifer|
  // is the identifier passed to CefBrowser::Find(), |count| is the number of
  // matches currently identified, |selectionRect| is the location of where the
  // match was found (in window coordinates), |activeMatchOrdinal| is the
  // current position in the search results, and |finalUpdate| is true if this
  // is the last find notification.
  ///
  /*--cef()--*/
  virtual void OnFindResult(CefRefPtr<CefBrowser> browser,
                            int identifier,
                            int count,
                            const CefRect& selectionRect,
                            int activeMatchOrdinal,
                            bool finalUpdate) {}
};


///
// Implement this interface to handle events related to JavaScript dialogs. The
// methods of this class will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefJSDialogHandler : public virtual CefBase
{
public:
  ///
  // Called  to run a JavaScript alert message. Return false to display the
  // default alert or true if you displayed a custom alert.
  ///
  /*--cef()--*/
  virtual bool OnJSAlert(CefRefPtr<CefBrowser> browser,
                         CefRefPtr<CefFrame> frame,
                         const CefString& message) { return false; }

  ///
  // Called to run a JavaScript confirm request. Return false to display the
  // default alert or true if you displayed a custom alert. If you handled the
  // alert set |retval| to true if the user accepted the confirmation.
  ///
  /*--cef()--*/
  virtual bool OnJSConfirm(CefRefPtr<CefBrowser> browser,
                           CefRefPtr<CefFrame> frame,
                           const CefString& message,
                           bool& retval) { return false; }

  ///
  // Called to run a JavaScript prompt request. Return false to display the
  // default prompt or true if you displayed a custom prompt. If you handled
  // the prompt set |retval| to true if the user accepted the prompt and request
  // and |result| to the resulting value.
  ///
  /*--cef()--*/
  virtual bool OnJSPrompt(CefRefPtr<CefBrowser> browser,
                          CefRefPtr<CefFrame> frame,
                          const CefString& message,
                          const CefString& defaultValue,
                          bool& retval,
                          CefString& result) { return false; }
};


///
// Implement this interface to handle V8 context events. The methods of this
// class will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefV8ContextHandler : public virtual CefBase
{
public:
  ///
  // Called immediately after the V8 context for a frame has been created. To
  // retrieve the JavaScript 'window' object use the CefV8Context::GetGlobal()
  // method.
  ///
  /*--cef()--*/
  virtual void OnContextCreated(CefRefPtr<CefBrowser> browser,
                                CefRefPtr<CefFrame> frame,
                                CefRefPtr<CefV8Context> context) {}

  ///
  // Called immediately before the V8 context for a frame is released. No
  // references to the context should be kept after this method is called.
  ///
  /*--cef()--*/
  virtual void OnContextReleased(CefRefPtr<CefBrowser> browser,
                                 CefRefPtr<CefFrame> frame,
                                 CefRefPtr<CefV8Context> context) {}
};


///
// Implement this interface to handle events when window rendering is disabled.
// The methods of this class will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefRenderHandler : public virtual CefBase
{
public:
  typedef cef_paint_element_type_t PaintElementType;
  typedef std::vector<CefRect> RectList;

  ///
  // Called to retrieve the view rectangle which is relative to screen
  // coordinates. Return true if the rectangle was provided.
  ///
  /*--cef()--*/
  virtual bool GetViewRect(CefRefPtr<CefBrowser> browser,
                           CefRect& rect) { return false; }

  ///
  // Called to retrieve the simulated screen rectangle. Return true if the
  // rectangle was provided.
  ///
  /*--cef()--*/
  virtual bool GetScreenRect(CefRefPtr<CefBrowser> browser,
                             CefRect& rect) { return false; }

  ///
  // Called to retrieve the translation from view coordinates to actual screen
  // coordinates. Return true if the screen coordinates were provided.
  ///
  /*--cef()--*/
  virtual bool GetScreenPoint(CefRefPtr<CefBrowser> browser,
                              int viewX,
                              int viewY,
                              int& screenX,
                              int& screenY) { return false; }

  ///
  // Called when the browser wants to show or hide the popup widget. The popup
  // should be shown if |show| is true and hidden if |show| is false.
  ///
  /*--cef()--*/
  virtual void OnPopupShow(CefRefPtr<CefBrowser> browser,
                           bool show) {}

  ///
  // Called when the browser wants to move or resize the popup widget. |rect|
  // contains the new location and size.
  ///
  /*--cef()--*/
  virtual void OnPopupSize(CefRefPtr<CefBrowser> browser,
                           const CefRect& rect) {}

  ///
  // Called when an element should be painted. |type| indicates whether the
  // element is the view or the popup widget. |buffer| contains the pixel data
  // for the whole image. |dirtyRects| contains the set of rectangles that need
  // to be repainted. On Windows |buffer| will be width*height*4 bytes in size
  // and represents a BGRA image with an upper-left origin.
  ///
  /*--cef()--*/
  virtual void OnPaint(CefRefPtr<CefBrowser> browser,
                       PaintElementType type,
                       const RectList& dirtyRects,
                       const void* buffer) {}

  ///
  // Called when the browser window's cursor has changed.
  ///
  /*--cef()--*/
  virtual void OnCursorChange(CefRefPtr<CefBrowser> browser,
                              CefCursorHandle cursor) {}
};


///
// Implement this interface to handle events related to dragging. The methods of
// this class will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefDragHandler : public virtual CefBase
{
public:
  typedef cef_drag_operations_mask_t DragOperationsMask;

  ///
  // Called when the browser window initiates a drag event. |dragData|
  // contains the drag event data and |mask| represents the type of drag
  // operation. Return false for default drag handling behavior or true to
  // cancel the drag event.
  ///
  /*--cef()--*/
  virtual bool OnDragStart(CefRefPtr<CefBrowser> browser,
                           CefRefPtr<CefDragData> dragData,
                           DragOperationsMask mask) { return false; }

  ///
  // Called when an external drag event enters the browser window. |dragData|
  // contains the drag event data and |mask| represents the type of drag
  // operation. Return false for default drag handling behavior or true to
  // cancel the drag event.
  ///
  /*--cef()--*/
  virtual bool OnDragEnter(CefRefPtr<CefBrowser> browser,
                           CefRefPtr<CefDragData> dragData,
                           DragOperationsMask mask) { return false; }
};


///
// Implement this interface to provide handler implementations.
///
/*--cef(source=client,no_debugct_check)--*/
class CefClient : public virtual CefBase
{
public:
  ///
  // Return the handler for browser life span events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() { return NULL; }

  ///
  // Return the handler for browser load status events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefLoadHandler> GetLoadHandler() { return NULL; }

  ///
  // Return the handler for browser request events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefRequestHandler> GetRequestHandler() { return NULL; }

  ///
  // Return the handler for browser display state events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDisplayHandler> GetDisplayHandler() { return NULL; }

  ///
  // Return the handler for focus events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefFocusHandler> GetFocusHandler() { return NULL; }

  ///
  // Return the handler for keyboard events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefKeyboardHandler> GetKeyboardHandler() { return NULL; }

  ///
  // Return the handler for context menu events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefMenuHandler> GetMenuHandler() { return NULL; }

  ///
  // Return the handler for printing events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefPrintHandler> GetPrintHandler() { return NULL; }

  ///
  // Return the handler for find result events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefFindHandler> GetFindHandler() { return NULL; }

  ///
  // Return the handler for JavaScript dialog events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefJSDialogHandler> GetJSDialogHandler() { return NULL; }

  ///
  // Return the handler for V8 context events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefV8ContextHandler> GetV8ContextHandler() { return NULL; }

  ///
  // Return the handler for off-screen rendering events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefRenderHandler> GetRenderHandler() { return NULL; }

  ///
  // Return the handler for drag events.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDragHandler> GetDragHandler() { return NULL; }
};


///
// Class used to represent a web request. The methods of this class may be
// called on any thread.
///
/*--cef(source=library)--*/
class CefRequest : public virtual CefBase
{
public:
  typedef std::multimap<CefString,CefString> HeaderMap;
  typedef cef_weburlrequest_flags_t RequestFlags;

  ///
  // Create a new CefRequest object.
  ///
  /*--cef()--*/
  static CefRefPtr<CefRequest> CreateRequest();

  ///
  // Get the fully qualified URL.
  ///
  /*--cef()--*/
  virtual CefString GetURL() =0;
  ///
  // Set the fully qualified URL.
  ///
  /*--cef()--*/
  virtual void SetURL(const CefString& url) =0;

  ///
  // Get the request method type. The value will default to POST if post data
  // is provided and GET otherwise.
  ///
  /*--cef()--*/
  virtual CefString GetMethod() =0;
  ///
  // Set the request method type.
  ///
  /*--cef()--*/
  virtual void SetMethod(const CefString& method) =0;

  ///
  // Get the post data.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefPostData> GetPostData() =0;
  ///
  // Set the post data.
  ///
  /*--cef()--*/
  virtual void SetPostData(CefRefPtr<CefPostData> postData) =0;

  ///
  // Get the header values.
  ///
  /*--cef()--*/
  virtual void GetHeaderMap(HeaderMap& headerMap) =0;
  ///
  // Set the header values.
  ///
  /*--cef()--*/
  virtual void SetHeaderMap(const HeaderMap& headerMap) =0;

  ///
  // Set all values at one time.
  ///
  /*--cef(optional_param=postData)--*/
  virtual void Set(const CefString& url,
                   const CefString& method,
                   CefRefPtr<CefPostData> postData,
                   const HeaderMap& headerMap) =0;

  ///
  // Get the flags used in combination with CefWebURLRequest.
  ///
  /*--cef(default_retval=WUR_FLAG_NONE)--*/
  virtual RequestFlags GetFlags() =0;
  ///
  // Set the flags used in combination with CefWebURLRequest.
  ///
  /*--cef()--*/
  virtual void SetFlags(RequestFlags flags) =0;

  ///
  // Set the URL to the first party for cookies used in combination with
  // CefWebURLRequest.
  ///
  /*--cef()--*/
  virtual CefString GetFirstPartyForCookies() =0;
  ///
  // Get the URL to the first party for cookies used in combination with
  // CefWebURLRequest.
  ///
  /*--cef()--*/
  virtual void SetFirstPartyForCookies(const CefString& url) =0;
};


///
// Class used to represent post data for a web request. The methods of this
// class may be called on any thread.
///
/*--cef(source=library)--*/
class CefPostData : public virtual CefBase
{
public:
  typedef std::vector<CefRefPtr<CefPostDataElement> > ElementVector;

  ///
  // Create a new CefPostData object.
  ///
  /*--cef()--*/
  static CefRefPtr<CefPostData> CreatePostData();

  ///
  // Returns the number of existing post data elements.
  ///
  /*--cef()--*/
  virtual size_t GetElementCount() =0;

  ///
  // Retrieve the post data elements.
  ///
  /*--cef(count_func=elements:GetElementCount)--*/
  virtual void GetElements(ElementVector& elements) =0;

  ///
  // Remove the specified post data element.  Returns true if the removal
  // succeeds.
  ///
  /*--cef()--*/
  virtual bool RemoveElement(CefRefPtr<CefPostDataElement> element) =0;

  ///
  // Add the specified post data element.  Returns true if the add succeeds.
  ///
  /*--cef()--*/
  virtual bool AddElement(CefRefPtr<CefPostDataElement> element) =0;

  ///
  // Remove all existing post data elements.
  ///
  /*--cef()--*/
  virtual void RemoveElements() =0;
};


///
// Class used to represent a single element in the request post data. The
// methods of this class may be called on any thread.
///
/*--cef(source=library)--*/
class CefPostDataElement : public virtual CefBase
{
public:
  ///
  // Post data elements may represent either bytes or files.
  ///
  typedef cef_postdataelement_type_t Type;

  ///
  // Create a new CefPostDataElement object.
  ///
  /*--cef()--*/
  static CefRefPtr<CefPostDataElement> CreatePostDataElement();

  ///
  // Remove all contents from the post data element.
  ///
  /*--cef()--*/
  virtual void SetToEmpty() =0;

  ///
  // The post data element will represent a file.
  ///
  /*--cef()--*/
  virtual void SetToFile(const CefString& fileName) =0;

  ///
  // The post data element will represent bytes.  The bytes passed
  // in will be copied.
  ///
  /*--cef()--*/
  virtual void SetToBytes(size_t size, const void* bytes) =0;

  ///
  // Return the type of this post data element.
  ///
  /*--cef(default_retval=PDE_TYPE_EMPTY)--*/
  virtual Type GetType() =0;

  ///
  // Return the file name.
  ///
  /*--cef()--*/
  virtual CefString GetFile() =0;

  ///
  // Return the number of bytes.
  ///
  /*--cef()--*/
  virtual size_t GetBytesCount() =0;

  ///
  // Read up to |size| bytes into |bytes| and return the number of bytes
  // actually read.
  ///
  /*--cef()--*/
  virtual size_t GetBytes(size_t size, void* bytes) =0;
};


///
// Class used to represent a web response. The methods of this class may be
// called on any thread.
///
/*--cef(source=library)--*/
class CefResponse : public virtual CefBase
{
public:
  typedef std::multimap<CefString,CefString> HeaderMap;

  ///
  // Get the response status code.
  ///
  /*--cef()--*/
  virtual int GetStatus() =0;
  ///
  // Set the response status code.
  ///
  /*--cef()--*/
  virtual void SetStatus(int status) = 0;

  ///
  // Get the response status text.
  ///
  /*--cef()--*/
  virtual CefString GetStatusText() =0;
  ///
  // Set the response status text.
  ///
  /*--cef()--*/
  virtual void SetStatusText(const CefString& statusText) = 0;

  ///
  // Get the response mime type.
  ///
  /*--cef()--*/
  virtual CefString GetMimeType() = 0;
  ///
  // Set the response mime type.
  ///
  /*--cef()--*/
  virtual void SetMimeType(const CefString& mimeType) = 0;

  ///
  // Get the value for the specified response header field.
  ///
  /*--cef()--*/
  virtual CefString GetHeader(const CefString& name) =0;

  ///
  // Get all response header fields.
  ///
  /*--cef()--*/
  virtual void GetHeaderMap(HeaderMap& headerMap) =0;
  ///
  // Set all response header fields.
  ///
  /*--cef()--*/
  virtual void SetHeaderMap(const HeaderMap& headerMap) =0;
};


///
// Interface the client can implement to provide a custom stream reader. The
// methods of this class may be called on any thread.
///
/*--cef(source=client)--*/
class CefReadHandler : public virtual CefBase
{
public:
  ///
  // Read raw binary data.
  ///
  /*--cef()--*/
  virtual size_t Read(void* ptr, size_t size, size_t n) =0;

  ///
  // Seek to the specified offset position. |whence| may be any one of
  // SEEK_CUR, SEEK_END or SEEK_SET.
  ///
  /*--cef()--*/
  virtual int Seek(long offset, int whence) =0;

  ///
  // Return the current offset position.
  ///
  /*--cef()--*/
  virtual long Tell() =0;

  ///
  // Return non-zero if at end of file.
  ///
  /*--cef()--*/
  virtual int Eof() =0;
};


///
// Class used to read data from a stream. The methods of this class may be
// called on any thread.
///
/*--cef(source=library)--*/
class CefStreamReader : public virtual CefBase
{
public:
  ///
  // Create a new CefStreamReader object from a file.
  ///
  /*--cef()--*/
  static CefRefPtr<CefStreamReader> CreateForFile(const CefString& fileName);
  ///
  // Create a new CefStreamReader object from data.
  ///
  /*--cef()--*/
  static CefRefPtr<CefStreamReader> CreateForData(void* data, size_t size);
  ///
  // Create a new CefStreamReader object from a custom handler.
  ///
  /*--cef()--*/
  static CefRefPtr<CefStreamReader> CreateForHandler(
      CefRefPtr<CefReadHandler> handler);

  ///
  // Read raw binary data.
  ///
  /*--cef()--*/
  virtual size_t Read(void* ptr, size_t size, size_t n) =0;

  ///
  // Seek to the specified offset position. |whence| may be any one of
  // SEEK_CUR, SEEK_END or SEEK_SET. Returns zero on success and non-zero on
  // failure.
  ///
  /*--cef()--*/
  virtual int Seek(long offset, int whence) =0;

  ///
  // Return the current offset position.
  ///
  /*--cef()--*/
  virtual long Tell() =0;

  ///
  // Return non-zero if at end of file.
  ///
  /*--cef()--*/
  virtual int Eof() =0;
};


///
// Interface the client can implement to provide a custom stream writer. The
// methods of this class may be called on any thread.
///
/*--cef(source=client)--*/
class CefWriteHandler : public virtual CefBase
{
public:
  ///
  // Write raw binary data.
  ///
  /*--cef()--*/
  virtual size_t Write(const void* ptr, size_t size, size_t n) =0;

  ///
  // Seek to the specified offset position. |whence| may be any one of
  // SEEK_CUR, SEEK_END or SEEK_SET.
  ///
  /*--cef()--*/
  virtual int Seek(long offset, int whence) =0;

  ///
  // Return the current offset position.
  ///
  /*--cef()--*/
  virtual long Tell() =0;

  ///
  // Flush the stream.
  ///
  /*--cef()--*/
  virtual int Flush() =0;
};


///
// Class used to write data to a stream. The methods of this class may be called
// on any thread.
///
/*--cef(source=library)--*/
class CefStreamWriter : public virtual CefBase
{
public:
  ///
  // Create a new CefStreamWriter object for a file.
  ///
  /*--cef()--*/
  static CefRefPtr<CefStreamWriter> CreateForFile(const CefString& fileName);
  ///
  // Create a new CefStreamWriter object for a custom handler.
  ///
  /*--cef()--*/
  static CefRefPtr<CefStreamWriter> CreateForHandler(
      CefRefPtr<CefWriteHandler> handler);

  ///
  // Write raw binary data.
  ///
  /*--cef()--*/
  virtual size_t Write(const void* ptr, size_t size, size_t n) =0;
	
  ///
  // Seek to the specified offset position. |whence| may be any one of
  // SEEK_CUR, SEEK_END or SEEK_SET.
  ///
  /*--cef()--*/
  virtual int Seek(long offset, int whence) =0;
	
  ///
  // Return the current offset position.
  ///
  /*--cef()--*/
  virtual long Tell() =0;

  ///
  // Flush the stream.
  ///
  /*--cef()--*/
  virtual int Flush() =0;
};


///
// Class that encapsulates a V8 context handle.
///
/*--cef(source=library)--*/
class CefV8Context : public virtual CefBase
{
public:
  ///
  // Returns the current (top) context object in the V8 context stack.
  ///
  /*--cef()--*/
  static CefRefPtr<CefV8Context> GetCurrentContext();

  ///
  // Returns the entered (bottom) context object in the V8 context stack.
  ///
  /*--cef()--*/
  static CefRefPtr<CefV8Context> GetEnteredContext();

  ///
  // Returns true if V8 is currently inside a context.
  ///
  /*--cef()--*/
  static bool InContext();

  ///
  // Returns the browser for this context.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefBrowser> GetBrowser() =0;

  ///
  // Returns the frame for this context.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefFrame> GetFrame() =0;

  ///
  // Returns the global object for this context.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefV8Value> GetGlobal() =0;

  ///
  // Enter this context. A context must be explicitly entered before creating a
  // V8 Object, Array or Function asynchronously. Exit() must be called the same
  // number of times as Enter() before releasing this context. V8 objects belong
  // to the context in which they are created. Returns true if the scope was
  // entered successfully.
  ///
  /*--cef()--*/
  virtual bool Enter() =0;

  ///
  // Exit this context. Call this method only after calling Enter(). Returns
  // true if the scope was exited successfully.
  ///
  /*--cef()--*/
  virtual bool Exit() =0;

  ///
  // Returns true if this object is pointing to the same handle as |that|
  // object.
  ///
  /*--cef()--*/
  virtual bool IsSame(CefRefPtr<CefV8Context> that) =0;
};


typedef std::vector<CefRefPtr<CefV8Value> > CefV8ValueList;

///
// Interface that should be implemented to handle V8 function calls. The methods
// of this class will always be called on the UI thread.
///
/*--cef(source=client)--*/
class CefV8Handler : public virtual CefBase
{
public:
  ///
  // Handle execution of the function identified by |name|. |object| is the
  // receiver ('this' object) of the function. |arguments| is the list of
  // arguments passed to the function. If execution succeeds set |retval| to the
  // function return value. If execution fails set |exception| to the exception
  // that will be thrown. Return true if execution was handled.
  ///
  /*--cef()--*/
  virtual bool Execute(const CefString& name,
                       CefRefPtr<CefV8Value> object,
                       const CefV8ValueList& arguments,
                       CefRefPtr<CefV8Value>& retval,
                       CefString& exception) =0;
};

///
// Interface that should be implemented to handle V8 accessor calls. Accessor
// identifiers are registered by calling CefV8Value::SetValue(). The methods
// of this class will always be called on the UI thread.
///
/*--cef(source=client)--*/
class CefV8Accessor : public virtual CefBase
{
public:
  ///
  // Handle retrieval the accessor value identified by |name|. |object| is the
  // receiver ('this' object) of the accessor. If retrieval succeeds set
  // |retval| to the return value. If retrieval fails set |exception| to the
  // exception that will be thrown. Return true if accessor retrieval was
  // handled.
  ///
  /*--cef()--*/
  virtual bool Get(const CefString& name,
                   const CefRefPtr<CefV8Value> object,
                   CefRefPtr<CefV8Value>& retval,
                   CefString& exception) =0;

  ///
  // Handle assignment of the accessor value identified by |name|. |object| is
  // the receiver ('this' object) of the accessor. |value| is the new value
  // being assigned to the accessor. If assignment fails set |exception| to the
  // exception that will be thrown. Return true if accessor assignment was
  // handled.
  ///
  /*--cef()--*/
  virtual bool Set(const CefString& name,
                   const CefRefPtr<CefV8Value> object,
                   const CefRefPtr<CefV8Value> value,
                   CefString& exception) =0;
};

///
// Class representing a V8 exception.
///
/*--cef(source=library)--*/
class CefV8Exception : public virtual CefBase
{
public:
  ///
  // Returns the exception message.
  ///
  /*--cef()--*/
  virtual CefString GetMessage() =0;

  ///
  // Returns the line of source code that the exception occurred within.
  ///
  /*--cef()--*/
  virtual CefString GetSourceLine() =0;

  ///
  // Returns the resource name for the script from where the function causing
  // the error originates.
  ///
  /*--cef()--*/
  virtual CefString GetScriptResourceName() =0;

  ///
  // Returns the 1-based number of the line where the error occurred or 0 if the
  // line number is unknown.
  ///
  /*--cef()--*/
  virtual int GetLineNumber() =0;

  ///
  // Returns the index within the script of the first character where the error
  // occurred.
  ///
  /*--cef()--*/
  virtual int GetStartPosition() =0;

  ///
  // Returns the index within the script of the last character where the error
  // occurred.
  ///
  /*--cef()--*/
  virtual int GetEndPosition() =0;

  ///
  // Returns the index within the line of the first character where the error
  // occurred.
  ///
  /*--cef()--*/
  virtual int GetStartColumn() =0;

  ///
  // Returns the index within the line of the last character where the error
  // occurred.
  ///
  /*--cef()--*/
  virtual int GetEndColumn() =0;
};

///
// Class representing a V8 value. The methods of this class should only be
// called on the UI thread.
///
/*--cef(source=library)--*/
class CefV8Value : public virtual CefBase
{
public:
  typedef cef_v8_accesscontrol_t AccessControl;
  typedef cef_v8_propertyattribute_t PropertyAttribute;

  ///
  // Create a new CefV8Value object of type undefined.
  ///
  /*--cef()--*/
  static CefRefPtr<CefV8Value> CreateUndefined();
  ///
  // Create a new CefV8Value object of type null.
  ///
  /*--cef()--*/
  static CefRefPtr<CefV8Value> CreateNull();
  ///
  // Create a new CefV8Value object of type bool.
  ///
  /*--cef()--*/
  static CefRefPtr<CefV8Value> CreateBool(bool value);
  ///
  // Create a new CefV8Value object of type int.
  ///
  /*--cef()--*/
  static CefRefPtr<CefV8Value> CreateInt(int value);
  ///
  // Create a new CefV8Value object of type double.
  ///
  /*--cef()--*/
  static CefRefPtr<CefV8Value> CreateDouble(double value);
  ///
  // Create a new CefV8Value object of type Date.
  ///
  /*--cef()--*/
  static CefRefPtr<CefV8Value> CreateDate(const CefTime& date);
  ///
  // Create a new CefV8Value object of type string.
  ///
  /*--cef(optional_param=value)--*/
  static CefRefPtr<CefV8Value> CreateString(const CefString& value);
  ///
  // Create a new CefV8Value object of type object. This method should only be
  // called from within the scope of a CefV8ContextHandler, CefV8Handler or
  // CefV8Accessor callback, or in combination with calling Enter() and Exit()
  // on a stored CefV8Context reference.
  ///
  /*--cef(optional_param=user_data)--*/
  static CefRefPtr<CefV8Value> CreateObject(CefRefPtr<CefBase> user_data);
  ///
  // Create a new CefV8Value object of type object with accessors. This method
  // should only be called from within the scope of a CefV8ContextHandler,
  // CefV8Handler or CefV8Accessor callback, or in combination with calling
  // Enter() and Exit() on a stored CefV8Context reference.
  ///
  /*--cef(capi_name=cef_v8value_create_object_with_accessor,
          optional_param=user_data,optional_param=accessor)--*/
  static CefRefPtr<CefV8Value> CreateObject(CefRefPtr<CefBase> user_data, 
                                            CefRefPtr<CefV8Accessor> accessor);
  ///
  // Create a new CefV8Value object of type array. This method should only be
  // called from within the scope of a CefV8ContextHandler, CefV8Handler or
  // CefV8Accessor callback, or in combination with calling Enter() and Exit()
  // on a stored CefV8Context reference.
  ///
  /*--cef()--*/
  static CefRefPtr<CefV8Value> CreateArray();
  ///
  // Create a new CefV8Value object of type function. This method should only be
  // called from within the scope of a CefV8ContextHandler, CefV8Handler or
  // CefV8Accessor callback, or in combination with calling Enter() and Exit()
  // on a stored CefV8Context reference.
  ///
  /*--cef()--*/
  static CefRefPtr<CefV8Value> CreateFunction(const CefString& name,
                                              CefRefPtr<CefV8Handler> handler);

  ///
  // True if the value type is undefined.
  ///
  /*--cef()--*/
  virtual bool IsUndefined() =0;
  ///
  // True if the value type is null.
  ///
  /*--cef()--*/
  virtual bool IsNull() =0;
  ///
  // True if the value type is bool.
  ///
  /*--cef()--*/
  virtual bool IsBool() =0;
  ///
  // True if the value type is int.
  ///
  /*--cef()--*/
  virtual bool IsInt() =0;
  ///
  // True if the value type is double.
  ///
  /*--cef()--*/
  virtual bool IsDouble() =0;
  ///
  // True if the value type is Date.
  ///
  /*--cef()--*/
  virtual bool IsDate() =0;
  ///
  // True if the value type is string.
  ///
  /*--cef()--*/
  virtual bool IsString() =0;
  ///
  // True if the value type is object.
  ///
  /*--cef()--*/
  virtual bool IsObject() =0;
  ///
  // True if the value type is array.
  ///
  /*--cef()--*/
  virtual bool IsArray() =0;
  ///
  // True if the value type is function.
  ///
  /*--cef()--*/
  virtual bool IsFunction() =0;

  ///
  // Returns true if this object is pointing to the same handle as |that|
  // object.
  ///
  /*--cef()--*/
  virtual bool IsSame(CefRefPtr<CefV8Value> that) =0;
  
  ///
  // Return a bool value.  The underlying data will be converted to if
  // necessary.
  ///
  /*--cef()--*/
  virtual bool GetBoolValue() =0;
  ///
  // Return an int value.  The underlying data will be converted to if
  // necessary.
  ///
  /*--cef()--*/
  virtual int GetIntValue() =0;
  ///
  // Return a double value.  The underlying data will be converted to if
  // necessary.
  ///
  /*--cef()--*/
  virtual double GetDoubleValue() =0;
  ///
  // Return a Date value.  The underlying data will be converted to if
  // necessary.
  ///
  /*--cef()--*/
  virtual CefTime GetDateValue() =0;
  ///
  // Return a string value.  The underlying data will be converted to if
  // necessary.
  ///
  /*--cef()--*/
  virtual CefString GetStringValue() =0;


  // OBJECT METHODS - These methods are only available on objects. Arrays and
  // functions are also objects. String- and integer-based keys can be used
  // interchangably with the framework converting between them as necessary.

  ///
  // Returns true if the object has a value with the specified identifier.
  ///
  /*--cef(capi_name=has_value_bykey)--*/
  virtual bool HasValue(const CefString& key) =0;
  ///
  // Returns true if the object has a value with the specified identifier.
  ///
  /*--cef(capi_name=has_value_byindex,index_param=index)--*/
  virtual bool HasValue(int index) =0;

  ///
  // Delete the value with the specified identifier.
  ///
  /*--cef(capi_name=delete_value_bykey)--*/
  virtual bool DeleteValue(const CefString& key) =0;
  ///
  // Delete the value with the specified identifier.
  ///
  /*--cef(capi_name=delete_value_byindex,index_param=index)--*/
  virtual bool DeleteValue(int index) =0;

  ///
  // Returns the value with the specified identifier.
  ///
  /*--cef(capi_name=get_value_bykey)--*/
  virtual CefRefPtr<CefV8Value> GetValue(const CefString& key) =0;
  ///
  // Returns the value with the specified identifier.
  ///
  /*--cef(capi_name=get_value_byindex,index_param=index)--*/
  virtual CefRefPtr<CefV8Value> GetValue(int index) =0;

  ///
  // Associate a value with the specified identifier.
  ///
  /*--cef(capi_name=set_value_bykey)--*/
  virtual bool SetValue(const CefString& key, CefRefPtr<CefV8Value> value,
                        PropertyAttribute attribute) =0;
  ///
  // Associate a value with the specified identifier.
  ///
  /*--cef(capi_name=set_value_byindex,index_param=index)--*/
  virtual bool SetValue(int index, CefRefPtr<CefV8Value> value) =0;

  ///
  // Register an identifier whose access will be forwarded to the CefV8Accessor
  // instance passed to CefV8Value::CreateObject().
  ///
  /*--cef(capi_name=set_value_byaccessor)--*/
  virtual bool SetValue(const CefString& key, AccessControl settings, 
                        PropertyAttribute attribute) =0;

  ///
  // Read the keys for the object's values into the specified vector. Integer-
  // based keys will also be returned as strings.
  ///
  /*--cef()--*/
  virtual bool GetKeys(std::vector<CefString>& keys) =0;

  ///
  // Returns the user data, if any, specified when the object was created.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefBase> GetUserData() =0;


  // ARRAY METHODS - These methods are only available on arrays.

  ///
  // Returns the number of elements in the array.
  ///
  /*--cef()--*/
  virtual int GetArrayLength() =0;


  // FUNCTION METHODS - These methods are only available on functions.

  ///
  // Returns the function name.
  ///
  /*--cef()--*/
  virtual CefString GetFunctionName() =0;

  ///
  // Returns the function handler or NULL if not a CEF-created function.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefV8Handler> GetFunctionHandler() =0;

  ///
  // Execute the function using the current V8 context. This method should only
  // be called from within the scope of a CefV8Handler or CefV8Accessor
  // callback, or in combination with calling Enter() and Exit() on a stored
  // CefV8Context reference. |object| is the receiver ('this' object) of the
  // function. |arguments| is the list of arguments that will be passed to the
  // function. If execution succeeds |retval| will be set to the function return
  // value. If execution fails |exception| will be set to the exception that was
  // thrown. If |rethrow_exception| is true any exception will also be re-
  // thrown. This method returns false if called incorrectly.
  ///
  /*--cef(optional_param=object)--*/
  virtual bool ExecuteFunction(CefRefPtr<CefV8Value> object,
                               const CefV8ValueList& arguments,
                               CefRefPtr<CefV8Value>& retval,
                               CefRefPtr<CefV8Exception>& exception,
                               bool rethrow_exception) =0;

  ///
  // Execute the function using the specified V8 context. |object| is the
  // receiver ('this' object) of the function. |arguments| is the list of
  // arguments that will be passed to the function. If execution succeeds
  // |retval| will be set to the function return value. If execution fails
  // |exception| will be set to the exception that was thrown. If
  // |rethrow_exception| is true any exception will also be re-thrown. This 
  // method returns false if called incorrectly.
  ///
  /*--cef(optional_param=object)--*/
  virtual bool ExecuteFunctionWithContext(CefRefPtr<CefV8Context> context,
                                          CefRefPtr<CefV8Value> object,
                                          const CefV8ValueList& arguments,
                                          CefRefPtr<CefV8Value>& retval,
                                          CefRefPtr<CefV8Exception>& exception,
                                          bool rethrow_exception) =0;
};


///
// Class that creates CefSchemeHandler instances. The methods of this class will
// always be called on the IO thread.
///
/*--cef(source=client)--*/
class CefSchemeHandlerFactory : public virtual CefBase
{
public:
  ///
  // Return a new scheme handler instance to handle the request. |browser| will
  // be the browser window that initiated the request. If the request was
  // initiated using the CefWebURLRequest API |browser| will be NULL.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefSchemeHandler> Create(CefRefPtr<CefBrowser> browser,
                                             const CefString& scheme_name,
                                             CefRefPtr<CefRequest> request) =0;
};

///
// Class used to facilitate asynchronous responses to custom scheme handler
// requests. The methods of this class may be called on any thread.
///
/*--cef(source=library)--*/
class CefSchemeHandlerCallback : public virtual CefBase
{
public:
  ///
  // Notify that header information is now available for retrieval.
  ///
  /*--cef()--*/
  virtual void HeadersAvailable() =0;

  ///
  // Notify that response data is now available for reading.
  ///
  /*--cef()--*/
  virtual void BytesAvailable() =0;

  ///
  // Cancel processing of the request.
  ///
  /*--cef()--*/
  virtual void Cancel() =0;
};

///
// Class used to implement a custom scheme handler interface. The methods of
// this class will always be called on the IO thread.
///
/*--cef(source=client)--*/
class CefSchemeHandler : public virtual CefBase
{
public:
  ///
  // Begin processing the request. To handle the request return true and call
  // HeadersAvailable() once the response header information is available
  // (HeadersAvailable() can also be called from inside this method if header
  // information is available immediately). To cancel the request return false. 
  ///
  /*--cef()--*/
  virtual bool ProcessRequest(CefRefPtr<CefRequest> request,
                              CefRefPtr<CefSchemeHandlerCallback> callback) =0;

  ///
  // Retrieve response header information. If the response length is not known
  // set |response_length| to -1 and ReadResponse() will be called until it
  // returns false. If the response length is known set |response_length|
  // to a positive value and ReadResponse() will be called until it returns
  // false or the specified number of bytes have been read. Use the |response|
  // object to set the mime type, http status code and other optional header
  // values. To redirect the request to a new URL set |redirectUrl| to the new
  // URL.
  ///
  /*--cef()--*/
  virtual void GetResponseHeaders(CefRefPtr<CefResponse> response,
                                  int64& response_length,
                                  CefString& redirectUrl) =0;

  ///
  // Read response data. If data is available immediately copy up to
  // |bytes_to_read| bytes into |data_out|, set |bytes_read| to the number of
  // bytes copied, and return true. To read the data at a later time set
  // |bytes_read| to 0, return true and call BytesAvailable() when the data is
  // available. To indicate response completion return false.
  ///
  /*--cef()--*/
  virtual bool ReadResponse(void* data_out,
                            int bytes_to_read,
                            int& bytes_read,
                            CefRefPtr<CefSchemeHandlerCallback> callback) =0;

  ///
  // Request processing has been canceled.
  ///
  /*--cef()--*/
  virtual void Cancel() =0;
};


///
// Class used to handle file downloads. The methods of this class will always be
// called on the UI thread.
///
/*--cef(source=client)--*/
class CefDownloadHandler : public virtual CefBase
{
public:
  ///
  // A portion of the file contents have been received. This method will be
  // called multiple times until the download is complete. Return |true| to
  // continue receiving data and |false| to cancel.
  ///
  /*--cef()--*/
  virtual bool ReceivedData(void* data, int data_size) =0;

  ///
  // The download is complete.
  ///
  /*--cef()--*/
  virtual void Complete() =0;
};


///
// Class used to make a Web URL request. Web URL requests are not associated
// with a browser instance so no CefClient callbacks will be executed. The
// methods of this class may be called on any thread.
///
/*--cef(source=library)--*/
class CefWebURLRequest : public virtual CefBase
{
public:
  typedef cef_weburlrequest_state_t RequestState;

  ///
  // Create a new CefWebUrlRequest object.
  ///
  /*--cef()--*/
  static CefRefPtr<CefWebURLRequest> CreateWebURLRequest(
      CefRefPtr<CefRequest> request, 
      CefRefPtr<CefWebURLRequestClient> client);

  ///
  // Cancels the request.
  ///
  /*--cef()--*/
  virtual void Cancel() =0;

  ///
  // Returns the current ready state of the request.
  ///
  /*--cef(default_retval=WUR_STATE_UNSENT)--*/
  virtual RequestState GetState() =0;
};

///
// Interface that should be implemented by the CefWebURLRequest client. The
// methods of this class will always be called on the UI thread.
///
/*--cef(source=client)--*/
class CefWebURLRequestClient : public virtual CefBase
{
public:
  typedef cef_weburlrequest_state_t RequestState;
  typedef cef_handler_errorcode_t ErrorCode;
  
  ///
  // Notifies the client that the request state has changed. State change
  // notifications will always be sent before the below notification methods
  // are called.
  ///
  /*--cef()--*/
  virtual void OnStateChange(CefRefPtr<CefWebURLRequest> requester, 
                             RequestState state) =0;

  ///
  // Notifies the client that the request has been redirected and  provides a
  // chance to change the request parameters.
  ///
  /*--cef()--*/
  virtual void OnRedirect(CefRefPtr<CefWebURLRequest> requester, 
                          CefRefPtr<CefRequest> request, 
                          CefRefPtr<CefResponse> response) =0;

  ///
  // Notifies the client of the response data.
  ///
  /*--cef()--*/
  virtual void OnHeadersReceived(CefRefPtr<CefWebURLRequest> requester,
                                 CefRefPtr<CefResponse> response) =0;

  ///
  // Notifies the client of the upload progress.
  ///
  /*--cef()--*/
  virtual void OnProgress(CefRefPtr<CefWebURLRequest> requester, 
                          uint64 bytesSent, uint64 totalBytesToBeSent) =0;

  ///
  // Notifies the client that content has been received.
  ///
  /*--cef()--*/
  virtual void OnData(CefRefPtr<CefWebURLRequest> requester, 
                      const void* data, int dataLength) =0;

  ///
  // Notifies the client that the request ended with an error.
  ///
  /*--cef()--*/
  virtual void OnError(CefRefPtr<CefWebURLRequest> requester, 
                       ErrorCode errorCode) =0;
};


///
// Class that supports the reading of XML data via the libxml streaming API.
// The methods of this class should only be called on the thread that creates
// the object.
///
/*--cef(source=library)--*/
class CefXmlReader : public virtual CefBase
{
public:
  typedef cef_xml_encoding_type_t EncodingType;
  typedef cef_xml_node_type_t NodeType;

  ///
  // Create a new CefXmlReader object. The returned object's methods can only
  // be called from the thread that created the object.
  ///
  /*--cef()--*/
  static CefRefPtr<CefXmlReader> Create(CefRefPtr<CefStreamReader> stream,
                                        EncodingType encodingType,
                                        const CefString& URI);

  ///
  // Moves the cursor to the next node in the document. This method must be
  // called at least once to set the current cursor position. Returns true if
  // the cursor position was set successfully.
  ///
  /*--cef()--*/
  virtual bool MoveToNextNode() =0;

  ///
  // Close the document. This should be called directly to ensure that cleanup
  // occurs on the correct thread.
  ///
  /*--cef()--*/
  virtual bool Close() =0;

  ///
  // Returns true if an error has been reported by the XML parser.
  ///
  /*--cef()--*/
  virtual bool HasError() =0;

  ///
  // Returns the error string.
  ///
  /*--cef()--*/
  virtual CefString GetError() =0;


  // The below methods retrieve data for the node at the current cursor
  // position.

  ///
  // Returns the node type.
  ///
  /*--cef(default_retval=XML_NODE_UNSUPPORTED)--*/
  virtual NodeType GetType() =0;

  ///
  // Returns the node depth. Depth starts at 0 for the root node.
  ///
  /*--cef()--*/
  virtual int GetDepth() =0;

  ///
  // Returns the local name. See
  // http://www.w3.org/TR/REC-xml-names/#NT-LocalPart for additional details.
  ///
  /*--cef()--*/
  virtual CefString GetLocalName() =0;

  ///
  // Returns the namespace prefix. See http://www.w3.org/TR/REC-xml-names/ for
  // additional details.
  ///
  /*--cef()--*/
  virtual CefString GetPrefix() =0;

  ///
  // Returns the qualified name, equal to (Prefix:)LocalName. See
  // http://www.w3.org/TR/REC-xml-names/#ns-qualnames for additional details.
  ///
  /*--cef()--*/
  virtual CefString GetQualifiedName() =0;

  ///
  // Returns the URI defining the namespace associated with the node. See
  // http://www.w3.org/TR/REC-xml-names/ for additional details.
  ///
  /*--cef()--*/
  virtual CefString GetNamespaceURI() =0;

  ///
  // Returns the base URI of the node. See http://www.w3.org/TR/xmlbase/ for
  // additional details.
  ///
  /*--cef()--*/
  virtual CefString GetBaseURI() =0;

  ///
  // Returns the xml:lang scope within which the node resides. See
  // http://www.w3.org/TR/REC-xml/#sec-lang-tag for additional details.
  ///
  /*--cef()--*/
  virtual CefString GetXmlLang() =0;

  ///
  // Returns true if the node represents an empty element. <a/> is considered
  // empty but <a></a> is not.
  ///
  /*--cef()--*/
  virtual bool IsEmptyElement() =0;

  ///
  // Returns true if the node has a text value.
  ///
  /*--cef()--*/
  virtual bool HasValue() =0;

  ///
  // Returns the text value.
  ///
  /*--cef()--*/
  virtual CefString GetValue() =0;

  ///
  // Returns true if the node has attributes.
  ///
  /*--cef()--*/
  virtual bool HasAttributes() =0;

  ///
  // Returns the number of attributes.
  ///
  /*--cef()--*/
  virtual size_t GetAttributeCount() =0;

  ///
  // Returns the value of the attribute at the specified 0-based index.
  ///
  /*--cef(capi_name=get_attribute_byindex,index_param=index)--*/
  virtual CefString GetAttribute(int index) =0;

  ///
  // Returns the value of the attribute with the specified qualified name.
  ///
  /*--cef(capi_name=get_attribute_byqname)--*/
  virtual CefString GetAttribute(const CefString& qualifiedName) =0;

  ///
  // Returns the value of the attribute with the specified local name and
  // namespace URI.
  ///
  /*--cef(capi_name=get_attribute_bylname)--*/
  virtual CefString GetAttribute(const CefString& localName,
                                 const CefString& namespaceURI) =0;

  ///
  // Returns an XML representation of the current node's children.
  ///
  /*--cef()--*/
  virtual CefString GetInnerXml() =0;

  ///
  // Returns an XML representation of the current node including its children.
  ///
  /*--cef()--*/
  virtual CefString GetOuterXml() =0;

  ///
  // Returns the line number for the current node.
  ///
  /*--cef()--*/
  virtual int GetLineNumber() =0;


  // Attribute nodes are not traversed by default. The below methods can be
  // used to move the cursor to an attribute node. MoveToCarryingElement() can
  // be called afterwards to return the cursor to the carrying element. The
  // depth of an attribute node will be 1 + the depth of the carrying element.

  ///
  // Moves the cursor to the attribute at the specified 0-based index. Returns
  // true if the cursor position was set successfully.
  ///
  /*--cef(capi_name=move_to_attribute_byindex,index_param=index)--*/
  virtual bool MoveToAttribute(int index) =0;

  ///
  // Moves the cursor to the attribute with the specified qualified name.
  // Returns true if the cursor position was set successfully.
  ///
  /*--cef(capi_name=move_to_attribute_byqname)--*/
  virtual bool MoveToAttribute(const CefString& qualifiedName) =0;

  ///
  // Moves the cursor to the attribute with the specified local name and
  // namespace URI. Returns true if the cursor position was set successfully.
  ///
  /*--cef(capi_name=move_to_attribute_bylname)--*/
  virtual bool MoveToAttribute(const CefString& localName,
                               const CefString& namespaceURI) =0;

  ///
  // Moves the cursor to the first attribute in the current element. Returns
  // true if the cursor position was set successfully.
  ///
  /*--cef()--*/
  virtual bool MoveToFirstAttribute() =0;

  ///
  // Moves the cursor to the next attribute in the current element. Returns
  // true if the cursor position was set successfully.
  ///
  /*--cef()--*/
  virtual bool MoveToNextAttribute() =0;

  ///
  // Moves the cursor back to the carrying element. Returns true if the cursor
  // position was set successfully.
  ///
  /*--cef()--*/
  virtual bool MoveToCarryingElement() =0;
};


///
// Class that supports the reading of zip archives via the zlib unzip API.
// The methods of this class should only be called on the thread that creates
// the object.
///
/*--cef(source=library)--*/
class CefZipReader : public virtual CefBase
{
public:
  ///
  // Create a new CefZipReader object. The returned object's methods can only
  // be called from the thread that created the object.
  ///
  /*--cef()--*/
  static CefRefPtr<CefZipReader> Create(CefRefPtr<CefStreamReader> stream);

  ///
  // Moves the cursor to the first file in the archive. Returns true if the
  // cursor position was set successfully.
  ///
  /*--cef()--*/
  virtual bool MoveToFirstFile() =0;

  ///
  // Moves the cursor to the next file in the archive. Returns true if the
  // cursor position was set successfully.
  ///
  /*--cef()--*/
  virtual bool MoveToNextFile() =0;

  ///
  // Moves the cursor to the specified file in the archive. If |caseSensitive|
  // is true then the search will be case sensitive. Returns true if the cursor
  // position was set successfully. 
  ///
  /*--cef()--*/
  virtual bool MoveToFile(const CefString& fileName, bool caseSensitive) =0;

  ///
  // Closes the archive. This should be called directly to ensure that cleanup
  // occurs on the correct thread.
  ///
  /*--cef()--*/
  virtual bool Close() =0;


  // The below methods act on the file at the current cursor position.

  ///
  // Returns the name of the file.
  ///
  /*--cef()--*/
  virtual CefString GetFileName() =0;

  ///
  // Returns the uncompressed size of the file.
  ///
  /*--cef()--*/
  virtual long GetFileSize() =0;

  ///
  // Returns the last modified timestamp for the file.
  ///
  /*--cef()--*/
  virtual time_t GetFileLastModified() =0;

  ///
  // Opens the file for reading of uncompressed data. A read password may
  // optionally be specified.
  ///
  /*--cef(optional_param=password)--*/
  virtual bool OpenFile(const CefString& password) =0;

  ///
  // Closes the file.
  ///
  /*--cef()--*/
  virtual bool CloseFile() =0;

  ///
  // Read uncompressed file contents into the specified buffer. Returns < 0 if
  // an error occurred, 0 if at the end of file, or the number of bytes read.
  ///
  /*--cef()--*/
  virtual int ReadFile(void* buffer, size_t bufferSize) =0;

  ///
  // Returns the current offset in the uncompressed file contents.
  ///
  /*--cef()--*/
  virtual long Tell() =0;

  ///
  // Returns true if at end of the file contents.
  ///
  /*--cef()--*/
  virtual bool Eof() =0;
};


///
// Interface to implement for visiting the DOM. The methods of this class will
// be called on the UI thread.
///
/*--cef(source=client)--*/
class CefDOMVisitor : public virtual CefBase
{
public:
  ///
  // Method executed for visiting the DOM. The document object passed to this
  // method represents a snapshot of the DOM at the time this method is
  // executed. DOM objects are only valid for the scope of this method. Do not
  // keep references to or attempt to access any DOM objects outside the scope
  // of this method.
  ///
  /*--cef()--*/
  virtual void Visit(CefRefPtr<CefDOMDocument> document) =0;
};


///
// Class used to represent a DOM document. The methods of this class should only
// be called on the UI thread.
///
/*--cef(source=library)--*/
class CefDOMDocument : public virtual CefBase
{
public:
  typedef cef_dom_document_type_t Type;

  ///
  // Returns the document type.
  ///
  /*--cef(default_retval=DOM_DOCUMENT_TYPE_UNKNOWN)--*/
  virtual Type GetType() =0;

  ///
  // Returns the root document node.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetDocument() =0;

  ///
  // Returns the BODY node of an HTML document.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetBody() =0;

  ///
  // Returns the HEAD node of an HTML document.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetHead() =0;

  ///
  // Returns the title of an HTML document.
  ///
  /*--cef()--*/
  virtual CefString GetTitle() =0;

  ///
  // Returns the document element with the specified ID value.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetElementById(const CefString& id) =0;

  ///
  // Returns the node that currently has keyboard focus.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetFocusedNode() =0;

  ///
  // Returns true if a portion of the document is selected.
  ///
  /*--cef()--*/
  virtual bool HasSelection() =0;

  ///
  // Returns the selection start node.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetSelectionStartNode() =0;

  ///
  // Returns the selection offset within the start node.
  ///
  /*--cef()--*/
  virtual int GetSelectionStartOffset() =0;

  ///
  // Returns the selection end node.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetSelectionEndNode() =0;

  ///
  // Returns the selection offset within the end node.
  ///
  /*--cef()--*/
  virtual int GetSelectionEndOffset() =0;

  ///
  // Returns the contents of this selection as markup.
  ///
  /*--cef()--*/
  virtual CefString GetSelectionAsMarkup() =0;

  ///
  // Returns the contents of this selection as text.
  ///
  /*--cef()--*/
  virtual CefString GetSelectionAsText() =0;

  ///
  // Returns the base URL for the document.
  ///
  /*--cef()--*/
  virtual CefString GetBaseURL() =0;

  ///
  // Returns a complete URL based on the document base URL and the specified
  // partial URL.
  ///
  /*--cef()--*/
  virtual CefString GetCompleteURL(const CefString& partialURL) =0;
};


///
// Class used to represent a DOM node. The methods of this class should only be
// called on the UI thread.
///
/*--cef(source=library)--*/
class CefDOMNode : public virtual CefBase
{
public:
  typedef std::map<CefString,CefString> AttributeMap;
  typedef cef_dom_node_type_t Type;

  ///
  // Returns the type for this node.
  ///
  /*--cef(default_retval=DOM_NODE_TYPE_UNSUPPORTED)--*/
  virtual Type GetType() =0;

  ///
  // Returns true if this is a text node.
  ///
  /*--cef()--*/
  virtual bool IsText() =0;

  ///
  // Returns true if this is an element node.
  ///
  /*--cef()--*/
  virtual bool IsElement() =0;

  ///
  // Returns true if this is a form control element node.
  ///
  /*--cef()--*/
  virtual bool IsFormControlElement() =0;

  ///
  // Returns the type of this form control element node.
  ///
  /*--cef()--*/
  virtual CefString GetFormControlElementType() =0;

  ///
  // Returns true if this object is pointing to the same handle as |that|
  // object.
  ///
  /*--cef()--*/
  virtual bool IsSame(CefRefPtr<CefDOMNode> that) =0;

  ///
  // Returns the name of this node.
  ///
  /*--cef()--*/
  virtual CefString GetName() =0;

  ///
  // Returns the value of this node.
  ///
  /*--cef()--*/
  virtual CefString GetValue() =0;

  ///
  // Set the value of this node. Returns true on success.
  ///
  /*--cef()--*/
  virtual bool SetValue(const CefString& value) =0;

  ///
  // Returns the contents of this node as markup.
  ///
  /*--cef()--*/
  virtual CefString GetAsMarkup() =0;

  ///
  // Returns the document associated with this node.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMDocument> GetDocument() =0;

  ///
  // Returns the parent node.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetParent() =0;

  ///
  // Returns the previous sibling node.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetPreviousSibling() =0;

  ///
  // Returns the next sibling node.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetNextSibling() =0;

  ///
  // Returns true if this node has child nodes.
  ///
  /*--cef()--*/
  virtual bool HasChildren() =0;

  ///
  // Return the first child node.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetFirstChild() =0;

  ///
  // Returns the last child node.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetLastChild() =0;

  ///
  // Add an event listener to this node for the specified event type. If
  // |useCapture| is true then this listener will be considered a capturing
  // listener. Capturing listeners will recieve all events of the specified
  // type before the events are dispatched to any other event targets beneath
  // the current node in the tree. Events which are bubbling upwards through
  // the tree will not trigger a capturing listener. Separate calls to this
  // method can be used to register the same listener with and without capture.
  // See WebCore/dom/EventNames.h for the list of supported event types.
  ///
  /*--cef()--*/
  virtual void AddEventListener(const CefString& eventType,
                                CefRefPtr<CefDOMEventListener> listener,
                                bool useCapture) =0;


  // The following methods are valid only for element nodes.

  ///
  // Returns the tag name of this element.
  ///
  /*--cef()--*/
  virtual CefString GetElementTagName() =0;

  ///
  // Returns true if this element has attributes.
  ///
  /*--cef()--*/
  virtual bool HasElementAttributes() =0;

  ///
  // Returns true if this element has an attribute named |attrName|.
  ///
  /*--cef()--*/
  virtual bool HasElementAttribute(const CefString& attrName) =0;

  ///
  // Returns the element attribute named |attrName|.
  ///
  /*--cef()--*/
  virtual CefString GetElementAttribute(const CefString& attrName) =0;

  ///
  // Returns a map of all element attributes.
  ///
  /*--cef()--*/
  virtual void GetElementAttributes(AttributeMap& attrMap) =0;

  ///
  // Set the value for the element attribute named |attrName|. Returns true on
  // success.
  ///
  /*--cef()--*/
  virtual bool SetElementAttribute(const CefString& attrName,
                                   const CefString& value) =0;

  ///
  // Returns the inner text of the element.
  ///
  /*--cef()--*/
  virtual CefString GetElementInnerText() =0;
};


///
// Class used to represent a DOM event. The methods of this class should only
// be called on the UI thread.
///
/*--cef(source=library)--*/
class CefDOMEvent : public virtual CefBase
{
public:
  typedef cef_dom_event_category_t Category;
  typedef cef_dom_event_phase_t Phase;

  ///
  // Returns the event type.
  ///
  /*--cef()--*/
  virtual CefString GetType() =0;

  ///
  // Returns the event category.
  ///
  /*--cef(default_retval=DOM_EVENT_CATEGORY_UNKNOWN)--*/
  virtual Category GetCategory() =0;

  ///
  // Returns the event processing phase.
  ///
  /*--cef(default_retval=DOM_EVENT_PHASE_UNKNOWN)--*/
  virtual Phase GetPhase() =0;

  ///
  // Returns true if the event can bubble up the tree.
  ///
  /*--cef()--*/
  virtual bool CanBubble() =0;

  ///
  // Returns true if the event can be canceled.
  ///
  /*--cef()--*/
  virtual bool CanCancel() =0;

  ///
  // Returns the document associated with this event.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMDocument> GetDocument() =0;

  ///
  // Returns the target of the event.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetTarget() =0;

  ///
  // Returns the current target of the event.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetCurrentTarget() =0;
};


///
// Interface to implement for handling DOM events. The methods of this class
// will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefDOMEventListener : public virtual CefBase
{
public:
  ///
  // Called when an event is received. The event object passed to this method
  // contains a snapshot of the DOM at the time this method is executed. DOM
  // objects are only valid for the scope of this method. Do not keep references
  // to or attempt to access any DOM objects outside the scope of this method.
  ///
  /*--cef()--*/
  virtual void HandleEvent(CefRefPtr<CefDOMEvent> event) =0;
};


///
// Interface to implement for filtering response content. The methods of this
// class will always be called on the UI thread.
///
/*--cef(source=client)--*/
class CefContentFilter : public virtual CefBase
{
public:
  ///
  // Set |substitute_data| to the replacement for the data in |data| if data
  // should be modified.
  ///
  /*--cef()--*/
  virtual void ProcessData(const void* data, int data_size,
                           CefRefPtr<CefStreamReader>& substitute_data) {}

  ///
  // Called when there is no more data to be processed. It is expected that
  // whatever data was retained in the last ProcessData() call, it should be
  // returned now by setting |remainder| if appropriate.
  ///
  /*--cef()--*/
  virtual void Drain(CefRefPtr<CefStreamReader>& remainder) {}
};


///
// Class used to represent drag data. The methods of this class may be called
// on any thread.
///
/*--cef(source=library)--*/
class CefDragData : public virtual CefBase
{
public:
  ///
  // Returns true if the drag data is a link.
  ///
  /*--cef()--*/
  virtual bool IsLink() =0;

  ///
  // Returns true if the drag data is a text or html fragment.
  ///
  /*--cef()--*/
  virtual bool IsFragment() =0;

  ///
  // Returns true if the drag data is a file.
  ///
  /*--cef()--*/
  virtual bool IsFile() =0;

  ///
  // Return the link URL that is being dragged.
  ///
  /*--cef()--*/
  virtual CefString GetLinkURL() =0;

  ///
  // Return the title associated with the link being dragged.
  ///
  /*--cef()--*/
  virtual CefString GetLinkTitle() =0;

  ///
  // Return the metadata, if any, associated with the link being dragged.
  ///
  /*--cef()--*/
  virtual CefString GetLinkMetadata() =0;

  ///
  // Return the plain text fragment that is being dragged.
  ///
  /*--cef()--*/
  virtual CefString GetFragmentText() =0;

  ///
  // Return the text/html fragment that is being dragged.
  ///
  /*--cef()--*/
  virtual CefString GetFragmentHtml() =0;

  ///
  // Return the base URL that the fragment came from. This value is used for
  // resolving relative URLs and may be empty.
  ///
  /*--cef()--*/
  virtual CefString GetFragmentBaseURL() =0;

  ///
  // Return the extension of the file being dragged out of the browser window.
  ///
  /*--cef()--*/
  virtual CefString GetFileExtension() =0;

  ///
  // Return the name of the file being dragged out of the browser window.
  ///
  /*--cef()--*/
  virtual CefString GetFileName() =0;

  ///
  // Retrieve the list of file names that are being dragged into the browser
  // window.
  ///
  /*--cef()--*/
  virtual bool GetFileNames(std::vector<CefString>& names) =0;
};


///
// Class used to create and/or parse command line arguments. Arguments with
// '--', '-' and, on Windows, '/' prefixes are considered switches. Switches
// will always precede any arguments without switch prefixes. Switches can
// optionally have a value specified using the '=' delimiter (e.g. 
// "-switch=value"). An argument of "--" will terminate switch parsing with all
// subsequent tokens, regardless of prefix, being interpreted as non-switch
// arguments. Switch names are considered case-insensitive. This class can be
// used before CefInitialize() is called.
///
/*--cef(source=library,no_debugct_check)--*/
class CefCommandLine : public virtual CefBase
{
public:
  typedef std::vector<CefString> ArgumentList;
  typedef std::map<CefString,CefString> SwitchMap;

  ///
  // Create a new CefCommandLine instance.
  ///
  /*--cef(revision_check)--*/
  static CefRefPtr<CefCommandLine> CreateCommandLine();

  ///
  // Initialize the command line with the specified |argc| and |argv| values.
  // The first argument must be the name of the program. This method is only
  // supported on non-Windows platforms.
  ///
  /*--cef()--*/
  virtual void InitFromArgv(int argc, const char* const* argv) =0;

  ///
  // Initialize the command line with the string returned by calling
  // GetCommandLineW(). This method is only supported on Windows.
  ///
  /*--cef()--*/
  virtual void InitFromString(const CefString& command_line) =0;

  ///
  // Constructs and returns the represented command line string. Use this method
  // cautiously because quoting behavior is unclear.
  ///
  /*--cef()--*/
  virtual CefString GetCommandLineString() =0;

  ///
  // Get the program part of the command line string (the first item).
  ///
  /*--cef()--*/
  virtual CefString GetProgram() =0;

  ///
  // Set the program part of the command line string (the first item).
  ///
  /*--cef()--*/
  virtual void SetProgram(const CefString& program) =0;

  ///
  // Returns true if the command line has switches.
  ///
  /*--cef()--*/
  virtual bool HasSwitches() =0;

  ///
  // Returns true if the command line contains the given switch.
  ///
  /*--cef()--*/
  virtual bool HasSwitch(const CefString& name) =0;

  ///
  // Returns the value associated with the given switch. If the switch has no
  // value or isn't present this method returns the empty string.
  ///
  /*--cef()--*/
  virtual CefString GetSwitchValue(const CefString& name) =0;

  ///
  // Returns the map of switch names and values. If a switch has no value an 
  // empty string is returned.
  ///
  /*--cef()--*/
  virtual void GetSwitches(SwitchMap& switches) =0;

  ///
  // Add a switch to the end of the command line. If the switch has no value
  // pass an empty value string.
  ///
  /*--cef()--*/
  virtual void AppendSwitch(const CefString& name) =0;

  ///
  // Add a switch with the specified value to the end of the command line.
  ///
  /*--cef()--*/
  virtual void AppendSwitchWithValue(const CefString& name,
                                     const CefString& value) =0;

  ///
  // True if there are remaining command line arguments.
  ///
  /*--cef()--*/
  virtual bool HasArguments() =0;

  ///
  // Get the remaining command line arguments.
  ///
  /*--cef()--*/
  virtual void GetArguments(ArgumentList& arguments) =0;

  ///
  // Add an argument to the end of the command line.
  ///
  /*--cef()--*/
  virtual void AppendArgument(const CefString& argument) =0;
};

#endif // _CEF_H
