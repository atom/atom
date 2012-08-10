// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "libcef/browser/menu_creator.h"
#include "libcef/browser/browser_host_impl.h"
#include "libcef/browser/context_menu_params_impl.h"

#include "base/compiler_specific.h"
#include "base/logging.h"
#include "content/public/browser/render_view_host.h"
#include "content/public/browser/render_widget_host_view.h"
#include "content/public/common/content_client.h"
#include "grit/cef_strings.h"

#if defined(OS_WIN)
#include "libcef/browser/menu_creator_runner_win.h"
#elif defined(OS_MACOSX)
#include "libcef/browser/menu_creator_runner_mac.h"
#elif defined(TOOLKIT_GTK)
#include "libcef/browser/menu_creator_runner_gtk.h"
#endif

namespace {

CefString GetLabel(int message_id) {
  string16 label = content::GetContentClient()->GetLocalizedString(message_id);
  DCHECK(!label.empty());
  return label;
}

}  // namespace

CefMenuCreator::CefMenuCreator(CefBrowserHostImpl* browser)
  : browser_(browser) {
  model_ = new CefMenuModelImpl(this);
}

CefMenuCreator::~CefMenuCreator() {
  // The model may outlive the delegate if the context menu is visible when the
  // application is closed.
  model_->set_delegate(NULL);
}

bool CefMenuCreator::IsShowingContextMenu() {
  content::RenderWidgetHostView* view =
      browser_->GetWebContents()->GetRenderWidgetHostView();
  return (view && view->IsShowingContextMenu());
}

bool CefMenuCreator::CreateContextMenu(
    const content::ContextMenuParams& params) {
  if (!CreateRunner())
    return true;

  // The renderer may send the "show context menu" message multiple times, one
  // for each right click mouse event it receives. Normally, this doesn't happen
  // because mouse events are not forwarded once the context menu is showing.
  // However, there's a race - the context menu may not yet be showing when
  // the second mouse event arrives. In this case, |HandleContextMenu()| will
  // get called multiple times - if so, don't create another context menu.
  // TODO(asvitkine): Fix the renderer so that it doesn't do this.
  if (IsShowingContextMenu())
    return true;

  params_ = params;
  model_->Clear();

  // Create the default menu model.
  CreateDefaultModel();

  // Give the client a chance to modify the model.
  CefRefPtr<CefClient> client = browser_->GetClient();
  if (client.get()) {
      CefRefPtr<CefContextMenuHandler> handler =
          client->GetContextMenuHandler();
      if (handler.get()) {
        CefRefPtr<CefFrame> frame;
        if (params_.frame_id > 0)
          frame = browser_->GetFrame(params_.frame_id);
        if (!frame.get())
          frame = browser_->GetMainFrame();

        CefRefPtr<CefContextMenuParamsImpl> paramsPtr(
            new CefContextMenuParamsImpl(&params_));

        handler->OnBeforeContextMenu(browser_, frame, paramsPtr.get(),
                                     model_.get());

        // Do not keep references to the parameters in the callback.
        paramsPtr->Detach(NULL);
        DCHECK_EQ(paramsPtr->GetRefCt(), 1);
        DCHECK(model_->VerifyRefCount());

        // Menu is empty so notify the client and return.
        if (model_->GetCount() == 0) {
          MenuClosed(model_);
          return true;
        }
      }
  }

  return runner_->RunContextMenu(this);
}

bool CefMenuCreator::CreateRunner() {
  if (!runner_.get()) {
    // Create the menu runner.
#if defined(OS_WIN)
    runner_.reset(new CefMenuCreatorRunnerWin);
#elif defined(OS_MACOSX)
    runner_.reset(new CefMenuCreatorRunnerMac);
#elif defined(TOOLKIT_GTK)
    runner_.reset(new CefMenuCreatorRunnerGtk);
#else
    // Need an implementation.
    NOTREACHED();
#endif
  }
  return (runner_.get() != NULL);
}

void CefMenuCreator::ExecuteCommand(CefRefPtr<CefMenuModelImpl> source,
                                    int command_id,
                                    cef_event_flags_t event_flags) {
  // Give the client a chance to handle the command.
  CefRefPtr<CefClient> client = browser_->GetClient();
  if (client.get()) {
      CefRefPtr<CefContextMenuHandler> handler =
          client->GetContextMenuHandler();
      if (handler.get()) {
        CefRefPtr<CefFrame> frame;
        if (params_.frame_id > 0)
          frame = browser_->GetFrame(params_.frame_id);
        if (!frame.get())
          frame = browser_->GetMainFrame();

        CefRefPtr<CefContextMenuParamsImpl> paramsPtr(
            new CefContextMenuParamsImpl(&params_));

        bool handled = handler->OnContextMenuCommand(browser_, frame,
            paramsPtr.get(), command_id, event_flags);

        // Do not keep references to the parameters in the callback.
        paramsPtr->Detach(NULL);
        DCHECK_EQ(paramsPtr->GetRefCt(), 1);

        if (handled)
          return;
      }
  }

  // Execute the default command handling.
  ExecuteDefaultCommand(command_id);
}

void CefMenuCreator::MenuWillShow(CefRefPtr<CefMenuModelImpl> source) {
  // May be called for sub-menus as well.
  if (source.get() != model_.get())
    return;

  // Notify the host before showing the context menu.
  content::RenderWidgetHostView* view =
      browser_->GetWebContents()->GetRenderWidgetHostView();
  if (view)
    view->SetShowingContextMenu(true);
}

