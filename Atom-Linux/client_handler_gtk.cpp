// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include <gtk/gtk.h>
#include <string>
#include "client_handler.h"
#include "include/cef_browser.h"
#include "include/cef_frame.h"

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

	GtkWidget* window = gtk_widget_get_ancestor(
			GTK_WIDGET(browser->GetWindowHandle()), GTK_TYPE_WINDOW);
	std::string titleStr(title);
	gtk_window_set_title(GTK_WINDOW(window), titleStr.c_str());
}

void ClientHandler::SendNotification(NotificationType type) {
	// TODO(port): Implement this method.
}

void ClientHandler::CloseMainWindow() {
	// TODO(port): Close main window.
}
