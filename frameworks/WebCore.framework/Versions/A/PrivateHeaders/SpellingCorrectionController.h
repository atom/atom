/*
 * Copyright (C) 2010 Apple Inc. All rights reserved.
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

#ifndef SpellingCorrectionController_h
#define SpellingCorrectionController_h

#include "DocumentMarker.h"
#include "Range.h"
#include "TextChecking.h"
#include "Timer.h"
#include "VisibleSelection.h"
#include <wtf/Noncopyable.h>
#include <wtf/UnusedParam.h>

namespace WebCore {

class CompositeEditCommand;
class EditorClient;
class EditCommand;
class EditCommandComposition;
class Frame;
class TextCheckerClient;

struct CorrectionPanelInfo {
    enum PanelType {
        PanelTypeCorrection = 0,
        PanelTypeReversion,
        PanelTypeSpellingSuggestions
    };

    RefPtr<Range> rangeToBeReplaced;
    String replacedString;
    String replacementString;
    PanelType panelType;
    bool isActive;
};

struct TextCheckingResult;

enum ReasonForDismissingCorrectionPanel {
    ReasonForDismissingCorrectionPanelCancelled = 0,
    ReasonForDismissingCorrectionPanelIgnored,
    ReasonForDismissingCorrectionPanelAccepted
};

#if USE(AUTOCORRECTION_PANEL)
#define UNLESS_ENABLED(functionBody) ;
#else
#define UNLESS_ENABLED(functionBody) functionBody
#endif

class SpellingCorrectionController {
    WTF_MAKE_NONCOPYABLE(SpellingCorrectionController); WTF_MAKE_FAST_ALLOCATED;
public:
    SpellingCorrectionController(Frame*) UNLESS_ENABLED({})
    ~SpellingCorrectionController() UNLESS_ENABLED({})

    void startCorrectionPanelTimer(CorrectionPanelInfo::PanelType) UNLESS_ENABLED({})
    void stopCorrectionPanelTimer() UNLESS_ENABLED({})

    void dismiss(ReasonForDismissingCorrectionPanel) UNLESS_ENABLED({})
    String dismissSoon(ReasonForDismissingCorrectionPanel) UNLESS_ENABLED({ return String(); })
    void show(PassRefPtr<Range> rangeToReplace, const String& replacement) UNLESS_ENABLED({ UNUSED_PARAM(rangeToReplace); UNUSED_PARAM(replacement); })

    void applyCorrectionPanelInfo(const Vector<DocumentMarker::MarkerType>&) UNLESS_ENABLED({})
    // Return true if correction was applied, false otherwise.
    bool applyAutocorrectionBeforeTypingIfAppropriate() UNLESS_ENABLED({ return false; })

    void respondToUnappliedSpellCorrection(const VisibleSelection&, const String& corrected, const String& correction) UNLESS_ENABLED({ UNUSED_PARAM(corrected); UNUSED_PARAM(correction); })
    void respondToAppliedEditing(CompositeEditCommand*) UNLESS_ENABLED({ })
    void respondToUnappliedEditing(EditCommandComposition*) UNLESS_ENABLED({ })
    void respondToChangedSelection(const VisibleSelection& oldSelection) UNLESS_ENABLED({ UNUSED_PARAM(oldSelection); })

    void stopPendingCorrection(const VisibleSelection& oldSelection) UNLESS_ENABLED({ UNUSED_PARAM(oldSelection); })
    void applyPendingCorrection(const VisibleSelection& selectionAfterTyping) UNLESS_ENABLED({ UNUSED_PARAM(selectionAfterTyping); })

    void handleCorrectionPanelResult(const String& correction) UNLESS_ENABLED({ UNUSED_PARAM(correction); })
    void handleCancelOperation() UNLESS_ENABLED({})

    bool hasPendingCorrection() const UNLESS_ENABLED({ return false; })
    bool isSpellingMarkerAllowed(PassRefPtr<Range> misspellingRange) const UNLESS_ENABLED({ UNUSED_PARAM(misspellingRange); return true; })
    bool isAutomaticSpellingCorrectionEnabled() UNLESS_ENABLED({ return false; })
    bool shouldRemoveMarkersUponEditing();

    void correctionPanelTimerFired(Timer<SpellingCorrectionController>*) UNLESS_ENABLED({})
    void recordAutocorrectionResponseReversed(const String& replacedString, PassRefPtr<Range> replacementRange) UNLESS_ENABLED({ UNUSED_PARAM(replacedString); UNUSED_PARAM(replacementRange); })
    void markReversed(PassRefPtr<Range> changedRange) UNLESS_ENABLED({ UNUSED_PARAM(changedRange); })
    void markCorrection(PassRefPtr<Range> replacedRange, const String& replacedString) UNLESS_ENABLED({ UNUSED_PARAM(replacedRange); UNUSED_PARAM(replacedString); })
    void recordSpellcheckerResponseForModifiedCorrection(Range* rangeOfCorrection, const String& corrected, const String& correction) UNLESS_ENABLED({ UNUSED_PARAM(rangeOfCorrection); UNUSED_PARAM(corrected); UNUSED_PARAM(correction); })

    // This function returns false if the replacement should not be carried out.
    bool processMarkersOnTextToBeReplacedByResult(const TextCheckingResult*, Range* rangeToBeReplaced, const String& stringToBeReplaced) UNLESS_ENABLED({ UNUSED_PARAM(rangeToBeReplaced); UNUSED_PARAM(stringToBeReplaced); return true; });
    void deletedAutocorrectionAtPosition(const Position&, const String& originalString) UNLESS_ENABLED({ UNUSED_PARAM(originalString); })

#if USE(AUTOCORRECTION_PANEL)
private:
    void recordAutocorrectionResponseReversed(const String& replacedString, const String& replacementString);

    bool shouldStartTimerFor(const DocumentMarker* marker, int endOffset) const
    {
        return (((marker->type() == DocumentMarker::Replacement && !marker->description().isNull()) 
                 || marker->type() == DocumentMarker::Spelling) && static_cast<int>(marker->endOffset()) == endOffset);
    }

    EditorClient* client();
    TextCheckerClient* textChecker();
    FloatRect rootViewRectForRange(const Range*) const;
    void markPrecedingWhitespaceForDeletedAutocorrectionAfterCommand(EditCommand*);

    EditorClient* m_client;
    Frame* m_frame;

    Timer<SpellingCorrectionController> m_correctionPanelTimer;
    CorrectionPanelInfo m_correctionPanelInfo;
    bool m_correctionPanelIsDismissedByEditor;

    String m_originalStringForLastDeletedAutocorrection;
    Position m_positionForLastDeletedAutocorrection;
#endif
};

#undef UNLESS_ENABLED

inline bool SpellingCorrectionController::shouldRemoveMarkersUponEditing()
{
#if USE(MARKER_REMOVAL_UPON_EDITING)
    return true;
#else
    return false;
#endif
}

} // namespace WebCore

#endif // SpellingCorrectionController_h
