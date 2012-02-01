/*
**********************************************************************
*   Copyright (C) 1997-2004, International Business Machines
*   Corporation and others.  All Rights Reserved.
**********************************************************************
*
* File UCHAR.H
*
* Modification History:
*
*   Date        Name        Description
*   04/02/97    aliu        Creation.
*   03/29/99    helena      Updated for C APIs.
*   4/15/99     Madhu       Updated for C Implementation and Javadoc
*   5/20/99     Madhu       Added the function u_getVersion()
*   8/19/1999   srl         Upgraded scripts to Unicode 3.0
*   8/27/1999   schererm    UCharDirection constants: U_...
*   11/11/1999  weiv        added u_isalnum(), cleaned comments
*   01/11/2000  helena      Renamed u_getVersion to u_getUnicodeVersion().
******************************************************************************
*/

#ifndef UCHAR_H
#define UCHAR_H

#include "unicode/utypes.h"

U_CDECL_BEGIN

/*==========================================================================*/
/* Unicode version number                                                   */
/*==========================================================================*/
/**
 * Unicode version number, default for the current ICU version.
 * The actual Unicode Character Database (UCD) data is stored in uprops.dat
 * and may be generated from UCD files from a different Unicode version.
 * Call u_getUnicodeVersion to get the actual Unicode version of the data.
 *
 * @see u_getUnicodeVersion
 * @stable ICU 2.0
 */
#define U_UNICODE_VERSION "4.0.1"

/**
 * \file
 * \brief C API: Unicode Properties
 *
 * This C API provides low-level access to the Unicode Character Database.
 * In addition to raw property values, some convenience functions calculate
 * derived properties, for example for Java-style programming.
 *
 * Unicode assigns each code point (not just assigned character) values for
 * many properties.
 * Most of them are simple boolean flags, or constants from a small enumerated list.
 * For some properties, values are strings or other relatively more complex types.
 *
 * For more information see
 * "About the Unicode Character Database" (http://www.unicode.org/ucd/)
 * and the ICU User Guide chapter on Properties (http://oss.software.ibm.com/icu/userguide/properties.html).
 *
 * Many functions are designed to match java.lang.Character functions.
 * See the individual function documentation,
 * and see the JDK 1.4.1 java.lang.Character documentation
 * at http://java.sun.com/j2se/1.4.1/docs/api/java/lang/Character.html
 *
 * There are also functions that provide easy migration from C/POSIX functions
 * like isblank(). Their use is generally discouraged because the C/POSIX
 * standards do not define their semantics beyond the ASCII range, which means
 * that different implementations exhibit very different behavior.
 * Instead, Unicode properties should be used directly.
 *
 * There are also only a few, broad C/POSIX character classes, and they tend
 * to be used for conflicting purposes. For example, the "isalpha()" class
 * is sometimes used to determine word boundaries, while a more sophisticated
 * approach would at least distinguish initial letters from continuation
 * characters (the latter including combining marks).
 * (In ICU, BreakIterator is the most sophisticated API for word boundaries.)
 * Another example: There is no "istitle()" class for titlecase characters.
 *
 * A summary of the behavior of some C/POSIX character classification implementations
 * for Unicode is available at http://oss.software.ibm.com/cvs/icu/~checkout~/icuhtml/design/posix_classes.html
 *
 * <strong>Important</strong>:
 * The behavior of the ICU C/POSIX-style character classification
 * functions is subject to change according to discussion of the above summary.
 *
 * Note: There are several ICU whitespace functions.
 * Comparison:
 * - u_isUWhiteSpace=UCHAR_WHITE_SPACE: Unicode White_Space property;
 *       most of general categories "Z" (separators) + most whitespace ISO controls
 *       (including no-break spaces, but excluding IS1..IS4 and ZWSP)
 * - u_isWhitespace: Java isWhitespace; Z + whitespace ISO controls but excluding no-break spaces
 * - u_isJavaSpaceChar: Java isSpaceChar; just Z (including no-break spaces)
 * - u_isspace: Z + whitespace ISO controls (including no-break spaces)
 * - u_isblank: "horizontal spaces" = TAB + Zs - ZWSP
 */

/**
 * Constants.
 */

/** The lowest Unicode code point value. Code points are non-negative. @stable ICU 2.0 */
#define UCHAR_MIN_VALUE 0

/**
 * The highest Unicode code point value (scalar value) according to
 * The Unicode Standard. This is a 21-bit value (20.1 bits, rounded up).
 * For a single character, UChar32 is a simple type that can hold any code point value.
 *
 * @see UChar32
 * @stable ICU 2.0
 */
#define UCHAR_MAX_VALUE 0x10ffff

/**
 * Get a single-bit bit set (a flag) from a bit number 0..31.
 * @stable ICU 2.1
 */
#define U_MASK(x) ((uint32_t)1<<(x))

/*
 * !! Note: Several comments in this file are machine-read by the
 * genpname tool.  These comments describe the correspondence between
 * icu enum constants and UCD entities.  Do not delete them.  Update
 * these comments as needed.
 *
 * Any comment of the form "/ *[name]* /" (spaces added) is such
 * a comment.
 *
 * The U_JG_* and U_GC_*_MASK constants are matched by their symbolic
 * name, which must match PropertyValueAliases.txt.
 */

/**
 * Selection constants for Unicode properties.
 * These constants are used in functions like u_hasBinaryProperty to select
 * one of the Unicode properties.
 *
 * The properties APIs are intended to reflect Unicode properties as defined
 * in the Unicode Character Database (UCD) and Unicode Technical Reports (UTR).
 * For details about the properties see http://www.unicode.org/ucd/ .
 * For names of Unicode properties see the UCD file PropertyAliases.txt.
 *
 * Important: If ICU is built with UCD files from Unicode versions below, e.g., 3.2,
 * then properties marked with "new in Unicode 3.2" are not or not fully available.
 * Check u_getUnicodeVersion to be sure.
 *
 * @see u_hasBinaryProperty
 * @see u_getIntPropertyValue
 * @see u_getUnicodeVersion
 * @stable ICU 2.1
 */
