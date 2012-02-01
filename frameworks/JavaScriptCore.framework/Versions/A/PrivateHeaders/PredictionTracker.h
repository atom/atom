/*
 * Copyright (C) 2011 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef PredictionTracker_h
#define PredictionTracker_h

#include "PredictedType.h"
#include <wtf/HashMap.h>

namespace JSC {

struct PredictionSlot {
public:
    PredictionSlot()
        : m_value(PredictNone)
    {
    }
    PredictedType m_value;
};

class PredictionTracker {
public:
    PredictionTracker()
    {
    }
    
    bool predictGlobalVar(unsigned varNumber, PredictedType prediction)
    {
        HashMap<unsigned, PredictionSlot>::iterator iter = m_globalVars.find(varNumber + 1);
        if (iter == m_globalVars.end()) {
            PredictionSlot predictionSlot;
            bool result = mergePrediction(predictionSlot.m_value, prediction);
            m_globalVars.add(varNumber + 1, predictionSlot);
            return result;
        }
        return mergePrediction(iter->second.m_value, prediction);
    }
    
    PredictedType getGlobalVarPrediction(unsigned varNumber)
    {
        HashMap<unsigned, PredictionSlot>::iterator iter = m_globalVars.find(varNumber + 1);
        if (iter == m_globalVars.end())
            return PredictNone;
        return iter->second.m_value;
    }
    
private:
    HashMap<unsigned, PredictionSlot> m_globalVars;
};

} // namespace JSC

#endif // PredictionTracker_h

