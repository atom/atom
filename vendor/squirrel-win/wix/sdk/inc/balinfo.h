#pragma once
//-------------------------------------------------------------------------------------------------
// <copyright file="balinfo.h" company="Outercurve Foundation">
//   Copyright (c) 2004, Outercurve Foundation.
//   This software is released under Microsoft Reciprocal License (MS-RL).
//   The license and further copyright text can be found in the file
//   LICENSE.TXT at the root directory of the distribution.
// </copyright>
//
// <summary>
// Bootstrapper Application Layer package utility.
// </summary>
//-------------------------------------------------------------------------------------------------


#ifdef __cplusplus
extern "C" {
#endif

enum BAL_INFO_PACKAGE_TYPE
{
    BAL_INFO_PACKAGE_TYPE_EXE,
    BAL_INFO_PACKAGE_TYPE_MSI,
    BAL_INFO_PACKAGE_TYPE_MSP,
    BAL_INFO_PACKAGE_TYPE_MSU,
};


typedef struct _BAL_INFO_PACKAGE
{
    LPWSTR sczId;
    LPWSTR sczDisplayName;
    LPWSTR sczDescription;
    BAL_INFO_PACKAGE_TYPE type;
    BOOL fPermanent;
    BOOL fVital;
    BOOL fDisplayInternalUI;
} BAL_INFO_PACKAGE;


typedef struct _BAL_INFO_PACKAGES
{
    BAL_INFO_PACKAGE* rgPackages;
    DWORD cPackages;
} BAL_INFO_PACKAGES;


typedef struct _BAL_INFO_BUNDLE
{
    BOOL fPerMachine;
    LPWSTR sczName;
    LPWSTR sczLogVariable;
    BAL_INFO_PACKAGES packages;
} BAL_INFO_BUNDLE;


/*******************************************************************
 BalInfoParseFromXml - loads the bundle and package info from the UX
                       manifest.

********************************************************************/
DAPI_(HRESULT) BalInfoParseFromXml(
    __in BAL_INFO_BUNDLE* pBundle,
    __in IXMLDOMDocument* pixdManifest
    );


/*******************************************************************
 BalInfoFindPackageById - finds a package by its id.

 ********************************************************************/
DAPI_(HRESULT) BalInfoFindPackageById(
    __in BAL_INFO_PACKAGES* pPackages,
    __in LPCWSTR wzId,
    __out BAL_INFO_PACKAGE** ppPackage
    );


/*******************************************************************
 BalInfoUninitialize - uninitializes any info previously loaded.

********************************************************************/
DAPI_(void) BalInfoUninitialize(
    __in BAL_INFO_BUNDLE* pBundle
    );


#ifdef __cplusplus
}
#endif
