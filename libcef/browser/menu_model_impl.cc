// Copyright (c) 2012 The Chromium Embedded Framework Authors.
// Portions copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "libcef/browser/menu_model_impl.h"

#include <vector>

#include "base/bind.h"
#include "base/logging.h"
#include "base/message_loop.h"
#include "ui/base/accelerators/accelerator.h"

namespace {

const int kSeparatorId = -1;

// A simple MenuModel implementation that delegates to CefMenuModelImpl.
class CefSimpleMenuModel : public ui::MenuModel {
 public:
  // The Delegate can be NULL, though if it is items can't be checked or
  // disabled.
  explicit CefSimpleMenuModel(CefMenuModelImpl* impl)
      : impl_(impl),
        menu_model_delegate_(NULL) {
  }

  virtual ~CefSimpleMenuModel() {
  }

  // MenuModel methods.
  virtual bool HasIcons() const OVERRIDE {
    return false;
  }

  virtual int GetItemCount() const OVERRIDE {
    return impl_->GetCount();
  }

  virtual ItemType GetTypeAt(int index) const OVERRIDE {
    switch (impl_->GetTypeAt(index)) {
    case MENUITEMTYPE_COMMAND:
      return TYPE_COMMAND;
    case MENUITEMTYPE_CHECK:
      return TYPE_CHECK;
    case MENUITEMTYPE_RADIO:
      return TYPE_RADIO;
    case MENUITEMTYPE_SEPARATOR:
      return TYPE_SEPARATOR;
    case MENUITEMTYPE_SUBMENU:
      return TYPE_SUBMENU;
    default:
      NOTREACHED();
      return TYPE_COMMAND;
    }
  }

  virtual int GetCommandIdAt(int index) const OVERRIDE {
    return impl_->GetCommandIdAt(index);
  }

  virtual string16 GetLabelAt(int index) const OVERRIDE {
    return impl_->GetLabelAt(index).ToString16();
  }

  virtual bool IsItemDynamicAt(int index) const OVERRIDE {
    return false;
  }

  virtual bool GetAcceleratorAt(int index,
                                ui::Accelerator* accelerator) const OVERRIDE {
    int key_code = 0;
    bool shift_pressed = false;
    bool ctrl_pressed = false;
    bool alt_pressed = false;
    if (impl_->GetAcceleratorAt(index, key_code, shift_pressed, ctrl_pressed,
                                alt_pressed)) {
      int modifiers = 0;
      if (shift_pressed)
        modifiers |= ui::EF_SHIFT_DOWN;
      if (ctrl_pressed)
        modifiers |= ui::EF_CONTROL_DOWN;
      if (alt_pressed)
        modifiers |= ui::EF_ALT_DOWN;

      *accelerator = ui::Accelerator(static_cast<ui::KeyboardCode>(key_code),
                                     modifiers);
      return true;
    }
    return false;
  }

  virtual bool IsItemCheckedAt(int index) const OVERRIDE {
    return impl_->IsCheckedAt(index);
  }

  virtual int GetGroupIdAt(int index) const OVERRIDE {
    return impl_->GetGroupIdAt(index);
  }

  virtual bool GetIconAt(int index, gfx::ImageSkia* icon) OVERRIDE {
    return false;
  }

  virtual ui::ButtonMenuItemModel* GetButtonMenuItemAt(
      int index) const OVERRIDE {
    return NULL;
  }

  virtual bool IsEnabledAt(int index) const OVERRIDE {
    return impl_->IsEnabledAt(index);
  }

  virtual bool IsVisibleAt(int index) const OVERRIDE {
    return impl_->IsVisibleAt(index);
  }

  virtual void HighlightChangedTo(int index) OVERRIDE {
  }

  virtual void ActivatedAt(int index) OVERRIDE {
    ActivatedAt(index, 0);
  }

  virtual void ActivatedAt(int index, int event_flags) OVERRIDE {
    impl_->ActivatedAt(index, static_cast<cef_event_flags_t>(event_flags));
  }

