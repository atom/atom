/*
 * Copyright (C) 2006, 2007 Apple Inc. All rights reserved.
 * Copyright (C) 2008 Nokia Corporation and/or its subsidiary(-ies)
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE COMPUTER, INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE COMPUTER, INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef EditorClient_h
#define EditorClient_h

#include "SpellingCorrectionController.h"
#include "EditorInsertAction.h"
#include "FloatRect.h"
#include "TextAffinity.h"
#include "UndoStep.h"
#include <wtf/Forward.h>
#include <wtf/Vector.h>

#if PLATFORM(MAC)
OBJC_CLASS NSAttributedString;
OBJC_CLASS NSPasteboard;
OBJC_CLASS NSString;
OBJC_CLASS NSURL;
#endif

namespace WebCore {

class ArchiveResource;
class CSSStyleDeclaration;
class DocumentFragment;
class Editor;
class Element;
class Frame;
class HTMLElement;
class KeyboardEvent;
class Node;
class Range;
class SpellChecker;
class TextCheckerClient;
class VisibleSelection;
class VisiblePosition;

struct GrammarDetail;

class EditorClient {
public:
    virtual ~EditorClient() {  }
    virtual void pageDestroyed() = 0;
    
    virtual bool shouldDeleteRange(Range*) = 0;
    virtual bool shouldShowDeleteInterface(HTMLElement*) = 0;
    virtual bool smartInsertDeleteEnabled() = 0; 
    virtual bool isSelectTrailingWhitespaceEnabled() = 0;
    virtual bool isContinuousSpellCheckingEnabled() = 0;
    virtual void toggleContinuousSpellChecking() = 0;
    virtual bool isGrammarCheckingEnabled() = 0;
    virtual void toggleGrammarChecking() = 0;
    virtual int spellCheckerDocumentTag() = 0;

    virtual bool shouldBeginEditing(Range*) = 0;
    virtual bool shouldEndEditing(Range*) = 0;
    virtual bool shouldInsertNode(Node*, Range*, EditorInsertAction) = 0;
    virtual bool shouldInsertText(const String&, Range*, EditorInsertAction) = 0;
    virtual bool shouldChangeSelectedRange(Range* fromRange, Range* toRange, EAffinity, bool stillSelecting) = 0;
    
    virtual bool shouldApplyStyle(CSSStyleDeclaration*, Range*) = 0;
    virtual bool shouldMoveRangeAfterDelete(Range*, Range*) = 0;

    virtual void didBeginEditing() = 0;
    virtual void respondToChangedContents() = 0;
    virtual void respondToChangedSelection(Frame*) = 0;
    virtual void didEndEditing() = 0;
    virtual void didWriteSelectionToPasteboard() = 0;
    virtual void didSetSelectionTypesForPasteboard() = 0;
    
    virtual void registerUndoStep(PassRefPtr<UndoStep>) = 0;
    virtual void registerRedoStep(PassRefPtr<UndoStep>) = 0;
    virtual void clearUndoRedoOperations() = 0;

    virtual bool canCopyCut(Frame*, bool defaultValue) const = 0;
    virtual bool canPaste(Frame*, bool defaultValue) const = 0;
    virtual bool canUndo() const = 0;
    virtual bool canRedo() const = 0;
    
    virtual void undo() = 0;
    virtual void redo() = 0;

    virtual void handleKeyboardEvent(KeyboardEvent*) = 0;
    virtual void handleInputMethodKeydown(KeyboardEvent*) = 0;
    
    virtual void textFieldDidBeginEditing(Element*) = 0;
    virtual void textFieldDidEndEditing(Element*) = 0;
    virtual void textDidChangeInTextField(Element*) = 0;
    virtual bool doTextFieldCommandFromEvent(Element*, KeyboardEvent*) = 0;
    virtual void textWillBeDeletedInTextField(Element*) = 0;
    virtual void textDidChangeInTextArea(Element*) = 0;

#if PLATFORM(MAC)
    virtual NSString* userVisibleString(NSURL*) = 0;
    virtual DocumentFragment* documentFragmentFromAttributedString(NSAttributedString*, Vector< RefPtr<ArchiveResource> >&) = 0;
    virtual void setInsertionPasteboard(NSPasteboard*) = 0;
    virtual NSURL* canonicalizeURL(NSURL*) = 0;
    virtual NSURL* canonicalizeURLString(NSString*) = 0;
#endif

#if PLATFORM(MAC) && !defined(BUILDING_ON_LEOPARD)
    virtual void uppercaseWord() = 0;
    virtual void lowercaseWord() = 0;
    virtual void capitalizeWord() = 0;
    virtual void showSubstitutionsPanel(bool show) = 0;
    virtual bool substitutionsPanelIsShowing() = 0;
    virtual void toggleSmartInsertDelete() = 0;
    virtual bool isAutomaticQuoteSubstitutionEnabled() = 0;
    virtual void toggleAutomaticQuoteSubstitution() = 0;
    virtual bool isAutomaticLinkDetectionEnabled() = 0;
    virtual void toggleAutomaticLinkDetection() = 0;
    virtual bool isAutomaticDashSubstitutionEnabled() = 0;
    virtual void toggleAutomaticDashSubstitution() = 0;
    virtual bool isAutomaticTextReplacementEnabled() = 0;
    virtual void toggleAutomaticTextReplacement() = 0;
    virtual bool isAutomaticSpellingCorrectionEnabled() = 0;
    virtual void toggleAutomaticSpellingCorrection() = 0;
#endif

    virtual TextCheckerClient* textChecker() = 0;

    enum AutocorrectionResponseType {
        AutocorrectionEdited,
        AutocorrectionReverted
    };

#if USE(AUTOCORRECTION_PANEL)
    virtual void showCorrectionPanel(CorrectionPanelInfo::PanelType, const FloatRect& boundingBoxOfReplacedString, const String& replacedString, const String& replacmentString, const Vector<String>& alternativeReplacementStrings) = 0;
    virtual void dismissCorrectionPanel(ReasonForDismissingCorrectionPanel) = 0;
    virtual String dismissCorrectionPanelSoon(ReasonForDismissingCorrectionPanel) = 0;
    virtual void recordAutocorrectionResponse(AutocorrectionResponseType, const String& replacedString, const String& replacementString) = 0;
#endif

    virtual void updateSpellingUIWithGrammarString(const String&, const GrammarDetail& detail) = 0;
    virtual void updateSpellingUIWithMisspelledWord(const String&) = 0;
    virtual void showSpellingUI(bool show) = 0;
    virtual bool spellingUIIsShowing() = 0;
    virtual void willSetInputMethodState() = 0;
    virtual void setInputMethodState(bool enabled) = 0;
};

}

#endif // EditorClient_h
