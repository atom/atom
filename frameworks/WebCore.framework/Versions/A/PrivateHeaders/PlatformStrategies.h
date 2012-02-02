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

#ifndef PlatformStrategies_h
#define PlatformStrategies_h

#if USE(PLATFORM_STRATEGIES)

namespace WebCore {

class CookiesStrategy;
class PluginStrategy;
class LocalizationStrategy;
class VisitedLinkStrategy;

class PlatformStrategies {
public:
    CookiesStrategy* cookiesStrategy()
    {
        if (!m_cookiesStrategy)
            m_cookiesStrategy = createCookiesStrategy();
        return m_cookiesStrategy;
    }

    PluginStrategy* pluginStrategy()
    {
        if (!m_pluginStrategy)
            m_pluginStrategy = createPluginStrategy();
        return m_pluginStrategy;
    }

    LocalizationStrategy* localizationStrategy()
    {
        if (!m_localizationStrategy)
            m_localizationStrategy = createLocalizationStrategy();
        return m_localizationStrategy;
    }

    VisitedLinkStrategy* visitedLinkStrategy()
    {
        if (!m_visitedLinkStrategy)
            m_visitedLinkStrategy = createVisitedLinkStrategy();
        return m_visitedLinkStrategy;
    }

protected:
    PlatformStrategies()
        : m_cookiesStrategy(0)
        , m_pluginStrategy(0)
        , m_localizationStrategy(0)
        , m_visitedLinkStrategy(0)
    {
    }

    virtual ~PlatformStrategies()
    {
    }

private:
    virtual CookiesStrategy* createCookiesStrategy() = 0;
    virtual PluginStrategy* createPluginStrategy() = 0;
    virtual LocalizationStrategy* createLocalizationStrategy();
    virtual VisitedLinkStrategy* createVisitedLinkStrategy() = 0;

    CookiesStrategy* m_cookiesStrategy;
    PluginStrategy* m_pluginStrategy;
    LocalizationStrategy* m_localizationStrategy;
    VisitedLinkStrategy* m_visitedLinkStrategy;
};

PlatformStrategies* platformStrategies();
void setPlatformStrategies(PlatformStrategies*);
bool hasPlatformStrategies();
    
} // namespace WebCore

#endif // USE(PLATFORM_STRATEGIES)

#endif // PlatformStrategies_h