  virtual MenuModel* GetSubmenuModelAt(int index) const OVERRIDE {
    CefRefPtr<CefMenuModel> submenu = impl_->GetSubMenuAt(index);
    if (submenu.get())
      return static_cast<CefMenuModelImpl*>(submenu.get())->model();
    return NULL;
  }

  virtual void MenuWillShow() OVERRIDE {
    impl_->MenuWillShow();
  }

  virtual void MenuClosed() OVERRIDE {
    impl_->MenuClosed();
  }

  virtual void SetMenuModelDelegate(
      ui::MenuModelDelegate* menu_model_delegate) OVERRIDE {
    menu_model_delegate_ = menu_model_delegate;
  }

 private:
  CefMenuModelImpl* impl_;
  ui::MenuModelDelegate* menu_model_delegate_;

  DISALLOW_COPY_AND_ASSIGN(CefSimpleMenuModel);
};

}  // namespace


struct CefMenuModelImpl::Item {
  Item(cef_menu_item_type_t type,
       int command_id,
       const CefString& label,
       int group_id)
      : type_(type),
        command_id_(command_id),
        label_(label),
        group_id_(group_id),
        enabled_(true),
        visible_(true),
        checked_(false),
        has_accelerator_(false),
        key_code_(0),
        shift_pressed_(false),
        ctrl_pressed_(false),
        alt_pressed_(false) {
  }

  // Basic information.
  cef_menu_item_type_t type_;
  int command_id_;
  CefString label_;
  int group_id_;
  CefRefPtr<CefMenuModelImpl> submenu_;

  // State information.
  bool enabled_;
  bool visible_;
  bool checked_;

  // Accelerator information.
  bool has_accelerator_;
  int key_code_;
  bool shift_pressed_;
  bool ctrl_pressed_;
  bool alt_pressed_;
};


CefMenuModelImpl::CefMenuModelImpl(Delegate* delegate)
    : supported_thread_id_(base::PlatformThread::CurrentId()),
      delegate_(delegate) {
  model_.reset(new CefSimpleMenuModel(this));
}

CefMenuModelImpl::~CefMenuModelImpl() {
}

bool CefMenuModelImpl::Clear() {
  if (!VerifyContext())
    return false;

  items_.clear();
  return true;
}

int CefMenuModelImpl::GetCount() {
  if (!VerifyContext())
    return 0;

  return static_cast<int>(items_.size());
}

bool CefMenuModelImpl::AddSeparator() {
  if (!VerifyContext())
    return false;

  AppendItem(Item(MENUITEMTYPE_SEPARATOR, kSeparatorId, CefString(), -1));
  return true;
}

bool CefMenuModelImpl::AddItem(int command_id, const CefString& label) {
  if (!VerifyContext())
    return false;

  AppendItem(Item(MENUITEMTYPE_COMMAND, command_id, label, -1));
  return true;
}

bool CefMenuModelImpl::AddCheckItem(int command_id, const CefString& label) {
  if (!VerifyContext())
    return false;

  AppendItem(Item(MENUITEMTYPE_CHECK, command_id, label, -1));
  return true;
}

bool CefMenuModelImpl::AddRadioItem(int command_id, const CefString& label,
                                    int group_id) {
  if (!VerifyContext())
    return false;

  AppendItem(Item(MENUITEMTYPE_RADIO, command_id, label, group_id));
  return true;
}

CefRefPtr<CefMenuModel> CefMenuModelImpl::AddSubMenu(int command_id,
                                                     const CefString& label) {
  if (!VerifyContext())
    return NULL;

  Item item(MENUITEMTYPE_SUBMENU, command_id, label, -1);
  item.submenu_ = new CefMenuModelImpl(delegate_);
  AppendItem(item);
  return item.submenu_.get();
}

bool CefMenuModelImpl::InsertSeparatorAt(int index) {
  if (!VerifyContext())
    return false;

  InsertItemAt(Item(MENUITEMTYPE_SEPARATOR, kSeparatorId, CefString(), -1),
               index);
  return true;
}

bool CefMenuModelImpl::InsertItemAt(int index, int command_id,
                                    const CefString& label) {
  if (!VerifyContext())
    return false;

  InsertItemAt(Item(MENUITEMTYPE_COMMAND, command_id, label, -1), index);
  return true;
}

