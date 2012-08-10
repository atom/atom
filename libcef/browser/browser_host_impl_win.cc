// Copyright (c) 2012 The Chromium Embedded Framework Authors.
// Portions copyright (c) 2011 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "libcef/browser/browser_host_impl.h"

#include <commdlg.h>
#include <dwmapi.h>
#include <shellapi.h>
#include <wininet.h>
#include <winspool.h>

#include "libcef/browser/thread_util.h"

#include "base/string_util.h"
#include "base/utf_string_conversions.h"
#include "base/win/registry.h"
#include "base/win/windows_version.h"
#include "content/public/browser/native_web_keyboard_event.h"
#include "content/public/browser/web_contents_view.h"
#include "content/public/common/file_chooser_params.h"
#include "ui/base/win/hwnd_util.h"

#pragma comment(lib, "dwmapi.lib")

namespace {

bool IsAeroGlassEnabled() {
  if (base::win::GetVersion() < base::win::VERSION_VISTA)
    return false;

  BOOL enabled = FALSE;
  return SUCCEEDED(DwmIsCompositionEnabled(&enabled)) && enabled;
}

void SetAeroGlass(HWND hWnd) {
  if (!IsAeroGlassEnabled())
    return;

  // Make the whole window transparent.
  MARGINS mgMarInset = { -1, -1, -1, -1 };
  DwmExtendFrameIntoClientArea(hWnd, &mgMarInset);
}

void WriteTextToFile(const std::string& data, const std::wstring& file_path) {
  FILE* fp;
  errno_t err = _wfopen_s(&fp, file_path.c_str(), L"wt");
  if (err)
      return;
  fwrite(data.c_str(), 1, data.size(), fp);
  fclose(fp);
}


// from chrome/browser/views/shell_dialogs_win.cc

bool RunOpenFileDialog(const std::wstring& filter, HWND owner, FilePath* path) {
  OPENFILENAME ofn;

  // We must do this otherwise the ofn's FlagsEx may be initialized to random
  // junk in release builds which can cause the Places Bar not to show up!
  ZeroMemory(&ofn, sizeof(ofn));
  ofn.lStructSize = sizeof(ofn);
  ofn.hwndOwner = owner;

  wchar_t filename[MAX_PATH];
  base::wcslcpy(filename, path->value().c_str(), arraysize(filename));

  ofn.lpstrFile = filename;
  ofn.nMaxFile = MAX_PATH;

  // We use OFN_NOCHANGEDIR so that the user can rename or delete the directory
  // without having to close Chrome first.
  ofn.Flags = OFN_FILEMUSTEXIST | OFN_NOCHANGEDIR;

  if (!filter.empty()) {
    ofn.lpstrFilter = filter.c_str();
  }
  bool success = !!GetOpenFileName(&ofn);
  if (success)
    *path = FilePath(filename);
  return success;
}

bool RunOpenMultiFileDialog(const std::wstring& filter, HWND owner,
                            std::vector<FilePath>* paths) {
  OPENFILENAME ofn;

  // We must do this otherwise the ofn's FlagsEx may be initialized to random
  // junk in release builds which can cause the Places Bar not to show up!
  ZeroMemory(&ofn, sizeof(ofn));
  ofn.lStructSize = sizeof(ofn);
  ofn.hwndOwner = owner;

  scoped_array<wchar_t> filename(new wchar_t[UNICODE_STRING_MAX_CHARS]);
  filename[0] = 0;

  ofn.lpstrFile = filename.get();
  ofn.nMaxFile = UNICODE_STRING_MAX_CHARS;

  // We use OFN_NOCHANGEDIR so that the user can rename or delete the directory
  // without having to close Chrome first.
  ofn.Flags = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST | OFN_EXPLORER
               | OFN_HIDEREADONLY | OFN_ALLOWMULTISELECT;

  if (!filter.empty()) {
    ofn.lpstrFilter = filter.c_str();
  }
  bool success = !!GetOpenFileName(&ofn);

  if (success) {
    std::vector<FilePath> files;
    const wchar_t* selection = ofn.lpstrFile;
    while (*selection) {  // Empty string indicates end of list.
      files.push_back(FilePath(selection));
      // Skip over filename and null-terminator.
      selection += files.back().value().length() + 1;
    }
    if (files.empty()) {
      success = false;
    } else if (files.size() == 1) {
      // When there is one file, it contains the path and filename.
      paths->swap(files);
    } else {
      // Otherwise, the first string is the path, and the remainder are
      // filenames.
      std::vector<FilePath>::iterator path = files.begin();
      for (std::vector<FilePath>::iterator file = path + 1;
           file != files.end(); ++file) {
        paths->push_back(path->Append(*file));
      }
    }
  }
  return success;
}


// According to Mozilla in uriloader/exthandler/win/nsOSHelperAppService.cpp:
// "Some versions of windows (Win2k before SP3, Win XP before SP1) crash in
// ShellExecute on long URLs (bug 161357 on bugzilla.mozilla.org). IE 5 and 6
// support URLS of 2083 chars in length, 2K is safe."
const int kMaxAddressLengthChars = 2048;

bool HasExternalHandler(const std::string& scheme) {
  base::win::RegKey key;
  const std::wstring registry_path =
      ASCIIToWide(scheme + "\\shell\\open\\command");
  key.Open(HKEY_CLASSES_ROOT, registry_path.c_str(), KEY_READ);
  if (key.Valid()) {
    DWORD size = 0;
    key.ReadValue(NULL, NULL, &size, NULL);
    if (size > 2) {
       // ShellExecute crashes the process when the command is empty.
       // We check for "2" because it always returns the trailing NULL.
       return true;
    }
  }

  return false;
}

}  // namespace