typedef enum UProperty {
    /*  See note !!.  Comments of the form "Binary property Dash",
        "Enumerated property Script", "Double property Numeric_Value",
        and "String property Age" are read by genpname. */

    /*  Note: Place UCHAR_ALPHABETIC before UCHAR_BINARY_START so that
    debuggers display UCHAR_ALPHABETIC as the symbolic name for 0,
    rather than UCHAR_BINARY_START.  Likewise for other *_START
    identifiers. */

    /** Binary property Alphabetic. Same as u_isUAlphabetic, different from u_isalpha.
        Lu+Ll+Lt+Lm+Lo+Nl+Other_Alphabetic @stable ICU 2.1 */
    UCHAR_ALPHABETIC=0,
    /** First constant for binary Unicode properties. @stable ICU 2.1 */
    UCHAR_BINARY_START=UCHAR_ALPHABETIC,
    /** Binary property ASCII_Hex_Digit. 0-9 A-F a-f @stable ICU 2.1 */
    UCHAR_ASCII_HEX_DIGIT,
    /** Binary property Bidi_Control.
        Format controls which have specific functions
        in the Bidi Algorithm. @stable ICU 2.1 */
    UCHAR_BIDI_CONTROL,
    /** Binary property Bidi_Mirrored.
        Characters that may change display in RTL text.
        Same as u_isMirrored.
        See Bidi Algorithm, UTR 9. @stable ICU 2.1 */
    UCHAR_BIDI_MIRRORED,
    /** Binary property Dash. Variations of dashes. @stable ICU 2.1 */
    UCHAR_DASH,
    /** Binary property Default_Ignorable_Code_Point (new in Unicode 3.2).
        Ignorable in most processing.
        <2060..206F, FFF0..FFFB, E0000..E0FFF>+Other_Default_Ignorable_Code_Point+(Cf+Cc+Cs-White_Space) @stable ICU 2.1 */
    UCHAR_DEFAULT_IGNORABLE_CODE_POINT,
    /** Binary property Deprecated (new in Unicode 3.2).
        The usage of deprecated characters is strongly discouraged. @stable ICU 2.1 */
    UCHAR_DEPRECATED,
    /** Binary property Diacritic. Characters that linguistically modify
        the meaning of another character to which they apply. @stable ICU 2.1 */
    UCHAR_DIACRITIC,
    /** Binary property Extender.
        Extend the value or shape of a preceding alphabetic character,
        e.g., length and iteration marks. @stable ICU 2.1 */
    UCHAR_EXTENDER,
    /** Binary property Full_Composition_Exclusion.
        CompositionExclusions.txt+Singleton Decompositions+
        Non-Starter Decompositions. @stable ICU 2.1 */
    UCHAR_FULL_COMPOSITION_EXCLUSION,
    /** Binary property Grapheme_Base (new in Unicode 3.2).
        For programmatic determination of grapheme cluster boundaries.
        [0..10FFFF]-Cc-Cf-Cs-Co-Cn-Zl-Zp-Grapheme_Link-Grapheme_Extend-CGJ @stable ICU 2.1 */
    UCHAR_GRAPHEME_BASE,
    /** Binary property Grapheme_Extend (new in Unicode 3.2).
        For programmatic determination of grapheme cluster boundaries.
        Me+Mn+Mc+Other_Grapheme_Extend-Grapheme_Link-CGJ @stable ICU 2.1 */
    UCHAR_GRAPHEME_EXTEND,
    /** Binary property Grapheme_Link (new in Unicode 3.2).
        For programmatic determination of grapheme cluster boundaries. @stable ICU 2.1 */
    UCHAR_GRAPHEME_LINK,
    /** Binary property Hex_Digit.
        Characters commonly used for hexadecimal numbers. @stable ICU 2.1 */
    UCHAR_HEX_DIGIT,
    /** Binary property Hyphen. Dashes used to mark connections
        between pieces of words, plus the Katakana middle dot. @stable ICU 2.1 */
    UCHAR_HYPHEN,
    /** Binary property ID_Continue.
        Characters that can continue an identifier.
        DerivedCoreProperties.txt also says "NOTE: Cf characters should be filtered out."
        ID_Start+Mn+Mc+Nd+Pc @stable ICU 2.1 */
    UCHAR_ID_CONTINUE,
    /** Binary property ID_Start.
        Characters that can start an identifier.
        Lu+Ll+Lt+Lm+Lo+Nl @stable ICU 2.1 */
    UCHAR_ID_START,
    /** Binary property Ideographic.
        CJKV ideographs. @stable ICU 2.1 */
    UCHAR_IDEOGRAPHIC,
    /** Binary property IDS_Binary_Operator (new in Unicode 3.2).
        For programmatic determination of
        Ideographic Description Sequences. @stable ICU 2.1 */
    UCHAR_IDS_BINARY_OPERATOR,
    /** Binary property IDS_Trinary_Operator (new in Unicode 3.2).
        For programmatic determination of
        Ideographic Description Sequences. @stable ICU 2.1 */
    UCHAR_IDS_TRINARY_OPERATOR,
    /** Binary property Join_Control.
        Format controls for cursive joining and ligation. @stable ICU 2.1 */
    UCHAR_JOIN_CONTROL,
    /** Binary property Logical_Order_Exception (new in Unicode 3.2).
        Characters that do not use logical order and
        require special handling in most processing. @stable ICU 2.1 */
    UCHAR_LOGICAL_ORDER_EXCEPTION,
    /** Binary property Lowercase. Same as u_isULowercase, different from u_islower.
        Ll+Other_Lowercase @stable ICU 2.1 */
    UCHAR_LOWERCASE,
    /** Binary property Math. Sm+Other_Math @stable ICU 2.1 */
    UCHAR_MATH,
    /** Binary property Noncharacter_Code_Point.
        Code points that are explicitly defined as illegal
        for the encoding of characters. @stable ICU 2.1 */
    UCHAR_NONCHARACTER_CODE_POINT,
    /** Binary property Quotation_Mark. @stable ICU 2.1 */
    UCHAR_QUOTATION_MARK,
    /** Binary property Radical (new in Unicode 3.2).
        For programmatic determination of
        Ideographic Description Sequences. @stable ICU 2.1 */
    UCHAR_RADICAL,
    /** Binary property Soft_Dotted (new in Unicode 3.2).
        Characters with a "soft dot", like i or j.
        An accent placed on these characters causes
        the dot to disappear. @stable ICU 2.1 */
    UCHAR_SOFT_DOTTED,
    /** Binary property Terminal_Punctuation.
        Punctuation characters that generally mark
        the end of textual units. @stable ICU 2.1 */
    UCHAR_TERMINAL_PUNCTUATION,
    /** Binary property Unified_Ideograph (new in Unicode 3.2).
        For programmatic determination of
        Ideographic Description Sequences. @stable ICU 2.1 */
    UCHAR_UNIFIED_IDEOGRAPH,
    /** Binary property Uppercase. Same as u_isUUppercase, different from u_isupper.
        Lu+Other_Uppercase @stable ICU 2.1 */
    UCHAR_UPPERCASE,
    /** Binary property White_Space.
        Same as u_isUWhiteSpace, different from u_isspace and u_isWhitespace.
        Space characters+TAB+CR+LF-ZWSP-ZWNBSP @stable ICU 2.1 */
    UCHAR_WHITE_SPACE,
    /** Binary property XID_Continue.
        ID_Continue modified to allow closure under
        normalization forms NFKC and NFKD. @stable ICU 2.1 */
    UCHAR_XID_CONTINUE,
    /** Binary property XID_Start. ID_Start modified to allow
        closure under normalization forms NFKC and NFKD. @stable ICU 2.1 */
    UCHAR_XID_START,
    /** Binary property Case_Sensitive. Either the source of a case
        mapping or _in_ the target of a case mapping. Not the same as
        the general category Cased_Letter. @stable ICU 2.6 */
    UCHAR_CASE_SENSITIVE,
    /** Binary property STerm (new in Unicode 4.0.1).
        Sentence Terminal. Used in UAX #29: Text Boundaries
        (http://www.unicode.org/reports/tr29/)
        @draft ICU 3.0 */
    UCHAR_S_TERM,
    /** Binary property Variation_Selector (new in Unicode 4.0.1).
        Indicates all those characters that qualify as Variation Selectors.
        For details on the behavior of these characters,
        see StandardizedVariants.html and 15.6 Variation Selectors.
        @draft ICU 3.0 */
    UCHAR_VARIATION_SELECTOR,
    /** Binary property NFD_Inert.
        ICU-specific property for characters that are inert under NFD,
        i.e., they do not interact with adjacent characters.
        Used for example in normalizing transforms in incremental mode
        to find the boundary of safely normalizable text despite possible
        text additions.

        There is one such property per normalization form.
        These properties are computed as follows - an inert character is:
        a) unassigned, or ALL of the following:
        b) of combining class 0.
        c) not decomposed by this normalization form.
        AND if NFC or NFKC,
        d) can never compose with a previous character.
        e) can never compose with a following character.
        f) can never change if another character is added.
           Example: a-breve might satisfy all but f, but if you
           add an ogonek it changes to a-ogonek + breve

        See also com.ibm.text.UCD.NFSkippable in the ICU4J repository,
        and icu/source/common/unormimp.h .
        @draft ICU 3.0 */
    UCHAR_NFD_INERT,
    /** Binary property NFKD_Inert.
        ICU-specific property for characters that are inert under NFKD,
        i.e., they do not interact with adjacent characters.
        Used for example in normalizing transforms in incremental mode
        to find the boundary of safely normalizable text despite possible
        text additions.
        @see UCHAR_NFD_INERT
        @draft ICU 3.0 */
    UCHAR_NFKD_INERT,
    /** Binary property NFC_Inert.
        ICU-specific property for characters that are inert under NFC,
        i.e., they do not interact with adjacent characters.
        Used for example in normalizing transforms in incremental mode
        to find the boundary of safely normalizable text despite possible
        text additions.
        @see UCHAR_NFD_INERT
        @draft ICU 3.0 */
    UCHAR_NFC_INERT,
    /** Binary property NFKC_Inert.
        ICU-specific property for characters that are inert under NFKC,
        i.e., they do not interact with adjacent characters.
        Used for example in normalizing transforms in incremental mode
        to find the boundary of safely normalizable text despite possible
        text additions.
        @see UCHAR_NFD_INERT
        @draft ICU 3.0 */
    UCHAR_NFKC_INERT,
    /** Binary Property Segment_Starter.
        ICU-specific property for characters that are starters in terms of
        Unicode normalization and combining character sequences.
        They have ccc=0 and do not occur in non-initial position of the
        canonical decomposition of any character
        (like " in NFD(a-umlaut) and a Jamo T in an NFD(Hangul LVT)).
        ICU uses this property for segmenting a string for generating a set of
        canonically equivalent strings, e.g. for canonical closure while
        processing collation tailoring rules.
        @draft ICU 3.0 */
    UCHAR_SEGMENT_STARTER,
    /** One more than the last constant for binary Unicode properties. @stable ICU 2.1 */
    UCHAR_BINARY_LIMIT,

    /** Enumerated property Bidi_Class.
        Same as u_charDirection, returns UCharDirection values. @stable ICU 2.2 */
    UCHAR_BIDI_CLASS=0x1000,
    /** First constant for enumerated/integer Unicode properties. @stable ICU 2.2 */
    UCHAR_INT_START=UCHAR_BIDI_CLASS,
    /** Enumerated property Block.
        Same as ublock_getCode, returns UBlockCode values. @stable ICU 2.2 */
    UCHAR_BLOCK,
    /** Enumerated property Canonical_Combining_Class.
        Same as u_getCombiningClass, returns 8-bit numeric values. @stable ICU 2.2 */
    UCHAR_CANONICAL_COMBINING_CLASS,
    /** Enumerated property Decomposition_Type.
        Returns UDecompositionType values. @stable ICU 2.2 */
    UCHAR_DECOMPOSITION_TYPE,
    /** Enumerated property East_Asian_Width.
        See http://www.unicode.org/reports/tr11/
        Returns UEastAsianWidth values. @stable ICU 2.2 */
    UCHAR_EAST_ASIAN_WIDTH,
    /** Enumerated property General_Category.
        Same as u_charType, returns UCharCategory values. @stable ICU 2.2 */
    UCHAR_GENERAL_CATEGORY,
    /** Enumerated property Joining_Group.
        Returns UJoiningGroup values. @stable ICU 2.2 */
    UCHAR_JOINING_GROUP,
    /** Enumerated property Joining_Type.
        Returns UJoiningType values. @stable ICU 2.2 */
    UCHAR_JOINING_TYPE,
    /** Enumerated property Line_Break.
        Returns ULineBreak values. @stable ICU 2.2 */
    UCHAR_LINE_BREAK,
    /** Enumerated property Numeric_Type.
        Returns UNumericType values. @stable ICU 2.2 */
    UCHAR_NUMERIC_TYPE,
    /** Enumerated property Script.
        Same as uscript_getScript, returns UScriptCode values. @stable ICU 2.2 */
    UCHAR_SCRIPT,
    /** Enumerated property Hangul_Syllable_Type, new in Unicode 4.
        Returns UHangulSyllableType values. @stable ICU 2.6 */
    UCHAR_HANGUL_SYLLABLE_TYPE,
    /** Enumerated property NFD_Quick_Check.
        Returns UNormalizationCheckResult values. @draft ICU 3.0 */
    UCHAR_NFD_QUICK_CHECK,
    /** Enumerated property NFKD_Quick_Check.
        Returns UNormalizationCheckResult values. @draft ICU 3.0 */
    UCHAR_NFKD_QUICK_CHECK,
    /** Enumerated property NFC_Quick_Check.
        Returns UNormalizationCheckResult values. @draft ICU 3.0 */
    UCHAR_NFC_QUICK_CHECK,
    /** Enumerated property NFKC_Quick_Check.
        Returns UNormalizationCheckResult values. @draft ICU 3.0 */
    UCHAR_NFKC_QUICK_CHECK,
    /** Enumerated property Lead_Canonical_Combining_Class.
        ICU-specific property for the ccc of the first code point
        of the decomposition, or lccc(c)=ccc(NFD(c)[0]).
        Useful for checking for canonically ordered text;
        see UNORM_FCD and http://www.unicode.org/notes/tn5/#FCD .
        Returns 8-bit numeric values like UCHAR_CANONICAL_COMBINING_CLASS. @draft ICU 3.0 */
    UCHAR_LEAD_CANONICAL_COMBINING_CLASS,
    /** Enumerated property Trail_Canonical_Combining_Class.
        ICU-specific property for the ccc of the last code point
        of the decomposition, or tccc(c)=ccc(NFD(c)[last]).
        Useful for checking for canonically ordered text;
        see UNORM_FCD and http://www.unicode.org/notes/tn5/#FCD .
        Returns 8-bit numeric values like UCHAR_CANONICAL_COMBINING_CLASS. @draft ICU 3.0 */
    UCHAR_TRAIL_CANONICAL_COMBINING_CLASS,
    /** One more than the last constant for enumerated/integer Unicode properties. @stable ICU 2.2 */
    UCHAR_INT_LIMIT,

    /** Bitmask property General_Category_Mask.
        This is the General_Category property returned as a bit mask.
        When used in u_getIntPropertyValue(c), same as U_MASK(u_charType(c)),
        returns bit masks for UCharCategory values where exactly one bit is set.
        When used with u_getPropertyValueName() and u_getPropertyValueEnum(),
        a multi-bit mask is used for sets of categories like "Letters".
        Mask values should be cast to uint32_t.
        @stable ICU 2.4 */
    UCHAR_GENERAL_CATEGORY_MASK=0x2000,
    /** First constant for bit-mask Unicode properties. @stable ICU 2.4 */
    UCHAR_MASK_START=UCHAR_GENERAL_CATEGORY_MASK,
    /** One more than the last constant for bit-mask Unicode properties. @stable ICU 2.4 */
    UCHAR_MASK_LIMIT,

    /** Double property Numeric_Value.
        Corresponds to u_getNumericValue. @stable ICU 2.4 */
    UCHAR_NUMERIC_VALUE=0x3000,
    /** First constant for double Unicode properties. @stable ICU 2.4 */
    UCHAR_DOUBLE_START=UCHAR_NUMERIC_VALUE,
    /** One more than the last constant for double Unicode properties. @stable ICU 2.4 */
    UCHAR_DOUBLE_LIMIT,

    /** String property Age.
        Corresponds to u_charAge. @stable ICU 2.4 */
    UCHAR_AGE=0x4000,
    /** First constant for string Unicode properties. @stable ICU 2.4 */
    UCHAR_STRING_START=UCHAR_AGE,
    /** String property Bidi_Mirroring_Glyph.
        Corresponds to u_charMirror. @stable ICU 2.4 */
    UCHAR_BIDI_MIRRORING_GLYPH,
    /** String property Case_Folding.
        Corresponds to u_strFoldCase in ustring.h. @stable ICU 2.4 */
    UCHAR_CASE_FOLDING,
    /** String property ISO_Comment.
        Corresponds to u_getISOComment. @stable ICU 2.4 */
    UCHAR_ISO_COMMENT,
    /** String property Lowercase_Mapping.
        Corresponds to u_strToLower in ustring.h. @stable ICU 2.4 */
    UCHAR_LOWERCASE_MAPPING,
    /** String property Name.
        Corresponds to u_charName. @stable ICU 2.4 */
    UCHAR_NAME,
    /** String property Simple_Case_Folding.
        Corresponds to u_foldCase. @stable ICU 2.4 */
    UCHAR_SIMPLE_CASE_FOLDING,
    /** String property Simple_Lowercase_Mapping.
        Corresponds to u_tolower. @stable ICU 2.4 */
    UCHAR_SIMPLE_LOWERCASE_MAPPING,
    /** String property Simple_Titlecase_Mapping.
        Corresponds to u_totitle. @stable ICU 2.4 */
    UCHAR_SIMPLE_TITLECASE_MAPPING,
    /** String property Simple_Uppercase_Mapping.
        Corresponds to u_toupper. @stable ICU 2.4 */
    UCHAR_SIMPLE_UPPERCASE_MAPPING,
    /** String property Titlecase_Mapping.
        Corresponds to u_strToTitle in ustring.h. @stable ICU 2.4 */
    UCHAR_TITLECASE_MAPPING,
    /** String property Unicode_1_Name.
        Corresponds to u_charName. @stable ICU 2.4 */
    UCHAR_UNICODE_1_NAME,
    /** String property Uppercase_Mapping.
        Corresponds to u_strToUpper in ustring.h. @stable ICU 2.4 */
    UCHAR_UPPERCASE_MAPPING,
    /** One more than the last constant for string Unicode properties. @stable ICU 2.4 */
    UCHAR_STRING_LIMIT,

    /** Represents a nonexistent or invalid property or property value. @stable ICU 2.4 */
    UCHAR_INVALID_CODE = -1
} UProperty;

/**
 * Data for enumerated Unicode general category types.
 * See http://www.unicode.org/Public/UNIDATA/UnicodeData.html .
 * @stable ICU 2.0
 */
typedef enum UCharCategory
{
    /** See note !!.  Comments of the form "Cn" are read by genpname. */

    /** Non-category for unassigned and non-character code points. @stable ICU 2.0 */
    U_UNASSIGNED              = 0,
    /** Cn "Other, Not Assigned (no characters in [UnicodeData.txt] have this property)" (same as U_UNASSIGNED!) @stable ICU 2.0 */
    U_GENERAL_OTHER_TYPES     = 0,
    /** Lu @stable ICU 2.0 */
    U_UPPERCASE_LETTER        = 1,
    /** Ll @stable ICU 2.0 */
    U_LOWERCASE_LETTER        = 2,
    /** Lt @stable ICU 2.0 */
    U_TITLECASE_LETTER        = 3,
    /** Lm @stable ICU 2.0 */
    U_MODIFIER_LETTER         = 4,
    /** Lo @stable ICU 2.0 */
    U_OTHER_LETTER            = 5,
    /** Mn @stable ICU 2.0 */
    U_NON_SPACING_MARK        = 6,
    /** Me @stable ICU 2.0 */
    U_ENCLOSING_MARK          = 7,
    /** Mc @stable ICU 2.0 */
    U_COMBINING_SPACING_MARK  = 8,
    /** Nd @stable ICU 2.0 */
    U_DECIMAL_DIGIT_NUMBER    = 9,
    /** Nl @stable ICU 2.0 */
    U_LETTER_NUMBER           = 10,
    /** No @stable ICU 2.0 */
    U_OTHER_NUMBER            = 11,
    /** Zs @stable ICU 2.0 */
    U_SPACE_SEPARATOR         = 12,
    /** Zl @stable ICU 2.0 */
    U_LINE_SEPARATOR          = 13,
    /** Zp @stable ICU 2.0 */
    U_PARAGRAPH_SEPARATOR     = 14,
    /** Cc @stable ICU 2.0 */
    U_CONTROL_CHAR            = 15,
    /** Cf @stable ICU 2.0 */
    U_FORMAT_CHAR             = 16,
    /** Co @stable ICU 2.0 */
    U_PRIVATE_USE_CHAR        = 17,
    /** Cs @stable ICU 2.0 */
    U_SURROGATE               = 18,
    /** Pd @stable ICU 2.0 */
    U_DASH_PUNCTUATION        = 19,
    /** Ps @stable ICU 2.0 */
    U_START_PUNCTUATION       = 20,
    /** Pe @stable ICU 2.0 */
    U_END_PUNCTUATION         = 21,
    /** Pc @stable ICU 2.0 */
    U_CONNECTOR_PUNCTUATION   = 22,
    /** Po @stable ICU 2.0 */
    U_OTHER_PUNCTUATION       = 23,
    /** Sm @stable ICU 2.0 */
    U_MATH_SYMBOL             = 24,
    /** Sc @stable ICU 2.0 */
    U_CURRENCY_SYMBOL         = 25,
    /** Sk @stable ICU 2.0 */
    U_MODIFIER_SYMBOL         = 26,
    /** So @stable ICU 2.0 */
    U_OTHER_SYMBOL            = 27,
    /** Pi @stable ICU 2.0 */
    U_INITIAL_PUNCTUATION     = 28,
    /** Pf @stable ICU 2.0 */
    U_FINAL_PUNCTUATION       = 29,
    /** One higher than the last enum UCharCategory constant. @stable ICU 2.0 */
    U_CHAR_CATEGORY_COUNT
} UCharCategory;

/**
 * U_GC_XX_MASK constants are bit flags corresponding to Unicode
 * general category values.
 * For each category, the nth bit is set if the numeric value of the
 * corresponding UCharCategory constant is n.
 *
 * There are also some U_GC_Y_MASK constants for groups of general categories
 * like L for all letter categories.
 *
 * @see u_charType
 * @see U_GET_GC_MASK
 * @see UCharCategory
 * @stable ICU 2.1
 */