bool CefMenuModelImpl::InsertCheckItemAt(int index, int command_id,
    const CefString& label) {
  if (!VerifyContext())
    return false;

  InsertItemAt(Item(MENUITEMTYPE_CHECK, command_id, label, -1), index);
  return true;
}

bool CefMenuModelImpl::InsertRadioItemAt(int index, int command_id,
                                         const CefString& label, int group_id) {
  if (!VerifyContext())
    return false;

  InsertItemAt(Item(MENUITEMTYPE_RADIO, command_id, label, -1), index);
  return true;
}

CefRefPtr<CefMenuModel> CefMenuModelImpl::InsertSubMenuAt(
    int index, int command_id, const CefString& label) {
  if (!VerifyContext())
    return NULL;

  Item item(MENUITEMTYPE_SUBMENU, command_id, label, -1);
  item.submenu_ = new CefMenuModelImpl(delegate_);
  InsertItemAt(item, index);
  return item.submenu_.get();
}

bool CefMenuModelImpl::Remove(int command_id) {
  return RemoveAt(GetIndexOf(command_id));
}

bool CefMenuModelImpl::RemoveAt(int index) {
  if (!VerifyContext())
    return false;

  if (index >= 0 && index < static_cast<int>(items_.size())) {
    items_.erase(items_.begin()+index);
    return true;
  }
  return false;
}

int CefMenuModelImpl::GetIndexOf(int command_id) {
  if (!VerifyContext())
    return -1;

  for (ItemVector::iterator i = items_.begin(); i != items_.end(); ++i) {
    if ((*i).command_id_ == command_id) {
      return static_cast<int>(std::distance(items_.begin(), i));
    }
  }
  return -1;
}

int CefMenuModelImpl::GetCommandIdAt(int index) {
  if (!VerifyContext())
    return -1;

  if (index >= 0 && index < static_cast<int>(items_.size()))
    return items_[index].command_id_;
  return -1;
}

bool CefMenuModelImpl::SetCommandIdAt(int index, int command_id) {
  if (!VerifyContext())
    return false;

  if (index >= 0 && index < static_cast<int>(items_.size())) {
    items_[index].command_id_ = command_id;
    return true;
  }
  return false;
}

CefString CefMenuModelImpl::GetLabel(int command_id) {
  return GetLabelAt(GetIndexOf(command_id));
}

CefString CefMenuModelImpl::GetLabelAt(int index) {
  if (!VerifyContext())
    return CefString();

  if (index >= 0 && index < static_cast<int>(items_.size()))
    return items_[index].label_;
  return CefString();
}

bool CefMenuModelImpl::SetLabel(int command_id, const CefString& label) {
  return SetLabelAt(GetIndexOf(command_id), label);
}

bool CefMenuModelImpl::SetLabelAt(int index, const CefString& label) {
  if (!VerifyContext())
    return false;

  if (index >= 0 && index < static_cast<int>(items_.size())) {
    items_[index].label_ = label;
    return true;
  }
  return false;
}

CefMenuModelImpl::MenuItemType CefMenuModelImpl::GetType(int command_id) {
  return GetTypeAt(GetIndexOf(command_id));
}

CefMenuModelImpl::MenuItemType CefMenuModelImpl::GetTypeAt(int index) {
  if (!VerifyContext())
    return MENUITEMTYPE_NONE;

  if (index >= 0 && index < static_cast<int>(items_.size()))
    return items_[index].type_;
  return MENUITEMTYPE_NONE;
}

int CefMenuModelImpl::GetGroupId(int command_id) {
  return GetGroupIdAt(GetIndexOf(command_id));
}

int CefMenuModelImpl::GetGroupIdAt(int index) {
  if (!VerifyContext())
    return -1;

  if (index >= 0 && index < static_cast<int>(items_.size()))
    return items_[index].group_id_;
  return -1;
}

bool CefMenuModelImpl::SetGroupId(int command_id, int group_id) {
  return SetGroupIdAt(GetIndexOf(command_id), group_id);
}

