// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_ORIGIN_WHITELIST_IMPL_H_
#define CEF_LIBCEF_BROWSER_ORIGIN_WHITELIST_IMPL_H_

namespace content {
class RenderProcessHost;
}

// Called when a new RenderProcessHost is created to send existing cross-origin
// whitelist entry information.
void RegisterCrossOriginWhitelistEntriesWithHost(
    content::RenderProcessHost* host);

#endif  // CEF_LIBCEF_BROWSER_ORIGIN_WHITELIST_IMPL_H_
