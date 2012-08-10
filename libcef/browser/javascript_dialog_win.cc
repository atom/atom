// Copyright (c) 2012 The Chromium Embedded Framework Authors.
// Portions copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "libcef/browser/javascript_dialog.h"
#include "libcef/browser/javascript_dialog_creator.h"
#include "libcef/browser/browser_host_impl.h"
#include "libcef_dll/resource.h"

#include "base/file_path.h"
#include "base/path_service.h"
#include "base/string_util.h"
#include "base/utf_string_conversions.h"

class CefJavaScriptDialog;

HHOOK CefJavaScriptDialog::msg_hook_ = NULL;
int CefJavaScriptDialog::msg_hook_user_count_ = 0;

INT_PTR CALLBACK CefJavaScriptDialog::DialogProc(HWND dialog,
                                                 UINT message,
                                                 WPARAM wparam,
                                                 LPARAM lparam) {
  switch (message) {
    case WM_INITDIALOG: {
      SetWindowLongPtr(dialog, DWL_USER, static_cast<LONG_PTR>(lparam));
      CefJavaScriptDialog* owner =
          reinterpret_cast<CefJavaScriptDialog*>(lparam);
      owner->dialog_win_ = dialog;
      SetDlgItemText(dialog, IDC_DIALOGTEXT, owner->message_text_.c_str());
      if (owner->message_type_ == content::JAVASCRIPT_MESSAGE_TYPE_PROMPT)
        SetDlgItemText(dialog, IDC_PROMPTEDIT,
                       owner->default_prompt_text_.c_str());
      break;
    }
    case WM_CLOSE: {
      CefJavaScriptDialog* owner = reinterpret_cast<CefJavaScriptDialog*>(
          GetWindowLongPtr(dialog, DWL_USER));
      if (owner) {
        owner->Cancel();
        owner->callback_.Run(false, string16());
        owner->creator_->DialogClosed(owner);

        // No need for the system to call DestroyWindow() because it will be
        // called by the Cancel() method.
        return 0;
      }
      break;
    }
    case WM_COMMAND: {
      CefJavaScriptDialog* owner = reinterpret_cast<CefJavaScriptDialog*>(
          GetWindowLongPtr(dialog, DWL_USER));
      string16 user_input;
      bool finish = false;
      bool result;
      switch (LOWORD(wparam)) {
        case IDOK:
          finish = true;
          result = true;
          if (owner->message_type_ == content::JAVASCRIPT_MESSAGE_TYPE_PROMPT) {
            size_t length =
                GetWindowTextLength(GetDlgItem(dialog, IDC_PROMPTEDIT)) + 1;
            GetDlgItemText(dialog, IDC_PROMPTEDIT,
                           WriteInto(&user_input, length), length);
          }
          break;
        case IDCANCEL:
          finish = true;
          result = false;
          break;
      }
      if (finish) {
        owner->Cancel();
        owner->callback_.Run(result, user_input);
        owner->creator_->DialogClosed(owner);
      }
      break;
    }
    default:
      return DefWindowProc(dialog, message, wparam, lparam);
  }
  return 0;
}

