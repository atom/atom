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
		if (evalFunc->ExecuteFunctionWithContext(v8Context, globalObj, args,
				retVal, exception, false)) {
			if (retVal.get()) {
				frame->ExecuteJavaScript(
						std::string("alert('InvokeScript returns ")
								+ retVal->GetStringValue().ToString() + "!');",
						url, 0);
			} else {
				frame->ExecuteJavaScript(
						std::string("alert('InvokeScript returns exception: ")
								+ exception->GetMessage().ToString() + "!');",
						url, 0);
			}
		} else {
			frame->ExecuteJavaScript("alert('Failed to execute function!');",
					url, 0);
		}

		v8Context->Exit();
	} else {
		frame->ExecuteJavaScript("alert('Failed to enter into V8 context!');",
				url, 0);
	}
}

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

void AppInitCommandLine(int argc, const char* const * argv) {
	g_command_line = CefCommandLine::CreateCommandLine();
	g_command_line->InitFromArgv(argc, argv);
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

	CefString(&settings.cache_path) = g_command_line->GetSwitchValue(
			cefclient::kCachePath);
	CefString(&settings.user_agent) = g_command_line->GetSwitchValue(
			cefclient::kUserAgent);
	CefString(&settings.product_version) = g_command_line->GetSwitchValue(
			cefclient::kProductVersion);
	CefString(&settings.locale) = g_command_line->GetSwitchValue(
			cefclient::kLocale);
	CefString(&settings.log_file) = g_command_line->GetSwitchValue(
			cefclient::kLogFile);

	{
		std::string str = g_command_line->GetSwitchValue(
				cefclient::kLogSeverity);
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
		std::string str = g_command_line->GetSwitchValue(
				cefclient::kGraphicsImpl);
		if (!str.empty()) {
			if (str == cefclient::kGraphicsImpl_Desktop)
				settings.graphics_implementation = DESKTOP_IN_PROCESS;
			else if (str == cefclient::kGraphicsImpl_DesktopCmdBuffer)
				settings.graphics_implementation =
						DESKTOP_IN_PROCESS_COMMAND_BUFFER;
		}
	}

	settings.local_storage_quota = GetIntValue(
			g_command_line->GetSwitchValue(cefclient::kLocalStorageQuota));
	settings.session_storage_quota = GetIntValue(
			g_command_line->GetSwitchValue(cefclient::kSessionStorageQuota));

	CefString(&settings.javascript_flags) = g_command_line->GetSwitchValue(
			cefclient::kJavascriptFlags);

	CefString(&settings.pack_file_path) = g_command_line->GetSwitchValue(
			cefclient::kPackFilePath);
	CefString(&settings.locales_dir_path) = g_command_line->GetSwitchValue(
			cefclient::kLocalesDirPath);

	settings.pack_loading_disabled = g_command_line->HasSwitch(
			cefclient::kPackLoadingDisabled);

	// Retrieve command-line proxy configuration, if any.
	bool has_proxy = false;
	cef_proxy_type_t proxy_type = PROXY_TYPE_DIRECT;
	CefString proxy_config;

	if (g_command_line->HasSwitch(cefclient::kProxyType)) {
		std::string str = g_command_line->GetSwitchValue(cefclient::kProxyType);
		if (str == cefclient::kProxyType_Direct) {
			has_proxy = true;
			proxy_type = PROXY_TYPE_DIRECT;
		} else if (str == cefclient::kProxyType_Named
				|| str == cefclient::kProxyType_Pac) {
			proxy_config = g_command_line->GetSwitchValue(
					cefclient::kProxyConfig);
			if (!proxy_config.empty()) {
				has_proxy = true;
				proxy_type = (
						str == cefclient::kProxyType_Named ?
								PROXY_TYPE_NAMED : PROXY_TYPE_PAC_STRING);
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

	settings.drag_drop_disabled = g_command_line->HasSwitch(
			cefclient::kDragDropDisabled);
	settings.load_drops_disabled = g_command_line->HasSwitch(
			cefclient::kLoadDropsDisabled);
	settings.history_disabled = g_command_line->HasSwitch(
			cefclient::kHistoryDisabled);
	settings.remote_fonts_disabled = g_command_line->HasSwitch(
			cefclient::kRemoteFontsDisabled);

	CefString(&settings.default_encoding) = g_command_line->GetSwitchValue(
			cefclient::kDefaultEncoding);

	settings.encoding_detector_enabled = g_command_line->HasSwitch(
			cefclient::kEncodingDetectorEnabled);
	settings.javascript_disabled = g_command_line->HasSwitch(
			cefclient::kJavascriptDisabled);
	settings.javascript_open_windows_disallowed = g_command_line->HasSwitch(
			cefclient::kJavascriptOpenWindowsDisallowed);
	settings.javascript_close_windows_disallowed = g_command_line->HasSwitch(
			cefclient::kJavascriptCloseWindowsDisallowed);
	settings.javascript_access_clipboard_disallowed = g_command_line->HasSwitch(
			cefclient::kJavascriptAccessClipboardDisallowed);
	settings.dom_paste_disabled = g_command_line->HasSwitch(
			cefclient::kDomPasteDisabled);
	settings.caret_browsing_enabled = g_command_line->HasSwitch(
			cefclient::kCaretBrowsingDisabled);
	settings.java_disabled = g_command_line->HasSwitch(
			cefclient::kJavaDisabled);
	settings.plugins_disabled = g_command_line->HasSwitch(
			cefclient::kPluginsDisabled);
	settings.universal_access_from_file_urls_allowed =
			g_command_line->HasSwitch(
					cefclient::kUniversalAccessFromFileUrlsAllowed);
	settings.file_access_from_file_urls_allowed = g_command_line->HasSwitch(
			cefclient::kFileAccessFromFileUrlsAllowed);
	settings.web_security_disabled = g_command_line->HasSwitch(
			cefclient::kWebSecurityDisabled);
	settings.xss_auditor_enabled = g_command_line->HasSwitch(
			cefclient::kXssAuditorEnabled);
	settings.image_load_disabled = g_command_line->HasSwitch(
			cefclient::kImageLoadingDisabled);
	settings.shrink_standalone_images_to_fit = g_command_line->HasSwitch(
			cefclient::kShrinkStandaloneImagesToFit);
	settings.site_specific_quirks_disabled = g_command_line->HasSwitch(
			cefclient::kSiteSpecificQuirksDisabled);
	settings.text_area_resize_disabled = g_command_line->HasSwitch(
			cefclient::kTextAreaResizeDisabled);
	settings.page_cache_disabled = g_command_line->HasSwitch(
			cefclient::kPageCacheDisabled);
	settings.tab_to_links_disabled = g_command_line->HasSwitch(
			cefclient::kTabToLinksDisabled);
	settings.hyperlink_auditing_disabled = g_command_line->HasSwitch(
			cefclient::kHyperlinkAuditingDisabled);
	settings.user_style_sheet_enabled = g_command_line->HasSwitch(
			cefclient::kUserStyleSheetEnabled);

	CefString(&settings.user_style_sheet_location) =
			g_command_line->GetSwitchValue(cefclient::kUserStyleSheetLocation);

	settings.author_and_user_styles_disabled = g_command_line->HasSwitch(
			cefclient::kAuthorAndUserStylesDisabled);
	settings.local_storage_disabled = g_command_line->HasSwitch(
			cefclient::kLocalStorageDisabled);
	settings.databases_disabled = g_command_line->HasSwitch(
			cefclient::kDatabasesDisabled);
	settings.application_cache_disabled = g_command_line->HasSwitch(
			cefclient::kApplicationCacheDisabled);
	settings.webgl_disabled = g_command_line->HasSwitch(
			cefclient::kWebglDisabled);
	settings.accelerated_compositing_enabled = g_command_line->HasSwitch(
			cefclient::kAcceleratedCompositingEnabled);
	settings.threaded_compositing_enabled = g_command_line->HasSwitch(
			cefclient::kThreadedCompositingEnabled);
	settings.accelerated_layers_disabled = g_command_line->HasSwitch(
			cefclient::kAcceleratedLayersDisabled);
	settings.accelerated_video_disabled = g_command_line->HasSwitch(
			cefclient::kAcceleratedVideoDisabled);
	settings.accelerated_2d_canvas_disabled = g_command_line->HasSwitch(
			cefclient::kAcceledated2dCanvasDisabled);
	settings.accelerated_painting_disabled = g_command_line->HasSwitch(
			cefclient::kAcceleratedPaintingDisabled);
	settings.accelerated_filters_disabled = g_command_line->HasSwitch(
			cefclient::kAcceleratedFiltersDisabled);
	settings.accelerated_plugins_disabled = g_command_line->HasSwitch(
			cefclient::kAcceleratedPluginsDisabled);
	settings.developer_tools_disabled = g_command_line->HasSwitch(
			cefclient::kDeveloperToolsDisabled);
	settings.fullscreen_enabled = g_command_line->HasSwitch(
			cefclient::kFullscreenEnabled);
}
