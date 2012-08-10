// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_TESTS_CEFCLIENT_CEFCLIENT_H_
#define CEF_TESTS_CEFCLIENT_CEFCLIENT_H_
#pragma once

#include <string>
#include "include/cef_base.h"
#include "cefclient/client_app.h"

class CefApp;
class CefBrowser;
class CefCommandLine;

// Returns the main browser window instance.
CefRefPtr<CefBrowser> AppGetBrowser();

// Returns the main application window handle.
CefWindowHandle AppGetMainHwnd();

// Returns the application working directory.
std::string AppGetWorkingDirectory();

// Initialize the application command line.
void AppInitCommandLine(int argc, const char* const* argv);

// Returns the application command line object.
CefRefPtr<CefCommandLine> AppGetCommandLine();

// Returns the application settings based on command line arguments.
void AppGetSettings(CefSettings& settings, CefRefPtr<ClientApp> app);

// Returns the application browser settings based on command line arguments.
void AppGetBrowserSettings(CefBrowserSettings& settings);

// Implementations for various tests.
void RunGetSourceTest(CefRefPtr<CefBrowser> browser);
void RunGetTextTest(CefRefPtr<CefBrowser> browser);
void RunRequestTest(CefRefPtr<CefBrowser> browser);
void RunPopupTest(CefRefPtr<CefBrowser> browser);
void RunDialogTest(CefRefPtr<CefBrowser> browser);
void RunPluginInfoTest(CefRefPtr<CefBrowser> browser);
void RunLocalStorageTest(CefRefPtr<CefBrowser> browser);
void RunAccelerated2DCanvasTest(CefRefPtr<CefBrowser> browser);
void RunAcceleratedLayersTest(CefRefPtr<CefBrowser> browser);
void RunWebGLTest(CefRefPtr<CefBrowser> browser);
void RunHTML5VideoTest(CefRefPtr<CefBrowser> browser);
void RunXMLHTTPRequestTest(CefRefPtr<CefBrowser> browser);
void RunDragDropTest(CefRefPtr<CefBrowser> browser);
void RunGeolocationTest(CefRefPtr<CefBrowser> browser);

#if defined(OS_WIN)
void RunTransparentPopupTest(CefRefPtr<CefBrowser> browser);
#endif

#endif  // CEF_TESTS_CEFCLIENT_CEFCLIENT_H_
