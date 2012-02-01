/*
 * Copyright (C) 2010 Apple Inc. All rights reserved.
 * Copyright (C) 2010 Igalia S.L
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef LocalizationStrategy_h
#define LocalizationStrategy_h

#if USE(PLATFORM_STRATEGIES)

#include <wtf/Forward.h>

namespace WebCore {

class IntSize;

class LocalizationStrategy {
public:    
    virtual String inputElementAltText() = 0;
    virtual String resetButtonDefaultLabel() = 0;
    virtual String searchableIndexIntroduction() = 0;
    virtual String submitButtonDefaultLabel() = 0;
    virtual String fileButtonChooseFileLabel() = 0;
    virtual String fileButtonChooseMultipleFilesLabel() = 0;
    virtual String fileButtonNoFileSelectedLabel() = 0;
    virtual String fileButtonNoFilesSelectedLabel() = 0;
    virtual String defaultDetailsSummaryText() = 0;

#if PLATFORM(MAC)
    virtual String copyImageUnknownFileLabel() = 0;
#endif

#if ENABLE(CONTEXT_MENUS)
    virtual String contextMenuItemTagOpenLinkInNewWindow() = 0;
    virtual String contextMenuItemTagDownloadLinkToDisk() = 0;
    virtual String contextMenuItemTagCopyLinkToClipboard() = 0;
    virtual String contextMenuItemTagOpenImageInNewWindow() = 0;
    virtual String contextMenuItemTagDownloadImageToDisk() = 0;
    virtual String contextMenuItemTagCopyImageToClipboard() = 0;
#if PLATFORM(QT) || PLATFORM(GTK) || PLATFORM(EFL)
    virtual String contextMenuItemTagCopyImageUrlToClipboard() = 0;
#endif
    virtual String contextMenuItemTagOpenFrameInNewWindow() = 0;
    virtual String contextMenuItemTagCopy() = 0;
    virtual String contextMenuItemTagGoBack() = 0;
    virtual String contextMenuItemTagGoForward() = 0;
    virtual String contextMenuItemTagStop() = 0;
    virtual String contextMenuItemTagReload() = 0;
    virtual String contextMenuItemTagCut() = 0;
    virtual String contextMenuItemTagPaste() = 0;
#if PLATFORM(GTK)
    virtual String contextMenuItemTagDelete() = 0;
    virtual String contextMenuItemTagInputMethods() = 0;
    virtual String contextMenuItemTagUnicode() = 0;
#endif
#if PLATFORM(GTK) || PLATFORM(QT) || PLATFORM(EFL)
    virtual String contextMenuItemTagSelectAll() = 0;
#endif
    virtual String contextMenuItemTagNoGuessesFound() = 0;
    virtual String contextMenuItemTagIgnoreSpelling() = 0;
    virtual String contextMenuItemTagLearnSpelling() = 0;
    virtual String contextMenuItemTagSearchWeb() = 0;
    virtual String contextMenuItemTagLookUpInDictionary(const String& selectedString) = 0;
    virtual String contextMenuItemTagOpenLink() = 0;
    virtual String contextMenuItemTagIgnoreGrammar() = 0;
    virtual String contextMenuItemTagSpellingMenu() = 0;
    virtual String contextMenuItemTagShowSpellingPanel(bool show) = 0;
    virtual String contextMenuItemTagCheckSpelling() = 0;
    virtual String contextMenuItemTagCheckSpellingWhileTyping() = 0;
    virtual String contextMenuItemTagCheckGrammarWithSpelling() = 0;
    virtual String contextMenuItemTagFontMenu() = 0;
    virtual String contextMenuItemTagBold() = 0;
    virtual String contextMenuItemTagItalic() = 0;
    virtual String contextMenuItemTagUnderline() = 0;
    virtual String contextMenuItemTagOutline() = 0;
    virtual String contextMenuItemTagWritingDirectionMenu() = 0;
    virtual String contextMenuItemTagTextDirectionMenu() = 0;
    virtual String contextMenuItemTagDefaultDirection() = 0;
    virtual String contextMenuItemTagLeftToRight() = 0;
    virtual String contextMenuItemTagRightToLeft() = 0;
#if PLATFORM(MAC)
    virtual String contextMenuItemTagSearchInSpotlight() = 0;
    virtual String contextMenuItemTagShowFonts() = 0;
    virtual String contextMenuItemTagStyles() = 0;
    virtual String contextMenuItemTagShowColors() = 0;
    virtual String contextMenuItemTagSpeechMenu() = 0;
    virtual String contextMenuItemTagStartSpeaking() = 0;
    virtual String contextMenuItemTagStopSpeaking() = 0;
    virtual String contextMenuItemTagCorrectSpellingAutomatically() = 0;
    virtual String contextMenuItemTagSubstitutionsMenu() = 0;
    virtual String contextMenuItemTagShowSubstitutions(bool show) = 0;
    virtual String contextMenuItemTagSmartCopyPaste() = 0;
    virtual String contextMenuItemTagSmartQuotes() = 0;
    virtual String contextMenuItemTagSmartDashes() = 0;
    virtual String contextMenuItemTagSmartLinks() = 0;
    virtual String contextMenuItemTagTextReplacement() = 0;
    virtual String contextMenuItemTagTransformationsMenu() = 0;
    virtual String contextMenuItemTagMakeUpperCase() = 0;
    virtual String contextMenuItemTagMakeLowerCase() = 0;
    virtual String contextMenuItemTagCapitalize() = 0;
    virtual String contextMenuItemTagChangeBack(const String& replacedString) = 0;
#endif
    virtual String contextMenuItemTagOpenVideoInNewWindow() = 0;
    virtual String contextMenuItemTagOpenAudioInNewWindow() = 0;
    virtual String contextMenuItemTagCopyVideoLinkToClipboard() = 0;
    virtual String contextMenuItemTagCopyAudioLinkToClipboard() = 0;
    virtual String contextMenuItemTagToggleMediaControls() = 0;
    virtual String contextMenuItemTagToggleMediaLoop() = 0;
    virtual String contextMenuItemTagEnterVideoFullscreen() = 0;
    virtual String contextMenuItemTagMediaPlay() = 0;
    virtual String contextMenuItemTagMediaPause() = 0;
    virtual String contextMenuItemTagMediaMute() = 0;
    virtual String contextMenuItemTagInspectElement() = 0;
#endif // ENABLE(CONTEXT_MENUS)

    virtual String searchMenuNoRecentSearchesText() = 0;
    virtual String searchMenuRecentSearchesText() = 0;
    virtual String searchMenuClearRecentSearchesText() = 0;

    virtual String AXWebAreaText() = 0;
    virtual String AXLinkText() = 0;
    virtual String AXListMarkerText() = 0;
    virtual String AXImageMapText() = 0;
    virtual String AXHeadingText() = 0;
    virtual String AXDefinitionListTermText() = 0;
    virtual String AXDefinitionListDefinitionText() = 0;

#if PLATFORM(MAC)
    virtual String AXARIAContentGroupText(const String& ariaType) = 0;
#endif
    
    virtual String AXButtonActionVerb() = 0;
    virtual String AXRadioButtonActionVerb() = 0;
    virtual String AXTextFieldActionVerb() = 0;
    virtual String AXCheckedCheckBoxActionVerb() = 0;
    virtual String AXUncheckedCheckBoxActionVerb() = 0;
    virtual String AXMenuListActionVerb() = 0;
    virtual String AXMenuListPopupActionVerb() = 0;
    virtual String AXLinkActionVerb() = 0;

    virtual String missingPluginText() = 0;
    virtual String crashedPluginText() = 0;
    virtual String multipleFileUploadText(unsigned numberOfFiles) = 0;
    virtual String unknownFileSizeText() = 0;

#if PLATFORM(WIN)
    virtual String uploadFileText() = 0;
    virtual String allFilesText() = 0;
#endif

#if PLATFORM(MAC)
    virtual String builtInPDFPluginName() = 0;
    virtual String pdfDocumentTypeDescription() = 0;
    virtual String keygenMenuItem512() = 0;
    virtual String keygenMenuItem1024() = 0;
    virtual String keygenMenuItem2048() = 0;
    virtual String keygenKeychainItemName(const String& host) = 0;
#endif

    virtual String imageTitle(const String& filename, const IntSize& size) = 0;

    virtual String mediaElementLoadingStateText() = 0;
    virtual String mediaElementLiveBroadcastStateText() = 0;
    virtual String localizedMediaControlElementString(const String&) = 0;
    virtual String localizedMediaControlElementHelpText(const String&) = 0;
    virtual String localizedMediaTimeDescription(float) = 0;

    virtual String validationMessageValueMissingText() = 0;
    virtual String validationMessageTypeMismatchText() = 0;
    virtual String validationMessagePatternMismatchText() = 0;
    virtual String validationMessageTooLongText() = 0;
    virtual String validationMessageRangeUnderflowText() = 0;
    virtual String validationMessageRangeOverflowText() = 0;
    virtual String validationMessageStepMismatchText() = 0;

protected:
    virtual ~LocalizationStrategy()
    {
    }
};

} // namespace WebCore

#endif // USE(PLATFORM_STRATEGIES)

#endif // LocalizationStrategy_h
