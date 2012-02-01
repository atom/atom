/*
******************************************************************************
*
*   Copyright (C) 2000-2004, International Business Machines
*   Corporation and others.  All Rights Reserved.
*
******************************************************************************
*   file name:  ushape.h
*   encoding:   US-ASCII
*   tab size:   8 (not used)
*   indentation:4
*
*   created on: 2000jun29
*   created by: Markus W. Scherer
*/

#ifndef __USHAPE_H__
#define __USHAPE_H__

#include "unicode/utypes.h"

/**
 * \file
 * \brief C API:  Arabic shaping
 * 
 */

/**
 * Shape Arabic text on a character basis.
 *
 * <p>This function performs basic operations for "shaping" Arabic text. It is most
 * useful for use with legacy data formats and legacy display technology
 * (simple terminals). All operations are performed on Unicode characters.</p>
 *
 * <p>Text-based shaping means that some character code points in the text are
 * replaced by others depending on the context. It transforms one kind of text
 * into another. In comparison, modern displays for Arabic text select
 * appropriate, context-dependent font glyphs for each text element, which means
 * that they transform text into a glyph vector.</p>
 *
 * <p>Text transformations are necessary when modern display technology is not
 * available or when text needs to be transformed to or from legacy formats that
 * use "shaped" characters. Since the Arabic script is cursive, connecting
 * adjacent letters to each other, computers select images for each letter based
 * on the surrounding letters. This usually results in four images per Arabic
 * letter: initial, middle, final, and isolated forms. In Unicode, on the other
 * hand, letters are normally stored abstract, and a display system is expected
 * to select the necessary glyphs. (This makes searching and other text
 * processing easier because the same letter has only one code.) It is possible
 * to mimic this with text transformations because there are characters in
 * Unicode that are rendered as letters with a specific shape
 * (or cursive connectivity). They were included for interoperability with
 * legacy systems and codepages, and for unsophisticated display systems.</p>
 *
 * <p>A second kind of text transformations is supported for Arabic digits:
 * For compatibility with legacy codepages that only include European digits,
 * it is possible to replace one set of digits by another, changing the
 * character code points. These operations can be performed for either
 * Arabic-Indic Digits (U+0660...U+0669) or Eastern (Extended) Arabic-Indic
 * digits (U+06f0...U+06f9).</p>
 *
 * <p>Some replacements may result in more or fewer characters (code points).
 * By default, this means that the destination buffer may receive text with a
 * length different from the source length. Some legacy systems rely on the
 * length of the text to be constant. They expect extra spaces to be added
 * or consumed either next to the affected character or at the end of the
 * text.</p>
 *
 * <p>For details about the available operations, see the description of the
 * <code>U_SHAPE_...</code> options.</p>
 *
 * @param source The input text.
 *
 * @param sourceLength The number of UChars in <code>source</code>.
 *
 * @param dest The destination buffer that will receive the results of the
 *             requested operations. It may be <code>NULL</code> only if
 *             <code>destSize</code> is 0. The source and destination must not
 *             overlap.
 *
 * @param destSize The size (capacity) of the destination buffer in UChars.
 *                 If <code>destSize</code> is 0, then no output is produced,
 *                 but the necessary buffer size is returned ("preflighting").
 *
 * @param options This is a 32-bit set of flags that specify the operations
 *                that are performed on the input text. If no error occurs,
 *                then the result will always be written to the destination
 *                buffer.
 *
 * @param pErrorCode must be a valid pointer to an error code value,
 *        which must not indicate a failure before the function call.
 *
 * @return The number of UChars written to the destination buffer.
 *         If an error occured, then no output was written, or it may be
 *         incomplete. If <code>U_BUFFER_OVERFLOW_ERROR</code> is set, then
 *         the return value indicates the necessary destination buffer size.
 * @stable ICU 2.0
 */
U_STABLE int32_t U_EXPORT2
u_shapeArabic(const UChar *source, int32_t sourceLength,
              UChar *dest, int32_t destSize,
              uint32_t options,
              UErrorCode *pErrorCode);

/**
 * Memory option: allow the result to have a different length than the source.
 * @stable ICU 2.0
 */
#define U_SHAPE_LENGTH_GROW_SHRINK              0

/**
 * Memory option: the result must have the same length as the source.
 * If more room is necessary, then try to consume spaces next to modified characters.
 * @stable ICU 2.0
 */
#define U_SHAPE_LENGTH_FIXED_SPACES_NEAR        1

/**
 * Memory option: the result must have the same length as the source.
 * If more room is necessary, then try to consume spaces at the end of the text.
 * @stable ICU 2.0
 */
#define U_SHAPE_LENGTH_FIXED_SPACES_AT_END      2