#define U_GC_CN_MASK    U_MASK(U_GENERAL_OTHER_TYPES)

/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_LU_MASK    U_MASK(U_UPPERCASE_LETTER)
/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_LL_MASK    U_MASK(U_LOWERCASE_LETTER)
/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_LT_MASK    U_MASK(U_TITLECASE_LETTER)
/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_LM_MASK    U_MASK(U_MODIFIER_LETTER)
/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_LO_MASK    U_MASK(U_OTHER_LETTER)

/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_MN_MASK    U_MASK(U_NON_SPACING_MARK)
/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_ME_MASK    U_MASK(U_ENCLOSING_MARK)
/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_MC_MASK    U_MASK(U_COMBINING_SPACING_MARK)

/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_ND_MASK    U_MASK(U_DECIMAL_DIGIT_NUMBER)
/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_NL_MASK    U_MASK(U_LETTER_NUMBER)
/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_NO_MASK    U_MASK(U_OTHER_NUMBER)

/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_ZS_MASK    U_MASK(U_SPACE_SEPARATOR)
/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_ZL_MASK    U_MASK(U_LINE_SEPARATOR)
/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_ZP_MASK    U_MASK(U_PARAGRAPH_SEPARATOR)

/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_CC_MASK    U_MASK(U_CONTROL_CHAR)
/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_CF_MASK    U_MASK(U_FORMAT_CHAR)
/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_CO_MASK    U_MASK(U_PRIVATE_USE_CHAR)
/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_CS_MASK    U_MASK(U_SURROGATE)

/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_PD_MASK    U_MASK(U_DASH_PUNCTUATION)
/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_PS_MASK    U_MASK(U_START_PUNCTUATION)
/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_PE_MASK    U_MASK(U_END_PUNCTUATION)
/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_PC_MASK    U_MASK(U_CONNECTOR_PUNCTUATION)
/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_PO_MASK    U_MASK(U_OTHER_PUNCTUATION)

/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_SM_MASK    U_MASK(U_MATH_SYMBOL)
/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_SC_MASK    U_MASK(U_CURRENCY_SYMBOL)
/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_SK_MASK    U_MASK(U_MODIFIER_SYMBOL)
/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_SO_MASK    U_MASK(U_OTHER_SYMBOL)

/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_PI_MASK    U_MASK(U_INITIAL_PUNCTUATION)
/** Mask constant for a UCharCategory. @stable ICU 2.1 */
#define U_GC_PF_MASK    U_MASK(U_FINAL_PUNCTUATION)


/** Mask constant for multiple UCharCategory bits (L Letters). @stable ICU 2.1 */
#define U_GC_L_MASK \
            (U_GC_LU_MASK|U_GC_LL_MASK|U_GC_LT_MASK|U_GC_LM_MASK|U_GC_LO_MASK)

/** Mask constant for multiple UCharCategory bits (LC Cased Letters). @stable ICU 2.1 */
#define U_GC_LC_MASK \
            (U_GC_LU_MASK|U_GC_LL_MASK|U_GC_LT_MASK)

/** Mask constant for multiple UCharCategory bits (M Marks). @stable ICU 2.1 */
#define U_GC_M_MASK (U_GC_MN_MASK|U_GC_ME_MASK|U_GC_MC_MASK)

/** Mask constant for multiple UCharCategory bits (N Numbers). @stable ICU 2.1 */
#define U_GC_N_MASK (U_GC_ND_MASK|U_GC_NL_MASK|U_GC_NO_MASK)

/** Mask constant for multiple UCharCategory bits (Z Separators). @stable ICU 2.1 */
#define U_GC_Z_MASK (U_GC_ZS_MASK|U_GC_ZL_MASK|U_GC_ZP_MASK)

/** Mask constant for multiple UCharCategory bits (C Others). @stable ICU 2.1 */
#define U_GC_C_MASK \
            (U_GC_CN_MASK|U_GC_CC_MASK|U_GC_CF_MASK|U_GC_CO_MASK|U_GC_CS_MASK)

/** Mask constant for multiple UCharCategory bits (P Punctuation). @stable ICU 2.1 */
#define U_GC_P_MASK \
            (U_GC_PD_MASK|U_GC_PS_MASK|U_GC_PE_MASK|U_GC_PC_MASK|U_GC_PO_MASK| \
             U_GC_PI_MASK|U_GC_PF_MASK)

/** Mask constant for multiple UCharCategory bits (S Symbols). @stable ICU 2.1 */
#define U_GC_S_MASK (U_GC_SM_MASK|U_GC_SC_MASK|U_GC_SK_MASK|U_GC_SO_MASK)

/**
 * This specifies the language directional property of a character set.
 * @stable ICU 2.0
 */
typedef enum UCharDirection {
    /** See note !!.  Comments of the form "EN" are read by genpname. */

    /** L @stable ICU 2.0 */
    U_LEFT_TO_RIGHT               = 0,
    /** R @stable ICU 2.0 */
    U_RIGHT_TO_LEFT               = 1,
    /** EN @stable ICU 2.0 */
    U_EUROPEAN_NUMBER             = 2,
    /** ES @stable ICU 2.0 */
    U_EUROPEAN_NUMBER_SEPARATOR   = 3,
    /** ET @stable ICU 2.0 */
    U_EUROPEAN_NUMBER_TERMINATOR  = 4,
    /** AN @stable ICU 2.0 */
    U_ARABIC_NUMBER               = 5,
    /** CS @stable ICU 2.0 */
    U_COMMON_NUMBER_SEPARATOR     = 6,
    /** B @stable ICU 2.0 */
    U_BLOCK_SEPARATOR             = 7,
    /** S @stable ICU 2.0 */
    U_SEGMENT_SEPARATOR           = 8,
    /** WS @stable ICU 2.0 */
    U_WHITE_SPACE_NEUTRAL         = 9,
    /** ON @stable ICU 2.0 */
    U_OTHER_NEUTRAL               = 10,
    /** LRE @stable ICU 2.0 */
    U_LEFT_TO_RIGHT_EMBEDDING     = 11,
    /** LRO @stable ICU 2.0 */
    U_LEFT_TO_RIGHT_OVERRIDE      = 12,
    /** AL @stable ICU 2.0 */
    U_RIGHT_TO_LEFT_ARABIC        = 13,
    /** RLE @stable ICU 2.0 */
    U_RIGHT_TO_LEFT_EMBEDDING     = 14,
    /** RLO @stable ICU 2.0 */
    U_RIGHT_TO_LEFT_OVERRIDE      = 15,
    /** PDF @stable ICU 2.0 */
    U_POP_DIRECTIONAL_FORMAT      = 16,
    /** NSM @stable ICU 2.0 */
    U_DIR_NON_SPACING_MARK        = 17,
    /** BN @stable ICU 2.0 */
    U_BOUNDARY_NEUTRAL            = 18,
    /** @stable ICU 2.0 */
    U_CHAR_DIRECTION_COUNT
} UCharDirection;

/**
 * Constants for Unicode blocks, see the Unicode Data file Blocks.txt
 * @stable ICU 2.0
 */
enum UBlockCode {

    /** New No_Block value in Unicode 4. @stable ICU 2.6 */
    UBLOCK_NO_BLOCK = 0, /*[none]*/ /* Special range indicating No_Block */

    /** @stable ICU 2.0 */
    UBLOCK_BASIC_LATIN = 1, /*[0000]*/ /*See note !!*/

    /** @stable ICU 2.0 */
    UBLOCK_LATIN_1_SUPPLEMENT=2, /*[0080]*/

    /** @stable ICU 2.0 */
    UBLOCK_LATIN_EXTENDED_A =3, /*[0100]*/

    /** @stable ICU 2.0 */
    UBLOCK_LATIN_EXTENDED_B =4, /*[0180]*/

    /** @stable ICU 2.0 */
    UBLOCK_IPA_EXTENSIONS =5, /*[0250]*/

    /** @stable ICU 2.0 */
    UBLOCK_SPACING_MODIFIER_LETTERS =6, /*[02B0]*/

    /** @stable ICU 2.0 */
    UBLOCK_COMBINING_DIACRITICAL_MARKS =7, /*[0300]*/

    /**
     * Unicode 3.2 renames this block to "Greek and Coptic".
     * @stable ICU 2.0
     */
    UBLOCK_GREEK =8, /*[0370]*/

    /** @stable ICU 2.0 */
    UBLOCK_CYRILLIC =9, /*[0400]*/

    /** @stable ICU 2.0 */
    UBLOCK_ARMENIAN =10, /*[0530]*/

    /** @stable ICU 2.0 */
    UBLOCK_HEBREW =11, /*[0590]*/

    /** @stable ICU 2.0 */
    UBLOCK_ARABIC =12, /*[0600]*/

    /** @stable ICU 2.0 */
    UBLOCK_SYRIAC =13, /*[0700]*/

    /** @stable ICU 2.0 */
    UBLOCK_THAANA =14, /*[0780]*/

    /** @stable ICU 2.0 */
    UBLOCK_DEVANAGARI =15, /*[0900]*/

    /** @stable ICU 2.0 */
    UBLOCK_BENGALI =16, /*[0980]*/

    /** @stable ICU 2.0 */
    UBLOCK_GURMUKHI =17, /*[0A00]*/

    /** @stable ICU 2.0 */
    UBLOCK_GUJARATI =18, /*[0A80]*/

    /** @stable ICU 2.0 */
    UBLOCK_ORIYA =19, /*[0B00]*/

    /** @stable ICU 2.0 */
    UBLOCK_TAMIL =20, /*[0B80]*/

    /** @stable ICU 2.0 */
    UBLOCK_TELUGU =21, /*[0C00]*/

    /** @stable ICU 2.0 */
    UBLOCK_KANNADA =22, /*[0C80]*/

    /** @stable ICU 2.0 */
    UBLOCK_MALAYALAM =23, /*[0D00]*/

    /** @stable ICU 2.0 */
    UBLOCK_SINHALA =24, /*[0D80]*/

    /** @stable ICU 2.0 */
    UBLOCK_THAI =25, /*[0E00]*/

    /** @stable ICU 2.0 */
    UBLOCK_LAO =26, /*[0E80]*/

    /** @stable ICU 2.0 */
    UBLOCK_TIBETAN =27, /*[0F00]*/

    /** @stable ICU 2.0 */
    UBLOCK_MYANMAR =28, /*[1000]*/

    /** @stable ICU 2.0 */
    UBLOCK_GEORGIAN =29, /*[10A0]*/

    /** @stable ICU 2.0 */
    UBLOCK_HANGUL_JAMO =30, /*[1100]*/

    /** @stable ICU 2.0 */
    UBLOCK_ETHIOPIC =31, /*[1200]*/

    /** @stable ICU 2.0 */
    UBLOCK_CHEROKEE =32, /*[13A0]*/

    /** @stable ICU 2.0 */
    UBLOCK_UNIFIED_CANADIAN_ABORIGINAL_SYLLABICS =33, /*[1400]*/

    /** @stable ICU 2.0 */
    UBLOCK_OGHAM =34, /*[1680]*/

    /** @stable ICU 2.0 */
    UBLOCK_RUNIC =35, /*[16A0]*/

    /** @stable ICU 2.0 */
    UBLOCK_KHMER =36, /*[1780]*/

    /** @stable ICU 2.0 */
    UBLOCK_MONGOLIAN =37, /*[1800]*/

    /** @stable ICU 2.0 */
    UBLOCK_LATIN_EXTENDED_ADDITIONAL =38, /*[1E00]*/

    /** @stable ICU 2.0 */
    UBLOCK_GREEK_EXTENDED =39, /*[1F00]*/

    /** @stable ICU 2.0 */
    UBLOCK_GENERAL_PUNCTUATION =40, /*[2000]*/

    /** @stable ICU 2.0 */
    UBLOCK_SUPERSCRIPTS_AND_SUBSCRIPTS =41, /*[2070]*/

    /** @stable ICU 2.0 */
    UBLOCK_CURRENCY_SYMBOLS =42, /*[20A0]*/

    /**
     * Unicode 3.2 renames this block to "Combining Diacritical Marks for Symbols".
     * @stable ICU 2.0
     */
    UBLOCK_COMBINING_MARKS_FOR_SYMBOLS =43, /*[20D0]*/

    /** @stable ICU 2.0 */
    UBLOCK_LETTERLIKE_SYMBOLS =44, /*[2100]*/

    /** @stable ICU 2.0 */
    UBLOCK_NUMBER_FORMS =45, /*[2150]*/

    /** @stable ICU 2.0 */
    UBLOCK_ARROWS =46, /*[2190]*/

    /** @stable ICU 2.0 */
    UBLOCK_MATHEMATICAL_OPERATORS =47, /*[2200]*/

    /** @stable ICU 2.0 */
    UBLOCK_MISCELLANEOUS_TECHNICAL =48, /*[2300]*/

    /** @stable ICU 2.0 */
    UBLOCK_CONTROL_PICTURES =49, /*[2400]*/

    /** @stable ICU 2.0 */
    UBLOCK_OPTICAL_CHARACTER_RECOGNITION =50, /*[2440]*/

    /** @stable ICU 2.0 */
    UBLOCK_ENCLOSED_ALPHANUMERICS =51, /*[2460]*/

    /** @stable ICU 2.0 */
    UBLOCK_BOX_DRAWING =52, /*[2500]*/

    /** @stable ICU 2.0 */
    UBLOCK_BLOCK_ELEMENTS =53, /*[2580]*/

    /** @stable ICU 2.0 */
    UBLOCK_GEOMETRIC_SHAPES =54, /*[25A0]*/

    /** @stable ICU 2.0 */
    UBLOCK_MISCELLANEOUS_SYMBOLS =55, /*[2600]*/

    /** @stable ICU 2.0 */
    UBLOCK_DINGBATS =56, /*[2700]*/

    /** @stable ICU 2.0 */
    UBLOCK_BRAILLE_PATTERNS =57, /*[2800]*/

    /** @stable ICU 2.0 */
    UBLOCK_CJK_RADICALS_SUPPLEMENT =58, /*[2E80]*/

    /** @stable ICU 2.0 */
    UBLOCK_KANGXI_RADICALS =59, /*[2F00]*/

    /** @stable ICU 2.0 */
    UBLOCK_IDEOGRAPHIC_DESCRIPTION_CHARACTERS =60, /*[2FF0]*/

