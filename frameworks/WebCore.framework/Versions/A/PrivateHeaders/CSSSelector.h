/*
 * Copyright (C) 1999-2003 Lars Knoll (knoll@kde.org)
 *               1999 Waldo Bastian (bastian@kde.org)
 * Copyright (C) 2004, 2006, 2007, 2008, 2009, 2010 Apple Inc. All rights reserved.
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
 */

#ifndef CSSSelector_h
#define CSSSelector_h

#include "QualifiedName.h"
#include "RenderStyleConstants.h"
#include <wtf/Noncopyable.h>
#include <wtf/OwnPtr.h>
#include <wtf/PassOwnPtr.h>

namespace WebCore {
    class CSSSelectorList;

    // this class represents a selector for a StyleRule
    class CSSSelector {
        WTF_MAKE_NONCOPYABLE(CSSSelector); WTF_MAKE_FAST_ALLOCATED;
    public:
        CSSSelector()
            : m_relation(Descendant)
            , m_match(None)
            , m_pseudoType(PseudoNotParsed)
            , m_parsedNth(false)
            , m_isLastInSelectorList(false)
            , m_isLastInTagHistory(true)
            , m_hasRareData(false)
            , m_isForPage(false)
            , m_tag(anyQName())
        {
        }

        CSSSelector(const QualifiedName& qName)
            : m_relation(Descendant)
            , m_match(None)
            , m_pseudoType(PseudoNotParsed)
            , m_parsedNth(false)
            , m_isLastInSelectorList(false)
            , m_isLastInTagHistory(true)
            , m_hasRareData(false)
            , m_isForPage(false)
            , m_tag(qName)
        {
        }

        ~CSSSelector()
        {
            if (m_hasRareData)
                delete m_data.m_rareData;
            else if (m_data.m_value)
                m_data.m_value->deref();
        }

        /**
         * Re-create selector text from selector's data
         */
        String selectorText() const;

        // checks if the 2 selectors (including sub selectors) agree.
        bool operator==(const CSSSelector&);

        // tag == -1 means apply to all elements (Selector = *)

        unsigned specificity() const;

        /* how the attribute value has to match.... Default is Exact */
        enum Match {
            None = 0,
            Id,
            Class,
            Exact,
            Set,
            List,
            Hyphen,
            PseudoClass,
            PseudoElement,
            Contain, // css3: E[foo*="bar"]
            Begin, // css3: E[foo^="bar"]
            End, // css3: E[foo$="bar"]
            PagePseudoClass
        };

        enum Relation {
            Descendant = 0,
            Child,
            DirectAdjacent,
            IndirectAdjacent,
            SubSelector,
            ShadowDescendant
        };

        enum PseudoType {
            PseudoNotParsed = 0,
            PseudoUnknown,
            PseudoEmpty,
            PseudoFirstChild,
            PseudoFirstOfType,
            PseudoLastChild,
            PseudoLastOfType,
            PseudoOnlyChild,
            PseudoOnlyOfType,
            PseudoFirstLine,
            PseudoFirstLetter,
            PseudoNthChild,
            PseudoNthOfType,
            PseudoNthLastChild,
            PseudoNthLastOfType,
            PseudoLink,
            PseudoVisited,
            PseudoAny,
            PseudoAnyLink,
            PseudoAutofill,
            PseudoHover,
            PseudoDrag,
            PseudoFocus,
            PseudoActive,
            PseudoChecked,
            PseudoEnabled,
            PseudoFullPageMedia,
            PseudoDefault,
            PseudoDisabled,
            PseudoOptional,
            PseudoRequired,
            PseudoReadOnly,
            PseudoReadWrite,
            PseudoValid,
            PseudoInvalid,
            PseudoIndeterminate,
            PseudoTarget,
            PseudoBefore,
            PseudoAfter,
            PseudoLang,
            PseudoNot,
            PseudoResizer,
            PseudoRoot,
            PseudoScrollbar,
            PseudoScrollbarBack,
            PseudoScrollbarButton,
            PseudoScrollbarCorner,
            PseudoScrollbarForward,
            PseudoScrollbarThumb,
            PseudoScrollbarTrack,
            PseudoScrollbarTrackPiece,
            PseudoWindowInactive,
            PseudoCornerPresent,
            PseudoDecrement,
            PseudoIncrement,
            PseudoHorizontal,
            PseudoVertical,
            PseudoStart,
            PseudoEnd,
            PseudoDoubleButton,
            PseudoSingleButton,
            PseudoNoButton,
            PseudoSelection,
            PseudoInputListButton,
            PseudoLeftPage,
            PseudoRightPage,
            PseudoFirstPage,
#if ENABLE(FULLSCREEN_API)
            PseudoFullScreen,
            PseudoFullScreenDocument,
            PseudoFullScreenAncestor,
            PseudoAnimatingFullScreenTransition,
#endif
            PseudoInRange,
            PseudoOutOfRange,
        };

