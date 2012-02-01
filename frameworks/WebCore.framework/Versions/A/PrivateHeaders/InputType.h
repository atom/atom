/*
 * Copyright (C) 2010 Google Inc. All rights reserved.
 * Copyright (C) 2011 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *     * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *     * Neither the name of Google Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef InputType_h
#define InputType_h

#include <wtf/Forward.h>
#include <wtf/FastAllocBase.h>
#include <wtf/Noncopyable.h>
#include <wtf/RefPtr.h>
#include <wtf/Vector.h>

namespace WebCore {

class BeforeTextInsertedEvent;
class Chrome;
class Color;
class DateComponents;
class Event;
class FileList;
class FormDataList;
class HTMLElement;
class HTMLFormElement;
class HTMLInputElement;
class Icon;
class KeyboardEvent;
class MouseEvent;
class Node;
class RenderArena;
class RenderObject;
class RenderStyle;
class WheelEvent;

typedef int ExceptionCode;

struct ClickHandlingState {
    WTF_MAKE_FAST_ALLOCATED;
public:
    bool checked;
    bool indeterminate;
    RefPtr<HTMLInputElement> checkedRadioButton;
};

// An InputType object represents the type-specific part of an HTMLInputElement.
// Do not expose instances of InputType and classes derived from it to classes
// other than HTMLInputElement.
class InputType {
    WTF_MAKE_NONCOPYABLE(InputType); WTF_MAKE_FAST_ALLOCATED;
public:
    static PassOwnPtr<InputType> create(HTMLInputElement*, const String&);
    static PassOwnPtr<InputType> createText(HTMLInputElement*);
    virtual ~InputType();

    virtual const AtomicString& formControlType() const = 0;
    virtual bool canChangeFromAnotherType() const;

    // Type query functions

    // Any time we are using one of these functions it's best to refactor
    // to add a virtual function to allow the input type object to do the
    // work instead, or at least make a query function that asks a higher
    // level question. These functions make the HTMLInputElement class
    // inflexible because it's harder to add new input types if there is
    // scattered code with special cases for various types.

#if ENABLE(INPUT_COLOR)
    virtual bool isColorControl() const;
#endif
    virtual bool isCheckbox() const;
    virtual bool isEmailField() const;
    virtual bool isFileUpload() const;
    virtual bool isHiddenType() const;
    virtual bool isImageButton() const;
    virtual bool isNumberField() const;
    virtual bool isPasswordField() const;
    virtual bool isRadioButton() const;
    virtual bool isRangeControl() const;
    virtual bool isSearchField() const;
    virtual bool isSubmitButton() const;
    virtual bool isTelephoneField() const;
    virtual bool isTextButton() const;
    virtual bool isTextField() const;
    virtual bool isTextType() const;
    virtual bool isURLField() const;

    // Form value functions

    virtual bool saveFormControlState(String&) const;
    virtual void restoreFormControlState(const String&) const;
    virtual bool isFormDataAppendable() const;
    virtual bool appendFormData(FormDataList&, bool multipart) const;

    // DOM property functions

    virtual bool getTypeSpecificValue(String&); // Checked first, before internal storage or the value attribute.
    virtual String fallbackValue() const; // Checked last, if both internal storage and value attribute are missing.
    virtual String defaultValue() const; // Checked after even fallbackValue, only when the valueWithDefault function is called.
    virtual double valueAsDate() const;
    virtual void setValueAsDate(double, ExceptionCode&) const;
    virtual double valueAsNumber() const;
    virtual void setValueAsNumber(double, bool sendChangeEvent, ExceptionCode&) const;

    // Validation functions

    virtual bool supportsValidation() const;
    virtual bool typeMismatchFor(const String&) const;
    // Type check for the current input value. We do nothing for some types
    // though typeMismatchFor() does something for them because of value
    // sanitization.
    virtual bool typeMismatch() const;
    virtual bool supportsRequired() const;
    virtual bool valueMissing(const String&) const;
    virtual bool patternMismatch(const String&) const;
    virtual bool rangeUnderflow(const String&) const;
    virtual bool rangeOverflow(const String&) const;
    virtual bool supportsRangeLimitation() const;
    virtual double defaultValueForStepUp() const;
    virtual double minimum() const;
    virtual double maximum() const;
    virtual bool sizeShouldIncludeDecoration(int defaultSize, int& preferredSize) const;
    virtual bool stepMismatch(const String&, double step) const;
    virtual double stepBase() const;
    virtual double stepBaseWithDecimalPlaces(unsigned*) const;
    virtual double defaultStep() const;
    virtual double stepScaleFactor() const;
    virtual bool parsedStepValueShouldBeInteger() const;
    virtual bool scaledStepValueShouldBeInteger() const;
    virtual double acceptableError(double) const;
    virtual String typeMismatchText() const;
    virtual String valueMissingText() const;
    virtual bool canSetStringValue() const;
    virtual String visibleValue() const;
    virtual String convertFromVisibleValue(const String&) const;
    virtual bool isAcceptableValue(const String&);
    // Returing the null string means "use the default value."
    // This function must be called only by HTMLInputElement::sanitizeValue().
    virtual String sanitizeValue(const String&) const;
    virtual bool hasUnacceptableValue();

    // Event handlers

    virtual void handleClickEvent(MouseEvent*);
    virtual void handleMouseDownEvent(MouseEvent*);
    virtual PassOwnPtr<ClickHandlingState> willDispatchClick();
    virtual void didDispatchClick(Event*, const ClickHandlingState&);
    virtual void handleDOMActivateEvent(Event*);
    virtual void handleKeydownEvent(KeyboardEvent*);
    virtual void handleKeypressEvent(KeyboardEvent*);
    virtual void handleKeyupEvent(KeyboardEvent*);
    virtual void handleBeforeTextInsertedEvent(BeforeTextInsertedEvent*);
    virtual void handleWheelEvent(WheelEvent*);
    virtual void forwardEvent(Event*);
    // Helpers for event handlers.
    virtual bool shouldSubmitImplicitly(Event*);
    virtual PassRefPtr<HTMLFormElement> formForSubmission() const;
    virtual bool isKeyboardFocusable() const;
    virtual bool shouldUseInputMethod() const;
    virtual void handleBlurEvent();
    virtual void accessKeyAction(bool sendMouseEvents);
    virtual bool canBeSuccessfulSubmitButton();


    // Shadow tree handling

    virtual void createShadowSubtree();
    virtual void destroyShadowSubtree();

    virtual HTMLElement* containerElement() const { return 0; }
    virtual HTMLElement* innerBlockElement() const { return 0; }
    virtual HTMLElement* innerTextElement() const { return 0; }
    virtual HTMLElement* innerSpinButtonElement() const { return 0; }
    virtual HTMLElement* resultsButtonElement() const { return 0; }
    virtual HTMLElement* cancelButtonElement() const { return 0; }
#if ENABLE(INPUT_SPEECH)
    virtual HTMLElement* speechButtonElement() const { return 0; }
#endif
    virtual HTMLElement* placeholderElement() const;

    // Miscellaneous functions

    virtual bool rendererIsNeeded();
    virtual RenderObject* createRenderer(RenderArena*, RenderStyle*) const;
    virtual void attach();
    virtual void detach();
    virtual void minOrMaxAttributeChanged();
    virtual void stepAttributeChanged();
    virtual void altAttributeChanged();
    virtual void srcAttributeChanged();
    virtual void willMoveToNewOwnerDocument();
    virtual bool shouldRespectAlignAttribute();
    virtual FileList* files();
    virtual void receiveDroppedFiles(const Vector<String>&);
    virtual Icon* icon() const;
    // Should return true if the corresponding renderer for a type can display a suggested value.
    virtual bool canSetSuggestedValue();
    virtual bool shouldSendChangeEventAfterCheckedChanged();
    virtual bool canSetValue(const String&);
    virtual bool storesValueSeparateFromAttribute();
    virtual void setValue(const String&, bool valueChanged, bool sendChangeEvent);
    virtual void dispatchChangeEventInResponseToSetValue();
    virtual bool shouldResetOnDocumentActivation();
    virtual bool shouldRespectListAttribute();
    virtual bool shouldRespectSpeechAttribute();
    virtual bool isEnumeratable();
    virtual bool isCheckable();
    virtual bool isSteppable() const;
    virtual bool shouldRespectHeightAndWidthAttributes();
    virtual bool supportsPlaceholder() const;
    virtual void updatePlaceholderText();
    virtual void multipleAttributeChanged();
    virtual void disabledAttributeChanged();
    virtual void readonlyAttributeChanged();
    virtual String defaultToolTip() const;

    // Parses the specified string for the type, and return
    // the double value for the parsing result if the parsing
    // succeeds; Returns defaultValue otherwise. This function can
    // return NaN or Infinity only if defaultValue is NaN or Infinity.
    virtual double parseToDouble(const String&, double defaultValue) const;

    // Parses the specified string for the type as parseToDouble() does.
    // In addition, it stores the number of digits after the decimal point
    // into *decimalPlaces.
    virtual double parseToDoubleWithDecimalPlaces(const String&, double defaultValue, unsigned* decimalPlaces) const;

    // Parses the specified string for this InputType, and returns true if it
    // is successfully parsed. An instance pointed by the DateComponents*
    // parameter will have parsed values and be modified even if the parsing
    // fails. The DateComponents* parameter may be 0.
    virtual bool parseToDateComponents(const String&, DateComponents*) const;

    // Create a string representation of the specified double value for the
    // input type. If NaN or Infinity is specified, this returns an empty
    // string. This should not be called for types without valueAsNumber.
    virtual String serialize(double) const;

protected:
    InputType(HTMLInputElement* element) : m_element(element) { }
    HTMLInputElement* element() const { return m_element; }
    void dispatchSimulatedClickIfActive(KeyboardEvent*) const;
    // We can't make this a static const data member because VC++ doesn't like it.
    static double defaultStepBase() { return 0.0; }
    Chrome* chrome() const;

private:
    // Raw pointer because the HTMLInputElement object owns this InputType object.
    HTMLInputElement* m_element;
};

namespace InputTypeNames {

const AtomicString& button();
const AtomicString& checkbox();
#if ENABLE(INPUT_COLOR)
const AtomicString& color();
#endif
const AtomicString& date();
const AtomicString& datetime();
const AtomicString& datetimelocal();
const AtomicString& email();
const AtomicString& file();
const AtomicString& hidden();
const AtomicString& image();
const AtomicString& isindex();
const AtomicString& month();
const AtomicString& number();
const AtomicString& password();
const AtomicString& radio();
const AtomicString& range();
const AtomicString& reset();
const AtomicString& search();
const AtomicString& submit();
const AtomicString& telephone();
const AtomicString& text();
const AtomicString& time();
const AtomicString& url();
const AtomicString& week();

} // namespace WebCore::InputTypeNames

} // namespace WebCore

#endif