    /** @stable ICU 2.0 */
    UBLOCK_CJK_SYMBOLS_AND_PUNCTUATION =61, /*[3000]*/

    /** @stable ICU 2.0 */
    UBLOCK_HIRAGANA =62, /*[3040]*/

    /** @stable ICU 2.0 */
    UBLOCK_KATAKANA =63, /*[30A0]*/

    /** @stable ICU 2.0 */
    UBLOCK_BOPOMOFO =64, /*[3100]*/

    /** @stable ICU 2.0 */
    UBLOCK_HANGUL_COMPATIBILITY_JAMO =65, /*[3130]*/

    /** @stable ICU 2.0 */
    UBLOCK_KANBUN =66, /*[3190]*/

    /** @stable ICU 2.0 */
    UBLOCK_BOPOMOFO_EXTENDED =67, /*[31A0]*/

    /** @stable ICU 2.0 */
    UBLOCK_ENCLOSED_CJK_LETTERS_AND_MONTHS =68, /*[3200]*/

    /** @stable ICU 2.0 */
    UBLOCK_CJK_COMPATIBILITY =69, /*[3300]*/

    /** @stable ICU 2.0 */
    UBLOCK_CJK_UNIFIED_IDEOGRAPHS_EXTENSION_A =70, /*[3400]*/

    /** @stable ICU 2.0 */
    UBLOCK_CJK_UNIFIED_IDEOGRAPHS =71, /*[4E00]*/

    /** @stable ICU 2.0 */
    UBLOCK_YI_SYLLABLES =72, /*[A000]*/

    /** @stable ICU 2.0 */
    UBLOCK_YI_RADICALS =73, /*[A490]*/

    /** @stable ICU 2.0 */
    UBLOCK_HANGUL_SYLLABLES =74, /*[AC00]*/

    /** @stable ICU 2.0 */
    UBLOCK_HIGH_SURROGATES =75, /*[D800]*/

    /** @stable ICU 2.0 */
    UBLOCK_HIGH_PRIVATE_USE_SURROGATES =76, /*[DB80]*/

    /** @stable ICU 2.0 */
    UBLOCK_LOW_SURROGATES =77, /*[DC00]*/

    /**
     * Same as UBLOCK_PRIVATE_USE_AREA.
     * Until Unicode 3.1.1, the corresponding block name was "Private Use",
     * and multiple code point ranges had this block.
     * Unicode 3.2 renames the block for the BMP PUA to "Private Use Area" and
     * adds separate blocks for the supplementary PUAs.
     *
     * @stable ICU 2.0
     */
    UBLOCK_PRIVATE_USE = 78,
    /**
     * Same as UBLOCK_PRIVATE_USE.
     * Until Unicode 3.1.1, the corresponding block name was "Private Use",
     * and multiple code point ranges had this block.
     * Unicode 3.2 renames the block for the BMP PUA to "Private Use Area" and
     * adds separate blocks for the supplementary PUAs.
     *
     * @stable ICU 2.0
     */
    UBLOCK_PRIVATE_USE_AREA =UBLOCK_PRIVATE_USE, /*[E000]*/

    /** @stable ICU 2.0 */
    UBLOCK_CJK_COMPATIBILITY_IDEOGRAPHS =79, /*[F900]*/

    /** @stable ICU 2.0 */
    UBLOCK_ALPHABETIC_PRESENTATION_FORMS =80, /*[FB00]*/

    /** @stable ICU 2.0 */
    UBLOCK_ARABIC_PRESENTATION_FORMS_A =81, /*[FB50]*/

    /** @stable ICU 2.0 */
    UBLOCK_COMBINING_HALF_MARKS =82, /*[FE20]*/

    /** @stable ICU 2.0 */
    UBLOCK_CJK_COMPATIBILITY_FORMS =83, /*[FE30]*/

    /** @stable ICU 2.0 */
    UBLOCK_SMALL_FORM_VARIANTS =84, /*[FE50]*/

    /** @stable ICU 2.0 */
    UBLOCK_ARABIC_PRESENTATION_FORMS_B =85, /*[FE70]*/

    /** @stable ICU 2.0 */
    UBLOCK_SPECIALS =86, /*[FFF0]*/

    /** @stable ICU 2.0 */
    UBLOCK_HALFWIDTH_AND_FULLWIDTH_FORMS =87, /*[FF00]*/

    /* New blocks in Unicode 3.1 */

    /** @stable ICU 2.0 */
    UBLOCK_OLD_ITALIC = 88  , /*[10300]*/
    /** @stable ICU 2.0 */
    UBLOCK_GOTHIC = 89 , /*[10330]*/
    /** @stable ICU 2.0 */
    UBLOCK_DESERET = 90 , /*[10400]*/
    /** @stable ICU 2.0 */
    UBLOCK_BYZANTINE_MUSICAL_SYMBOLS = 91 , /*[1D000]*/
    /** @stable ICU 2.0 */
    UBLOCK_MUSICAL_SYMBOLS = 92 , /*[1D100]*/
    /** @stable ICU 2.0 */
    UBLOCK_MATHEMATICAL_ALPHANUMERIC_SYMBOLS = 93  , /*[1D400]*/
    /** @stable ICU 2.0 */
    UBLOCK_CJK_UNIFIED_IDEOGRAPHS_EXTENSION_B  = 94 , /*[20000]*/
    /** @stable ICU 2.0 */
    UBLOCK_CJK_COMPATIBILITY_IDEOGRAPHS_SUPPLEMENT = 95 , /*[2F800]*/
    /** @stable ICU 2.0 */
    UBLOCK_TAGS = 96, /*[E0000]*/

    /* New blocks in Unicode 3.2 */

    /**
     * Unicode 4.0.1 renames the "Cyrillic Supplementary" block to "Cyrillic Supplement".
     * @stable ICU 2.2
     */
    UBLOCK_CYRILLIC_SUPPLEMENTARY = 97, 
    /** @draft ICU 3.0  */
    UBLOCK_CYRILLIC_SUPPLEMENT = UBLOCK_CYRILLIC_SUPPLEMENTARY, /*[0500]*/
    /** @stable ICU 2.2 */
    UBLOCK_TAGALOG = 98, /*[1700]*/
    /** @stable ICU 2.2 */
    UBLOCK_HANUNOO = 99, /*[1720]*/
    /** @stable ICU 2.2 */
    UBLOCK_BUHID = 100, /*[1740]*/
    /** @stable ICU 2.2 */
    UBLOCK_TAGBANWA = 101, /*[1760]*/
    /** @stable ICU 2.2 */
    UBLOCK_MISCELLANEOUS_MATHEMATICAL_SYMBOLS_A = 102, /*[27C0]*/
    /** @stable ICU 2.2 */
    UBLOCK_SUPPLEMENTAL_ARROWS_A = 103, /*[27F0]*/
    /** @stable ICU 2.2 */
    UBLOCK_SUPPLEMENTAL_ARROWS_B = 104, /*[2900]*/
    /** @stable ICU 2.2 */
    UBLOCK_MISCELLANEOUS_MATHEMATICAL_SYMBOLS_B = 105, /*[2980]*/
    /** @stable ICU 2.2 */
    UBLOCK_SUPPLEMENTAL_MATHEMATICAL_OPERATORS = 106, /*[2A00]*/
    /** @stable ICU 2.2 */
    UBLOCK_KATAKANA_PHONETIC_EXTENSIONS = 107, /*[31F0]*/
    /** @stable ICU 2.2 */
    UBLOCK_VARIATION_SELECTORS = 108, /*[FE00]*/
    /** @stable ICU 2.2 */
    UBLOCK_SUPPLEMENTARY_PRIVATE_USE_AREA_A = 109, /*[F0000]*/
    /** @stable ICU 2.2 */
    UBLOCK_SUPPLEMENTARY_PRIVATE_USE_AREA_B = 110, /*[100000]*/

    /* New blocks in Unicode 4 */

    /** @stable ICU 2.6 */
    UBLOCK_LIMBU = 111, /*[1900]*/
    /** @stable ICU 2.6 */
    UBLOCK_TAI_LE = 112, /*[1950]*/
    /** @stable ICU 2.6 */
    UBLOCK_KHMER_SYMBOLS = 113, /*[19E0]*/
    /** @stable ICU 2.6 */
    UBLOCK_PHONETIC_EXTENSIONS = 114, /*[1D00]*/
    /** @stable ICU 2.6 */
    UBLOCK_MISCELLANEOUS_SYMBOLS_AND_ARROWS = 115, /*[2B00]*/
    /** @stable ICU 2.6 */
    UBLOCK_YIJING_HEXAGRAM_SYMBOLS = 116, /*[4DC0]*/
    /** @stable ICU 2.6 */
    UBLOCK_LINEAR_B_SYLLABARY = 117, /*[10000]*/
    /** @stable ICU 2.6 */
    UBLOCK_LINEAR_B_IDEOGRAMS = 118, /*[10080]*/
    /** @stable ICU 2.6 */
    UBLOCK_AEGEAN_NUMBERS = 119, /*[10100]*/
    /** @stable ICU 2.6 */
    UBLOCK_UGARITIC = 120, /*[10380]*/
    /** @stable ICU 2.6 */
    UBLOCK_SHAVIAN = 121, /*[10450]*/
    /** @stable ICU 2.6 */
    UBLOCK_OSMANYA = 122, /*[10480]*/
    /** @stable ICU 2.6 */
    UBLOCK_CYPRIOT_SYLLABARY = 123, /*[10800]*/
    /** @stable ICU 2.6 */
    UBLOCK_TAI_XUAN_JING_SYMBOLS = 124, /*[1D300]*/
    /** @stable ICU 2.6 */
    UBLOCK_VARIATION_SELECTORS_SUPPLEMENT = 125, /*[E0100]*/

    /** @stable ICU 2.0 */
    UBLOCK_COUNT,

    /** @stable ICU 2.0 */
    UBLOCK_INVALID_CODE=-1
};

/** @stable ICU 2.0 */
typedef enum UBlockCode UBlockCode;

/**
 * East Asian Width constants.
 *
 * @see UCHAR_EAST_ASIAN_WIDTH
 * @see u_getIntPropertyValue
 * @stable ICU 2.2
 */
typedef enum UEastAsianWidth {
    U_EA_NEUTRAL,   /*[N]*/ /*See note !!*/
    U_EA_AMBIGUOUS, /*[A]*/
    U_EA_HALFWIDTH, /*[H]*/
    U_EA_FULLWIDTH, /*[F]*/
    U_EA_NARROW,    /*[Na]*/
    U_EA_WIDE,      /*[W]*/
    U_EA_COUNT
} UEastAsianWidth;
/*
 * Implementation note:
 * Keep UEastAsianWidth constant values in sync with names list in genprops/props2.c.
 */

/**
 * Selector constants for u_charName().
 * u_charName() returns the "modern" name of a
 * Unicode character; or the name that was defined in
 * Unicode version 1.0, before the Unicode standard merged
 * with ISO-10646; or an "extended" name that gives each
 * Unicode code point a unique name.
 *
 * @see u_charName
 * @stable ICU 2.0
 */
typedef enum UCharNameChoice {
    U_UNICODE_CHAR_NAME,
    U_UNICODE_10_CHAR_NAME,
    U_EXTENDED_CHAR_NAME,
    U_CHAR_NAME_CHOICE_COUNT
} UCharNameChoice;

/**
 * Selector constants for u_getPropertyName() and
 * u_getPropertyValueName().  These selectors are used to choose which
 * name is returned for a given property or value.  All properties and
 * values have a long name.  Most have a short name, but some do not.
 * Unicode allows for additional names, beyond the long and short
 * name, which would be indicated by U_LONG_PROPERTY_NAME + i, where
 * i=1, 2,...
 *
 * @see u_getPropertyName()
 * @see u_getPropertyValueName()
 * @stable ICU 2.4
 */
typedef enum UPropertyNameChoice {
    U_SHORT_PROPERTY_NAME,
    U_LONG_PROPERTY_NAME,
    U_PROPERTY_NAME_CHOICE_COUNT
} UPropertyNameChoice;

/**
 * Decomposition Type constants.
 *
 * @see UCHAR_DECOMPOSITION_TYPE
 * @stable ICU 2.2
 */
typedef enum UDecompositionType {
    U_DT_NONE,              /*[none]*/ /*See note !!*/
    U_DT_CANONICAL,         /*[can]*/
    U_DT_COMPAT,            /*[com]*/
    U_DT_CIRCLE,            /*[enc]*/
    U_DT_FINAL,             /*[fin]*/
    U_DT_FONT,              /*[font]*/
    U_DT_FRACTION,          /*[fra]*/
    U_DT_INITIAL,           /*[init]*/
    U_DT_ISOLATED,          /*[iso]*/
    U_DT_MEDIAL,            /*[med]*/
    U_DT_NARROW,            /*[nar]*/
    U_DT_NOBREAK,           /*[nb]*/
    U_DT_SMALL,             /*[sml]*/
    U_DT_SQUARE,            /*[sqr]*/
    U_DT_SUB,               /*[sub]*/
    U_DT_SUPER,             /*[sup]*/
    U_DT_VERTICAL,          /*[vert]*/
    U_DT_WIDE,              /*[wide]*/
    U_DT_COUNT /* 18 */
} UDecompositionType;

/**
 * Joining Type constants.
 *
 * @see UCHAR_JOINING_TYPE
 * @stable ICU 2.2
 */
typedef enum UJoiningType {
    U_JT_NON_JOINING,       /*[U]*/ /*See note !!*/
    U_JT_JOIN_CAUSING,      /*[C]*/
    U_JT_DUAL_JOINING,      /*[D]*/
    U_JT_LEFT_JOINING,      /*[L]*/
    U_JT_RIGHT_JOINING,     /*[R]*/
    U_JT_TRANSPARENT,       /*[T]*/
    U_JT_COUNT /* 6 */
} UJoiningType;

/**
 * Joining Group constants.
 *
 * @see UCHAR_JOINING_GROUP
 * @stable ICU 2.2
 */