        enum MarginBoxType {
            TopLeftCornerMarginBox,
            TopLeftMarginBox,
            TopCenterMarginBox,
            TopRightMarginBox,
            TopRightCornerMarginBox,
            BottomLeftCornerMarginBox,
            BottomLeftMarginBox,
            BottomCenterMarginBox,
            BottomRightMarginBox,
            BottomRightCornerMarginBox,
            LeftTopMarginBox,
            LeftMiddleMarginBox,
            LeftBottomMarginBox,
            RightTopMarginBox,
            RightMiddleMarginBox,
            RightBottomMarginBox,
        };

        PseudoType pseudoType() const
        {
            if (m_pseudoType == PseudoNotParsed)
                extractPseudoType();
            return static_cast<PseudoType>(m_pseudoType);
        }

        static PseudoType parsePseudoType(const AtomicString&);
        static bool isUnknownPseudoType(const AtomicString&);
        static PseudoId pseudoId(PseudoType);

        // Selectors are kept in an array by CSSSelectorList. The next component of the selector is
        // the next item in the array.
        CSSSelector* tagHistory() const { return m_isLastInTagHistory ? 0 : const_cast<CSSSelector*>(this + 1); }

        bool hasTag() const { return m_tag != anyQName(); }

        const QualifiedName& tag() const { return m_tag; }
        // AtomicString is really just an AtomicStringImpl* so the cast below is safe.
        // FIXME: Perhaps call sites could be changed to accept AtomicStringImpl?
        const AtomicString& value() const { return *reinterpret_cast<const AtomicString*>(m_hasRareData ? &m_data.m_rareData->m_value : &m_data.m_value); }
        const QualifiedName& attribute() const;
        const AtomicString& argument() const { return m_hasRareData ? m_data.m_rareData->m_argument : nullAtom; }
        CSSSelectorList* selectorList() const { return m_hasRareData ? m_data.m_rareData->m_selectorList.get() : 0; }

        void setTag(const QualifiedName& value) { m_tag = value; }
        void setValue(const AtomicString&);
        void setAttribute(const QualifiedName&);
        void setArgument(const AtomicString&);
        void setSelectorList(PassOwnPtr<CSSSelectorList>);

        bool parseNth();
        bool matchNth(int count);

        bool matchesPseudoElement() const;
        bool isUnknownPseudoElement() const;
        bool isSiblingSelector() const;
        bool isAttributeSelector() const;

        Relation relation() const { return static_cast<Relation>(m_relation); }

        bool isLastInSelectorList() const { return m_isLastInSelectorList; }
        void setLastInSelectorList() { m_isLastInSelectorList = true; }
        bool isLastInTagHistory() const { return m_isLastInTagHistory; }
        void setNotLastInTagHistory() { m_isLastInTagHistory = false; }

        bool isSimple() const;

