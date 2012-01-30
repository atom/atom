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

#ifndef Options_h
#define Options_h

#include <stdint.h>

namespace JSC { namespace Options {

extern unsigned maximumOptimizationCandidateInstructionCount;

extern unsigned maximumFunctionForCallInlineCandidateInstructionCount;
extern unsigned maximumFunctionForConstructInlineCandidateInstructionCount;

extern unsigned maximumInliningDepth; // Depth of inline stack, so 1 = no inlining, 2 = one level, etc.

extern int32_t executionCounterValueForOptimizeAfterWarmUp;
extern int32_t executionCounterValueForOptimizeAfterLongWarmUp;
extern int32_t executionCounterValueForDontOptimizeAnytimeSoon;
extern int32_t executionCounterValueForOptimizeSoon;
extern int32_t executionCounterValueForOptimizeNextInvocation;

extern int32_t executionCounterIncrementForLoop;
extern int32_t executionCounterIncrementForReturn;

extern unsigned desiredSpeculativeSuccessFailRatio;

extern double likelyToTakeSlowCaseThreshold;
extern double couldTakeSlowCaseThreshold;
extern unsigned likelyToTakeSlowCaseMinimumCount;
extern unsigned couldTakeSlowCaseMinimumCount;

extern double osrExitProminenceForFrequentExitSite;

extern unsigned largeFailCountThresholdBase;
extern unsigned largeFailCountThresholdBaseForLoop;

extern unsigned reoptimizationRetryCounterMax;
extern unsigned reoptimizationRetryCounterStep;

extern unsigned minimumOptimizationDelay;
extern unsigned maximumOptimizationDelay;
extern double desiredProfileLivenessRate;
extern double desiredProfileFullnessRate;

extern double doubleVoteRatioForDoubleFormat;

extern unsigned minimumNumberOfScansBetweenRebalance;
extern unsigned gcMarkStackSegmentSize;
extern unsigned minimumNumberOfCellsToKeep;
extern unsigned maximumNumberOfSharedSegments;
extern unsigned sharedStackWakeupThreshold;
JS_EXPORTDATA extern unsigned numberOfGCMarkers;
JS_EXPORTDATA extern unsigned opaqueRootMergeThreshold;

void initializeOptions();

} } // namespace JSC::Options

#endif // Options_h

