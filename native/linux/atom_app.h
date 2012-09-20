#ifndef ATOM_APP_H_
#define ATOM_APP_H_
#pragma once

#include <string>
#include "include/cef_base.h"

class CefApp;
class CefBrowser;
class CefCommandLine;

// Returns the main browser window instance.
CefRefPtr<CefBrowser> AppGetBrowser();

// Returns the main application window handle.
CefWindowHandle AppGetMainHwnd();

// Returns the application working directory.
std::string AppGetWorkingDirectory();

// Returns the application's path.
std::string AppPath();

// Returns the initial path to open.
std::string PathToOpen();

// Returns the application settings
void AppGetSettings(CefSettings& settings, CefRefPtr<CefApp>& app);

#endif