typedef enum UJoiningGroup {
    U_JG_NO_JOINING_GROUP,
    U_JG_AIN,
    U_JG_ALAPH,
    U_JG_ALEF,
    U_JG_BEH,
    U_JG_BETH,
    U_JG_DAL,
    U_JG_DALATH_RISH,
    U_JG_E,
    U_JG_FEH,
    U_JG_FINAL_SEMKATH,
    U_JG_GAF,
    U_JG_GAMAL,
    U_JG_HAH,
    U_JG_HAMZA_ON_HEH_GOAL,
    U_JG_HE,
    U_JG_HEH,
    U_JG_HEH_GOAL,
    U_JG_HETH,
    U_JG_KAF,
    U_JG_KAPH,
    U_JG_KNOTTED_HEH,
    U_JG_LAM,
    U_JG_LAMADH,
    U_JG_MEEM,
    U_JG_MIM,
    U_JG_NOON,
    U_JG_NUN,
    U_JG_PE,
    U_JG_QAF,
    U_JG_QAPH,
    U_JG_REH,
    U_JG_REVERSED_PE,
    U_JG_SAD,
    U_JG_SADHE,
    U_JG_SEEN,
    U_JG_SEMKATH,
    U_JG_SHIN,
    U_JG_SWASH_KAF,
    U_JG_SYRIAC_WAW,
    U_JG_TAH,
    U_JG_TAW,
    U_JG_TEH_MARBUTA,
    U_JG_TETH,
    U_JG_WAW,
    U_JG_YEH,
    U_JG_YEH_BARREE,
    U_JG_YEH_WITH_TAIL,
    U_JG_YUDH,
    U_JG_YUDH_HE,
    U_JG_ZAIN,
    U_JG_FE,        /**< @stable ICU 2.6 */
    U_JG_KHAPH,     /**< @stable ICU 2.6 */
    U_JG_ZHAIN,     /**< @stable ICU 2.6 */
    U_JG_COUNT
} UJoiningGroup;

/**
 * Line Break constants.
 *
 * @see UCHAR_LINE_BREAK
 * @stable ICU 2.2
 */
typedef enum ULineBreak {
    U_LB_UNKNOWN,           /*[XX]*/ /*See note !!*/
    U_LB_AMBIGUOUS,         /*[AI]*/
    U_LB_ALPHABETIC,        /*[AL]*/
    U_LB_BREAK_BOTH,        /*[B2]*/
    U_LB_BREAK_AFTER,       /*[BA]*/
    U_LB_BREAK_BEFORE,      /*[BB]*/
    U_LB_MANDATORY_BREAK,   /*[BK]*/
    U_LB_CONTINGENT_BREAK,  /*[CB]*/
    U_LB_CLOSE_PUNCTUATION, /*[CL]*/
    U_LB_COMBINING_MARK,    /*[CM]*/
    U_LB_CARRIAGE_RETURN,   /*[CR]*/
    U_LB_EXCLAMATION,       /*[EX]*/
    U_LB_GLUE,              /*[GL]*/
    U_LB_HYPHEN,            /*[HY]*/
    U_LB_IDEOGRAPHIC,       /*[ID]*/
    U_LB_INSEPERABLE,
    /** Renamed from the misspelled "inseperable" in Unicode 4.0.1/ICU 3.0 @draft ICU 3.0 */
    U_LB_INSEPARABLE=U_LB_INSEPERABLE,/*[IN]*/
    U_LB_INFIX_NUMERIC,     /*[IS]*/
    U_LB_LINE_FEED,         /*[LF]*/
    U_LB_NONSTARTER,        /*[NS]*/
    U_LB_NUMERIC,           /*[NU]*/
    U_LB_OPEN_PUNCTUATION,  /*[OP]*/
    U_LB_POSTFIX_NUMERIC,   /*[PO]*/
    U_LB_PREFIX_NUMERIC,    /*[PR]*/
    U_LB_QUOTATION,         /*[QU]*/
    U_LB_COMPLEX_CONTEXT,   /*[SA]*/
    U_LB_SURROGATE,         /*[SG]*/
    U_LB_SPACE,             /*[SP]*/
    U_LB_BREAK_SYMBOLS,     /*[SY]*/
    U_LB_ZWSPACE,           /*[ZW]*/
    U_LB_NEXT_LINE,         /*[NL]*/ /* from here on: new in Unicode 4/ICU 2.6 */
    U_LB_WORD_JOINER,       /*[WJ]*/
    U_LB_COUNT
} ULineBreak;

/**
 * Numeric Type constants.
 *
 * @see UCHAR_NUMERIC_TYPE
 * @stable ICU 2.2
 */
typedef enum UNumericType {
    U_NT_NONE,              /*[None]*/ /*See note !!*/
    U_NT_DECIMAL,           /*[de]*/
    U_NT_DIGIT,             /*[di]*/
    U_NT_NUMERIC,           /*[nu]*/
    U_NT_COUNT
} UNumericType;

/**
 * Hangul Syllable Type constants.
 *
 * @see UCHAR_HANGUL_SYLLABLE_TYPE
 * @stable ICU 2.6
 */
typedef enum UHangulSyllableType {
    U_HST_NOT_APPLICABLE,   /*[NA]*/ /*See note !!*/
    U_HST_LEADING_JAMO,     /*[L]*/
    U_HST_VOWEL_JAMO,       /*[V]*/
    U_HST_TRAILING_JAMO,    /*[T]*/
    U_HST_LV_SYLLABLE,      /*[LV]*/
    U_HST_LVT_SYLLABLE,     /*[LVT]*/
    U_HST_COUNT
} UHangulSyllableType;

/**
 * Check a binary Unicode property for a code point.
 *
 * Unicode, especially in version 3.2, defines many more properties than the
 * original set in UnicodeData.txt.
 *
 * The properties APIs are intended to reflect Unicode properties as defined
 * in the Unicode Character Database (UCD) and Unicode Technical Reports (UTR).
 * For details about the properties see http://www.unicode.org/ucd/ .
 * For names of Unicode properties see the UCD file PropertyAliases.txt.
 *
 * Important: If ICU is built with UCD files from Unicode versions below 3.2,
 * then properties marked with "new in Unicode 3.2" are not or not fully available.
 *
 * @param c Code point to test.
 * @param which UProperty selector constant, identifies which binary property to check.
 *        Must be UCHAR_BINARY_START<=which<UCHAR_BINARY_LIMIT.
 * @return TRUE or FALSE according to the binary Unicode property value for c.
 *         Also FALSE if 'which' is out of bounds or if the Unicode version
 *         does not have data for the property at all, or not for this code point.
 *
 * @see UProperty
 * @see u_getIntPropertyValue
 * @see u_getUnicodeVersion
 * @stable ICU 2.1
 */
U_STABLE UBool U_EXPORT2
u_hasBinaryProperty(UChar32 c, UProperty which);

/**
 * Check if a code point has the Alphabetic Unicode property.
 * Same as u_hasBinaryProperty(c, UCHAR_ALPHABETIC).
 * This is different from u_isalpha!
 * @param c Code point to test
 * @return true if the code point has the Alphabetic Unicode property, false otherwise
 *
 * @see UCHAR_ALPHABETIC
 * @see u_isalpha
 * @see u_hasBinaryProperty
 * @stable ICU 2.1
 */
U_STABLE UBool U_EXPORT2
u_isUAlphabetic(UChar32 c);

/**
 * Check if a code point has the Lowercase Unicode property.
 * Same as u_hasBinaryProperty(c, UCHAR_LOWERCASE).
 * This is different from u_islower!
 * @param c Code point to test
 * @return true if the code point has the Lowercase Unicode property, false otherwise
 *
 * @see UCHAR_LOWERCASE
 * @see u_islower
 * @see u_hasBinaryProperty
 * @stable ICU 2.1
 */
U_STABLE UBool U_EXPORT2
u_isULowercase(UChar32 c);

/**
 * Check if a code point has the Uppercase Unicode property.
 * Same as u_hasBinaryProperty(c, UCHAR_UPPERCASE).
 * This is different from u_isupper!
 * @param c Code point to test
 * @return true if the code point has the Uppercase Unicode property, false otherwise
 *
 * @see UCHAR_UPPERCASE
 * @see u_isupper
 * @see u_hasBinaryProperty
 * @stable ICU 2.1
 */
U_STABLE UBool U_EXPORT2
u_isUUppercase(UChar32 c);

/**
 * Check if a code point has the White_Space Unicode property.
 * Same as u_hasBinaryProperty(c, UCHAR_WHITE_SPACE).
 * This is different from both u_isspace and u_isWhitespace!
 *
 * Note: There are several ICU whitespace functions; please see the uchar.h
 * file documentation for a detailed comparison.
 *
 * @param c Code point to test
 * @return true if the code point has the White_Space Unicode property, false otherwise.
 *
 * @see UCHAR_WHITE_SPACE
 * @see u_isWhitespace
 * @see u_isspace
 * @see u_isJavaSpaceChar
 * @see u_hasBinaryProperty
 * @stable ICU 2.1
 */
U_STABLE UBool U_EXPORT2
u_isUWhiteSpace(UChar32 c);

/**
 * Get the property value for an enumerated or integer Unicode property for a code point.
 * Also returns binary and mask property values.
 *
 * Unicode, especially in version 3.2, defines many more properties than the
 * original set in UnicodeData.txt.
 *
 * The properties APIs are intended to reflect Unicode properties as defined
 * in the Unicode Character Database (UCD) and Unicode Technical Reports (UTR).
 * For details about the properties see http://www.unicode.org/ .
 * For names of Unicode properties see the UCD file PropertyAliases.txt.
 *
 * Sample usage:
 * UEastAsianWidth ea=(UEastAsianWidth)u_getIntPropertyValue(c, UCHAR_EAST_ASIAN_WIDTH);
 * UBool b=(UBool)u_getIntPropertyValue(c, UCHAR_IDEOGRAPHIC);
 *
 * @param c Code point to test.
 * @param which UProperty selector constant, identifies which property to check.
 *        Must be UCHAR_BINARY_START<=which<UCHAR_BINARY_LIMIT
 *        or UCHAR_INT_START<=which<UCHAR_INT_LIMIT
 *        or UCHAR_MASK_START<=which<UCHAR_MASK_LIMIT.
 * @return Numeric value that is directly the property value or,
 *         for enumerated properties, corresponds to the numeric value of the enumerated
 *         constant of the respective property value enumeration type
 *         (cast to enum type if necessary).
 *         Returns 0 or 1 (for FALSE/TRUE) for binary Unicode properties.
 *         Returns a bit-mask for mask properties.
 *         Returns 0 if 'which' is out of bounds or if the Unicode version
 *         does not have data for the property at all, or not for this code point.
 *
 * @see UProperty
 * @see u_hasBinaryProperty
 * @see u_getIntPropertyMinValue
 * @see u_getIntPropertyMaxValue
 * @see u_getUnicodeVersion
 * @stable ICU 2.2
 */
U_STABLE int32_t U_EXPORT2
u_getIntPropertyValue(UChar32 c, UProperty which);

/**
 * Get the minimum value for an enumerated/integer/binary Unicode property.
 * Can be used together with u_getIntPropertyMaxValue
 * to allocate arrays of UnicodeSet or similar.
 *
 * @param which UProperty selector constant, identifies which binary property to check.
 *        Must be UCHAR_BINARY_START<=which<UCHAR_BINARY_LIMIT
 *        or UCHAR_INT_START<=which<UCHAR_INT_LIMIT.
 * @return Minimum value returned by u_getIntPropertyValue for a Unicode property.
 *         0 if the property selector is out of range.
 *
 * @see UProperty
 * @see u_hasBinaryProperty
 * @see u_getUnicodeVersion
 * @see u_getIntPropertyMaxValue
 * @see u_getIntPropertyValue
 * @stable ICU 2.2
 */
U_STABLE int32_t U_EXPORT2
u_getIntPropertyMinValue(UProperty which);

/**
 * Get the maximum value for an enumerated/integer/binary Unicode property.
 * Can be used together with u_getIntPropertyMinValue
 * to allocate arrays of UnicodeSet or similar.
 *
 * Examples for min/max values (for Unicode 3.2):
 *
 * - UCHAR_BIDI_CLASS:    0/18 (U_LEFT_TO_RIGHT/U_BOUNDARY_NEUTRAL)
 * - UCHAR_SCRIPT:        0/45 (USCRIPT_COMMON/USCRIPT_TAGBANWA)
 * - UCHAR_IDEOGRAPHIC:   0/1  (FALSE/TRUE)
 *
 * For undefined UProperty constant values, min/max values will be 0/-1.
 *
 * @param which UProperty selector constant, identifies which binary property to check.
 *        Must be UCHAR_BINARY_START<=which<UCHAR_BINARY_LIMIT
 *        or UCHAR_INT_START<=which<UCHAR_INT_LIMIT.
 * @return Maximum value returned by u_getIntPropertyValue for a Unicode property.
 *         <=0 if the property selector is out of range.
 *
 * @see UProperty
 * @see u_hasBinaryProperty
 * @see u_getUnicodeVersion
 * @see u_getIntPropertyMaxValue
 * @see u_getIntPropertyValue
 * @stable ICU 2.2
 */
U_STABLE int32_t U_EXPORT2
u_getIntPropertyMaxValue(UProperty which);

/**
 * Get the numeric value for a Unicode code point as defined in the
 * Unicode Character Database.
 *
 * A "double" return type is necessary because
 * some numeric values are fractions, negative, or too large for int32_t.
 *
 * For characters without any numeric values in the Unicode Character Database,
 * this function will return U_NO_NUMERIC_VALUE.
 *
 * Similar to java.lang.Character.getNumericValue(), but u_getNumericValue()
 * also supports negative values, large values, and fractions,
 * while Java's getNumericValue() returns values 10..35 for ASCII letters.
 *
 * @param c Code point to get the numeric value for.
 * @return Numeric value of c, or U_NO_NUMERIC_VALUE if none is defined.
 *
 * @see U_NO_NUMERIC_VALUE
 * @stable ICU 2.2
 */
U_STABLE double U_EXPORT2
u_getNumericValue(UChar32 c);

/**
 * Special value that is returned by u_getNumericValue when
 * no numeric value is defined for a code point.
 *
 * @see u_getNumericValue
 * @stable ICU 2.2
 */
#define U_NO_NUMERIC_VALUE ((double)-123456789.)

/**
 * Determines whether the specified code point has the general category "Ll"
 * (lowercase letter).
 *
 * Same as java.lang.Character.isLowerCase().
 *
 * This misses some characters that are also lowercase but
 * have a different general category value.
 * In order to include those, use UCHAR_LOWERCASE.
 *
 * In addition to being equivalent to a Java function, this also serves
 * as a C/POSIX migration function.
 * See the comments about C/POSIX character classification functions in the
 * documentation at the top of this header file.
 *
 * @param c the code point to be tested
 * @return TRUE if the code point is an Ll lowercase letter
 *
 * @see UCHAR_LOWERCASE
 * @see u_isupper
 * @see u_istitle
 * @see u_islower
 * @stable ICU 2.0
 */
