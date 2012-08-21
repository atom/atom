// Copyright (c) 2012 Marshall A. Greenblatt. All rights reserved.
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

#ifndef CEF_INCLUDE_CEF_SCHEME_H_
#define CEF_INCLUDE_CEF_SCHEME_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_browser.h"
#include "include/cef_frame.h"
#include "include/cef_request.h"
#include "include/cef_response.h"
#include "include/cef_resource_handler.h"

class CefSchemeHandlerFactory;


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
bool CefRegisterSchemeHandlerFactory(
    const CefString& scheme_name,
    const CefString& domain_name,
    CefRefPtr<CefSchemeHandlerFactory> factory);

///
// Clear all registered scheme handler factories. Returns false on error. This
// function may be called on any thread.
///
/*--cef()--*/
bool CefClearSchemeHandlerFactories();


///
// Class that manages custom scheme registrations.
///
/*--cef(source=library)--*/
class CefSchemeRegistrar : public virtual CefBase {
 public:
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
  // domain name as defined in Section 3.5 of RFC 1034 [13] and Section 2.1 of
  // RFC 1123. These URLs will be canonicalized to "scheme://host/path" in the
  // simplest case and "scheme://username:password@host:port/path" in the most
  // explicit case. For example, "scheme:host/path" and "scheme:///host/path"
  // will both be canonicalized to "scheme://host/path". The origin of a
  // standard scheme URL is the combination of scheme, host and port (i.e.,
  // "scheme://host:port" in the most explicit case).
  //
  // For non-standard scheme URLs only the "scheme:" component is parsed and
  // canonicalized. The remainder of the URL will be passed to the handler
  // as-is. For example, "scheme:///some%20text" will remain the same.
  // Non-standard scheme URLs cannot be used as a target for form submission.
  //
  // If |is_local| is true the scheme will be treated as local (i.e., with the
  // same security rules as those applied to "file" URLs). Normal pages cannot
  // link to or access local URLs. Also, by default, local URLs can only perform
  // XMLHttpRequest calls to the same URL (origin + path) that originated the
  // request. To allow XMLHttpRequest calls from a local URL to other URLs with
  // the same origin set the CefSettings.file_access_from_file_urls_allowed
  // value to true. To allow XMLHttpRequest calls from a local URL to all
  // origins set the CefSettings.universal_access_from_file_urls_allowed value
  // to true.
  //
  // If |is_display_isolated| is true the scheme will be treated as display-
  // isolated. This means that pages cannot display these URLs unless they are
  // from the same scheme. For example, pages in another origin cannot create
  // iframes or hyperlinks to URLs with this scheme.
  //
  // This function may be called on any thread. It should only be called once
  // per unique |scheme_name| value. If |scheme_name| is already registered or
  // if an error occurs this method will return false.
  ///
  /*--cef()--*/
  virtual bool AddCustomScheme(const CefString& scheme_name,
                               bool is_standard,
                               bool is_local,
                               bool is_display_isolated) =0;
};


///
// Class that creates CefResourceHandler instances for handling scheme requests.
// The methods of this class will always be called on the IO thread.
///
/*--cef(source=client)--*/
class CefSchemeHandlerFactory : public virtual CefBase {
 public:
  ///
  // Return a new resource handler instance to handle the request. |browser|
  // and |frame| will be the browser window and frame respectively that
  // originated the request or NULL if the request did not originate from a
  // browser window (for example, if the request came from CefURLRequest). The
  // |request| object passed to this method will not contain cookie data.
  ///
  /*--cef(optional_param=browser,optional_param=frame)--*/
  virtual CefRefPtr<CefResourceHandler> Create(
      CefRefPtr<CefBrowser> browser,
      CefRefPtr<CefFrame> frame,
      const CefString& scheme_name,
      CefRefPtr<CefRequest> request) =0;
};

#endif  // CEF_INCLUDE_CEF_SCHEME_H_
