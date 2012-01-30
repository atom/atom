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

#ifndef HTMLInputElement_h
#define HTMLInputElement_h

#include "HTMLTextFormControlElement.h"

namespace WebCore {

class FileList;
class HTMLDataListElement;
class HTMLOptionElement;
class Icon;
class InputType;
class KURL;

class HTMLInputElement : public HTMLTextFormControlElement {
public:
    static PassRefPtr<HTMLInputElement> create(const QualifiedName&, Document*, HTMLFormElement*, bool createdByParser);
    virtual ~HTMLInputElement();

    DEFINE_ATTRIBUTE_EVENT_LISTENER(webkitspeechchange);

    virtual HTMLInputElement* toInputElement() { return this; }

    virtual bool shouldAutocomplete() const;

    // For ValidityState
    bool typeMismatch() const;
    // valueMissing() ignores the specified string value for CHECKBOX and RADIO.
    bool valueMissing(const String&) const;
    bool patternMismatch(const String&) const;
    bool tooLong(const String&, NeedsToCheckDirtyFlag) const;
    bool rangeUnderflow(const String&) const;
    bool rangeOverflow(const String&) const;
    // Returns the minimum value for type=date, number, or range.  Don't call this for other types.
    double minimum() const;
    // Returns the maximum value for type=date, number, or range.  Don't call this for other types.
    // This always returns a value which is >= minimum().
    double maximum() const;
    // Sets the "allowed value step" defined in the HTML spec to the specified double pointer.
    // Returns false if there is no "allowed value step."
    bool getAllowedValueStep(double*) const;

    // For ValidityState.
    bool stepMismatch(const String&) const;
    String minimumString() const;
    String maximumString() const;
    String stepBaseString() const;
    String stepString() const;
    String typeMismatchText() const;
    String valueMissingText() const;

    // Implementations of HTMLInputElement::stepUp() and stepDown().
    void stepUp(int, ExceptionCode&);
    void stepDown(int, ExceptionCode&);
    void stepUp(ExceptionCode& ec) { stepUp(1, ec); }
    void stepDown(ExceptionCode& ec) { stepDown(1, ec); }
    // stepUp()/stepDown() for user-interaction.
    bool isSteppable() const;
    void stepUpFromRenderer(int);

    bool isTextButton() const;

    virtual bool isRadioButton() const;
    bool isTextField() const;
    bool isSearchField() const;
    bool isInputTypeHidden() const;
    bool isPasswordField() const;
    bool isCheckbox() const;
    bool isRangeControl() const;

    // FIXME: It's highly likely that any call site calling this function should instead
    // be using a different one. Many input elements behave like text fields, and in addition
    // any unknown input type is treated as text. Consider, for example, isTextField or
    // isTextField && !isPasswordField.
    bool isText() const;

    bool isEmailField() const;
    bool isFileUpload() const;
    bool isImageButton() const;
    bool isNumberField() const;
    bool isSubmitButton() const;
    bool isTelephoneField() const;
    bool isURLField() const;

#if ENABLE(INPUT_SPEECH)
    bool isSpeechEnabled() const;
#endif

    HTMLElement* containerElement() const;
    virtual HTMLElement* innerTextElement() const;
    HTMLElement* innerBlockElement() const;
    HTMLElement* innerSpinButtonElement() const;
    HTMLElement* resultsButtonElement() const;
    HTMLElement* cancelButtonElement() const;
#if ENABLE(INPUT_SPEECH)
    HTMLElement* speechButtonElement() const;
#endif
    virtual HTMLElement* placeholderElement() const;

    bool checked() const { return m_isChecked; }
    void setChecked(bool, bool sendChangeEvent = false);

    // 'indeterminate' is a state independent of the checked state that causes the control to draw in a way that hides the actual state.
    bool indeterminate() const { return m_isIndeterminate; }
    void setIndeterminate(bool);
    // shouldAppearChecked is used by the rendering tree/CSS while checked() is used by JS to determine checked state
    bool shouldAppearChecked() const;
    virtual bool isIndeterminate() const { return indeterminate(); }