U_STABLE UBool U_EXPORT2
u_islower(UChar32 c);

/**
 * Determines whether the specified code point has the general category "Lu"
 * (uppercase letter).
 *
 * Same as java.lang.Character.isUpperCase().
 *
 * This misses some characters that are also uppercase but
 * have a different general category value.
 * In order to include those, use UCHAR_UPPERCASE.
 *
 * In addition to being equivalent to a Java function, this also serves
 * as a C/POSIX migration function.
 * See the comments about C/POSIX character classification functions in the
 * documentation at the top of this header file.
 *
 * @param c the code point to be tested
 * @return TRUE if the code point is an Lu uppercase letter
 *
 * @see UCHAR_UPPERCASE
 * @see u_islower
 * @see u_istitle
 * @see u_tolower
 * @stable ICU 2.0
 */
U_STABLE UBool U_EXPORT2
u_isupper(UChar32 c);

/**
 * Determines whether the specified code point is a titlecase letter.
 * True for general category "Lt" (titlecase letter).
 *
 * Same as java.lang.Character.isTitleCase().
 *
 * @param c the code point to be tested
 * @return TRUE if the code point is an Lt titlecase letter
 *
 * @see u_isupper
 * @see u_islower
 * @see u_totitle
 * @stable ICU 2.0
 */
U_STABLE UBool U_EXPORT2
u_istitle(UChar32 c);

/**
 * Determines whether the specified code point is a digit character according to Java.
 * True for characters with general category "Nd" (decimal digit numbers).
 * Beginning with Unicode 4, this is the same as
 * testing for the Numeric_Type of Decimal.
 *
 * Same as java.lang.Character.isDigit().
 *
 * In addition to being equivalent to a Java function, this also serves
 * as a C/POSIX migration function.
 * See the comments about C/POSIX character classification functions in the
 * documentation at the top of this header file.
 *
 * @param c the code point to be tested
 * @return TRUE if the code point is a digit character according to Character.isDigit()
 *
 * @stable ICU 2.0
 */
U_STABLE UBool U_EXPORT2
u_isdigit(UChar32 c);

/**
 * Determines whether the specified code point is a letter character.
 * True for general categories "L" (letters).
 *
 * Same as java.lang.Character.isLetter().
 *
 * In addition to being equivalent to a Java function, this also serves
 * as a C/POSIX migration function.
 * See the comments about C/POSIX character classification functions in the
 * documentation at the top of this header file.
 *
 * @param c the code point to be tested
 * @return TRUE if the code point is a letter character
 *
 * @see u_isdigit
 * @see u_isalnum
 * @stable ICU 2.0
 */
U_STABLE UBool U_EXPORT2
u_isalpha(UChar32 c);

/**
 * Determines whether the specified code point is an alphanumeric character
 * (letter or digit) according to Java.
 * True for characters with general categories
 * "L" (letters) and "Nd" (decimal digit numbers).
 *
 * Same as java.lang.Character.isLetterOrDigit().
 *
 * In addition to being equivalent to a Java function, this also serves
 * as a C/POSIX migration function.
 * See the comments about C/POSIX character classification functions in the
 * documentation at the top of this header file.
 *
 * @param c the code point to be tested
 * @return TRUE if the code point is an alphanumeric character according to Character.isLetterOrDigit()
 *
 * @stable ICU 2.0
 */
U_STABLE UBool U_EXPORT2
u_isalnum(UChar32 c);

/**
 * Determines whether the specified code point is a hexadecimal digit.
 * This is equivalent to u_digit(c, 16)>=0.
 * True for characters with general category "Nd" (decimal digit numbers)
 * as well as Latin letters a-f and A-F in both ASCII and Fullwidth ASCII.
 * (That is, for letters with code points
 * 0041..0046, 0061..0066, FF21..FF26, FF41..FF46.)
 *
 * In order to narrow the definition of hexadecimal digits to only ASCII
 * characters, use (c<=0x7f && u_isxdigit(c)).
 *
 * This is a C/POSIX migration function.
 * See the comments about C/POSIX character classification functions in the
 * documentation at the top of this header file.
 *
 * @param c the code point to be tested
 * @return TRUE if the code point is a hexadecimal digit
 *
 * @stable ICU 2.6
 */
U_STABLE UBool U_EXPORT2
u_isxdigit(UChar32 c);

/**
 * Determines whether the specified code point is a punctuation character.
 * True for characters with general categories "P" (punctuation).
 *
 * This is a C/POSIX migration function.
 * See the comments about C/POSIX character classification functions in the
 * documentation at the top of this header file.
 *
 * @param c the code point to be tested
 * @return TRUE if the code point is a punctuation character
 *
 * @stable ICU 2.6
 */
U_STABLE UBool U_EXPORT2
u_ispunct(UChar32 c);

/**
 * Determines whether the specified code point is a "graphic" character
 * (printable, excluding spaces).
 * TRUE for all characters except those with general categories
 * "Cc" (control codes), "Cf" (format controls), "Cs" (surrogates),
 * "Cn" (unassigned), and "Z" (separators).
 *
 * This is a C/POSIX migration function.
 * See the comments about C/POSIX character classification functions in the
 * documentation at the top of this header file.
 *
 * @param c the code point to be tested
 * @return TRUE if the code point is a "graphic" character
 *
 * @stable ICU 2.6
 */
U_STABLE UBool U_EXPORT2
u_isgraph(UChar32 c);

/**
 * Determines whether the specified code point is a "blank" or "horizontal space",
 * a character that visibly separates words on a line.
 * The following are equivalent definitions:
 *
 * TRUE for Unicode White_Space characters except for "vertical space controls"
 * where "vertical space controls" are the following characters:
 * U+000A (LF) U+000B (VT) U+000C (FF) U+000D (CR) U+0085 (NEL) U+2028 (LS) U+2029 (PS)
 *
 * same as
 *
 * TRUE for U+0009 (TAB) and characters with general category "Zs" (space separators)
 * except Zero Width Space (ZWSP, U+200B).
 *
 * Note: There are several ICU whitespace functions; please see the uchar.h
 * file documentation for a detailed comparison.
 *
 * This is a C/POSIX migration function.
 * See the comments about C/POSIX character classification functions in the
 * documentation at the top of this header file.
 *
 * @param c the code point to be tested
 * @return TRUE if the code point is a "blank"
 *
 * @stable ICU 2.6
 */
U_STABLE UBool U_EXPORT2
u_isblank(UChar32 c);

/**
 * Determines whether the specified code point is "defined",
 * which usually means that it is assigned a character.
 * True for general categories other than "Cn" (other, not assigned),
 * i.e., true for all code points mentioned in UnicodeData.txt.
 *
 * Note that non-character code points (e.g., U+FDD0) are not "defined"
 * (they are Cn), but surrogate code points are "defined" (Cs).
 *
 * Same as java.lang.Character.isDefined().
 *
 * @param c the code point to be tested
 * @return TRUE if the code point is assigned a character
 *
 * @see u_isdigit
 * @see u_isalpha
 * @see u_isalnum
 * @see u_isupper
 * @see u_islower
 * @see u_istitle
 * @stable ICU 2.0
 */
U_STABLE UBool U_EXPORT2
u_isdefined(UChar32 c);

/**
 * Determines if the specified character is a space character or not.
 *
 * Note: There are several ICU whitespace functions; please see the uchar.h
 * file documentation for a detailed comparison.
 *
 * This is a C/POSIX migration function.
 * See the comments about C/POSIX character classification functions in the
 * documentation at the top of this header file.
 *
 * @param c    the character to be tested
 * @return  true if the character is a space character; false otherwise.
 *
 * @see u_isJavaSpaceChar
 * @see u_isWhitespace
 * @see u_isUWhiteSpace
 * @stable ICU 2.0
 */
U_STABLE UBool U_EXPORT2
u_isspace(UChar32 c);

/**
 * Determine if the specified code point is a space character according to Java.
 * True for characters with general categories "Z" (separators),
 * which does not include control codes (e.g., TAB or Line Feed).
 *
 * Same as java.lang.Character.isSpaceChar().
 *
 * Note: There are several ICU whitespace functions; please see the uchar.h
 * file documentation for a detailed comparison.
 *
 * @param c the code point to be tested
 * @return TRUE if the code point is a space character according to Character.isSpaceChar()
 *
 * @see u_isspace
 * @see u_isWhitespace
 * @see u_isUWhiteSpace
 * @stable ICU 2.6
 */
U_STABLE UBool U_EXPORT2
u_isJavaSpaceChar(UChar32 c);

/**
 * Determines if the specified code point is a whitespace character according to Java/ICU.
 * A character is considered to be a Java whitespace character if and only
 * if it satisfies one of the following criteria:
 *
 * - It is a Unicode separator (categories "Z"), but is not
 *      a no-break space (U+00A0 NBSP or U+2007 Figure Space or U+202F Narrow NBSP).
 * - It is U+0009 HORIZONTAL TABULATION.
 * - It is U+000A LINE FEED.
 * - It is U+000B VERTICAL TABULATION.
 * - It is U+000C FORM FEED.
 * - It is U+000D CARRIAGE RETURN.
 * - It is U+001C FILE SEPARATOR.
 * - It is U+001D GROUP SEPARATOR.
 * - It is U+001E RECORD SEPARATOR.
 * - It is U+001F UNIT SEPARATOR.
 * - It is U+0085 NEXT LINE.
 *
 * Same as java.lang.Character.isWhitespace() except that Java omits U+0085.
 *
 * Note: There are several ICU whitespace functions; please see the uchar.h
 * file documentation for a detailed comparison.
 *
 * @param c the code point to be tested
 * @return TRUE if the code point is a whitespace character according to Java/ICU
 *
 * @see u_isspace
 * @see u_isJavaSpaceChar
 * @see u_isUWhiteSpace
 * @stable ICU 2.0
 */
U_STABLE UBool U_EXPORT2
u_isWhitespace(UChar32 c);

/**
 * Determines whether the specified code point is a control character
 * (as defined by this function).
 * A control character is one of the following:
 * - ISO 8-bit control character (U+0000..U+001f and U+007f..U+009f)
 * - U_CONTROL_CHAR (Cc)
 * - U_FORMAT_CHAR (Cf)
 * - U_LINE_SEPARATOR (Zl)
 * - U_PARAGRAPH_SEPARATOR (Zp)
 *
 * This is a C/POSIX migration function.
 * See the comments about C/POSIX character classification functions in the
 * documentation at the top of this header file.
 *
 * @param c the code point to be tested
 * @return TRUE if the code point is a control character
 *
 * @see UCHAR_DEFAULT_IGNORABLE_CODE_POINT
 * @see u_isprint
 * @stable ICU 2.0
 */
U_STABLE UBool U_EXPORT2
u_iscntrl(UChar32 c);

/**
 * Determines whether the specified code point is an ISO control code.
 * True for U+0000..U+001f and U+007f..U+009f (general category "Cc").
 *
 * Same as java.lang.Character.isISOControl().
 *
 * @param c the code point to be tested
 * @return TRUE if the code point is an ISO control code
 *
 * @see u_iscntrl
 * @stable ICU 2.6
 */
U_STABLE UBool U_EXPORT2
u_isISOControl(UChar32 c);

/**
 * Determines whether the specified code point is a printable character.
 * True for general categories <em>other</em> than "C" (controls).
 *
 * This is a C/POSIX migration function.
 * See the comments about C/POSIX character classification functions in the
 * documentation at the top of this header file.
 *
 * @param c the code point to be tested
 * @return TRUE if the code point is a printable character
 *
 * @see UCHAR_DEFAULT_IGNORABLE_CODE_POINT
 * @see u_iscntrl
 * @stable ICU 2.0
 */
U_STABLE UBool U_EXPORT2
u_isprint(UChar32 c);

/**
 * Determines whether the specified code point is a base character.
 * True for general categories "L" (letters), "N" (numbers),
 * "Mc" (spacing combining marks), and "Me" (enclosing marks).
 *
 * Note that this is different from the Unicode definition in
 * chapter 3.5, conformance clause D13,
 * which defines base characters to be all characters (not Cn)
 * that do not graphically combine with preceding characters (M)
 * and that are neither control (Cc) or format (Cf) characters.
 *
 * @param c the code point to be tested
 * @return TRUE if the code point is a base character according to this function
 *
 * @see u_isalpha
 * @see u_isdigit
 * @stable ICU 2.0
 */
U_STABLE UBool U_EXPORT2
u_isbase(UChar32 c);

/**
 * Returns the bidirectional category value for the code point,
 * which is used in the Unicode bidirectional algorithm
 * (UAX #9 http://www.unicode.org/reports/tr9/).
 * Note that some <em>unassigned</em> code points have bidi values
 * of R or AL because they are in blocks that are reserved
 * for Right-To-Left scripts.
 *
 * Same as java.lang.Character.getDirectionality()
 *
 * @param c the code point to be tested
 * @return the bidirectional category (UCharDirection) value
 *
 * @see UCharDirection
 * @stable ICU 2.0
 */
U_STABLE UCharDirection U_EXPORT2
u_charDirection(UChar32 c);

/**
 * Determines whether the code point has the Bidi_Mirrored property.
 * This property is set for characters that are commonly used in
 * Right-To-Left contexts and need to be displayed with a "mirrored"
 * glyph.
 *
 * Same as java.lang.Character.isMirrored().
 * Same as UCHAR_BIDI_MIRRORED
 *
 * @param c the code point to be tested
 * @return TRUE if the character has the Bidi_Mirrored property
 *
 * @see UCHAR_BIDI_MIRRORED
 * @stable ICU 2.0
 */
U_STABLE UBool U_EXPORT2
u_isMirrored(UChar32 c);

/**
 * Maps the specified character to a "mirror-image" character.
 * For characters with the Bidi_Mirrored property, implementations
 * sometimes need a "poor man's" mapping to another Unicode
 * character (code point) such that the default glyph may serve
 * as the mirror-image of the default glyph of the specified
 * character. This is useful for text conversion to and from
 * codepages with visual order, and for displays without glyph
 * selecetion capabilities.
 *
 * @param c the code point to be mapped
 * @return another Unicode code point that may serve as a mirror-image
 *         substitute, or c itself if there is no such mapping or c
 *         does not have the Bidi_Mirrored property
 *
 * @see UCHAR_BIDI_MIRRORED
 * @see u_isMirrored
 * @stable ICU 2.0
 */
