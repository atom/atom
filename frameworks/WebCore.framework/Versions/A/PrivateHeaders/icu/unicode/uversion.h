/*
*******************************************************************************
*   Copyright (C) 2000-2004, International Business Machines
*   Corporation and others.  All Rights Reserved.
*******************************************************************************
*
*   file name:  uversion.h
*   encoding:   US-ASCII
*   tab size:   8 (not used)
*   indentation:4
*
*   Created by: Vladimir Weinstein
*
*  Contains all the important version numbers for ICU. 
*  Gets included by utypes.h and Windows .rc files
*/

/*===========================================================================*/
/* Main ICU version information                                              */
/*===========================================================================*/

#ifndef UVERSION_H
#define UVERSION_H

/** IMPORTANT: When updating version, the following things need to be done:   */
/** source/common/unicode/uversion.h - this file: update major, minor,        */
/**        patchlevel, suffix, version, short version constants, namespace,   */
/**                                                             and copyright */
/** source/common/common.dsp - update 'Output file name' on the link tab so   */
/**                   that it contains the new major/minor combination        */
/** source/i18n/i18n.dsp - same as for the common.dsp                         */
/** source/layout/layout.dsp - same as for the common.dsp                     */
/** source/stubdata/stubdata.dsp - same as for the common.dsp                 */
/** source/extra/ustdio/ustdio.dsp - same as for the common.dsp               */
/** source/data/makedata.mak - change U_ICUDATA_NAME so that it contains      */
/**                            the new major/minor combination                */
/** source/tools/genren/genren.pl - use this script according to the README   */
/**                    in that folder                                         */

#include "unicode/umachine.h"

/** The standard copyright notice that gets compiled into each library. 
 *  This value will change in the subsequent releases of ICU
 *  @stable ICU 2.4
 */
#define U_COPYRIGHT_STRING \
  " Copyright (C) 2004, International Business Machines Corporation and others. All Rights Reserved. "

/** Maximum length of the copyright string.
 *  @stable ICU 2.4
 */
#define U_COPYRIGHT_STRING_LENGTH  128

/** The current ICU major version as an integer. 
 *  This value will change in the subsequent releases of ICU
 *  @stable ICU 2.4
 */
#define U_ICU_VERSION_MAJOR_NUM 3

/** The current ICU minor version as an integer. 
 *  This value will change in the subsequent releases of ICU
 *  @stable ICU 2.6
 */
#define U_ICU_VERSION_MINOR_NUM 2

/** The current ICU patchlevel version as an integer.  
 *  This value will change in the subsequent releases of ICU
 *  @stable ICU 2.4
 */
#define U_ICU_VERSION_PATCHLEVEL_NUM 0

/** Glued version suffix for renamers 
 *  This value will change in the subsequent releases of ICU
 *  @stable ICU 2.6
 */
#define U_ICU_VERSION_SUFFIX _3_2

/** The current ICU library version as a dotted-decimal string. The patchlevel
 *  only appears in this string if it non-zero. 
 *  This value will change in the subsequent releases of ICU
 *  @stable ICU 2.4
 */
#define U_ICU_VERSION "3.2"

/** The current ICU library major/minor version as a string without dots, for library name suffixes. 
 *  This value will change in the subsequent releases of ICU
 *  @stable ICU 2.6
 */
#define U_ICU_VERSION_SHORT "32"

/** An ICU version consists of up to 4 numbers from 0..255.
 *  @stable ICU 2.4
 */
#define U_MAX_VERSION_LENGTH 4

/** In a string, ICU version fields are delimited by dots.
 *  @stable ICU 2.4
 */
#define U_VERSION_DELIMITER '.'

/** The maximum length of an ICU version string.
 *  @stable ICU 2.4
 */
#define U_MAX_VERSION_STRING_LENGTH 20

/** The binary form of a version on ICU APIs is an array of 4 uint8_t.
 *  @stable ICU 2.4
 */
typedef uint8_t UVersionInfo[U_MAX_VERSION_LENGTH];