bool CefMenuModelImpl::SetGroupIdAt(int index, int group_id) {
  if (!VerifyContext())
    return false;

  if (index >= 0 && index < static_cast<int>(items_.size())) {
    items_[index].group_id_ = group_id;
    return true;
  }
  return false;
}

CefRefPtr<CefMenuModel> CefMenuModelImpl::GetSubMenu(int command_id) {
  return GetSubMenuAt(GetIndexOf(command_id));
}

CefRefPtr<CefMenuModel> CefMenuModelImpl::GetSubMenuAt(int index) {
  if (!VerifyContext())
    return NULL;

  if (index >= 0 && index < static_cast<int>(items_.size()))
    return items_[index].submenu_.get();
  return NULL;
}

bool CefMenuModelImpl::IsVisible(int command_id) {
  return IsVisibleAt(GetIndexOf(command_id));
}

bool CefMenuModelImpl::IsVisibleAt(int index) {
  if (!VerifyContext())
    return false;

  if (index >= 0 && index < static_cast<int>(items_.size()))
    return items_[index].visible_;
  return false;
}

bool CefMenuModelImpl::SetVisible(int command_id, bool visible) {
  return SetVisibleAt(GetIndexOf(command_id), visible);
}

bool CefMenuModelImpl::SetVisibleAt(int index, bool visible) {
  if (!VerifyContext())
    return false;

  if (index >= 0 && index < static_cast<int>(items_.size())) {
    items_[index].visible_ = visible;
    return true;
  }
  return false;
}

bool CefMenuModelImpl::IsEnabled(int command_id) {
  return IsEnabledAt(GetIndexOf(command_id));
}

bool CefMenuModelImpl::IsEnabledAt(int index) {
  if (!VerifyContext())
    return false;

  if (index >= 0 && index < static_cast<int>(items_.size()))
    return items_[index].enabled_;
  return false;
}

bool CefMenuModelImpl::SetEnabled(int command_id, bool enabled) {
  return SetEnabledAt(GetIndexOf(command_id), enabled);
}

bool CefMenuModelImpl::SetEnabledAt(int index, bool enabled) {
  if (!VerifyContext())
    return false;

  if (index >= 0 && index < static_cast<int>(items_.size())) {
    items_[index].enabled_ = enabled;
    return true;
  }
  return false;
}

bool CefMenuModelImpl::IsChecked(int command_id) {
  return IsCheckedAt(GetIndexOf(command_id));
}

bool CefMenuModelImpl::IsCheckedAt(int index) {
  if (!VerifyContext())
    return false;

  if (index >= 0 && index < static_cast<int>(items_.size()))
    return items_[index].checked_;
  return false;
}

bool CefMenuModelImpl::SetChecked(int command_id, bool checked) {
  return SetCheckedAt(GetIndexOf(command_id), checked);
}

bool CefMenuModelImpl::SetCheckedAt(int index, bool checked) {
  if (!VerifyContext())
    return false;

  if (index >= 0 && index < static_cast<int>(items_.size())) {
    items_[index].checked_ = checked;
    return true;
  }
  return false;
}

bool CefMenuModelImpl::HasAccelerator(int command_id) {
  return HasAcceleratorAt(GetIndexOf(command_id));
}

bool CefMenuModelImpl::HasAcceleratorAt(int index) {
  if (!VerifyContext())
    return false;

  if (index >= 0 && index < static_cast<int>(items_.size()))
    return items_[index].has_accelerator_;
  return false;
}

bool CefMenuModelImpl::SetAccelerator(int command_id, int key_code,
                                      bool shift_pressed, bool ctrl_pressed,
                                      bool alt_pressed) {
  return SetAcceleratorAt(GetIndexOf(command_id), key_code, shift_pressed,
                          ctrl_pressed, alt_pressed);
}

bool CefMenuModelImpl::SetAcceleratorAt(int index, int key_code,
                                        bool shift_pressed, bool ctrl_pressed,
                                        bool alt_pressed) {
  if (!VerifyContext())
    return false;

  if (index >= 0 && index < static_cast<int>(items_.size())) {
    Item& item = items_[index];
    item.has_accelerator_ = true;
    item.key_code_ = key_code;
    item.shift_pressed_ = shift_pressed;
    item.ctrl_pressed_ = ctrl_pressed;
    item.alt_pressed_ = alt_pressed;
    return true;
  }
  return false;
}