U_STABLE UChar32 U_EXPORT2
u_charMirror(UChar32 c);

/**
 * Returns the general category value for the code point.
 *
 * Same as java.lang.Character.getType().
 *
 * @param c the code point to be tested
 * @return the general category (UCharCategory) value
 *
 * @see UCharCategory
 * @stable ICU 2.0
 */
U_STABLE int8_t U_EXPORT2
u_charType(UChar32 c);

/**
 * Get a single-bit bit set for the general category of a character.
 * This bit set can be compared bitwise with U_GC_SM_MASK, U_GC_L_MASK, etc.
 * Same as U_MASK(u_charType(c)).
 *
 * @param c the code point to be tested
 * @return a single-bit mask corresponding to the general category (UCharCategory) value
 *
 * @see u_charType
 * @see UCharCategory
 * @see U_GC_CN_MASK
 * @stable ICU 2.1
 */
#define U_GET_GC_MASK(c) U_MASK(u_charType(c))

/**
 * Callback from u_enumCharTypes(), is called for each contiguous range
 * of code points c (where start<=c<limit)
 * with the same Unicode general category ("character type").
 *
 * The callback function can stop the enumeration by returning FALSE.
 *
 * @param context an opaque pointer, as passed into utrie_enum()
 * @param start the first code point in a contiguous range with value
 * @param limit one past the last code point in a contiguous range with value
 * @param type the general category for all code points in [start..limit[
 * @return FALSE to stop the enumeration
 *
 * @stable ICU 2.1
 * @see UCharCategory
 * @see u_enumCharTypes
 */
typedef UBool U_CALLCONV
UCharEnumTypeRange(const void *context, UChar32 start, UChar32 limit, UCharCategory type);

/**
 * Enumerate efficiently all code points with their Unicode general categories.
 *
 * This is useful for building data structures (e.g., UnicodeSet's),
 * for enumerating all assigned code points (type!=U_UNASSIGNED), etc.
 *
 * For each contiguous range of code points with a given general category ("character type"),
 * the UCharEnumTypeRange function is called.
 * Adjacent ranges have different types.
 * The Unicode Standard guarantees that the numeric value of the type is 0..31.
 *
 * @param enumRange a pointer to a function that is called for each contiguous range
 *                  of code points with the same general category
 * @param context an opaque pointer that is passed on to the callback function
 *
 * @stable ICU 2.1
 * @see UCharCategory
 * @see UCharEnumTypeRange
 */
U_STABLE void U_EXPORT2
u_enumCharTypes(UCharEnumTypeRange *enumRange, const void *context);

#if !UCONFIG_NO_NORMALIZATION

/**
 * Returns the combining class of the code point as specified in UnicodeData.txt.
 *
 * @param c the code point of the character
 * @return the combining class of the character
 * @stable ICU 2.0
 */
U_STABLE uint8_t U_EXPORT2
u_getCombiningClass(UChar32 c);

#endif

/**
 * Returns the decimal digit value of a decimal digit character.
 * Such characters have the general category "Nd" (decimal digit numbers)
 * and a Numeric_Type of Decimal.
 *
 * Unlike ICU releases before 2.6, no digit values are returned for any
 * Han characters because Han number characters are often used with a special
 * Chinese-style number format (with characters for powers of 10 in between)
 * instead of in decimal-positional notation.
 * Unicode 4 explicitly assigns Han number characters the Numeric_Type
 * Numeric instead of Decimal.
 * See Jitterbug 1483 for more details.
 *
 * Use u_getIntPropertyValue(c, UCHAR_NUMERIC_TYPE) and u_getNumericValue()
 * for complete numeric Unicode properties.
 *
 * @param c the code point for which to get the decimal digit value
 * @return the decimal digit value of c,
 *         or -1 if c is not a decimal digit character
 *
 * @see u_getNumericValue
 * @stable ICU 2.0
 */
U_STABLE int32_t U_EXPORT2
u_charDigitValue(UChar32 c);

/**
 * Returns the Unicode allocation block that contains the character.
 *
 * @param c the code point to be tested
 * @return the block value (UBlockCode) for c
 *
 * @see UBlockCode
 * @stable ICU 2.0
 */
U_STABLE UBlockCode U_EXPORT2
ublock_getCode(UChar32 c);

/**
 * Retrieve the name of a Unicode character.
 * Depending on <code>nameChoice</code>, the character name written
 * into the buffer is the "modern" name or the name that was defined
 * in Unicode version 1.0.
 * The name contains only "invariant" characters
 * like A-Z, 0-9, space, and '-'.
 * Unicode 1.0 names are only retrieved if they are different from the modern
 * names and if the data file contains the data for them. gennames may or may
 * not be called with a command line option to include 1.0 names in unames.dat.
 *
 * @param code The character (code point) for which to get the name.
 *             It must be <code>0<=code<=0x10ffff</code>.
 * @param nameChoice Selector for which name to get.
 * @param buffer Destination address for copying the name.
 *               The name will always be zero-terminated.
 *               If there is no name, then the buffer will be set to the empty string.
 * @param bufferLength <code>==sizeof(buffer)</code>
 * @param pErrorCode Pointer to a UErrorCode variable;
 *        check for <code>U_SUCCESS()</code> after <code>u_charName()</code>
 *        returns.
 * @return The length of the name, or 0 if there is no name for this character.
 *         If the bufferLength is less than or equal to the length, then the buffer
 *         contains the truncated name and the returned length indicates the full
 *         length of the name.
 *         The length does not include the zero-termination.
 *
 * @see UCharNameChoice
 * @see u_charFromName
 * @see u_enumCharNames
 * @stable ICU 2.0
 */
U_STABLE int32_t U_EXPORT2
u_charName(UChar32 code, UCharNameChoice nameChoice,
           char *buffer, int32_t bufferLength,
           UErrorCode *pErrorCode);

/**
 * Get the ISO 10646 comment for a character.
 * The ISO 10646 comment is an informative field in the Unicode Character
 * Database (UnicodeData.txt field 11) and is from the ISO 10646 names list.
 *
 * @param c The character (code point) for which to get the ISO comment.
 *             It must be <code>0<=c<=0x10ffff</code>.
 * @param dest Destination address for copying the comment.
 *             The comment will be zero-terminated if possible.
 *             If there is no comment, then the buffer will be set to the empty string.
 * @param destCapacity <code>==sizeof(dest)</code>
 * @param pErrorCode Pointer to a UErrorCode variable;
 *        check for <code>U_SUCCESS()</code> after <code>u_getISOComment()</code>
 *        returns.
 * @return The length of the comment, or 0 if there is no comment for this character.
 *         If the destCapacity is less than or equal to the length, then the buffer
 *         contains the truncated name and the returned length indicates the full
 *         length of the name.
 *         The length does not include the zero-termination.
 *
 * @stable ICU 2.2
 */
U_STABLE int32_t U_EXPORT2
u_getISOComment(UChar32 c,
                char *dest, int32_t destCapacity,
                UErrorCode *pErrorCode);

/**
 * Find a Unicode character by its name and return its code point value.
 * The name is matched exactly and completely.
 * If the name does not correspond to a code point, <i>pErrorCode</i>
 * is set to <code>U_INVALID_CHAR_FOUND</code>.
 * A Unicode 1.0 name is matched only if it differs from the modern name.
 * Unicode names are all uppercase. Extended names are lowercase followed
 * by an uppercase hexadecimal number, and within angle brackets.
 *
 * @param nameChoice Selector for which name to match.
 * @param name The name to match.
 * @param pErrorCode Pointer to a UErrorCode variable
 * @return The Unicode value of the code point with the given name,
 *         or an undefined value if there is no such code point.
 *
 * @see UCharNameChoice
 * @see u_charName
 * @see u_enumCharNames
 * @stable ICU 1.7
 */
U_STABLE UChar32 U_EXPORT2
u_charFromName(UCharNameChoice nameChoice,
               const char *name,
               UErrorCode *pErrorCode);

/**
 * Type of a callback function for u_enumCharNames() that gets called
 * for each Unicode character with the code point value and
 * the character name.
 * If such a function returns FALSE, then the enumeration is stopped.
 *
 * @param context The context pointer that was passed to u_enumCharNames().
 * @param code The Unicode code point for the character with this name.
 * @param nameChoice Selector for which kind of names is enumerated.
 * @param name The character's name, zero-terminated.
 * @param length The length of the name.
 * @return TRUE if the enumeration should continue, FALSE to stop it.
 *
 * @see UCharNameChoice
 * @see u_enumCharNames
 * @stable ICU 1.7
 */
typedef UBool UEnumCharNamesFn(void *context,
                               UChar32 code,
                               UCharNameChoice nameChoice,
                               const char *name,
                               int32_t length);

/**
 * Enumerate all assigned Unicode characters between the start and limit
 * code points (start inclusive, limit exclusive) and call a function
 * for each, passing the code point value and the character name.
 * For Unicode 1.0 names, only those are enumerated that differ from the
 * modern names.
 *
 * @param start The first code point in the enumeration range.
 * @param limit One more than the last code point in the enumeration range
 *              (the first one after the range).
 * @param fn The function that is to be called for each character name.
 * @param context An arbitrary pointer that is passed to the function.
 * @param nameChoice Selector for which kind of names to enumerate.
 * @param pErrorCode Pointer to a UErrorCode variable
 *
 * @see UCharNameChoice
 * @see UEnumCharNamesFn
 * @see u_charName
 * @see u_charFromName
 * @stable ICU 1.7
 */
U_STABLE void U_EXPORT2
u_enumCharNames(UChar32 start, UChar32 limit,
                UEnumCharNamesFn *fn,
                void *context,
                UCharNameChoice nameChoice,
                UErrorCode *pErrorCode);

/**
 * Return the Unicode name for a given property, as given in the
 * Unicode database file PropertyAliases.txt.
 *
 * In addition, this function maps the property
 * UCHAR_GENERAL_CATEGORY_MASK to the synthetic names "gcm" /
 * "General_Category_Mask".  These names are not in
 * PropertyAliases.txt.
 *
 * @param property UProperty selector other than UCHAR_INVALID_CODE.
 *         If out of range, NULL is returned.
 *
 * @param nameChoice selector for which name to get.  If out of range,
 *         NULL is returned.  All properties have a long name.  Most
 *         have a short name, but some do not.  Unicode allows for
 *         additional names; if present these will be returned by
 *         U_LONG_PROPERTY_NAME + i, where i=1, 2,...
 *
 * @return a pointer to the name, or NULL if either the
 *         property or the nameChoice is out of range.  If a given
 *         nameChoice returns NULL, then all larger values of
 *         nameChoice will return NULL, with one exception: if NULL is
 *         returned for U_SHORT_PROPERTY_NAME, then
 *         U_LONG_PROPERTY_NAME (and higher) may still return a
 *         non-NULL value.  The returned pointer is valid until
 *         u_cleanup() is called.
 *
 * @see UProperty
 * @see UPropertyNameChoice
 * @stable ICU 2.4
 */
U_STABLE const char* U_EXPORT2
u_getPropertyName(UProperty property,
                  UPropertyNameChoice nameChoice);

/**
 * Return the UProperty enum for a given property name, as specified
 * in the Unicode database file PropertyAliases.txt.  Short, long, and
 * any other variants are recognized.
 *
 * In addition, this function maps the synthetic names "gcm" /
 * "General_Category_Mask" to the property
 * UCHAR_GENERAL_CATEGORY_MASK.  These names are not in
 * PropertyAliases.txt.
 *
 * @param alias the property name to be matched.  The name is compared
 *         using "loose matching" as described in PropertyAliases.txt.
 *
 * @return a UProperty enum, or UCHAR_INVALID_CODE if the given name
 *         does not match any property.
 *
 * @see UProperty
 * @stable ICU 2.4
 */
U_STABLE UProperty U_EXPORT2
u_getPropertyEnum(const char* alias);

/**
 * Return the Unicode name for a given property value, as given in the
 * Unicode database file PropertyValueAliases.txt.
 *
 * Note: Some of the names in PropertyValueAliases.txt can only be
 * retrieved using UCHAR_GENERAL_CATEGORY_MASK, not
 * UCHAR_GENERAL_CATEGORY.  These include: "C" / "Other", "L" /
 * "Letter", "LC" / "Cased_Letter", "M" / "Mark", "N" / "Number", "P"
 * / "Punctuation", "S" / "Symbol", and "Z" / "Separator".
 *
 * @param property UProperty selector constant.
 *        Must be UCHAR_BINARY_START<=which<UCHAR_BINARY_LIMIT
 *        or UCHAR_INT_START<=which<UCHAR_INT_LIMIT
 *        or UCHAR_MASK_START<=which<UCHAR_MASK_LIMIT.
 *        If out of range, NULL is returned.
 *
 * @param value selector for a value for the given property.  If out
 *         of range, NULL is returned.  In general, valid values range
 *         from 0 up to some maximum.  There are a few exceptions:
 *         (1.) UCHAR_BLOCK values begin at the non-zero value
 *         UBLOCK_BASIC_LATIN.  (2.)  UCHAR_CANONICAL_COMBINING_CLASS
 *         values are not contiguous and range from 0..240.  (3.)
 *         UCHAR_GENERAL_CATEGORY_MASK values are not values of
 *         UCharCategory, but rather mask values produced by
 *         U_GET_GC_MASK().  This allows grouped categories such as
 *         [:L:] to be represented.  Mask values range
 *         non-contiguously from 1..U_GC_P_MASK.
 *
 * @param nameChoice selector for which name to get.  If out of range,
 *         NULL is returned.  All values have a long name.  Most have
 *         a short name, but some do not.  Unicode allows for
 *         additional names; if present these will be returned by
 *         U_LONG_PROPERTY_NAME + i, where i=1, 2,...

 * @return a pointer to the name, or NULL if either the
 *         property or the nameChoice is out of range.  If a given
 *         nameChoice returns NULL, then all larger values of
 *         nameChoice will return NULL, with one exception: if NULL is
 *         returned for U_SHORT_PROPERTY_NAME, then
 *         U_LONG_PROPERTY_NAME (and higher) may still return a
 *         non-NULL value.  The returned pointer is valid until
 *         u_cleanup() is called.
 *
 * @see UProperty
 * @see UPropertyNameChoice
 * @stable ICU 2.4
 */
