/*
 * Copyright (C) 2000 Peter Kelly (pmk@post.com)
 * Copyright (C) 2005, 2006 Apple Computer, Inc.
 * Copyright (C) 2007 Samuel Weinig (sam@webkit.org)
 * Copyright (C) 2010 Google, Inc.
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

#ifndef DocumentParser_h
#define DocumentParser_h

#include <wtf/RefCounted.h>

namespace WebCore {

class Document;
class DocumentWriter;
class SegmentedString;
class ScriptableDocumentParser;

class DocumentParser : public RefCounted<DocumentParser> {
public:
    virtual ~DocumentParser();

    virtual ScriptableDocumentParser* asScriptableDocumentParser() { return 0; }

    // http://www.whatwg.org/specs/web-apps/current-work/#insertion-point
    virtual bool hasInsertionPoint() { return true; }

    // insert is used by document.write.
    virtual void insert(const SegmentedString&) = 0;

    // appendBytes and flush are used by DocumentWriter (the loader).
    virtual void appendBytes(DocumentWriter*, const char* bytes, size_t length) = 0;
    virtual void flush(DocumentWriter*) = 0;

    // FIXME: append() should be private, but DocumentWriter::replaceDocument
    // uses it for now.
    virtual void append(const SegmentedString&) = 0;

    virtual void finish() = 0;
    virtual bool finishWasCalled() = 0;

    // FIXME: processingData() is only used by DocumentLoader::isLoadingInAPISense
    // and is very unclear as to what it actually means.  The LegacyHTMLDocumentParser
    // used to implement it.
    virtual bool processingData() const { return false; }

    // document() will return 0 after detach() is called.
    Document* document() const { ASSERT(m_document); return m_document; }

    bool isParsing() const { return m_state == ParsingState; }
    bool isStopping() const { return m_state == StoppingState; }
    bool isStopped() const { return m_state >= StoppedState; }
    bool isDetached() const { return m_state == DetachedState; }

    // FIXME: Is this necessary? Does XMLDocumentParserLibxml2 really need to set this?
    virtual void startParsing();

    // prepareToStop() is used when the EOF token is encountered and parsing is to be
    // stopped normally.
    virtual void prepareToStopParsing();

    // stopParsing() is used when a load is canceled/stopped.
    // stopParsing() is currently different from detach(), but shouldn't be.
    // It should NOT be ok to call any methods on DocumentParser after either
    // detach() or stopParsing() but right now only detach() will ASSERT.
    virtual void stopParsing();

    // Document is expected to detach the parser before releasing its ref.
    // After detach, m_document is cleared.  The parser will unwind its
    // callstacks, but not produce any more nodes.
    // It is impossible for the parser to touch the rest of WebCore after
    // detach is called.
    virtual void detach();

    void setDocumentWasLoadedAsPartOfNavigation() { m_documentWasLoadedAsPartOfNavigation = true; }
    bool documentWasLoadedAsPartOfNavigation() const { return m_documentWasLoadedAsPartOfNavigation; }

    // FIXME: The names are not very accurate :(
    virtual void suspendScheduledTasks();
    virtual void resumeScheduledTasks();

protected:
    DocumentParser(Document*);

private:
    enum ParserState {
        ParsingState,
        StoppingState,
        StoppedState,
        DetachedState
    };
    ParserState m_state;
    bool m_documentWasLoadedAsPartOfNavigation;

    // Every DocumentParser needs a pointer back to the document.
    // m_document will be 0 after the parser is stopped.
    Document* m_document;
};

} // namespace WebCore

#endif // DocumentParser_h
