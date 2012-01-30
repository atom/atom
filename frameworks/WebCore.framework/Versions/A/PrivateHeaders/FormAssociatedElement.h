/*
 * Copyright (C) 1999 Lars Knoll (knoll@kde.org)
 *           (C) 1999 Antti Koivisto (koivisto@kde.org)
 *           (C) 2000 Dirk Mueller (mueller@kde.org)
 * Copyright (C) 2004, 2005, 2006, 2007, 2008, 2009, 2010 Apple Inc. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this library; see the file COPYING.LIB.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 *
 */

#ifndef FormAssociatedElement_h
#define FormAssociatedElement_h

#include "HTMLElement.h"

namespace WebCore {

class FormDataList;
class HTMLFormElement;
class ValidationMessage;
class ValidityState;
class VisibleSelection;

class FormAssociatedElement {
public:
    virtual ~FormAssociatedElement();

    void ref() { refFormAssociatedElement(); }
    void deref() { derefFormAssociatedElement(); }

    HTMLFormElement* form() const { return m_form; }
    ValidityState* validity();

    virtual bool isFormControlElement() const = 0;
    virtual bool isEnumeratable() const = 0;

    const AtomicString& name() const { return formControlName(); }

    // Override in derived classes to get the encoded name=value pair for submitting.
    // Return true for a successful control (see HTML4-17.13.2).
    virtual bool appendFormData(FormDataList&, bool) { return false; }

    void formWillBeDestroyed();

    void resetFormOwner();

protected:
    FormAssociatedElement();

    void insertedIntoTree();
    void removedFromTree();
    void insertedIntoDocument();
    void removedFromDocument();
    void didMoveToNewDocument(Document* oldDocument);

    void setForm(HTMLFormElement*);
    void formAttributeChanged();

    // If you add an override of willChangeForm() or didChangeForm() to a class
    // derived from this one, you will need to add a call to setForm(0) to the
    // destructor of that class.
    virtual void willChangeForm();
    virtual void didChangeForm();

private:
    virtual const AtomicString& formControlName() const = 0;

    virtual void refFormAssociatedElement() = 0;
    virtual void derefFormAssociatedElement() = 0;

    HTMLFormElement* m_form;
    OwnPtr<ValidityState> m_validityState;
};

HTMLElement* toHTMLElement(FormAssociatedElement*);
const HTMLElement* toHTMLElement(const FormAssociatedElement*);

} // namespace

#endif // FormAssociatedElement_h