U_STABLE const char* U_EXPORT2
u_getPropertyValueName(UProperty property,
                       int32_t value,
                       UPropertyNameChoice nameChoice);

/**
 * Return the property value integer for a given value name, as
 * specified in the Unicode database file PropertyValueAliases.txt.
 * Short, long, and any other variants are recognized.
 *
 * Note: Some of the names in PropertyValueAliases.txt will only be
 * recognized with UCHAR_GENERAL_CATEGORY_MASK, not
 * UCHAR_GENERAL_CATEGORY.  These include: "C" / "Other", "L" /
 * "Letter", "LC" / "Cased_Letter", "M" / "Mark", "N" / "Number", "P"
 * / "Punctuation", "S" / "Symbol", and "Z" / "Separator".
 *
 * @param property UProperty selector constant.
 *        Must be UCHAR_BINARY_START<=which<UCHAR_BINARY_LIMIT
 *        or UCHAR_INT_START<=which<UCHAR_INT_LIMIT
 *        or UCHAR_MASK_START<=which<UCHAR_MASK_LIMIT.
 *        If out of range, UCHAR_INVALID_CODE is returned.
 *
 * @param alias the value name to be matched.  The name is compared
 *         using "loose matching" as described in
 *         PropertyValueAliases.txt.
 *
 * @return a value integer or UCHAR_INVALID_CODE if the given name
 *         does not match any value of the given property, or if the
 *         property is invalid.  Note: U CHAR_GENERAL_CATEGORY values
 *         are not values of UCharCategory, but rather mask values
 *         produced by U_GET_GC_MASK().  This allows grouped
 *         categories such as [:L:] to be represented.
 *
 * @see UProperty
 * @stable ICU 2.4
 */
U_STABLE int32_t U_EXPORT2
u_getPropertyValueEnum(UProperty property,
                       const char* alias);

/**
 * Determines if the specified character is permissible as the
 * first character in an identifier according to Unicode
 * (The Unicode Standard, Version 3.0, chapter 5.16 Identifiers).
 * True for characters with general categories "L" (letters) and "Nl" (letter numbers).
 *
 * Same as java.lang.Character.isUnicodeIdentifierStart().
 * Same as UCHAR_ID_START
 *
 * @param c the code point to be tested
 * @return TRUE if the code point may start an identifier
 *
 * @see UCHAR_ID_START
 * @see u_isalpha
 * @see u_isIDPart
 * @stable ICU 2.0
 */
U_STABLE UBool U_EXPORT2
u_isIDStart(UChar32 c);

/**
 * Determines if the specified character is permissible
 * in an identifier according to Java.
 * True for characters with general categories "L" (letters),
 * "Nl" (letter numbers), "Nd" (decimal digits),
 * "Mc" and "Mn" (combining marks), "Pc" (connecting punctuation), and
 * u_isIDIgnorable(c).
 *
 * Same as java.lang.Character.isUnicodeIdentifierPart().
 * Almost the same as Unicode's ID_Continue (UCHAR_ID_CONTINUE)
 * except that Unicode recommends to ignore Cf which is less than
 * u_isIDIgnorable(c).
 *
 * @param c the code point to be tested
 * @return TRUE if the code point may occur in an identifier according to Java
 *
 * @see UCHAR_ID_CONTINUE
 * @see u_isIDStart
 * @see u_isIDIgnorable
 * @stable ICU 2.0
 */
U_STABLE UBool U_EXPORT2
u_isIDPart(UChar32 c);

/**
 * Determines if the specified character should be regarded
 * as an ignorable character in an identifier,
 * according to Java.
 * True for characters with general category "Cf" (format controls) as well as
 * non-whitespace ISO controls
 * (U+0000..U+0008, U+000E..U+001B, U+007F..U+0084, U+0086..U+009F).
 *
 * Same as java.lang.Character.isIdentifierIgnorable()
 * except that Java also returns TRUE for U+0085 Next Line
 * (it omits U+0085 from whitespace ISO controls).
 *
 * Note that Unicode just recommends to ignore Cf (format controls).
 *
 * @param c the code point to be tested
 * @return TRUE if the code point is ignorable in identifiers according to Java
 *
 * @see UCHAR_DEFAULT_IGNORABLE_CODE_POINT
 * @see u_isIDStart
 * @see u_isIDPart
 * @stable ICU 2.0
 */
U_STABLE UBool U_EXPORT2
u_isIDIgnorable(UChar32 c);

/**
 * Determines if the specified character is permissible as the
 * first character in a Java identifier.
 * In addition to u_isIDStart(c), true for characters with
 * general categories "Sc" (currency symbols) and "Pc" (connecting punctuation).
 *
 * Same as java.lang.Character.isJavaIdentifierStart().
 *
 * @param c the code point to be tested
 * @return TRUE if the code point may start a Java identifier
 *
 * @see     u_isJavaIDPart
 * @see     u_isalpha
 * @see     u_isIDStart
 * @stable ICU 2.0
 */
U_STABLE UBool U_EXPORT2
u_isJavaIDStart(UChar32 c);

/**
 * Determines if the specified character is permissible
 * in a Java identifier.
 * In addition to u_isIDPart(c), true for characters with
 * general category "Sc" (currency symbols).
 *
 * Same as java.lang.Character.isJavaIdentifierPart().
 *
 * @param c the code point to be tested
 * @return TRUE if the code point may occur in a Java identifier
 *
 * @see     u_isIDIgnorable
 * @see     u_isJavaIDStart
 * @see     u_isalpha
 * @see     u_isdigit
 * @see     u_isIDPart
 * @stable ICU 2.0
 */
U_STABLE UBool U_EXPORT2
u_isJavaIDPart(UChar32 c);

/**
 * The given character is mapped to its lowercase equivalent according to
 * UnicodeData.txt; if the character has no lowercase equivalent, the character
 * itself is returned.
 *
 * Same as java.lang.Character.toLowerCase().
 *
 * This function only returns the simple, single-code point case mapping.
 * Full case mappings may result in zero, one or more code points and depend
 * on context or language etc.
 * Full case mappings are applied by the string case mapping functions,
 * see ustring.h and the UnicodeString class.
 *
 * @param c the code point to be mapped
 * @return the Simple_Lowercase_Mapping of the code point, if any;
 *         otherwise the code point itself.
 * @stable ICU 2.0
 */
U_STABLE UChar32 U_EXPORT2
u_tolower(UChar32 c);

/**
 * The given character is mapped to its uppercase equivalent according to UnicodeData.txt;
 * if the character has no uppercase equivalent, the character itself is
 * returned.
 *
 * Same as java.lang.Character.toUpperCase().
 *
 * This function only returns the simple, single-code point case mapping.
 * Full case mappings may result in zero, one or more code points and depend
 * on context or language etc.
 * Full case mappings are applied by the string case mapping functions,
 * see ustring.h and the UnicodeString class.
 *
 * @param c the code point to be mapped
 * @return the Simple_Uppercase_Mapping of the code point, if any;
 *         otherwise the code point itself.
 * @stable ICU 2.0
 */
U_STABLE UChar32 U_EXPORT2
u_toupper(UChar32 c);

/**
 * The given character is mapped to its titlecase equivalent
 * according to UnicodeData.txt;
 * if none is defined, the character itself is returned.
 *
 * Same as java.lang.Character.toTitleCase().
 *
 * This function only returns the simple, single-code point case mapping.
 * Full case mappings may result in zero, one or more code points and depend
 * on context or language etc.
 * Full case mappings are applied by the string case mapping functions,
 * see ustring.h and the UnicodeString class.
 *
 * @param c the code point to be mapped
 * @return the Simple_Titlecase_Mapping of the code point, if any;
 *         otherwise the code point itself.
 * @stable ICU 2.0
 */
U_STABLE UChar32 U_EXPORT2
u_totitle(UChar32 c);

/** Option value for case folding: use default mappings defined in CaseFolding.txt. @stable ICU 2.0 */
#define U_FOLD_CASE_DEFAULT 0

/**
 * Option value for case folding:
 *
 * Use the modified set of mappings provided in CaseFolding.txt to handle dotted I
 * and dotless i appropriately for Turkic languages (tr, az).
 *
 * Before Unicode 3.2, CaseFolding.txt contains mappings marked with 'I' that
 * are to be included for default mappings and
 * excluded for the Turkic-specific mappings.
 *
 * Unicode 3.2 CaseFolding.txt instead contains mappings marked with 'T' that
 * are to be excluded for default mappings and
 * included for the Turkic-specific mappings.
 *
 * @stable ICU 2.0
 */
#define U_FOLD_CASE_EXCLUDE_SPECIAL_I 1

/**
 * The given character is mapped to its case folding equivalent according to
 * UnicodeData.txt and CaseFolding.txt;
 * if the character has no case folding equivalent, the character
 * itself is returned.
 *
 * This function only returns the simple, single-code point case mapping.
 * Full case mappings may result in zero, one or more code points and depend
 * on context or language etc.
 * Full case mappings are applied by the string case mapping functions,
 * see ustring.h and the UnicodeString class.
 *
 * @param c the code point to be mapped
 * @param options Either U_FOLD_CASE_DEFAULT or U_FOLD_CASE_EXCLUDE_SPECIAL_I
 * @return the Simple_Case_Folding of the code point, if any;
 *         otherwise the code point itself.
 * @stable ICU 2.0
 */
U_STABLE UChar32 U_EXPORT2
u_foldCase(UChar32 c, uint32_t options);

/**
 * Returns the decimal digit value of the code point in the
 * specified radix.
 *
 * If the radix is not in the range <code>2<=radix<=36</code> or if the
 * value of <code>c</code> is not a valid digit in the specified
 * radix, <code>-1</code> is returned. A character is a valid digit
 * if at least one of the following is true:
 * <ul>
 * <li>The character has a decimal digit value.
 *     Such characters have the general category "Nd" (decimal digit numbers)
 *     and a Numeric_Type of Decimal.
 *     In this case the value is the character's decimal digit value.</li>
 * <li>The character is one of the uppercase Latin letters
 *     <code>'A'</code> through <code>'Z'</code>.
 *     In this case the value is <code>c-'A'+10</code>.</li>
 * <li>The character is one of the lowercase Latin letters
 *     <code>'a'</code> through <code>'z'</code>.
 *     In this case the value is <code>ch-'a'+10</code>.</li>
 * <li>Latin letters from both the ASCII range (0061..007A, 0041..005A)
 *     as well as from the Fullwidth ASCII range (FF41..FF5A, FF21..FF3A)
 *     are recognized.</li>
 * </ul>
 *
 * Same as java.lang.Character.digit().
 *
 * @param   ch      the code point to be tested.
 * @param   radix   the radix.
 * @return  the numeric value represented by the character in the
 *          specified radix,
 *          or -1 if there is no value or if the value exceeds the radix.
 *
 * @see     UCHAR_NUMERIC_TYPE
 * @see     u_forDigit
 * @see     u_charDigitValue
 * @see     u_isdigit
 * @stable ICU 2.0
 */
U_STABLE int32_t U_EXPORT2
u_digit(UChar32 ch, int8_t radix);

/**
 * Determines the character representation for a specific digit in
 * the specified radix. If the value of <code>radix</code> is not a
 * valid radix, or the value of <code>digit</code> is not a valid
 * digit in the specified radix, the null character
 * (<code>U+0000</code>) is returned.
 * <p>
 * The <code>radix</code> argument is valid if it is greater than or
 * equal to 2 and less than or equal to 36.
 * The <code>digit</code> argument is valid if
 * <code>0 <= digit < radix</code>.
 * <p>
 * If the digit is less than 10, then
 * <code>'0' + digit</code> is returned. Otherwise, the value
 * <code>'a' + digit - 10</code> is returned.
 *
 * Same as java.lang.Character.forDigit().
 *
 * @param   digit   the number to convert to a character.
 * @param   radix   the radix.
 * @return  the <code>char</code> representation of the specified digit
 *          in the specified radix.
 *
 * @see     u_digit
 * @see     u_charDigitValue
 * @see     u_isdigit
 * @stable ICU 2.0
 */
U_STABLE UChar32 U_EXPORT2
u_forDigit(int32_t digit, int8_t radix);

/**
 * Get the "age" of the code point.
 * The "age" is the Unicode version when the code point was first
 * designated (as a non-character or for Private Use)
 * or assigned a character.
 * This can be useful to avoid emitting code points to receiving
 * processes that do not accept newer characters.
 * The data is from the UCD file DerivedAge.txt.
 *
 * @param c The code point.
 * @param versionArray The Unicode version number array, to be filled in.
 *
 * @stable ICU 2.1
 */
U_STABLE void U_EXPORT2
u_charAge(UChar32 c, UVersionInfo versionArray);

/**
 * Gets the Unicode version information.
 * The version array is filled in with the version information
 * for the Unicode standard that is currently used by ICU.
 * For example, Unicode version 3.1.1 is represented as an array with
 * the values { 3, 1, 1, 0 }.
 *
 * @param versionArray an output array that will be filled in with
 *                     the Unicode version number
 * @stable ICU 2.0
 */
U_STABLE void U_EXPORT2
u_getUnicodeVersion(UVersionInfo versionArray);

/**
 * Get the FC_NFKC_Closure property string for a character.
 * See Unicode Standard Annex #15 for details, search for "FC_NFKC_Closure"
 * or for "FNC": http://www.unicode.org/reports/tr15/
 *
 * @param c The character (code point) for which to get the FC_NFKC_Closure string.
 *             It must be <code>0<=c<=0x10ffff</code>.
 * @param dest Destination address for copying the string.
 *             The string will be zero-terminated if possible.
 *             If there is no FC_NFKC_Closure string,
 *             then the buffer will be set to the empty string.
 * @param destCapacity <code>==sizeof(dest)</code>
 * @param pErrorCode Pointer to a UErrorCode variable.
 * @return The length of the string, or 0 if there is no FC_NFKC_Closure string for this character.
 *         If the destCapacity is less than or equal to the length, then the buffer
 *         contains the truncated name and the returned length indicates the full
 *         length of the name.
 *         The length does not include the zero-termination.
 *
 * @stable ICU 2.2
 */
U_STABLE int32_t U_EXPORT2
u_getFC_NFKC_Closure(UChar32 c, UChar *dest, int32_t destCapacity, UErrorCode *pErrorCode);

U_CDECL_END

#endif /*_UCHAR*/
/*eof*/
