/*
 * Copyright (C) 2005, 2006, 2009 Apple Inc. All rights reserved.
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

#ifndef QualifiedName_h
#define QualifiedName_h

#include <wtf/HashTraits.h>
#include <wtf/RefCounted.h>
#include <wtf/text/AtomicString.h>

namespace WebCore {

struct QualifiedNameComponents {
    StringImpl* m_prefix;
    StringImpl* m_localName;
    StringImpl* m_namespace;
};

class QualifiedName {
    WTF_MAKE_FAST_ALLOCATED;
public:
    class QualifiedNameImpl : public RefCounted<QualifiedNameImpl> {
    public:
        static PassRefPtr<QualifiedNameImpl> create(const AtomicString& prefix, const AtomicString& localName, const AtomicString& namespaceURI)
        {
            return adoptRef(new QualifiedNameImpl(prefix, localName, namespaceURI));
        }

        const AtomicString m_prefix;
        const AtomicString m_localName;
        const AtomicString m_namespace;
        mutable AtomicString m_localNameUpper;

    private:
        QualifiedNameImpl(const AtomicString& prefix, const AtomicString& localName, const AtomicString& namespaceURI)
            : m_prefix(prefix)
            , m_localName(localName)
            , m_namespace(namespaceURI)
        {
            ASSERT(!namespaceURI.isEmpty() || namespaceURI.isNull());
        }        
    };

    QualifiedName(const AtomicString& prefix, const AtomicString& localName, const AtomicString& namespaceURI);
    QualifiedName(const AtomicString& prefix, const char* localName, const AtomicString& namespaceURI);
    QualifiedName(WTF::HashTableDeletedValueType) : m_impl(hashTableDeletedValue()) { }
    bool isHashTableDeletedValue() const { return m_impl == hashTableDeletedValue(); }
    ~QualifiedName();
#ifdef QNAME_DEFAULT_CONSTRUCTOR
    QualifiedName() : m_impl(0) { }
#endif

    QualifiedName(const QualifiedName& other) : m_impl(other.m_impl) { ref(); }
    const QualifiedName& operator=(const QualifiedName& other) { other.ref(); deref(); m_impl = other.m_impl; return *this; }

    bool operator==(const QualifiedName& other) const { return m_impl == other.m_impl; }
    bool operator!=(const QualifiedName& other) const { return !(*this == other); }

    bool matches(const QualifiedName& other) const { return m_impl == other.m_impl || (localName() == other.localName() && namespaceURI() == other.namespaceURI()); }

    bool hasPrefix() const { return m_impl->m_prefix != nullAtom; }
    void setPrefix(const AtomicString& prefix) { *this = QualifiedName(prefix, localName(), namespaceURI()); }

    const AtomicString& prefix() const { return m_impl->m_prefix; }
    const AtomicString& localName() const { return m_impl->m_localName; }
    const AtomicString& namespaceURI() const { return m_impl->m_namespace; }

    // Uppercased localName, cached for efficiency
    const AtomicString& localNameUpper() const;

    String toString() const;

    QualifiedNameImpl* impl() const { return m_impl; }
    
    // Init routine for globals
    static void init();
    
private:
    void init(const AtomicString& prefix, const AtomicString& localName, const AtomicString& namespaceURI);
    void ref() const { m_impl->ref(); }
    void deref();

    static QualifiedNameImpl* hashTableDeletedValue() { return RefPtr<QualifiedNameImpl>::hashTableDeletedValue(); }
    
    QualifiedNameImpl* m_impl;
};

#ifndef WEBCORE_QUALIFIEDNAME_HIDE_GLOBALS
extern const QualifiedName anyName;
inline const QualifiedName& anyQName() { return anyName; }
#endif

inline bool operator==(const AtomicString& a, const QualifiedName& q) { return a == q.localName(); }
inline bool operator!=(const AtomicString& a, const QualifiedName& q) { return a != q.localName(); }
inline bool operator==(const QualifiedName& q, const AtomicString& a) { return a == q.localName(); }
inline bool operator!=(const QualifiedName& q, const AtomicString& a) { return a != q.localName(); }

inline unsigned hashComponents(const QualifiedNameComponents& buf)
{
    return StringHasher::hashMemory<sizeof(QualifiedNameComponents)>(&buf);
}

struct QualifiedNameHash {
    static unsigned hash(const QualifiedName& name) { return hash(name.impl()); }

    static unsigned hash(const QualifiedName::QualifiedNameImpl* name) 
    {
        QualifiedNameComponents c = { name->m_prefix.impl(), name->m_localName.impl(), name->m_namespace.impl() };
        return hashComponents(c);
    }

    static bool equal(const QualifiedName& a, const QualifiedName& b) { return a == b; }
    static bool equal(const QualifiedName::QualifiedNameImpl* a, const QualifiedName::QualifiedNameImpl* b) { return a == b; }

    static const bool safeToCompareToEmptyOrDeleted = false;
};

}

namespace WTF {
    
    template<typename T> struct DefaultHash;

    template<> struct DefaultHash<WebCore::QualifiedName> {
        typedef WebCore::QualifiedNameHash Hash;
    };
    
    template<> struct HashTraits<WebCore::QualifiedName> : SimpleClassHashTraits<WebCore::QualifiedName> {
        static const bool emptyValueIsZero = false;
        static WebCore::QualifiedName emptyValue() { return WebCore::QualifiedName(nullAtom, nullAtom, nullAtom); }
    };
}

#endif