// static
void CefBrowserHostImpl::RegisterWindowClass() {
  // Register the window class
  WNDCLASSEX wcex = {
    /* cbSize = */ sizeof(WNDCLASSEX),
    /* style = */ CS_HREDRAW | CS_VREDRAW,
    /* lpfnWndProc = */ CefBrowserHostImpl::WndProc,
    /* cbClsExtra = */ 0,
    /* cbWndExtra = */ 0,
    /* hInstance = */ ::GetModuleHandle(NULL),
    /* hIcon = */ NULL,
    /* hCursor = */ LoadCursor(NULL, IDC_ARROW),
    /* hbrBackground = */ 0,
    /* lpszMenuName = */ NULL,
    /* lpszClassName = */ CefBrowserHostImpl::GetWndClass(),
    /* hIconSm = */ NULL,
  };
  RegisterClassEx(&wcex);
}

// static
LPCTSTR CefBrowserHostImpl::GetWndClass() {
  return L"CefBrowserWindow";
}

// static
LRESULT CALLBACK CefBrowserHostImpl::WndProc(HWND hwnd, UINT message,
                                         WPARAM wParam, LPARAM lParam) {
  CefBrowserHostImpl* browser =
      static_cast<CefBrowserHostImpl*>(ui::GetWindowUserData(hwnd));

  switch (message) {
  case WM_CLOSE:
    if (browser) {
      bool handled(false);

      if (browser->client_.get()) {
        CefRefPtr<CefLifeSpanHandler> handler =
            browser->client_->GetLifeSpanHandler();
        if (handler.get()) {
          // Give the client a chance to handle this one.
          handled = handler->DoClose(browser);
        }
      }

      if (handled)
        return 0;

      // We are our own parent in this case.
      browser->ParentWindowWillClose();
    }
    break;

  case WM_DESTROY:
    if (browser) {
      // Clear the user data pointer.
      ui::SetWindowUserData(hwnd, NULL);

      // Destroy the browser.
      browser->DestroyBrowser();

      // Release the reference added in PlatformCreateWindow().
      browser->Release();
    }
    return 0;

  case WM_SIZE:
    // Minimizing resizes the window to 0x0 which causes our layout to go all
    // screwy, so we just ignore it.
    if (wParam != SIZE_MINIMIZED && browser) {
      // resize the web view window to the full size of the browser window
      RECT rc;
      GetClientRect(hwnd, &rc);
      MoveWindow(browser->GetContentView(), 0, 0, rc.right, rc.bottom,
          TRUE);
    }
    return 0;

  case WM_SETFOCUS:
    if (browser)
      browser->OnSetFocus(FOCUS_SOURCE_SYSTEM);
    return 0;

  case WM_ERASEBKGND:
    return 0;

  case WM_DWMCOMPOSITIONCHANGED:
    // Message sent to top-level windows when composition has been enabled or
    // disabled.
    if (browser && browser->window_info_.transparent_painting)
      SetAeroGlass(hwnd);
    break;
  }

  return DefWindowProc(hwnd, message, wParam, lParam);
}

