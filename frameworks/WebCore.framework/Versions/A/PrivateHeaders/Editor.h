/*
 * Copyright (C) 2006, 2007, 2008 Apple Inc. All rights reserved.
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

#ifndef Editor_h
#define Editor_h

#include "ClipboardAccessPolicy.h"
#include "Color.h"
#include "DocumentMarker.h"
#include "EditAction.h"
#include "EditingBehavior.h"
#include "EditingStyle.h"
#include "EditorInsertAction.h"
#include "FindOptions.h"
#include "FrameSelection.h"
#include "TextChecking.h"
#include "VisibleSelection.h"
#include "WritingDirection.h"

#if PLATFORM(MAC) && !defined(__OBJC__)
class NSDictionary;
typedef int NSWritingDirection;
#endif

namespace WebCore {

class CSSStyleDeclaration;
class Clipboard;
class CompositeEditCommand;
class DeleteButtonController;
class EditCommand;
class EditCommandComposition;
class EditorClient;
class EditorInternalCommand;
class Frame;
class HTMLElement;
class HitTestResult;
class KillRing;
class Pasteboard;
class SimpleFontData;
class SpellChecker;
class SpellCheckRequest;
class SpellingCorrectionController;
class Text;
class TextCheckerClient;
class TextEvent;
struct TextCheckingResult;

struct CompositionUnderline {
    CompositionUnderline() 
        : startOffset(0), endOffset(0), thick(false) { }
    CompositionUnderline(unsigned s, unsigned e, const Color& c, bool t) 
        : startOffset(s), endOffset(e), color(c), thick(t) { }
    unsigned startOffset;
    unsigned endOffset;
    Color color;
    bool thick;
};

enum EditorCommandSource { CommandFromMenuOrKeyBinding, CommandFromDOM, CommandFromDOMWithUserInterface };

class Editor {
public:
    Editor(Frame*);
    ~Editor();

    EditorClient* client() const;
    TextCheckerClient* textChecker() const;

    Frame* frame() const { return m_frame; }
    DeleteButtonController* deleteButtonController() const { return m_deleteButtonController.get(); }
    CompositeEditCommand* lastEditCommand() { return m_lastEditCommand.get(); }

    void handleKeyboardEvent(KeyboardEvent*);
    void handleInputMethodKeydown(KeyboardEvent*);
    bool handleTextEvent(TextEvent*);

    bool canEdit() const;
    bool canEditRichly() const;

    bool canDHTMLCut();
    bool canDHTMLCopy();
    bool canDHTMLPaste();
    bool tryDHTMLCopy();
    bool tryDHTMLCut();
    bool tryDHTMLPaste();

    bool canCut() const;
    bool canCopy() const;
    bool canPaste() const;
    bool canDelete() const;
    bool canSmartCopyOrDelete();

    void cut();
    void copy();
    void paste();
    void pasteAsPlainText();
    void performDelete();

    void copyURL(const KURL&, const String&);
    void copyImage(const HitTestResult&);

    void indent();
    void outdent();
    void transpose();

    bool shouldInsertFragment(PassRefPtr<DocumentFragment>, PassRefPtr<Range>, EditorInsertAction);
    bool shouldInsertText(const String&, Range*, EditorInsertAction) const;
    bool shouldShowDeleteInterface(HTMLElement*) const;
    bool shouldDeleteRange(Range*) const;
    bool shouldApplyStyle(CSSStyleDeclaration*, Range*);
    
    void respondToChangedSelection(const VisibleSelection& oldSelection);
    void respondToChangedContents(const VisibleSelection& endingSelection);

    bool selectionStartHasStyle(int propertyID, const String& value) const;
    TriState selectionHasStyle(int propertyID, const String& value) const;
    String selectionStartCSSPropertyValue(int propertyID);
    WritingDirection textDirectionForSelection(bool&) const;
    
    TriState selectionUnorderedListState() const;
    TriState selectionOrderedListState() const;
    PassRefPtr<Node> insertOrderedList();
    PassRefPtr<Node> insertUnorderedList();
    bool canIncreaseSelectionListLevel();
    bool canDecreaseSelectionListLevel();
    PassRefPtr<Node> increaseSelectionListLevel();
    PassRefPtr<Node> increaseSelectionListLevelOrdered();
    PassRefPtr<Node> increaseSelectionListLevelUnordered();
    void decreaseSelectionListLevel();
   
    void removeFormattingAndStyle();

    void clearLastEditCommand();

    bool deleteWithDirection(SelectionDirection, TextGranularity, bool killRing, bool isTypingAction);
    void deleteSelectionWithSmartDelete(bool smartDelete);
    bool dispatchCPPEvent(const AtomicString&, ClipboardAccessPolicy);
    
    Node* removedAnchor() const { return m_removedAnchor.get(); }
    void setRemovedAnchor(PassRefPtr<Node> n) { m_removedAnchor = n; }

    void applyStyle(CSSStyleDeclaration*, EditAction = EditActionUnspecified);
    void applyParagraphStyle(CSSStyleDeclaration*, EditAction = EditActionUnspecified);
    void applyStyleToSelection(CSSStyleDeclaration*, EditAction);
    void applyParagraphStyleToSelection(CSSStyleDeclaration*, EditAction);

    void appliedEditing(PassRefPtr<CompositeEditCommand>);
    void unappliedEditing(PassRefPtr<EditCommandComposition>);
    void reappliedEditing(PassRefPtr<EditCommandComposition>);
    void unappliedSpellCorrection(const VisibleSelection& selectionOfCorrected, const String& corrected, const String& correction);

    void setShouldStyleWithCSS(bool flag) { m_shouldStyleWithCSS = flag; }
    bool shouldStyleWithCSS() const { return m_shouldStyleWithCSS; }

    class Command {
    public:
        Command();
        Command(const EditorInternalCommand*, EditorCommandSource, PassRefPtr<Frame>);

        bool execute(const String& parameter = String(), Event* triggeringEvent = 0) const;
        bool execute(Event* triggeringEvent) const;

        bool isSupported() const;
        bool isEnabled(Event* triggeringEvent = 0) const;

        TriState state(Event* triggeringEvent = 0) const;
        String value(Event* triggeringEvent = 0) const;

        bool isTextInsertion() const;

    private:
        const EditorInternalCommand* m_command;
        EditorCommandSource m_source;
        RefPtr<Frame> m_frame;
    };
    Command command(const String& commandName); // Command source is CommandFromMenuOrKeyBinding.
    Command command(const String& commandName, EditorCommandSource);
    static bool commandIsSupportedFromMenuOrKeyBinding(const String& commandName); // Works without a frame.

    bool insertText(const String&, Event* triggeringEvent);
    bool insertTextForConfirmedComposition(const String& text);
    bool insertTextWithoutSendingTextEvent(const String&, bool selectInsertedText, TextEvent* triggeringEvent);
    bool insertLineBreak();
    bool insertParagraphSeparator();
    
    bool isContinuousSpellCheckingEnabled();
    void toggleContinuousSpellChecking();
    bool isGrammarCheckingEnabled();
    void toggleGrammarChecking();
    void ignoreSpelling();
    void learnSpelling();
    int spellCheckerDocumentTag();
    bool isSelectionUngrammatical();
    bool isSelectionMisspelled();
    Vector<String> guessesForMisspelledSelection();
    Vector<String> guessesForUngrammaticalSelection();
    Vector<String> guessesForMisspelledOrUngrammaticalSelection(bool& misspelled, bool& ungrammatical);
    bool isSpellCheckingEnabledInFocusedNode() const;
    bool isSpellCheckingEnabledFor(Node*) const;
    void markMisspellingsAfterTypingToWord(const VisiblePosition &wordStart, const VisibleSelection& selectionAfterTyping, bool doReplacement);
    void markMisspellings(const VisibleSelection&, RefPtr<Range>& firstMisspellingRange);
    void markBadGrammar(const VisibleSelection&);
    void markMisspellingsAndBadGrammar(const VisibleSelection& spellingSelection, bool markGrammar, const VisibleSelection& grammarSelection);
    void markAndReplaceFor(PassRefPtr<SpellCheckRequest>, const Vector<TextCheckingResult>&);

#if USE(AUTOMATIC_TEXT_REPLACEMENT)
    void uppercaseWord();
    void lowercaseWord();
    void capitalizeWord();
    void showSubstitutionsPanel();
    bool substitutionsPanelIsShowing();
    void toggleSmartInsertDelete();
    bool isAutomaticQuoteSubstitutionEnabled();
    void toggleAutomaticQuoteSubstitution();
    bool isAutomaticLinkDetectionEnabled();
    void toggleAutomaticLinkDetection();
    bool isAutomaticDashSubstitutionEnabled();
    void toggleAutomaticDashSubstitution();
    bool isAutomaticTextReplacementEnabled();
    void toggleAutomaticTextReplacement();
    bool isAutomaticSpellingCorrectionEnabled();
    void toggleAutomaticSpellingCorrection();
#endif

    void markAllMisspellingsAndBadGrammarInRanges(TextCheckingTypeMask, Range* spellingRange, Range* grammarRange);
    void changeBackToReplacedString(const String& replacedString);

    void advanceToNextMisspelling(bool startBeforeSelection = false);
    void showSpellingGuessPanel();
    bool spellingPanelIsShowing();

    bool shouldBeginEditing(Range*);
    bool shouldEndEditing(Range*);

    void clearUndoRedoOperations();
    bool canUndo();
    void undo();
    bool canRedo();
    void redo();

    void didBeginEditing();
    void didEndEditing();
    void didWriteSelectionToPasteboard();
    
    void showFontPanel();
    void showStylesPanel();
    void showColorPanel();
    void toggleBold();
    void toggleUnderline();
    void setBaseWritingDirection(WritingDirection);

    // smartInsertDeleteEnabled and selectTrailingWhitespaceEnabled are 
    // mutually exclusive, meaning that enabling one will disable the other.
    bool smartInsertDeleteEnabled();
    bool isSelectTrailingWhitespaceEnabled();
    
    bool hasBidiSelection() const;

    // international text input composition
    bool hasComposition() const { return m_compositionNode; }
    void setComposition(const String&, const Vector<CompositionUnderline>&, unsigned selectionStart, unsigned selectionEnd);
    void confirmComposition();
    void confirmComposition(const String&); // if no existing composition, replaces selection
    void cancelComposition();
    PassRefPtr<Range> compositionRange() const;
    bool getCompositionSelection(unsigned& selectionStart, unsigned& selectionEnd) const;

    // getting international text input composition state (for use by InlineTextBox)
    Text* compositionNode() const { return m_compositionNode.get(); }
    unsigned compositionStart() const { return m_compositionStart; }
    unsigned compositionEnd() const { return m_compositionEnd; }
    bool compositionUsesCustomUnderlines() const { return !m_customCompositionUnderlines.isEmpty(); }
    const Vector<CompositionUnderline>& customCompositionUnderlines() const { return m_customCompositionUnderlines; }

    void setIgnoreCompositionSelectionChange(bool);
    bool ignoreCompositionSelectionChange() const { return m_ignoreCompositionSelectionChange; }

    void setStartNewKillRingSequence(bool);

    PassRefPtr<Range> rangeForPoint(const LayoutPoint& windowPoint);

    void clear();

    VisibleSelection selectionForCommand(Event*);

    KillRing* killRing() const { return m_killRing.get(); }
    SpellChecker* spellChecker() const { return m_spellChecker.get(); }

    EditingBehavior behavior() const;

    PassRefPtr<Range> selectedRange();
    
    // We should make these functions private when their callers in Frame are moved over here to Editor
    bool insideVisibleArea(const LayoutPoint&) const;
    bool insideVisibleArea(Range*) const;

    void addToKillRing(Range*, bool prepend);

    void startCorrectionPanelTimer();
    // If user confirmed a correction in the correction panel, correction has non-zero length, otherwise it means that user has dismissed the panel.
    void handleCorrectionPanelResult(const String& correction);
    void dismissCorrectionPanelAsIgnored();

    void pasteAsFragment(PassRefPtr<DocumentFragment>, bool smartReplace, bool matchStyle);
    void pasteAsPlainText(const String&, bool smartReplace);

    // This is only called on the mac where paste is implemented primarily at the WebKit level.
    void pasteAsPlainTextBypassingDHTML();
 
    void clearMisspellingsAndBadGrammar(const VisibleSelection&);
    void markMisspellingsAndBadGrammar(const VisibleSelection&);

    Node* findEventTargetFrom(const VisibleSelection& selection) const;

    String selectedText() const;
    bool findString(const String&, FindOptions);
    // FIXME: Switch callers over to the FindOptions version and retire this one.
    bool findString(const String&, bool forward, bool caseFlag, bool wrapFlag, bool startInSelection);

    PassRefPtr<Range> rangeOfString(const String&, Range*, FindOptions);
    PassRefPtr<Range> findStringAndScrollToVisible(const String&, Range*, FindOptions);

    const VisibleSelection& mark() const; // Mark, to be used as emacs uses it.
    void setMark(const VisibleSelection&);

    void computeAndSetTypingStyle(CSSStyleDeclaration* , EditAction = EditActionUnspecified);
    void applyEditingStyleToBodyElement() const;
    void applyEditingStyleToElement(Element*) const;

    IntRect firstRectForRange(Range*) const;

    void respondToChangedSelection(const VisibleSelection& oldSelection, FrameSelection::SetSelectionOptions);
    bool shouldChangeSelection(const VisibleSelection& oldSelection, const VisibleSelection& newSelection, EAffinity, bool stillSelecting) const;
    unsigned countMatchesForText(const String&, FindOptions, unsigned limit, bool markMatches);
    unsigned countMatchesForText(const String&, Range*, FindOptions, unsigned limit, bool markMatches);
    bool markedTextMatchesAreHighlighted() const;
    void setMarkedTextMatchesAreHighlighted(bool);

    void textFieldDidBeginEditing(Element*);
    void textFieldDidEndEditing(Element*);
    void textDidChangeInTextField(Element*);
    bool doTextFieldCommandFromEvent(Element*, KeyboardEvent*);
    void textWillBeDeletedInTextField(Element* input);
    void textDidChangeInTextArea(Element*);

#if PLATFORM(MAC)
    const SimpleFontData* fontForSelection(bool&) const;
    NSDictionary* fontAttributesForSelectionStart() const;
    NSWritingDirection baseWritingDirectionForSelectionStart() const;
    bool canCopyExcludingStandaloneImages();
    void takeFindStringFromSelection();
    void writeSelectionToPasteboard(const String& pasteboardName, const Vector<String>& pasteboardTypes);
    void readSelectionFromPasteboard(const String& pasteboardName);
#endif

    void replaceSelectionWithFragment(PassRefPtr<DocumentFragment>, bool selectReplacement, bool smartReplace, bool matchStyle);
    void replaceSelectionWithText(const String&, bool selectReplacement, bool smartReplace);
    bool selectionStartHasMarkerFor(DocumentMarker::MarkerType, int from, int length) const;
    void updateMarkersForWordsAffectedByEditing(bool onlyHandleWordsContainingSelection);
    void deletedAutocorrectionAtPosition(const Position&, const String& originalString);

    void deviceScaleFactorChanged();

private:
    Frame* m_frame;
    OwnPtr<DeleteButtonController> m_deleteButtonController;
    RefPtr<CompositeEditCommand> m_lastEditCommand;
    RefPtr<Node> m_removedAnchor;
    RefPtr<Text> m_compositionNode;
    unsigned m_compositionStart;
    unsigned m_compositionEnd;
    Vector<CompositionUnderline> m_customCompositionUnderlines;
    bool m_ignoreCompositionSelectionChange;
    bool m_shouldStartNewKillRingSequence;
    bool m_shouldStyleWithCSS;
    OwnPtr<KillRing> m_killRing;
    OwnPtr<SpellChecker> m_spellChecker;
    OwnPtr<SpellingCorrectionController> m_spellingCorrector;
    VisibleSelection m_mark;
    bool m_areMarkedTextMatchesHighlighted;

    bool canDeleteRange(Range*) const;
    bool canSmartReplaceWithPasteboard(Pasteboard*);
    PassRefPtr<Clipboard> newGeneralClipboard(ClipboardAccessPolicy, Frame*);
    void pasteAsPlainTextWithPasteboard(Pasteboard*);
    void pasteWithPasteboard(Pasteboard*, bool allowPlainText);
    void writeSelectionToPasteboard(Pasteboard*);
    void revealSelectionAfterEditingOperation();
    void markMisspellingsOrBadGrammar(const VisibleSelection&, bool checkSpelling, RefPtr<Range>& firstMisspellingRange);
    TextCheckingTypeMask resolveTextCheckingTypeMask(TextCheckingTypeMask);

    void selectComposition();
    enum SetCompositionMode { ConfirmComposition, CancelComposition };
    void setComposition(const String&, SetCompositionMode);

    PassRefPtr<Range> firstVisibleRange(const String&, FindOptions);
    PassRefPtr<Range> lastVisibleRange(const String&, FindOptions);
    PassRefPtr<Range> nextVisibleRange(Range*, const String&, FindOptions);

    void changeSelectionAfterCommand(const VisibleSelection& newSelection, bool closeTyping, bool clearTypingStyle);

    Node* findEventTargetFromSelection() const;

    bool unifiedTextCheckerEnabled() const;
};

inline void Editor::setStartNewKillRingSequence(bool flag)
{
    m_shouldStartNewKillRingSequence = flag;
}

inline const VisibleSelection& Editor::mark() const
{
    return m_mark;
}

inline void Editor::setMark(const VisibleSelection& selection)
{
    m_mark = selection;
}

inline bool Editor::markedTextMatchesAreHighlighted() const
{
    return m_areMarkedTextMatchesHighlighted;
}


} // namespace WebCore

#endif // Editor_h
