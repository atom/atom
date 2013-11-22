#pragma once
//-------------------------------------------------------------------------------------------------
// <copyright file="balretry.h" company="Outercurve Foundation">
//   Copyright (c) 2004, Outercurve Foundation.
//   This software is released under Microsoft Reciprocal License (MS-RL).
//   The license and further copyright text can be found in the file
//   LICENSE.TXT at the root directory of the distribution.
// </copyright>
//
// <summary>
// Bootstrapper Application Layer retry utility.
// </summary>
//-------------------------------------------------------------------------------------------------


#ifdef __cplusplus
extern "C" {
#endif

enum BALRETRY_TYPE
{
    BALRETRY_TYPE_CACHE,
    BALRETRY_TYPE_EXECUTE,
};

/*******************************************************************
 BalRetryInitialize - initialize the retry count and timeout between
                      retries (in milliseconds).
********************************************************************/
DAPI_(void) BalRetryInitialize(
    __in DWORD dwMaxRetries,
    __in DWORD dwTimeout
    );

/*******************************************************************
 BalRetryUninitialize - call to cleanup any memory allocated during
                        use of the retry utility.
********************************************************************/
DAPI_(void) BalRetryUninitialize();

/*******************************************************************
 BalRetryStartPackage - call when a package begins to be modified. If
                        the package is being retried, the function will
                        wait the specified timeout.
********************************************************************/
DAPI_(void) BalRetryStartPackage(
    __in BALRETRY_TYPE type,
    __in_z_opt LPCWSTR wzPackageId,
    __in_z_opt LPCWSTR wzPayloadId
    );

/*******************************************************************
 BalRetryErrorOccured - call when an error occurs for the retry utility
                        to consider.
********************************************************************/
DAPI_(void) BalRetryErrorOccurred(
    __in_z_opt LPCWSTR wzPackageId,
    __in DWORD dwError
    );

/*******************************************************************
 BalRetryEndPackage - returns IDRETRY is a retry is recommended or 
                      IDNOACTION if a retry is not recommended.
********************************************************************/
DAPI_(int) BalRetryEndPackage(
    __in BALRETRY_TYPE type,
    __in_z_opt LPCWSTR wzPackageId,
    __in_z_opt LPCWSTR wzPayloadId,
    __in HRESULT hrError
    );


#ifdef __cplusplus
}
#endif