        bool isForPage() const { return m_isForPage; }
        void setForPage() { m_isForPage = true; }

        unsigned m_relation           : 3; // enum Relation
        mutable unsigned m_match      : 4; // enum Match
        mutable unsigned m_pseudoType : 8; // PseudoType

    private:
        bool m_parsedNth              : 1; // Used for :nth-*
        bool m_isLastInSelectorList   : 1;
        bool m_isLastInTagHistory     : 1;
        bool m_hasRareData            : 1;
        bool m_isForPage              : 1;

        unsigned specificityForOneSelector() const;
        unsigned specificityForPage() const;
        void extractPseudoType() const;

        struct RareData {
            WTF_MAKE_NONCOPYABLE(RareData); WTF_MAKE_FAST_ALLOCATED;
        public:
            RareData(PassRefPtr<AtomicStringImpl> value);
            ~RareData();

            bool parseNth();
            bool matchNth(int count);

            AtomicStringImpl* m_value; // Plain pointer to keep things uniform with the union.
            int m_a; // Used for :nth-*
            int m_b; // Used for :nth-*
            QualifiedName m_attribute; // used for attribute selector
            AtomicString m_argument; // Used for :contains, :lang and :nth-*
            OwnPtr<CSSSelectorList> m_selectorList; // Used for :-webkit-any and :not
        };
        void createRareData();

        union DataUnion {
            DataUnion() : m_value(0) { }
            AtomicStringImpl* m_value;
            RareData* m_rareData;
        } m_data;

        QualifiedName m_tag;
    };

inline const QualifiedName& CSSSelector::attribute() const
{
    ASSERT(isAttributeSelector());
    ASSERT(m_hasRareData);
    return m_data.m_rareData->m_attribute;
}

inline bool CSSSelector::matchesPseudoElement() const
{
    if (m_pseudoType == PseudoUnknown)
        extractPseudoType();
    return m_match == PseudoElement;
}

inline bool CSSSelector::isUnknownPseudoElement() const
{
    return m_match == PseudoElement && m_pseudoType == PseudoUnknown;
}

inline bool CSSSelector::isSiblingSelector() const
{
    PseudoType type = pseudoType();
    return m_relation == DirectAdjacent
        || m_relation == IndirectAdjacent
        || type == PseudoEmpty
        || type == PseudoFirstChild
        || type == PseudoFirstOfType
        || type == PseudoLastChild
        || type == PseudoLastOfType
        || type == PseudoOnlyChild
        || type == PseudoOnlyOfType
        || type == PseudoNthChild
        || type == PseudoNthOfType
        || type == PseudoNthLastChild
        || type == PseudoNthLastOfType;
}

inline bool CSSSelector::isAttributeSelector() const
{
    return m_match == CSSSelector::Exact
        || m_match ==  CSSSelector::Set
        || m_match == CSSSelector::List
        || m_match == CSSSelector::Hyphen
        || m_match == CSSSelector::Contain
        || m_match == CSSSelector::Begin
        || m_match == CSSSelector::End;
}

inline void CSSSelector::setValue(const AtomicString& value)
{
    // Need to do ref counting manually for the union.
    if (m_hasRareData) {
        if (m_data.m_rareData->m_value)
            m_data.m_rareData->m_value->deref();
        m_data.m_rareData->m_value = value.impl();
        m_data.m_rareData->m_value->ref();
        return;
    }
    if (m_data.m_value)
        m_data.m_value->deref();
    m_data.m_value = value.impl();
    m_data.m_value->ref();
}

inline void move(PassOwnPtr<CSSSelector> from, CSSSelector* to)
{
    memcpy(to, from.get(), sizeof(CSSSelector));
    // We want to free the memory (which was allocated with fastNew), but we
    // don't want the destructor to run since it will affect the copy we've just made.
    fastDeleteSkippingDestructor(from.leakPtr());
}

} // namespace WebCore

#endif // CSSSelector_h
