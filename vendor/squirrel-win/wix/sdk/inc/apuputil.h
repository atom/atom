#pragma once
//-------------------------------------------------------------------------------------------------
// <copyright file="apuputil.h" company="Outercurve Foundation">
//   Copyright (c) 2004, Outercurve Foundation.
//   This software is released under Microsoft Reciprocal License (MS-RL).
//   The license and further copyright text can be found in the file
//   LICENSE.TXT at the root directory of the distribution.
// </copyright>
// 
// <summary>
//    Header for Application Update helper functions.
// </summary>
//-------------------------------------------------------------------------------------------------

#ifdef __cplusplus
extern "C" {
#endif

#define ReleaseApupChain(p) if (p) { ApupFreeChain(p); p = NULL; }
#define ReleaseNullApupChain(p) if (p) { ApupFreeChain(p); p = NULL; }


const LPCWSTR APPLICATION_SYNDICATION_NAMESPACE = L"http://appsyndication.org/2006/appsyn";

enum APUP_HASH_ALGORITHM
{
    APUP_HASH_ALGORITHM_UNKNOWN,
    APUP_HASH_ALGORITHM_MD5,
    APUP_HASH_ALGORITHM_SHA1,
    APUP_HASH_ALGORITHM_SHA256,
};


struct APPLICATION_UPDATE_ENCLOSURE
{
    LPWSTR wzUrl;
    LPWSTR wzLocalName;
    DWORD64 dw64Size;

    BYTE* rgbDigest;
    DWORD cbDigest;
    APUP_HASH_ALGORITHM digestAlgorithm;

    BOOL fInstaller;
};


struct APPLICATION_UPDATE_ENTRY
{
    LPWSTR wzApplicationId;
    LPWSTR wzApplicationType;

    LPWSTR wzUpgradeId;
    BOOL fUpgradeExclusive;
    DWORD64 dw64Version;
    DWORD64 dw64UpgradeVersion;

    DWORD64 dw64TotalSize;

    DWORD cEnclosures;
    APPLICATION_UPDATE_ENCLOSURE* rgEnclosures;
};


struct APPLICATION_UPDATE_CHAIN
{
    LPWSTR wzDefaultApplicationId;
    LPWSTR wzDefaultApplicationType;

    DWORD cEntries;
    APPLICATION_UPDATE_ENTRY* rgEntries;
};


HRESULT DAPI ApupAllocChainFromAtom(
    __in ATOM_FEED* pFeed,
    __out APPLICATION_UPDATE_CHAIN** ppChain
    );

HRESULT DAPI ApupFilterChain(
    __in APPLICATION_UPDATE_CHAIN* pChain,
    __in DWORD64 dw64Version,
    __out APPLICATION_UPDATE_CHAIN** ppFilteredChain
    );

void DAPI ApupFreeChain(
    __in APPLICATION_UPDATE_CHAIN* pChain
    );

#ifdef __cplusplus
}
#endif