CefJavaScriptDialog::CefJavaScriptDialog(
    CefJavaScriptDialogCreator* creator,
    content::JavaScriptMessageType message_type,
    const string16& display_url,
    const string16& message_text,
    const string16& default_prompt_text,
    const content::JavaScriptDialogCreator::DialogClosedCallback& callback)
    : creator_(creator),
      callback_(callback),
      message_text_(message_text),
      default_prompt_text_(default_prompt_text),
      message_type_(message_type) {
  InstallMessageHook();

  int dialog_type;
  if (message_type == content::JAVASCRIPT_MESSAGE_TYPE_ALERT)
    dialog_type = IDD_ALERT;
  else if (message_type == content::JAVASCRIPT_MESSAGE_TYPE_CONFIRM)
    dialog_type = IDD_CONFIRM;
  else  // JAVASCRIPT_MESSAGE_TYPE_PROMPT
    dialog_type = IDD_PROMPT;

  FilePath file_path;
  HMODULE hModule = NULL;

  // Try to load the dialog from the DLL.
  if (PathService::Get(base::FILE_MODULE, &file_path))
    hModule = ::GetModuleHandle(file_path.value().c_str());
  if (!hModule)
    hModule = ::GetModuleHandle(NULL);
  DCHECK(hModule);

  parent_win_ = GetAncestor(creator->browser()->GetWindowHandle(), GA_ROOT);
  dialog_win_ = CreateDialogParam(hModule,
                                  MAKEINTRESOURCE(dialog_type),
                                  parent_win_,
                                  DialogProc,
                                  reinterpret_cast<LPARAM>(this));
  DCHECK(dialog_win_);

  if (!display_url.empty()) {
    // Add the display URL to the window title.
    TCHAR text[64];
    GetWindowText(dialog_win_, text, sizeof(text)/sizeof(TCHAR));

    string16 new_window_text = text + ASCIIToUTF16(" - ") + display_url;
    SetWindowText(dialog_win_, new_window_text.c_str());
  }

  // Disable the parent window so the user can't interact with it.
  if (IsWindowEnabled(parent_win_))
    EnableWindow(parent_win_, FALSE);

  ShowWindow(dialog_win_, SW_SHOWNORMAL);
}

CefJavaScriptDialog::~CefJavaScriptDialog() {
  Cancel();
  UninstallMessageHook();
}

void CefJavaScriptDialog::Cancel() {
  HWND parent = NULL;

  // Re-enable the parent before closing the popup to avoid focus/activation/
  // z-order issues.
  if (parent_win_ && IsWindow(parent_win_) && !IsWindowEnabled(parent_win_)) {
    parent = parent_win_;
    EnableWindow(parent_win_, TRUE);
    parent_win_ = NULL;
  }

  if (dialog_win_ && IsWindow(dialog_win_)) {
    SetWindowLongPtr(dialog_win_, DWL_USER, NULL);
    DestroyWindow(dialog_win_);
    dialog_win_ = NULL;
  }

  // Return focus to the parent window.
  if (parent)
    SetFocus(parent);
}

// static
LRESULT CALLBACK CefJavaScriptDialog::GetMsgProc(int code, WPARAM wparam,
                                                 LPARAM lparam) {
  // Mostly borrowed from http://support.microsoft.com/kb/q187988/
  // and http://www.codeproject.com/KB/atl/cdialogmessagehook.aspx.
  LPMSG msg = reinterpret_cast<LPMSG>(lparam);
  if (code >= 0 && wparam == PM_REMOVE &&
      msg->message >= WM_KEYFIRST && msg->message <= WM_KEYLAST) {
    HWND hwnd = GetActiveWindow();
    if (::IsWindow(hwnd) && ::IsDialogMessage(hwnd, msg)) {
      // The value returned from this hookproc is ignored, and it cannot
      // be used to tell Windows the message has been handled. To avoid
      // further processing, convert the message to WM_NULL before
      // returning.
      msg->hwnd = NULL;
      msg->message = WM_NULL;
      msg->lParam = 0L;
      msg->wParam = 0;
    }
  }

  // Passes the hook information to the next hook procedure in
  // the current hook chain.
  return ::CallNextHookEx(msg_hook_, code, wparam, lparam);
}

// static
bool CefJavaScriptDialog::InstallMessageHook() {
  msg_hook_user_count_++;

  // Make sure we only call this once.
  if (msg_hook_ != NULL)
    return true;

  msg_hook_ = ::SetWindowsHookEx(WH_GETMESSAGE,
                                 &CefJavaScriptDialog::GetMsgProc,
                                 NULL,
                                 GetCurrentThreadId());
  DCHECK(msg_hook_ != NULL);
  return msg_hook_ != NULL;
}

// static
bool CefJavaScriptDialog::UninstallMessageHook() {
  msg_hook_user_count_--;
  DCHECK_GE(msg_hook_user_count_, 0);

  if (msg_hook_user_count_ > 0)
    return true;

  DCHECK(msg_hook_ != NULL);
  BOOL result = ::UnhookWindowsHookEx(msg_hook_);
  DCHECK(result);
  msg_hook_ = NULL;

  return result != FALSE;
}
