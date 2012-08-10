// Copyright (c) 2012 The Chromium Embedded Framework Authors.
// Portions copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_JAVASCRIPT_DIALOG_CREATOR_H_
#define CEF_LIBCEF_BROWSER_JAVASCRIPT_DIALOG_CREATOR_H_
#pragma once

#include <string>

#include "base/compiler_specific.h"
#include "base/memory/scoped_ptr.h"
#include "content/public/browser/javascript_dialogs.h"

class CefBrowserHostImpl;
class CefJavaScriptDialog;

class CefJavaScriptDialogCreator : public content::JavaScriptDialogCreator {
 public:
  explicit CefJavaScriptDialogCreator(CefBrowserHostImpl* browser);
  virtual ~CefJavaScriptDialogCreator();

  // JavaScriptDialogCreator methods.
  virtual void RunJavaScriptDialog(
      content::WebContents* web_contents,
      const GURL& origin_url,
      const std::string& accept_lang,
      content::JavaScriptMessageType message_type,
      const string16& message_text,
      const string16& default_prompt_text,
      const DialogClosedCallback& callback,
      bool* did_suppress_message) OVERRIDE;

  virtual void RunBeforeUnloadDialog(
      content::WebContents* web_contents,
      const string16& message_text,
      bool is_reload,
      const DialogClosedCallback& callback) OVERRIDE;

  virtual void ResetJavaScriptState(
      content::WebContents* web_contents) OVERRIDE;

  // Called by the CefJavaScriptDialog when it closes.
  void DialogClosed(CefJavaScriptDialog* dialog);

  CefBrowserHostImpl* browser() const { return browser_; }

 private:
  // This pointer is guaranteed to outlive the CefJavaScriptDialogCreator.
  CefBrowserHostImpl* browser_;

#if defined(OS_MACOSX) || defined(OS_WIN)
  // The dialog being shown. No queueing.
  scoped_ptr<CefJavaScriptDialog> dialog_;
#endif

  DISALLOW_COPY_AND_ASSIGN(CefJavaScriptDialogCreator);
};

#endif  // CEF_LIBCEF_BROWSER_JAVASCRIPT_DIALOG_CREATOR_H_