    int size() const;
    bool sizeShouldIncludeDecoration(int& preferredSize) const;

    void setType(const String&);

    String value() const;
    void setValue(const String&, bool sendChangeEvent = false);
    void setValueForUser(const String&);
    // Checks if the specified string would be a valid value.
    // We should not call this for types with no string value such as CHECKBOX and RADIO.
    bool isValidValue(const String&) const;
    bool hasDirtyValue() const { return !m_valueIfDirty.isNull(); };

    String sanitizeValue(const String&) const;

    void updateInnerTextValue();

    // The value which is drawn by a renderer.
    String visibleValue() const;
    String convertFromVisibleValue(const String&) const;
    // Returns true if the specified string can be set as the value of HTMLInputElement.
    bool isAcceptableValue(const String&) const;

    const String& suggestedValue() const;
    void setSuggestedValue(const String&);

    double valueAsDate() const;
    void setValueAsDate(double, ExceptionCode&);

    double valueAsNumber() const;
    void setValueAsNumber(double, ExceptionCode&, bool sendChangeEvent = false);

    virtual String placeholder() const;
    virtual void setPlaceholder(const String&);

    String valueWithDefault() const;

    void setValueFromRenderer(const String&);

    bool canHaveSelection() const;

    virtual bool rendererIsNeeded(const NodeRenderingContext&);
    virtual RenderObject* createRenderer(RenderArena*, RenderStyle*);
    virtual void detach();

    // FIXME: For isActivatedSubmit and setActivatedSubmit, we should use the NVI-idiom here by making
    // it private virtual in all classes and expose a public method in HTMLFormControlElement to call
    // the private virtual method.
    virtual bool isActivatedSubmit() const;
    virtual void setActivatedSubmit(bool flag);

    String altText() const;

    int maxResults() const { return m_maxResults; }

    String defaultValue() const;
    void setDefaultValue(const String&);

    Vector<String> acceptMIMETypes();
    String accept() const;
    String alt() const;

    void setSize(unsigned);

    KURL src() const;

    virtual int maxLength() const;
    void setMaxLength(int, ExceptionCode&);

    bool multiple() const;

    bool isAutofilled() const { return m_isAutofilled; }
    void setAutofilled(bool = true);

    FileList* files();
    void receiveDroppedFiles(const Vector<String>&);
    Icon* icon() const;
    // These functions are used for rendering the input active during a
    // drag-and-drop operation.
    bool canReceiveDroppedFiles() const;
    void setCanReceiveDroppedFiles(bool);

    void addSearchResult();
    void onSearch();
    bool searchEventsShouldBeDispatched() const;

#if ENABLE(DATALIST)
    HTMLElement* list() const;
    HTMLOptionElement* selectedOption() const;
#endif

    // These functions are public so they can be used in InputType classes.
    // Otherwise, they would be private.
    CheckedRadioButtons& checkedRadioButtons() const;
    void updateCheckedRadioButtons();
    void setValueInternal(const String&, bool sendChangeEvent);

    void cacheSelectionInResponseToSetValue(int caretOffset) { cacheSelection(caretOffset, caretOffset, SelectionHasNoDirection); }

#if ENABLE(INPUT_COLOR)
    // For test purposes.
    void selectColorInColorChooser(const Color&);
#endif

    String defaultToolTip() const;

    static const int maximumLength;

protected:
    HTMLInputElement(const QualifiedName&, Document*, HTMLFormElement*, bool createdByParser);
    void createShadowSubtree();
    void setInitialName(const AtomicString&);
    virtual void defaultEventHandler(Event*);

private:
    enum AutoCompleteSetting { Uninitialized, On, Off };
    enum AnyStepHandling { RejectAny, AnyIsDefaultStep };

    virtual void willChangeForm() OVERRIDE;
    virtual void didChangeForm() OVERRIDE;
    virtual void insertedIntoDocument() OVERRIDE;
    virtual void removedFromDocument() OVERRIDE;
    virtual void didMoveToNewDocument(Document* oldDocument) OVERRIDE;

