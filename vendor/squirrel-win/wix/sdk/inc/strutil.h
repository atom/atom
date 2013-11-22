#pragma once
//-------------------------------------------------------------------------------------------------
// <copyright file="strutil.h" company="Outercurve Foundation">
//   Copyright (c) 2004, Outercurve Foundation.
//   This software is released under Microsoft Reciprocal License (MS-RL).
//   The license and further copyright text can be found in the file
//   LICENSE.TXT at the root directory of the distribution.
// </copyright>
// 
// <summary>
//    Header for string helper functions.
// </summary>
//-------------------------------------------------------------------------------------------------

#ifdef __cplusplus
extern "C" {
#endif

#define ReleaseStr(pwz) if (pwz) { StrFree(pwz); }
#define ReleaseNullStr(pwz) if (pwz) { StrFree(pwz); pwz = NULL; }
#define ReleaseBSTR(bstr) if (bstr) { ::SysFreeString(bstr); }
#define ReleaseNullBSTR(bstr) if (bstr) { ::SysFreeString(bstr); bstr = NULL; }
#define ReleaseStrArray(rg, c) { if (rg) { StrArrayFree(rg, c); } }
#define ReleaseNullStrArray(rg, c) { if (rg) { StrArrayFree(rg, c); c = 0; rg = NULL; } }

#define DeclareConstBSTR(bstr_const, wz) const WCHAR bstr_const[] = { 0x00, 0x00, sizeof(wz)-sizeof(WCHAR), 0x00, wz }
#define UseConstBSTR(bstr_const) const_cast<BSTR>(bstr_const + 4)

HRESULT DAPI StrAlloc(
    __deref_out_ecount_part(cch, 0) LPWSTR* ppwz,
    __in DWORD_PTR cch
    );
HRESULT DAPI StrTrimCapacity(
    __deref_out_z LPWSTR* ppwz
    );
HRESULT DAPI StrTrimWhitespace(
    __deref_out_z LPWSTR* ppwz,
    __in_z LPCWSTR wzSource
    );
HRESULT DAPI StrAnsiAlloc(
    __deref_out_ecount_part(cch, 0) LPSTR* ppz,
    __in DWORD_PTR cch
    );
HRESULT DAPI StrAnsiTrimCapacity(
    __deref_out_z LPSTR* ppz
    );
HRESULT DAPI StrAnsiTrimWhitespace(
    __deref_out_z LPSTR* ppz,
    __in_z LPCSTR szSource
    );
HRESULT DAPI StrAllocString(
    __deref_out_ecount_z(cchSource+1) LPWSTR* ppwz,
    __in_z LPCWSTR wzSource,
    __in DWORD_PTR cchSource
    );
HRESULT DAPI StrAnsiAllocString(
    __deref_out_ecount_z(cchSource+1) LPSTR* ppsz,
    __in_z LPCWSTR wzSource,
    __in DWORD_PTR cchSource,
    __in UINT uiCodepage
    );
HRESULT DAPI StrAllocStringAnsi(
    __deref_out_ecount_z(cchSource+1) LPWSTR* ppwz,
    __in_z LPCSTR szSource,
    __in DWORD_PTR cchSource,
    __in UINT uiCodepage
    );
HRESULT DAPI StrAnsiAllocStringAnsi(
    __deref_out_ecount_z(cchSource+1) LPSTR* ppsz,
    __in_z LPCSTR szSource,
    __in DWORD_PTR cchSource
    );
HRESULT DAPI StrAllocPrefix(
    __deref_out_z LPWSTR* ppwz,
    __in_z LPCWSTR wzPrefix,
    __in DWORD_PTR cchPrefix
    );
HRESULT DAPI StrAllocConcat(
    __deref_out_z LPWSTR* ppwz,
    __in_z LPCWSTR wzSource,
    __in DWORD_PTR cchSource
    );
HRESULT DAPI StrAnsiAllocConcat(
    __deref_out_z LPSTR* ppz,
    __in_z LPCSTR pzSource,
    __in DWORD_PTR cchSource
    );
HRESULT __cdecl StrAllocFormatted(
    __deref_out_z LPWSTR* ppwz,
    __in __format_string LPCWSTR wzFormat,
    ...
    );
HRESULT __cdecl StrAnsiAllocFormatted(
    __deref_out_z LPSTR* ppsz,
    __in __format_string LPCSTR szFormat,
    ...
    );
HRESULT DAPI StrAllocFormattedArgs(
    __deref_out_z LPWSTR* ppwz,
    __in __format_string LPCWSTR wzFormat,
    __in va_list args
    );
HRESULT DAPI StrAnsiAllocFormattedArgs(
    __deref_out_z LPSTR* ppsz,
    __in __format_string LPCSTR szFormat,
    __in va_list args
    );
HRESULT DAPI StrAllocFromError(
    __inout LPWSTR *ppwzMessage,
    __in HRESULT hrError,
    __in_opt HMODULE hModule,
    ...
    );

HRESULT DAPI StrMaxLength(
    __in LPCVOID p,
    __out DWORD_PTR* pcch
    );
HRESULT DAPI StrSize(
    __in LPCVOID p,
    __out DWORD_PTR* pcb
    );

HRESULT DAPI StrFree(
    __in LPVOID p
    );


HRESULT DAPI StrReplaceStringAll(
    __inout LPWSTR* ppwzOriginal,
    __in_z LPCWSTR wzOldSubString,
    __in_z LPCWSTR wzNewSubString
    );
HRESULT DAPI StrReplaceString(
    __inout LPWSTR* ppwzOriginal,
    __inout DWORD* pdwStartIndex,
    __in_z LPCWSTR wzOldSubString,
    __in_z LPCWSTR wzNewSubString
    );

HRESULT DAPI StrHexEncode(
    __in_ecount(cbSource) const BYTE* pbSource,
    __in DWORD_PTR cbSource,
    __out_ecount(cchDest) LPWSTR wzDest,
    __in DWORD_PTR cchDest
    );
HRESULT DAPI StrHexDecode(
    __in_z LPCWSTR wzSource,
    __out_bcount(cbDest) BYTE* pbDest,
    __in DWORD_PTR cbDest
    );
HRESULT DAPI StrAllocHexDecode(
    __in_z LPCWSTR wzSource,
    __out_bcount(*pcbDest) BYTE** ppbDest,
    __out_opt DWORD* pcbDest
    );

HRESULT DAPI StrAllocBase85Encode(
    __in_bcount_opt(cbSource) const BYTE* pbSource,
    __in DWORD_PTR cbSource,
    __deref_out_z LPWSTR* pwzDest
    );
HRESULT DAPI StrAllocBase85Decode(
    __in_z LPCWSTR wzSource,
    __deref_out_bcount(*pcbDest) BYTE** hbDest,
    __out DWORD_PTR* pcbDest
    );

HRESULT DAPI MultiSzLen(
    __in_ecount(*pcch) __nullnullterminated LPCWSTR pwzMultiSz,
    __out DWORD_PTR* pcch
    );
HRESULT DAPI MultiSzPrepend(
    __deref_inout_ecount(*pcchMultiSz) __nullnullterminated LPWSTR* ppwzMultiSz,
    __inout_opt DWORD_PTR *pcchMultiSz,
    __in __nullnullterminated LPCWSTR pwzInsert
    );
HRESULT DAPI MultiSzFindSubstring(
    __in __nullnullterminated LPCWSTR pwzMultiSz,
    __in __nullnullterminated LPCWSTR pwzSubstring,
    __out_opt DWORD_PTR* pdwIndex,
    __deref_opt_out_z LPCWSTR* ppwzFoundIn
    );
HRESULT DAPI MultiSzFindString(
    __in __nullnullterminated LPCWSTR pwzMultiSz,
    __in __nullnullterminated LPCWSTR pwzString,
    __out_opt DWORD_PTR* pdwIndex,
    __deref_opt_out __nullnullterminated LPCWSTR* ppwzFound
    );
HRESULT DAPI MultiSzRemoveString(
    __deref_inout __nullnullterminated LPWSTR* ppwzMultiSz,
    __in DWORD_PTR dwIndex
    );
HRESULT DAPI MultiSzInsertString(
    __deref_inout_z LPWSTR* ppwzMultiSz,
    __inout_opt DWORD_PTR *pcchMultiSz,
    __in DWORD_PTR dwIndex,
    __in_z LPCWSTR pwzInsert
    );
HRESULT DAPI MultiSzReplaceString(
    __deref_inout __nullnullterminated LPWSTR* ppwzMultiSz,
    __in DWORD_PTR dwIndex,
    __in_z LPCWSTR pwzString
    );

LPCWSTR wcsistr(
    __in_z LPCWSTR wzString,
    __in_z LPCWSTR wzCharSet
    );

HRESULT DAPI StrStringToInt16(
    __in_z LPCWSTR wzIn,
    __in DWORD cchIn,
    __out SHORT* psOut
    );
HRESULT DAPI StrStringToUInt16(
    __in_z LPCWSTR wzIn,
    __in DWORD cchIn,
    __out USHORT* pusOut
    );
HRESULT DAPI StrStringToInt32(
    __in_z LPCWSTR wzIn,
    __in DWORD cchIn,
    __out INT* piOut
    );
HRESULT DAPI StrStringToUInt32(
    __in_z LPCWSTR wzIn,
    __in DWORD cchIn,
    __out UINT* puiOut
    );
HRESULT DAPI StrStringToInt64(
    __in_z LPCWSTR wzIn,
    __in DWORD cchIn,
    __out LONGLONG* pllOut
    );
HRESULT DAPI StrStringToUInt64(
    __in_z LPCWSTR wzIn,
    __in DWORD cchIn,
    __out ULONGLONG* pullOut
    );
void DAPI StrStringToUpper(
    __inout_z LPWSTR wzIn
    );
void DAPI StrStringToLower(
    __inout_z LPWSTR wzIn
    );
HRESULT DAPI StrAllocStringToUpperInvariant(
    __deref_out_z LPWSTR* pscz,
    __in_z LPCWSTR wzSource,
    __in int cchSource
    );
HRESULT DAPI StrAllocStringToLowerInvariant(
    __deref_out_z LPWSTR* pscz,
    __in_z LPCWSTR wzSource,
    __in int cchSource
    );

HRESULT DAPI StrArrayAllocString(
    __deref_inout_ecount_opt(*pcStrArray) LPWSTR **prgsczStrArray,
    __inout LPUINT pcStrArray,
    __in_z LPCWSTR wzSource,
    __in DWORD_PTR cchSource
    );

HRESULT DAPI StrArrayFree(
    __in_ecount(cStrArray) LPWSTR *rgsczStrArray,
    __in UINT cStrArray
    );

HRESULT DAPI StrSplitAllocArray(
    __deref_inout_ecount_opt(*pcStrArray) LPWSTR **prgsczStrArray,
    __inout LPUINT pcStrArray,
    __in_z LPCWSTR wzSource,
    __in_z LPCWSTR wzDelim
    );

#ifdef __cplusplus
}
#endif
