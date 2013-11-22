//-------------------------------------------------------------------------------------------------
// <copyright file="wuautil.h" company="Outercurve Foundation">
//   Copyright (c) 2004, Outercurve Foundation.
//   This software is released under Microsoft Reciprocal License (MS-RL).
//   The license and further copyright text can be found in the file
//   LICENSE.TXT at the root directory of the distribution.
// </copyright>
//
// <summary>
//    Header for Windows Update Agent helpers.
// </summary>
//-------------------------------------------------------------------------------------------------

#pragma once


#if defined(__cplusplus)
extern "C" {
#endif

HRESULT DAPI WuaPauseAutomaticUpdates();

HRESULT DAPI WuaResumeAutomaticUpdates();

HRESULT DAPI WuaRestartRequired(
    __out BOOL* pfRestartRequired
    );

#if defined(__cplusplus)
}
#endif