void CefMenuCreator::MenuClosed(CefRefPtr<CefMenuModelImpl> source) {
  // May be called for sub-menus as well.
  if (source.get() != model_.get())
    return;

  // Notify the client.
  CefRefPtr<CefClient> client = browser_->GetClient();
  if (client.get()) {
      CefRefPtr<CefContextMenuHandler> handler =
          client->GetContextMenuHandler();
      if (handler.get()) {
        CefRefPtr<CefFrame> frame;
        if (params_.frame_id > 0)
          frame = browser_->GetFrame(params_.frame_id);
        if (!frame.get())
          frame = browser_->GetMainFrame();

        handler->OnContextMenuDismissed(browser_, frame);
      }
  }

  if (IsShowingContextMenu()) {
    // Notify the host after closing the context menu.
    content::RenderWidgetHostView* view =
        browser_->GetWebContents()->GetRenderWidgetHostView();
    if (view)
      view->SetShowingContextMenu(false);
    content::RenderViewHost* rvh =
        browser_->GetWebContents()->GetRenderViewHost();
    if (rvh)
      rvh->NotifyContextMenuClosed(params_.custom_context);
  }
}

void CefMenuCreator::CreateDefaultModel() {
  if (params_.is_editable) {
    // Editable node.
    model_->AddItem(MENU_ID_UNDO, GetLabel(IDS_MENU_UNDO));
    model_->AddItem(MENU_ID_REDO, GetLabel(IDS_MENU_REDO));

    model_->AddSeparator();
    model_->AddItem(MENU_ID_CUT, GetLabel(IDS_MENU_CUT));
    model_->AddItem(MENU_ID_COPY, GetLabel(IDS_MENU_COPY));
    model_->AddItem(MENU_ID_PASTE, GetLabel(IDS_MENU_PASTE));
    model_->AddItem(MENU_ID_DELETE, GetLabel(IDS_MENU_DELETE));

    model_->AddSeparator();
    model_->AddItem(MENU_ID_SELECT_ALL, GetLabel(IDS_MENU_SELECT_ALL));

    if (!(params_.edit_flags & CM_EDITFLAG_CAN_UNDO))
      model_->SetEnabled(MENU_ID_UNDO, false);
    if (!(params_.edit_flags & CM_EDITFLAG_CAN_REDO))
      model_->SetEnabled(MENU_ID_REDO, false);
    if (!(params_.edit_flags & CM_EDITFLAG_CAN_CUT))
      model_->SetEnabled(MENU_ID_CUT, false);
    if (!(params_.edit_flags & CM_EDITFLAG_CAN_COPY))
      model_->SetEnabled(MENU_ID_COPY, false);
    if (!(params_.edit_flags & CM_EDITFLAG_CAN_PASTE))
      model_->SetEnabled(MENU_ID_PASTE, false);
    if (!(params_.edit_flags & CM_EDITFLAG_CAN_DELETE))
      model_->SetEnabled(MENU_ID_DELETE, false);
    if (!(params_.edit_flags & CM_EDITFLAG_CAN_SELECT_ALL))
      model_->SetEnabled(MENU_ID_SELECT_ALL, false);
  } else if (!params_.selection_text.empty()) {
    // Something is selected.
    model_->AddItem(MENU_ID_COPY, GetLabel(IDS_MENU_COPY));
  } else if (!params_.page_url.is_empty() || !params_.frame_url.is_empty()) {
    // Page or frame.
    model_->AddItem(MENU_ID_BACK, GetLabel(IDS_MENU_BACK));
    model_->AddItem(MENU_ID_FORWARD, GetLabel(IDS_MENU_FORWARD));

    model_->AddSeparator();
    model_->AddItem(MENU_ID_PRINT, GetLabel(IDS_MENU_PRINT));
    model_->AddItem(MENU_ID_VIEW_SOURCE, GetLabel(IDS_MENU_VIEW_SOURCE));

    if (!browser_->CanGoBack())
      model_->SetEnabled(MENU_ID_BACK, false);
    if (!browser_->CanGoForward())
      model_->SetEnabled(MENU_ID_FORWARD, false);

    // TODO(cef): Enable once printing is supported.
    model_->SetEnabled(MENU_ID_PRINT, false);
  }
}

void CefMenuCreator::ExecuteDefaultCommand(int command_id) {
  switch (command_id) {
  // Navigation.
  case MENU_ID_BACK:
    browser_->GoBack();
    break;
  case MENU_ID_FORWARD:
    browser_->GoForward();
    break;
  case MENU_ID_RELOAD:
    browser_->Reload();
    break;
  case MENU_ID_RELOAD_NOCACHE:
    browser_->ReloadIgnoreCache();
    break;
  case MENU_ID_STOPLOAD:
    browser_->StopLoad();
    break;

  // Editing.
  case MENU_ID_UNDO:
    browser_->GetFocusedFrame()->Undo();
    break;
  case MENU_ID_REDO:
    browser_->GetFocusedFrame()->Redo();
    break;
  case MENU_ID_CUT:
    browser_->GetFocusedFrame()->Cut();
    break;
  case MENU_ID_COPY:
    browser_->GetFocusedFrame()->Copy();
    break;
  case MENU_ID_PASTE:
    browser_->GetFocusedFrame()->Paste();
    break;
  case MENU_ID_DELETE:
    browser_->GetFocusedFrame()->Delete();
    break;
  case MENU_ID_SELECT_ALL:
    browser_->GetFocusedFrame()->SelectAll();
    break;

  // Miscellaneous.
  case MENU_ID_FIND:
    // TODO(cef): Implement.
    NOTIMPLEMENTED();
    break;
  case MENU_ID_PRINT:
    // TODO(cef): Implement.
    NOTIMPLEMENTED();
    break;
  case MENU_ID_VIEW_SOURCE:
    browser_->GetFocusedFrame()->ViewSource();
    break;

  default:
    break;
  }
}