bool CefBrowserHostImpl::PlatformCreateWindow() {
  std::wstring windowName(CefString(&window_info_.window_name));

  // Create the new browser window.
  window_info_.window = CreateWindowEx(window_info_.ex_style,
      GetWndClass(), windowName.c_str(), window_info_.style,
      window_info_.x, window_info_.y, window_info_.width,
      window_info_.height, window_info_.parent_window, window_info_.menu,
      ::GetModuleHandle(NULL), NULL);

  // It's possible for CreateWindowEx to fail if the parent window was
  // destroyed between the call to CreateBrowser and the above one.
  DCHECK(window_info_.window != NULL);
  if (!window_info_.window)
    return false;

  if (window_info_.transparent_painting &&
      !(window_info_.style & WS_CHILD)) {
    // Transparent top-level windows will be given "sheet of glass" effect.
    SetAeroGlass(window_info_.window);
  }

  // Set window user data to this object for future reference from the window
  // procedure.
  ui::SetWindowUserData(window_info_.window, this);

  // Add a reference that will be released in the WM_DESTROY handler.
  AddRef();

  // Parent the TabContents to the browser window.
  SetParent(web_contents_->GetView()->GetNativeView(), window_info_.window);

  // Size the web view window to the browser window.
  RECT cr;
  GetClientRect(window_info_.window, &cr);

  // Respect the WS_VISIBLE window style when setting the window's position.
  UINT flags = SWP_NOZORDER | SWP_SHOWWINDOW;
  if (!(window_info_.style & WS_VISIBLE))
    flags |= SWP_NOACTIVATE;

  SetWindowPos(GetContentView(), NULL, cr.left, cr.top, cr.right,
                cr.bottom, flags);

  return true;
}

void CefBrowserHostImpl::PlatformCloseWindow() {
  if (window_info_.window != NULL)
    PostMessage(window_info_.window, WM_CLOSE, 0, 0);
}

void CefBrowserHostImpl::PlatformSizeTo(int width, int height) {
  RECT rect = {0, 0, width, height};
  DWORD style = GetWindowLong(window_info_.window, GWL_STYLE);
  DWORD ex_style = GetWindowLong(window_info_.window, GWL_EXSTYLE);
  bool has_menu = !(style & WS_CHILD) && (GetMenu(window_info_.window) != NULL);

  // The size value is for the client area. Calculate the whole window size
  // based on the current style.
  AdjustWindowRectEx(&rect, style, has_menu, ex_style);

  // Size the window.
  SetWindowPos(window_info_.window, NULL, 0, 0, rect.right,
               rect.bottom, SWP_NOZORDER | SWP_NOMOVE | SWP_NOACTIVATE);
}

CefWindowHandle CefBrowserHostImpl::PlatformGetWindowHandle() {
  return window_info_.window;
}

bool CefBrowserHostImpl::PlatformViewText(const std::string& text) {
  CEF_REQUIRE_UIT();

  DWORD dwRetVal;
  DWORD dwBufSize = 512;
  TCHAR lpPathBuffer[512];
  UINT uRetVal;
  TCHAR szTempName[512];

  dwRetVal = GetTempPath(dwBufSize,      // length of the buffer
                         lpPathBuffer);  // buffer for path
  if (dwRetVal > dwBufSize || (dwRetVal == 0))
    return false;

  // Create a temporary file.
  uRetVal = GetTempFileName(lpPathBuffer,  // directory for tmp files
                            TEXT("src"),   // temp file name prefix
                            0,             // create unique name
                            szTempName);   // buffer for name
  if (uRetVal == 0)
    return false;

  size_t len = wcslen(szTempName);
  wcscpy(szTempName + len - 3, L"txt");
  WriteTextToFile(text, szTempName);

  HWND frameWnd = GetAncestor(PlatformGetWindowHandle(), GA_ROOT);
  int errorCode = reinterpret_cast<int>(ShellExecute(frameWnd, L"open",
      szTempName, NULL, NULL, SW_SHOWNORMAL));
  if (errorCode <= 32)
    return false;

  return true;
}

void CefBrowserHostImpl::PlatformHandleKeyboardEvent(
    const content::NativeWebKeyboardEvent& event) {
  // Any unhandled keyboard/character messages are sent to DefWindowProc so that
  // shortcut keys work correctly.
  DefWindowProc(event.os_event.hwnd, event.os_event.message,
                event.os_event.wParam, event.os_event.lParam);
}

void CefBrowserHostImpl::PlatformRunFileChooser(
    content::WebContents* contents,
    const content::FileChooserParams& params,
    std::vector<FilePath>& files) {
  if (params.mode == content::FileChooserParams::OpenMultiple) {
    RunOpenMultiFileDialog(L"", PlatformGetWindowHandle(), &files);
  } else {
    FilePath file_name;
    if (RunOpenFileDialog(L"", PlatformGetWindowHandle(), &file_name))
      files.push_back(file_name);
  }
}

void CefBrowserHostImpl::PlatformHandleExternalProtocol(const GURL& url) {
  if (CEF_CURRENTLY_ON_FILET()) {
    if (!HasExternalHandler(url.scheme()))
      return;

    const std::string& address = url.spec();
    if (address.length() > kMaxAddressLengthChars)
      return;

    ShellExecuteA(NULL, "open", address.c_str(), NULL, NULL, SW_SHOWNORMAL);
  } else {
    // Execute on the FILE thread.
    CEF_POST_TASK(CEF_FILET,
        base::Bind(&CefBrowserHostImpl::PlatformHandleExternalProtocol, this,
                   url));
  }
}
