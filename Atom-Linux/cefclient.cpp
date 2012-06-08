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
#include "client_handler.h"
#include "util.h"

namespace {

// Return the int representation of the specified string.
int GetIntValue(const CefString& str) {
	if (str.empty())
		return 0;

	std::string stdStr = str;
	return atoi(stdStr.c_str());
}

// ClientApp implementation.
class ClientApp: public CefApp, public CefProxyHandler {
public:
	ClientApp(cef_proxy_type_t proxy_type, const CefString& proxy_config) :
			proxy_type_(proxy_type), proxy_config_(proxy_config) {
	}

	// CefApp methods
	virtual CefRefPtr<CefProxyHandler> GetProxyHandler() OVERRIDE {
		return this;
	}

	// CefProxyHandler methods
	virtual void GetProxyForUrl(const CefString& url, CefProxyInfo& proxy_info)
			OVERRIDE {
		proxy_info.proxyType = proxy_type_;
		if (!proxy_config_.empty())
			CefString(&proxy_info.proxyList) = proxy_config_;
	}

protected:
	cef_proxy_type_t proxy_type_;
	CefString proxy_config_;

IMPLEMENT_REFCOUNTING(ClientApp)
	;
};

} // namespace

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

void AppGetSettings(CefSettings& settings, CefRefPtr<CefApp>& app) {
	CefString(&settings.cache_path) = "";
	CefString(&settings.user_agent) = "";
	CefString(&settings.product_version) = "";
	CefString(&settings.locale) = "";
	CefString(&settings.log_file) = "";
	CefString(&settings.javascript_flags) = "";

	settings.log_severity = LOGSEVERITY_ERROR;
	settings.local_storage_quota = 0;
	settings.session_storage_quota = 0;
}
