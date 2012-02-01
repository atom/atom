/*
 * Copyright (C) 1999 Lars Knoll (knoll@kde.org)
 *           (C) 1999 Antti Koivisto (koivisto@kde.org)
 *           (C) 2000 Dirk Mueller (mueller@kde.org)
 * Copyright (C) 2004, 2005, 2006, 2007, 2010 Apple Inc. All rights reserved.
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

#ifndef HTMLTextAreaElement_h
#define HTMLTextAreaElement_h

#include "HTMLTextFormControlElement.h"

namespace WebCore {

class BeforeTextInsertedEvent;
class VisibleSelection;

class HTMLTextAreaElement : public HTMLTextFormControlElement {
public:
    static PassRefPtr<HTMLTextAreaElement> create(const QualifiedName&, Document*, HTMLFormElement*);

    int cols() const { return m_cols; }
    int rows() const { return m_rows; }

    bool shouldWrapText() const { return m_wrap != NoWrap; }

    virtual String value() const;
    void setValue(const String&);
    String defaultValue() const;
    void setDefaultValue(const String&);
    int textLength() const { return value().length(); }
    virtual int maxLength() const;
    void setMaxLength(int, ExceptionCode&);
    bool valueMissing(const String& value) const { return isRequiredFormControl() && !disabled() && !readOnly() && value.isEmpty(); }
    bool tooLong(const String&, NeedsToCheckDirtyFlag) const;
    bool isValidValue(const String&) const;
    
    virtual HTMLElement* innerTextElement() const;

    void rendererWillBeDestroyed();

    void setCols(int);
    void setRows(int);

private:
    HTMLTextAreaElement(const QualifiedName&, Document*, HTMLFormElement*);

    enum WrapMethod { NoWrap, SoftWrap, HardWrap };

    void createShadowSubtree();

    void handleBeforeTextInsertedEvent(BeforeTextInsertedEvent*) const;
    static String sanitizeUserInputValue(const String&, unsigned maxLength);
    void updateValue() const;
    void setNonDirtyValue(const String&);
    void setValueCommon(const String&);

    virtual bool supportsPlaceholder() const { return true; }
    virtual HTMLElement* placeholderElement() const;
    virtual void updatePlaceholderText();
    virtual bool isEmptyValue() const { return value().isEmpty(); }

    virtual bool isOptionalFormControl() const { return !isRequiredFormControl(); }
    virtual bool isRequiredFormControl() const { return required(); }

    virtual void defaultEventHandler(Event*);
    
    virtual void subtreeHasChanged();

    virtual bool isEnumeratable() const { return true; }

    virtual const AtomicString& formControlType() const;

    virtual bool saveFormControlState(String& value) const;
    virtual void restoreFormControlState(const String&);

    virtual bool isTextFormControl() const { return true; }

    virtual void childrenChanged(bool changedByParser = false, Node* beforeChange = 0, Node* afterChange = 0, int childCountDelta = 0);
    virtual void parseMappedAttribute(Attribute*);
    virtual RenderObject* createRenderer(RenderArena*, RenderStyle*);
    virtual bool appendFormData(FormDataList&, bool);
    virtual void reset();
    virtual bool isMouseFocusable() const;
    virtual bool isKeyboardFocusable(KeyboardEvent*) const;
    virtual void updateFocusAppearance(bool restorePreviousSelection);

    virtual void accessKeyAction(bool sendMouseEvents);

    virtual bool shouldUseInputMethod();

    int m_rows;
    int m_cols;
    WrapMethod m_wrap;
    RefPtr<HTMLElement> m_placeholder;
    mutable String m_value;
    mutable bool m_isDirty;
    mutable bool m_wasModifiedByUser;
};

} //namespace

#endif
