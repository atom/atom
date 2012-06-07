// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include <gtk/gtk.h>
#include <string>
#include "client_handler.h"
#include "include/cef_browser.h"
#include "include/cef_frame.h"
#include <stdlib.h>

// ClientHandler::ClientLifeSpanHandler implementation
bool ClientHandler::OnBeforePopup(CefRefPtr<CefBrowser> parentBrowser,
		const CefPopupFeatures& popupFeatures, CefWindowInfo& windowInfo,
		const CefString& url, CefRefPtr<CefClient>& client,
		CefBrowserSettings& settings) {
	REQUIRE_UI_THREAD();

	return false;
}

void ClientHandler::OnAddressChange(CefRefPtr<CefBrowser> browser,
		CefRefPtr<CefFrame> frame, const CefString& url) {
	//Intentionally left blank
}

void ClientHandler::OnTitleChange(CefRefPtr<CefBrowser> browser,
		const CefString& title) {
	REQUIRE_UI_THREAD();

	std::string titleStr(title);

	size_t inHomeDir;
	std::string home = getenv("HOME");
	inHomeDir = titleStr.find(home);
	if (inHomeDir == 0) {
		titleStr = titleStr.substr(home.length());
		titleStr.insert(0, "~");
	}

	size_t lastSlash;
	lastSlash = titleStr.rfind("/");

	std::string formatted;
	if (lastSlash != std::string::npos && lastSlash + 1 < titleStr.length()) {
		formatted.append(titleStr, lastSlash + 1,
				titleStr.length() - lastSlash);
		formatted.append(" (");
		formatted.append(titleStr, 0, lastSlash);
		formatted.append(")");
	} else
		formatted.append(titleStr);
	formatted.append(" - atom");

	GtkWidget* window = gtk_widget_get_ancestor(
			GTK_WIDGET(browser->GetWindowHandle()), GTK_TYPE_WINDOW);
	gtk_window_set_title(GTK_WINDOW(window), formatted.c_str());
}

void ClientHandler::SendNotification(NotificationType type) {
	// TODO(port): Implement this method.
}

void ClientHandler::CloseMainWindow() {
	// TODO(port): Close main window.
}