bool CefMenuModelImpl::RemoveAccelerator(int command_id) {
  return RemoveAcceleratorAt(GetIndexOf(command_id));
}

bool CefMenuModelImpl::RemoveAcceleratorAt(int index) {
  if (!VerifyContext())
    return false;

  if (index >= 0 && index < static_cast<int>(items_.size())) {
    Item& item = items_[index];
    if (item.has_accelerator_) {
      item.has_accelerator_ = false;
      item.key_code_ = 0;
      item.shift_pressed_ = false;
      item.ctrl_pressed_ = false;
      item.alt_pressed_ = false;
    }
    return true;
  }
  return false;
}

bool CefMenuModelImpl::GetAccelerator(int command_id, int& key_code,
                                      bool& shift_pressed, bool& ctrl_pressed,
                                      bool& alt_pressed) {
  return GetAcceleratorAt(GetIndexOf(command_id), key_code, shift_pressed,
                          ctrl_pressed, alt_pressed);
}

bool CefMenuModelImpl::GetAcceleratorAt(int index, int& key_code,
                                        bool& shift_pressed, bool& ctrl_pressed,
                                        bool& alt_pressed) {
  if (!VerifyContext())
    return false;

  if (index >= 0 && index < static_cast<int>(items_.size())) {
    const Item& item = items_[index];
    if (item.has_accelerator_) {
      key_code = item.key_code_;
      shift_pressed = item.shift_pressed_;
      ctrl_pressed = item.ctrl_pressed_;
      alt_pressed = item.alt_pressed_;
      return true;
    }
  }
  return false;
}

void CefMenuModelImpl::ActivatedAt(int index, cef_event_flags_t event_flags) {
  if (VerifyContext() && delegate_)
    delegate_->ExecuteCommand(this, GetCommandIdAt(index), event_flags);
}

void CefMenuModelImpl::MenuWillShow() {
  if (VerifyContext() && delegate_)
    delegate_->MenuWillShow(this);
}

void CefMenuModelImpl::MenuClosed() {
  if (!VerifyContext())
    return;

  // Due to how menus work on the different platforms, ActivatedAt will be
  // called after this.  It's more convenient for the delegate to be called
  // afterwards, though, so post a task.
  MessageLoop::current()->PostTask(
      FROM_HERE,
      base::Bind(&CefMenuModelImpl::OnMenuClosed, this));
}

bool CefMenuModelImpl::VerifyRefCount() {
  if (!VerifyContext())
    return false;

  if (GetRefCt() != 1)
    return false;

  for (ItemVector::iterator i = items_.begin(); i != items_.end(); ++i) {
    if ((*i).submenu_.get()) {
      if (!(*i).submenu_->VerifyRefCount())
        return false;
    }
  }

  return true;
}

void CefMenuModelImpl::AppendItem(const Item& item) {
  ValidateItem(item);
  items_.push_back(item);
}

void CefMenuModelImpl::InsertItemAt(const Item& item, int index) {
  // Sanitize the index.
  if (index < 0)
    index = 0;
  else if (index > static_cast<int>(items_.size()))
    index = items_.size();

  ValidateItem(item);
  items_.insert(items_.begin() + index, item);
}

void CefMenuModelImpl::ValidateItem(const Item& item) {
#ifndef NDEBUG
  if (item.type_ == MENUITEMTYPE_SEPARATOR) {
    DCHECK_EQ(item.command_id_, kSeparatorId);
  } else {
    DCHECK_GE(item.command_id_, 0);
  }
#endif  // NDEBUG
}

void CefMenuModelImpl::OnMenuClosed() {
  if (delegate_)
    delegate_->MenuClosed(this);
}

bool CefMenuModelImpl::VerifyContext() {
  if (base::PlatformThread::CurrentId() != supported_thread_id_) {
    // This object should only be accessed from the thread that created it.
    NOTREACHED();
    return false;
  }

  return true;
}