/**
 * Memory option: the result must have the same length as the source.
 * If more room is necessary, then try to consume spaces at the beginning of the text.
 * @stable ICU 2.0
 */
#define U_SHAPE_LENGTH_FIXED_SPACES_AT_BEGINNING 3

/** Bit mask for memory options. @stable ICU 2.0 */
#define U_SHAPE_LENGTH_MASK                     3


/** Direction indicator: the source is in logical (keyboard) order. @stable ICU 2.0 */
#define U_SHAPE_TEXT_DIRECTION_LOGICAL          0

/**
 * Direction indicator:
 * the source is in visual LTR order,
 * the leftmost displayed character stored first.
 * @stable ICU 2.0
 */
#define U_SHAPE_TEXT_DIRECTION_VISUAL_LTR       4

/** Bit mask for direction indicators. @stable ICU 2.0 */
#define U_SHAPE_TEXT_DIRECTION_MASK             4


/** Letter shaping option: do not perform letter shaping. @stable ICU 2.0 */
#define U_SHAPE_LETTERS_NOOP                    0

/** Letter shaping option: replace abstract letter characters by "shaped" ones. @stable ICU 2.0 */
#define U_SHAPE_LETTERS_SHAPE                   8

/** Letter shaping option: replace "shaped" letter characters by abstract ones. @stable ICU 2.0 */
#define U_SHAPE_LETTERS_UNSHAPE                 0x10

/**
 * Letter shaping option: replace abstract letter characters by "shaped" ones.
 * The only difference with U_SHAPE_LETTERS_SHAPE is that Tashkeel letters
 * are always "shaped" into the isolated form instead of the medial form
 * (selecting code points from the Arabic Presentation Forms-B block).
 * @stable ICU 2.0
 */
#define U_SHAPE_LETTERS_SHAPE_TASHKEEL_ISOLATED 0x18

/** Bit mask for letter shaping options. @stable ICU 2.0 */
#define U_SHAPE_LETTERS_MASK                    0x18


/** Digit shaping option: do not perform digit shaping. @stable ICU 2.0 */
#define U_SHAPE_DIGITS_NOOP                     0

/**
 * Digit shaping option:
 * Replace European digits (U+0030...) by Arabic-Indic digits.
 * @stable ICU 2.0
 */
#define U_SHAPE_DIGITS_EN2AN                    0x20

/**
 * Digit shaping option:
 * Replace Arabic-Indic digits by European digits (U+0030...).
 * @stable ICU 2.0
 */
#define U_SHAPE_DIGITS_AN2EN                    0x40

/**
 * Digit shaping option:
 * Replace European digits (U+0030...) by Arabic-Indic digits if the most recent
 * strongly directional character is an Arabic letter
 * (<code>u_charDirection()</code> result <code>U_RIGHT_TO_LEFT_ARABIC</code> [AL]).<br>
 * The direction of "preceding" depends on the direction indicator option.
 * For the first characters, the preceding strongly directional character
 * (initial state) is assumed to be not an Arabic letter
 * (it is <code>U_LEFT_TO_RIGHT</code> [L] or <code>U_RIGHT_TO_LEFT</code> [R]).
 * @stable ICU 2.0
 */
#define U_SHAPE_DIGITS_ALEN2AN_INIT_LR          0x60

/**
 * Digit shaping option:
 * Replace European digits (U+0030...) by Arabic-Indic digits if the most recent
 * strongly directional character is an Arabic letter
 * (<code>u_charDirection()</code> result <code>U_RIGHT_TO_LEFT_ARABIC</code> [AL]).<br>
 * The direction of "preceding" depends on the direction indicator option.
 * For the first characters, the preceding strongly directional character
 * (initial state) is assumed to be an Arabic letter.
 * @stable ICU 2.0
 */
#define U_SHAPE_DIGITS_ALEN2AN_INIT_AL          0x80

/** Not a valid option value. May be replaced by a new option. @stable ICU 2.0 */
#define U_SHAPE_DIGITS_RESERVED                 0xa0

/** Bit mask for digit shaping options. @stable ICU 2.0 */
#define U_SHAPE_DIGITS_MASK                     0xe0


/** Digit type option: Use Arabic-Indic digits (U+0660...U+0669). @stable ICU 2.0 */
#define U_SHAPE_DIGIT_TYPE_AN                   0

/** Digit type option: Use Eastern (Extended) Arabic-Indic digits (U+06f0...U+06f9). @stable ICU 2.0 */
#define U_SHAPE_DIGIT_TYPE_AN_EXTENDED          0x100

/** Not a valid option value. May be replaced by a new option. @stable ICU 2.0 */
#define U_SHAPE_DIGIT_TYPE_RESERVED             0x200

/** Bit mask for digit type options. @stable ICU 2.0 */
#define U_SHAPE_DIGIT_TYPE_MASK                 0x3f00

#endif