    virtual bool isKeyboardFocusable(KeyboardEvent*) const;
    virtual bool isMouseFocusable() const;
    virtual bool isEnumeratable() const;
    virtual void updateFocusAppearance(bool restorePreviousSelection);
    virtual void aboutToUnload();
    virtual bool shouldUseInputMethod();

    virtual const AtomicString& formControlName() const;

    virtual bool isTextFormControl() const { return isTextField(); }

    virtual bool canTriggerImplicitSubmission() const { return isTextField(); }

    virtual const AtomicString& formControlType() const;

    virtual bool saveFormControlState(String& value) const;
    virtual void restoreFormControlState(const String&);

    virtual bool canStartSelection() const;

    virtual void accessKeyAction(bool sendMouseEvents);

    virtual bool mapToEntry(const QualifiedName& attrName, MappedAttributeEntry& result) const;
    virtual void parseMappedAttribute(Attribute*);
    virtual void finishParsingChildren();

    virtual void copyNonAttributeProperties(const Element* source);

    virtual void attach();

    virtual bool appendFormData(FormDataList&, bool);

    virtual bool isSuccessfulSubmitButton() const;

    virtual void reset();

    virtual void* preDispatchEventHandler(Event*);
    virtual void postDispatchEventHandler(Event*, void* dataFromPreDispatch);

    virtual bool isURLAttribute(Attribute*) const;

    virtual bool hasUnacceptableValue() const;

    virtual bool isInRange() const;
    virtual bool isOutOfRange() const;

    virtual void documentDidResumeFromPageCache();

    virtual void addSubresourceAttributeURLs(ListHashSet<KURL>&) const;

    bool needsSuspensionCallback();
    void registerForSuspensionCallbackIfNeeded();
    void unregisterForSuspensionCallbackIfNeeded();

    bool supportsMaxLength() const { return isTextType(); }
    bool isTextType() const;

    virtual bool supportsPlaceholder() const;
    virtual void updatePlaceholderText();
    virtual bool isEmptyValue() const OVERRIDE { return innerTextValue().isEmpty(); }
    virtual bool isEmptySuggestedValue() const { return suggestedValue().isEmpty(); }
    virtual void handleFocusEvent();
    virtual void handleBlurEvent();

    virtual bool isOptionalFormControl() const { return !isRequiredFormControl(); }
    virtual bool isRequiredFormControl() const;
    virtual bool recalcWillValidate() const;
    virtual void requiredAttributeChanged() OVERRIDE;

    void updateType();
    
    virtual void subtreeHasChanged();

    bool getAllowedValueStepWithDecimalPlaces(AnyStepHandling, double*, unsigned*) const;

    // Helper for stepUp()/stepDown().  Adds step value * count to the current value.
    void applyStep(double count, AnyStepHandling, bool sendChangeEvent, ExceptionCode&);
    double alignValueForStep(double value, double step, unsigned currentDecimalPlaces, unsigned stepDecimalPlaces);

#if ENABLE(DATALIST)
    HTMLDataListElement* dataList() const;
#endif
    void parseMaxLengthAttribute(Attribute*);
    void updateValueIfNeeded();

    AtomicString m_name;
    String m_valueIfDirty;
    String m_suggestedValue;
    int m_size;
    int m_maxLength;
    short m_maxResults;
    bool m_isChecked : 1;
    bool m_reflectsCheckedAttribute : 1;
    bool m_isIndeterminate : 1;
    bool m_hasType : 1;
    bool m_isActivatedSubmit : 1;
    unsigned m_autocomplete : 2; // AutoCompleteSetting
    bool m_isAutofilled : 1;
#if ENABLE(DATALIST)
    bool m_hasNonEmptyList : 1;
#endif
    bool m_stateRestored : 1;
    bool m_parsingInProgress : 1;
    bool m_wasModifiedByUser : 1;
    bool m_canReceiveDroppedFiles : 1;
    OwnPtr<InputType> m_inputType;
};

} //namespace

#endif
