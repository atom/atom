/*
 * Copyright (C) 2005, 2006, 2008 Apple Inc. All rights reserved.
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

#ifndef EditCommand_h
#define EditCommand_h

#include "EditAction.h"
#include "VisibleSelection.h"

#ifndef NDEBUG
#include <wtf/HashSet.h>
#endif

namespace WebCore {

class CompositeEditCommand;
class Document;
class Element;

class EditCommand : public RefCounted<EditCommand> {
public:
    virtual ~EditCommand();

    void setParent(CompositeEditCommand*);

    virtual EditAction editingAction() const;

    const VisibleSelection& startingSelection() const { return m_startingSelection; }
    const VisibleSelection& endingSelection() const { return m_endingSelection; }

    virtual bool isSimpleEditCommand() const { return false; }
    virtual bool isCompositeEditCommand() const { return false; }
    virtual bool isEditCommandComposition() const { return false; }
    bool isTopLevelCommand() const { return !m_parent; }

    virtual void doApply() = 0;

protected:
    EditCommand(Document*);
    EditCommand(Document*, const VisibleSelection&, const VisibleSelection&);

    Document* document() const { return m_document.get(); }
    CompositeEditCommand* parent() const { return m_parent; }
    void setStartingSelection(const VisibleSelection&);
    void setEndingSelection(const VisibleSelection&);

private:
    RefPtr<Document> m_document;
    VisibleSelection m_startingSelection;
    VisibleSelection m_endingSelection;
    CompositeEditCommand* m_parent;
};

class SimpleEditCommand : public EditCommand {
public:
    virtual void doUnapply() = 0;
    virtual void doReapply(); // calls doApply()

#ifndef NDEBUG
    virtual void getNodesInCommand(HashSet<Node*>&) = 0;
#endif

protected:
    SimpleEditCommand(Document* document) : EditCommand(document) { }

#ifndef NDEBUG
    void addNodeAndDescendants(Node*, HashSet<Node*>&);
#endif

private:
    virtual bool isSimpleEditCommand() const OVERRIDE { return true; }
};

inline SimpleEditCommand* toSimpleEditCommand(EditCommand* command)
{
    ASSERT(command);
    ASSERT(command->isSimpleEditCommand());
    return static_cast<SimpleEditCommand*>(command);
}

} // namespace WebCore

#endif // EditCommand_h
