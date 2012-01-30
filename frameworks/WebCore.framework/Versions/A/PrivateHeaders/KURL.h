/*
 * Copyright (C) 2003, 2004, 2005, 2006, 2007, 2008, 2011 Apple Inc. All rights reserved.
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

#ifndef KURL_h
#define KURL_h

#include "PlatformString.h"
#include "URLString.h"
#include <wtf/HashMap.h>

#if USE(CF)
typedef const struct __CFURL* CFURLRef;
#endif

#if PLATFORM(MAC) || (PLATFORM(QT) && USE(QTKIT))
OBJC_CLASS NSURL;
#endif

#if PLATFORM(QT)
QT_BEGIN_NAMESPACE
class QUrl;
QT_END_NAMESPACE
#endif

#if USE(GOOGLEURL)
#include "KURLGooglePrivate.h"
#endif

#if USE(JSC)
#include <runtime/UString.h>
#endif

namespace WebCore {

class TextEncoding;
struct KURLHash;

typedef HashMap<String, String> ParsedURLParameters;

enum ParsedURLStringTag { ParsedURLString };

class KURL {
public:
    // Generates a URL which contains a null string.
    KURL() { invalidate(); }

    // The argument is an absolute URL string. The string is assumed to be output of KURL::string() called on a valid
    // KURL object, or indiscernible from such.
    // It is usually best to avoid repeatedly parsing a string, unless memory saving outweigh the possible slow-downs.
    KURL(ParsedURLStringTag, const String&);
    KURL(ParsedURLStringTag, const URLString&);
#if USE(GOOGLEURL)
    KURL(WTF::HashTableDeletedValueType) : m_url(WTF::HashTableDeletedValue) { }
#else
    KURL(WTF::HashTableDeletedValueType) : m_string(WTF::HashTableDeletedValue) { }
#endif
    bool isHashTableDeletedValue() const { return string().isHashTableDeletedValue(); }

    // Resolves the relative URL with the given base URL. If provided, the
    // TextEncoding is used to encode non-ASCII characers. The base URL can be
    // null or empty, in which case the relative URL will be interpreted as
    // absolute.
    // FIXME: If the base URL is invalid, this always creates an invalid
    // URL. Instead I think it would be better to treat all invalid base URLs
    // the same way we treate null and empty base URLs.
    KURL(const KURL& base, const String& relative);
    KURL(const KURL& base, const String& relative, const TextEncoding&);

#if USE(GOOGLEURL)
    // For conversions from other structures that have already parsed and
    // canonicalized the URL. The input must be exactly what KURL would have
    // done with the same input.
    KURL(const CString& canonicalSpec, const url_parse::Parsed&, bool isValid);
#endif

    String strippedForUseAsReferrer() const;

    // FIXME: The above functions should be harmonized so that passing a
    // base of null or the empty string gives the same result as the
    // standard String constructor.

    // Makes a deep copy. Helpful only if you need to use a KURL on another
    // thread.  Since the underlying StringImpl objects are immutable, there's
    // no other reason to ever prefer copy() over plain old assignment.
    KURL copy() const;

    bool isNull() const;
    bool isEmpty() const;
    bool isValid() const;

    // Returns true if this URL has a path. Note that "http://foo.com/" has a
    // path of "/", so this function will return true. Only invalid or
    // non-hierarchical (like "javascript:") URLs will have no path.
    bool hasPath() const;

    // Returns true if you can set the host and port for the URL.
    // Non-hierarchical URLs don't have a host and port.
    bool canSetHostOrPort() const { return isHierarchical(); }

    bool canSetPathname() const { return isHierarchical(); }

#if USE(GOOGLEURL)
    const String& string() const { return m_url.string(); }
    URLString urlString() const { return URLString(m_url.string()); }
#else
    const String& string() const { return m_string; }
    URLString urlString() const { return URLString(m_string); }
#endif

    String protocol() const;
    String host() const;
    unsigned short port() const;
    bool hasPort() const;
    String user() const;
    String pass() const;
    String path() const;
    String lastPathComponent() const;
    String query() const;
    String fragmentIdentifier() const;
    bool hasFragmentIdentifier() const;

    void copyParsedQueryTo(ParsedURLParameters&) const;

    String baseAsString() const;

    // This function is only used by location.href. It's likely we shouldn't
    // use it for that purpose, but more study is necessary before we remove it.
    String deprecatedString() const;
    String fileSystemPath() const;

    // Returns true if the current URL's protocol is the same as the null-
    // terminated ASCII argument. The argument must be lower-case.
    bool protocolIs(const char*) const;
    bool protocolIsData() const { return protocolIs("data"); }
    bool protocolIsInHTTPFamily() const;
    bool isLocalFile() const;

    bool setProtocol(const String&);
    void setHost(const String&);

    void removePort();
    void setPort(unsigned short);

    // Input is like "foo.com" or "foo.com:8000".
    void setHostAndPort(const String&);

    void setUser(const String&);
    void setPass(const String&);

    // If you pass an empty path for HTTP or HTTPS URLs, the resulting path
    // will be "/".
    void setPath(const String&);

    // The query may begin with a question mark, or, if not, one will be added
    // for you. Setting the query to the empty string will leave a "?" in the
    // URL (with nothing after it). To clear the query, pass a null string.
    void setQuery(const String&);

    void setFragmentIdentifier(const String&);
    void removeFragmentIdentifier();

    friend bool equalIgnoringFragmentIdentifier(const KURL&, const KURL&);

    friend bool protocolHostAndPortAreEqual(const KURL&, const KURL&);

    unsigned hostStart() const;
    unsigned hostEnd() const;

    unsigned pathStart() const;
    unsigned pathEnd() const;
    unsigned pathAfterLastSlash() const;

    operator const String&() const { return string(); }

#if USE(CF)
    KURL(CFURLRef);
    CFURLRef createCFURL() const;
#endif

#if PLATFORM(MAC) || (PLATFORM(QT) && USE(QTKIT))
    KURL(NSURL*);
    operator NSURL*() const;
#endif
#ifdef __OBJC__
    operator NSString*() const { return string(); }
#endif

#if PLATFORM(QT)
    KURL(const QUrl&);
    operator QUrl() const;
#endif

#if USE(GOOGLEURL)
    // Getters for the parsed structure and its corresponding 8-bit string.
    const url_parse::Parsed& parsed() const { return m_url.m_parsed; }
    const CString& utf8String() const { return m_url.utf8String(); }
#endif


#if USE(GOOGLEURL)
    const KURL* innerURL() const { return m_url.innerURL(); }
#else
    const KURL* innerURL() const { return 0; }
#endif

#ifndef NDEBUG
    void print() const;
#endif

    // FIXME: Remove this after changing all callers to use protocolIsInHTTPFamily.
    bool protocolInHTTPFamily() const { return protocolIsInHTTPFamily(); }

private:
    void invalidate();
    bool isHierarchical() const;
    static bool protocolIs(const String&, const char*);
#if USE(GOOGLEURL)
    friend class KURLGooglePrivate;
    KURLGooglePrivate m_url;
#else  // !USE(GOOGLEURL)
    void init(const KURL&, const String&, const TextEncoding&);
    void copyToBuffer(Vector<char, 512>& buffer) const;

    // Parses the given URL. The originalString parameter allows for an
    // optimization: When the source is the same as the fixed-up string,
    // it will use the passed-in string instead of allocating a new one.
    void parse(const String&);
    void parse(const char* url, const String* originalString = 0);

    String m_string;
    bool m_isValid : 1;
    bool m_protocolIsInHTTPFamily : 1;

    int m_schemeEnd;
    int m_userStart;
    int m_userEnd;
    int m_passwordEnd;
    int m_hostEnd;
    int m_portEnd;
    int m_pathAfterLastSlash;
    int m_pathEnd;
    int m_queryEnd;
    int m_fragmentEnd;
#endif
};

bool operator==(const KURL&, const KURL&);
bool operator==(const KURL&, const String&);
bool operator==(const String&, const KURL&);
bool operator!=(const KURL&, const KURL&);
bool operator!=(const KURL&, const String&);
bool operator!=(const String&, const KURL&);

bool equalIgnoringFragmentIdentifier(const KURL&, const KURL&);
bool protocolHostAndPortAreEqual(const KURL&, const KURL&);
    
const KURL& blankURL();

// Functions to do URL operations on strings.
// These are operations that aren't faster on a parsed URL.
// These are also different from the KURL functions in that they don't require the string to be a valid and parsable URL.
// This is especially important because valid javascript URLs are not necessarily considered valid by KURL.

bool protocolIs(const String& url, const char* protocol);
bool protocolIsInHTTPFamily(const String& url);
bool protocolIsJavaScript(const String& url);

bool isDefaultPortForProtocol(unsigned short port, const String& protocol);
bool portAllowed(const KURL&); // Blacklist ports that should never be used for Web resources.

bool isValidProtocol(const String&);

String mimeTypeFromDataURL(const String& url);

// Unescapes the given string using URL escaping rules, given an optional
// encoding (defaulting to UTF-8 otherwise). DANGER: If the URL has "%00"
// in it, the resulting string will have embedded null characters!
String decodeURLEscapeSequences(const String&);
String decodeURLEscapeSequences(const String&, const TextEncoding&);

String encodeWithURLEscapeSequences(const String&);

// Inlines.

inline bool operator==(const KURL& a, const KURL& b)
{
    return a.string() == b.string();
}

inline bool operator==(const KURL& a, const String& b)
{
    return a.string() == b;
}

inline bool operator==(const String& a, const KURL& b)
{
    return a == b.string();
}

inline bool operator!=(const KURL& a, const KURL& b)
{
    return a.string() != b.string();
}

inline bool operator!=(const KURL& a, const String& b)
{
    return a.string() != b;
}

inline bool operator!=(const String& a, const KURL& b)
{
    return a != b.string();
}

#if !USE(GOOGLEURL)

// Inline versions of some non-GoogleURL functions so we can get inlining
// without having to have a lot of ugly ifdefs in the class definition.

inline bool KURL::isNull() const
{
    return m_string.isNull();
}

inline bool KURL::isEmpty() const
{
    return m_string.isEmpty();
}

inline bool KURL::isValid() const
{
    return m_isValid;
}

inline bool KURL::hasPort() const
{
    return m_hostEnd < m_portEnd;
}

inline bool KURL::protocolIsInHTTPFamily() const
{
    return m_protocolIsInHTTPFamily;
}

inline unsigned KURL::hostStart() const
{
    return (m_passwordEnd == m_userStart) ? m_passwordEnd : m_passwordEnd + 1;
}

inline unsigned KURL::hostEnd() const
{
    return m_hostEnd;
}

inline unsigned KURL::pathStart() const
{
    return m_portEnd;
}

inline unsigned KURL::pathEnd() const
{
    return m_pathEnd;
}

inline unsigned KURL::pathAfterLastSlash() const
{
    return m_pathAfterLastSlash;
}

#endif  // !USE(GOOGLEURL)

} // namespace WebCore

namespace WTF {

    // KURLHash is the default hash for String
    template<typename T> struct DefaultHash;
    template<> struct DefaultHash<WebCore::KURL> {
        typedef WebCore::KURLHash Hash;
    };

} // namespace WTF

#endif // KURL_h
