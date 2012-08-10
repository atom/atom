// Copyright (c) 2012 The Chromium Embedded Framework Authors.
// Portions copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "libcef/browser/navigate_params.h"

CefNavigateParams::CefNavigateParams(
    const GURL& a_url,
    content::PageTransition a_transition)
    : url(a_url),
      frame_id(-1),
      disposition(CURRENT_TAB),
      transition(a_transition),
      is_renderer_initiated(false),
      user_gesture(true) {
}

CefNavigateParams::~CefNavigateParams() {
}