#if U_HAVE_NAMESPACE && defined(XP_CPLUSPLUS)
#if U_DISABLE_RENAMING
#define U_ICU_NAMESPACE icu
namespace U_ICU_NAMESPACE { }
#else
#define U_ICU_NAMESPACE icu_3_2
namespace U_ICU_NAMESPACE { }
namespace icu = U_ICU_NAMESPACE;
#endif
U_NAMESPACE_USE
#endif


/*===========================================================================*/
/* General version helper functions. Definitions in putil.c                  */
/*===========================================================================*/

/**
 * Parse a string with dotted-decimal version information and
 * fill in a UVersionInfo structure with the result.
 * Definition of this function lives in putil.c
 *
 * @param versionArray The destination structure for the version information.
 * @param versionString A string with dotted-decimal version information,
 *                      with up to four non-negative number fields with
 *                      values of up to 255 each.
 * @stable ICU 2.4
 */
U_STABLE void U_EXPORT2
u_versionFromString(UVersionInfo versionArray, const char *versionString);

/**
 * Write a string with dotted-decimal version information according
 * to the input UVersionInfo.
 * Definition of this function lives in putil.c
 *
 * @param versionArray The version information to be written as a string.
 * @param versionString A string buffer that will be filled in with
 *                      a string corresponding to the numeric version
 *                      information in versionArray.
 *                      The buffer size must be at least U_MAX_VERSION_STRING_LENGTH.
 * @stable ICU 2.4
 */
U_STABLE void U_EXPORT2
u_versionToString(UVersionInfo versionArray, char *versionString);

/**
 * Gets the ICU release version.  The version array stores the version information
 * for ICU.  For example, release "1.3.31.2" is then represented as 0x01031F02.
 * Definition of this function lives in putil.c
 *
 * @param versionArray the version # information, the result will be filled in
 * @stable ICU 2.0
 */
U_STABLE void U_EXPORT2
u_getVersion(UVersionInfo versionArray);


/*===========================================================================
 * ICU collation framework version information                               
 * Version info that can be obtained from a collator is affected by these    
 * numbers in a secret and magic way. Please use collator version as whole
 *===========================================================================
 */

/** Collation runtime version (sort key generator, strcoll). 
 * If the version is different, sortkeys for the same string could be different 
 * version 2 was in ICU 1.8.1. changed is: compression intervals, French secondary 
 * compression, generating quad level always when strength is quad or more 
 * version 4 - ICU 2.2 - tracking UCA changes, ignore completely ignorables 
 * in contractions, ignore primary ignorables after shifted 
 * version 5 - ICU 2.8 - changed implicit generation code
 * This value may change in the subsequent releases of ICU
 * @stable ICU 2.4
 */
#define UCOL_RUNTIME_VERSION 5

/** Builder code version. When this is different, same tailoring might result
 * in assigning different collation elements to code points                  
 * version 2 was in ICU 1.8.1. added support for prefixes, tweaked canonical 
 * closure. However, the tailorings should probably get same CEs assigned    
 * version 5 - ICU 2.2 - fixed some bugs, renamed some indirect values.      
 * version 6 - ICU 2.8 - fixed bug in builder that allowed 0xFF in primary values
 * Backward compatible with the old rules. 
 * This value may change in the subsequent releases of ICU
 * @stable ICU 2.4
 */
#define UCOL_BUILDER_VERSION 6

/** *** Removed *** Instead we use the data we read from FractionalUCA.txt
 * This is the version of FractionalUCA.txt tailoring rules
 * Version 1 was in ICU 1.8.1. Version two contains canonical closure for
 * supplementary code points 
 * Version 4 in ICU 2.2, following UCA=3.1.1d6, UCD=3.2.0 
 * This value may change in the subsequent releases of ICU
 * @stable ICU 2.4
 */
/*#define UCOL_FRACTIONAL_UCA_VERSION 4*/

/** This is the version of the tailorings 
 *  This value may change in the subsequent releases of ICU
 *  @stable ICU 2.4
 */
#define UCOL_TAILORINGS_VERSION 1

#endif
