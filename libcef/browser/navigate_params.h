// Copyright (c) 2012 The Chromium Embedded Framework Authors.
// Portions copyright (c) 2011 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_NAVIGATE_PARAMS_H_
#define CEF_LIBCEF_BROWSER_NAVIGATE_PARAMS_H_
#pragma once

#include <string>

#include "content/public/browser/global_request_id.h"
#include "content/public/common/page_transition_types.h"
#include "content/public/common/referrer.h"
#include "googleurl/src/gurl.h"
#include "net/base/upload_data.h"
#include "webkit/glue/window_open_disposition.h"

// Parameters that tell CefBrowserHostImpl::Navigate() what to do.
struct CefNavigateParams {
  CefNavigateParams(const GURL& a_url,
                    content::PageTransition a_transition);
  ~CefNavigateParams();

  // The following parameters are sent to the renderer via CefMsg_LoadRequest.
  // ---------------------------------------------------------------------------

  // Request method.
  std::string method;

  // The URL/referrer to be loaded.
  GURL url;
  content::Referrer referrer;

  // The frame that the request should be loaded in or -1 to use the main frame.
  int64 frame_id;

  // Usually the URL of the document in the top-level window, which may be
  // checked by the third-party cookie blocking policy. Leaving it empty may
  // lead to undesired cookie blocking. Third-party cookie blocking can be
  // bypassed by setting first_party_for_cookies = url, but this should ideally
  // only be done if there really is no way to determine the correct value.
  GURL first_party_for_cookies;

  // Additional HTTP request headers.
  std::string headers;

  // net::URLRequest load flags (0 by default).
  int load_flags;

  // Upload data (may be NULL).
  scoped_refptr<net::UploadData> upload_data;


  // The following parameters are used to define browser behavior when servicing
  // the navigation request.
  // ---------------------------------------------------------------------------

  // The disposition requested by the navigation source. Default is CURRENT_TAB.
  WindowOpenDisposition disposition;

  // The transition type of the navigation.
  content::PageTransition transition;

  // Whether this navigation was initiated by the renderer process.
  bool is_renderer_initiated;

  // If non-empty, the new tab contents encoding is overriden by this value.
  std::string override_encoding;

  // If false then the navigation was not initiated by a user gesture. Default
  // is true.
  bool user_gesture;

  // Refers to a navigation that was parked in the browser in order to be
  // transferred to another RVH. Only used in case of a redirection of a request
  // to a different site that created a new RVH.
  content::GlobalRequestID transferred_global_request_id;

 private:
  CefNavigateParams();
};

#endif  // CEF_LIBCEF_BROWSER_NAVIGATE_PARAMS_H_
