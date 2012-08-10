// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "libcef/common/process_message_impl.h"
#include "libcef/common/cef_messages.h"
#include "libcef/common/values_impl.h"

#include "base/logging.h"

namespace {

void CopyList(const base::ListValue& source,
              base::ListValue& target) {
  base::ListValue::const_iterator it = source.begin();
  for (; it != source.end(); ++it)
    target.Append((*it)->DeepCopy());
}

void CopyValue(const Cef_Request_Params& source,
               Cef_Request_Params& target) {
  target.name = source.name;
  CopyList(source.arguments, target.arguments);
}

}  // namespace

// static
CefRefPtr<CefProcessMessage> CefProcessMessage::Create(const CefString& name) {
  Cef_Request_Params* params = new Cef_Request_Params();
  params->name = name;
  return new CefProcessMessageImpl(params, true, false);
}

CefProcessMessageImpl::CefProcessMessageImpl(Cef_Request_Params* value,
                                             bool will_delete,
                                             bool read_only)
  : CefValueBase<CefProcessMessage, Cef_Request_Params>(
        value, NULL, will_delete ? kOwnerWillDelete : kOwnerNoDelete,
        read_only, NULL) {
}

bool CefProcessMessageImpl::CopyTo(Cef_Request_Params& target) {
  CEF_VALUE_VERIFY_RETURN(false, false);
  CopyValue(const_value(), target);
  return true;
}

bool CefProcessMessageImpl::IsValid() {
  return !detached();
}

bool CefProcessMessageImpl::IsReadOnly() {
  return read_only();
}

CefRefPtr<CefProcessMessage> CefProcessMessageImpl::Copy() {
  CEF_VALUE_VERIFY_RETURN(false, NULL);
  Cef_Request_Params* params = new Cef_Request_Params();
  CopyValue(const_value(), *params);
  return new CefProcessMessageImpl(params, true, false);
}

CefString CefProcessMessageImpl::GetName() {
  CEF_VALUE_VERIFY_RETURN(false, CefString());
  return const_value().name;
}

CefRefPtr<CefListValue> CefProcessMessageImpl::GetArgumentList() {
  CEF_VALUE_VERIFY_RETURN(false, NULL);
  return CefListValueImpl::GetOrCreateRef(
        const_cast<base::ListValue*>(&(const_value().arguments)),
        const_cast<Cef_Request_Params*>(&const_value()),
        read_only(),
        controller());
}
