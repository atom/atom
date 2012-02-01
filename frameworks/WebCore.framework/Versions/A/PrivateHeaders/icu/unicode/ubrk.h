/*
* Copyright (C) 1996-2004, International Business Machines Corporation and others. All Rights Reserved.
*****************************************************************************************
*/

#ifndef UBRK_H
#define UBRK_H

#include "unicode/utypes.h"
#include "unicode/uloc.h"

/**
 * A text-break iterator.
 *  For usage in C programs.
 */
#ifndef UBRK_TYPEDEF_UBREAK_ITERATOR
#   define UBRK_TYPEDEF_UBREAK_ITERATOR
    /**
     *  Opaque type representing an ICU Break iterator object.
     *  @stable ICU 2.0
     */
    typedef void UBreakIterator;
#endif

#if !UCONFIG_NO_BREAK_ITERATION

#include "unicode/parseerr.h"

/**
 * \file
 * \brief C API: BreakIterator
 *
 * <h2> BreakIterator C API </h2>
 *
 * The BreakIterator C API defines  methods for finding the location
 * of boundaries in text. Pointer to a UBreakIterator maintain a
 * current position and scan over text returning the index of characters
 * where boundaries occur.
 * <P>
 * Line boundary analysis determines where a text string can be broken
 * when line-wrapping. The mechanism correctly handles punctuation and
 * hyphenated words.
 * <P>
 * Sentence boundary analysis allows selection with correct
 * interpretation of periods within numbers and abbreviations, and
 * trailing punctuation marks such as quotation marks and parentheses.
 * <P>
 * Word boundary analysis is used by search and replace functions, as
 * well as within text editing applications that allow the user to
 * select words with a double click. Word selection provides correct
 * interpretation of punctuation marks within and following
 * words. Characters that are not part of a word, such as symbols or
 * punctuation marks, have word-breaks on both sides.
 * <P>
 * Character boundary analysis allows users to interact with
 * characters as they expect to, for example, when moving the cursor
 * through a text string. Character boundary analysis provides correct
 * navigation of through character strings, regardless of how the
 * character is stored.  For example, an accented character might be
 * stored as a base character and a diacritical mark. What users
 * consider to be a character can differ between languages.
 * <P>
 * Title boundary analysis locates all positions,
 * typically starts of words, that should be set to Title Case
 * when title casing the text.
 * <P>
 *
 * This is the interface for all text boundaries.
 * <P>
 * Examples:
 * <P>
 * Helper function to output text
 * <pre>
 * \code
 *    void printTextRange(UChar* str, int32_t start, int32_t end ) {
 *         UChar* result;
 *         UChar* temp;
 *         const char* res;
 *         temp=(UChar*)malloc(sizeof(UChar) * ((u_strlen(str)-start)+1));
 *         result=(UChar*)malloc(sizeof(UChar) * ((end-start)+1));
 *         u_strcpy(temp, &str[start]);
 *         u_strncpy(result, temp, end-start);
 *         res=(char*)malloc(sizeof(char) * (u_strlen(result)+1));
 *         u_austrcpy(res, result);
 *         printf("%s\n", res);
 *    }
 * \endcode
 * </pre>
 * Print each element in order:
 * <pre>
 * \code
 *    void printEachForward( UBreakIterator* boundary, UChar* str) {
 *       int32_t end;
 *       int32_t start = ubrk_first(boundary);
 *       for (end = ubrk_next(boundary)); end != UBRK_DONE; start = end, end = ubrk_next(boundary)) {
 *             printTextRange(str, start, end );
 *         }
 *    }
 * \endcode
 * </pre>
 * Print each element in reverse order:
 * <pre>
 * \code
 *    void printEachBackward( UBreakIterator* boundary, UChar* str) {
 *       int32_t start;
 *       int32_t end = ubrk_last(boundary);
 *       for (start = ubrk_previous(boundary); start != UBRK_DONE;  end = start, start =ubrk_previous(boundary)) {
 *             printTextRange( str, start, end );
 *         }
 *    }
 * \endcode
 * </pre>
 * Print first element
 * <pre>
 * \code
 *    void printFirst(UBreakIterator* boundary, UChar* str) {
 *        int32_t end;
 *        int32_t start = ubrk_first(boundary);
 *        end = ubrk_next(boundary);
 *        printTextRange( str, start, end );
 *    }
 * \endcode
 * </pre>
 * Print last element
 * <pre>
 * \code
 *    void printLast(UBreakIterator* boundary, UChar* str) {
 *        int32_t start;
 *        int32_t end = ubrk_last(boundary);
 *        start = ubrk_previous(boundary);
 *        printTextRange(str, start, end );
 *    }
 * \endcode
 * </pre>
 * Print the element at a specified position
 * <pre>
 * \code
 *    void printAt(UBreakIterator* boundary, int32_t pos , UChar* str) {
 *        int32_t start;
 *        int32_t end = ubrk_following(boundary, pos);
 *        start = ubrk_previous(boundary);
 *        printTextRange(str, start, end );
 *    }
 * \endcode
 * </pre>
 * Creating and using text boundaries
 * <pre>
 * \code
 *       void BreakIterator_Example( void ) {
 *           UBreakIterator* boundary;
 *           UChar *stringToExamine;
 *           stringToExamine=(UChar*)malloc(sizeof(UChar) * (strlen("Aaa bbb ccc. Ddd eee fff.")+1) );
 *           u_uastrcpy(stringToExamine, "Aaa bbb ccc. Ddd eee fff.");
 *           printf("Examining: "Aaa bbb ccc. Ddd eee fff.");
 *
 *           //print each sentence in forward and reverse order
 *           boundary = ubrk_open(UBRK_SENTENCE, "en_us", stringToExamine, u_strlen(stringToExamine), &status);
 *           printf("----- forward: -----------\n");
 *           printEachForward(boundary, stringToExamine);
 *           printf("----- backward: ----------\n");
 *           printEachBackward(boundary, stringToExamine);
 *           ubrk_close(boundary);
 *
 *           //print each word in order
 *           boundary = ubrk_open(UBRK_WORD, "en_us", stringToExamine, u_strlen(stringToExamine), &status);
 *           printf("----- forward: -----------\n");
 *           printEachForward(boundary, stringToExamine);
 *           printf("----- backward: ----------\n");
 *           printEachBackward(boundary, stringToExamine);
 *           //print first element
 *           printf("----- first: -------------\n");
 *           printFirst(boundary, stringToExamine);
 *           //print last element
 *           printf("----- last: --------------\n");
 *           printLast(boundary, stringToExamine);
 *           //print word at charpos 10
 *           printf("----- at pos 10: ---------\n");
 *           printAt(boundary, 10 , stringToExamine);
 *
 *           ubrk_close(boundary);
 *       }
 * \endcode
 * </pre>
 */

/** The possible types of text boundaries.  @stable ICU 2.0 */
typedef enum UBreakIteratorType {
  /** Character breaks  @stable ICU 2.0 */
  UBRK_CHARACTER,
  /** Word breaks @stable ICU 2.0 */
  UBRK_WORD,
  /** Line breaks @stable ICU 2.0 */
  UBRK_LINE,
  /** Sentence breaks @stable ICU 2.0 */
  UBRK_SENTENCE,

#ifndef U_HIDE_DEPRECATED_API
  /** 
   * Title Case breaks 
   * The iterator created using this type locates title boundaries as described for 
   * Unicode 3.2 only. For Unicode 4.0 and above title boundary iteration,
   * please use Word Boundary iterator.
   *
   * @deprecated ICU 2.8 Use the word break iterator for titlecasing for Unicode 4 and later.
   */
  UBRK_TITLE
#endif /* U_HIDE_DEPRECATED_API */

} UBreakIteratorType;

/** Value indicating all text boundaries have been returned.
 *  @stable ICU 2.0 
 */
#define UBRK_DONE ((int32_t) -1)


/**
 *  Enum constants for the word break tags returned by
 *  getRuleStatus().  A range of values is defined for each category of
 *  word, to allow for further subdivisions of a category in future releases.
 *  Applications should check for tag values falling within the range, rather
 *  than for single individual values.
 *  @stable ICU 2.2
*/
typedef enum UWordBreak {
    /** Tag value for "words" that do not fit into any of other categories. 
     *  Includes spaces and most punctuation. */
    UBRK_WORD_NONE           = 0,
    /** Upper bound for tags for uncategorized words. */
    UBRK_WORD_NONE_LIMIT     = 100,
    /** Tag value for words that appear to be numbers, lower limit.    */
    UBRK_WORD_NUMBER         = 100,
    /** Tag value for words that appear to be numbers, upper limit.    */
    UBRK_WORD_NUMBER_LIMIT   = 200,
    /** Tag value for words that contain letters, excluding
     *  hiragana, katakana or ideographic characters, lower limit.    */
    UBRK_WORD_LETTER         = 200,
    /** Tag value for words containing letters, upper limit  */
    UBRK_WORD_LETTER_LIMIT   = 300,
    /** Tag value for words containing kana characters, lower limit */
    UBRK_WORD_KANA           = 300,
    /** Tag value for words containing kana characters, upper limit */
    UBRK_WORD_KANA_LIMIT     = 400,
    /** Tag value for words containing ideographic characters, lower limit */
    UBRK_WORD_IDEO           = 400,
    /** Tag value for words containing ideographic characters, upper limit */
    UBRK_WORD_IDEO_LIMIT     = 500
} UWordBreak;

/**
 *  Enum constants for the line break tags returned by getRuleStatus().
 *  A range of values is defined for each category of
 *  word, to allow for further subdivisions of a category in future releases.
 *  Applications should check for tag values falling within the range, rather
 *  than for single individual values.
 *  @draft ICU 2.8
*/
typedef enum ULineBreakTag {
    /** Tag value for soft line breaks, positions at which a line break
      *  is acceptable but not required                */
    UBRK_LINE_SOFT            = 0,
    /** Upper bound for soft line breaks.              */
    UBRK_LINE_SOFT_LIMIT      = 100,
    /** Tag value for a hard, or mandatory line break  */
    UBRK_LINE_HARD            = 100,
    /** Upper bound for hard line breaks.              */
    UBRK_LINE_HARD_LIMIT      = 200
} ULineBreakTag;



/**
 *  Enum constants for the sentence break tags returned by getRuleStatus().
 *  A range of values is defined for each category of
 *  sentence, to allow for further subdivisions of a category in future releases.
 *  Applications should check for tag values falling within the range, rather
 *  than for single individual values.
 *  @draft ICU 2.8
*/
typedef enum USentenceBreakTag {
    /** Tag value for for sentences  ending with a sentence terminator
      * ('.', '?', '!', etc.) character, possibly followed by a
      * hard separator (CR, LF, PS, etc.)
      */
    UBRK_SENTENCE_TERM       = 0,
    /** Upper bound for tags for sentences ended by sentence terminators.    */
    UBRK_SENTENCE_TERM_LIMIT = 100,
    /** Tag value for for sentences that do not contain an ending
      * sentence terminator ('.', '?', '!', etc.) character, but 
      * are ended only by a hard separator (CR, LF, PS, etc.) or end of input.
      */
    UBRK_SENTENCE_SEP        = 100,
    /** Upper bound for tags for sentences ended by a separator.              */
    UBRK_SENTENCE_SEP_LIMIT  = 200
    /** Tag value for a hard, or mandatory line break  */
} USentenceBreakTag;


/**
 * Open a new UBreakIterator for locating text boundaries for a specified locale.
 * A UBreakIterator may be used for detecting character, line, word,
 * and sentence breaks in text.
 * @param type The type of UBreakIterator to open: one of UBRK_CHARACTER, UBRK_WORD,
 * UBRK_LINE, UBRK_SENTENCE
 * @param locale The locale specifying the text-breaking conventions.
 * @param text The text to be iterated over.
 * @param textLength The number of characters in text, or -1 if null-terminated.
 * @param status A UErrorCode to receive any errors.
 * @return A UBreakIterator for the specified locale.
 * @see ubrk_openRules
 * @stable ICU 2.0
 */
U_STABLE UBreakIterator* U_EXPORT2
ubrk_open(UBreakIteratorType type,
      const char *locale,
      const UChar *text,
      int32_t textLength,
      UErrorCode *status);

/**
 * Open a new UBreakIterator for locating text boundaries using specified breaking rules.
 * The rule syntax is ... (TBD)
 * @param rules A set of rules specifying the text breaking conventions.
 * @param rulesLength The number of characters in rules, or -1 if null-terminated.
 * @param text The text to be iterated over.  May be null, in which case ubrk_setText() is
 *        used to specify the text to be iterated.
 * @param textLength The number of characters in text, or -1 if null-terminated.
 * @param parseErr   Receives position and context information for any syntax errors
 *                   detected while parsing the rules.
 * @param status A UErrorCode to receive any errors.
 * @return A UBreakIterator for the specified rules.
 * @see ubrk_open
 * @stable ICU 2.2
 */
U_STABLE UBreakIterator* U_EXPORT2
ubrk_openRules(const UChar     *rules,
               int32_t         rulesLength,
               const UChar     *text,
               int32_t          textLength,
               UParseError     *parseErr,
               UErrorCode      *status);

/**
 * Thread safe cloning operation
 * @param bi iterator to be cloned
 * @param stackBuffer user allocated space for the new clone. If NULL new memory will be allocated.
 *  If buffer is not large enough, new memory will be allocated.
 *  Clients can use the U_BRK_SAFECLONE_BUFFERSIZE. This will probably be enough to avoid memory allocations.
 * @param pBufferSize pointer to size of allocated space.
 *  If *pBufferSize == 0, a sufficient size for use in cloning will
 *  be returned ('pre-flighting')
 *  If *pBufferSize is not enough for a stack-based safe clone,
 *  new memory will be allocated.
 * @param status to indicate whether the operation went on smoothly or there were errors
 *  An informational status value, U_SAFECLONE_ALLOCATED_ERROR, is used if any allocations were necessary.
 * @return pointer to the new clone
 * @stable ICU 2.0
 */
U_STABLE UBreakIterator * U_EXPORT2
ubrk_safeClone(
          const UBreakIterator *bi,
          void *stackBuffer,
          int32_t *pBufferSize,
          UErrorCode *status);

/**
  * A recommended size (in bytes) for the memory buffer to be passed to ubrk_saveClone().
  * @stable ICU 2.0
  */
#define U_BRK_SAFECLONE_BUFFERSIZE 512

/**
* Close a UBreakIterator.
* Once closed, a UBreakIterator may no longer be used.
* @param bi The break iterator to close.
 * @stable ICU 2.0
*/
U_STABLE void U_EXPORT2
ubrk_close(UBreakIterator *bi);

/**
 * Sets an existing iterator to point to a new piece of text
 * @param bi The iterator to use
 * @param text The text to be set
 * @param textLength The length of the text
 * @param status The error code
 * @stable ICU 2.0
 */
U_STABLE void U_EXPORT2
ubrk_setText(UBreakIterator* bi,
             const UChar*    text,
             int32_t         textLength,
             UErrorCode*     status);

/**
 * Determine the most recently-returned text boundary.
 *
 * @param bi The break iterator to use.
 * @return The character index most recently returned by \ref ubrk_next, \ref ubrk_previous,
 * \ref ubrk_first, or \ref ubrk_last.
 * @stable ICU 2.0
 */
U_STABLE int32_t U_EXPORT2
ubrk_current(const UBreakIterator *bi);

/**
 * Determine the text boundary following the current text boundary.
 *
 * @param bi The break iterator to use.
 * @return The character index of the next text boundary, or UBRK_DONE
 * if all text boundaries have been returned.
 * @see ubrk_previous
 * @stable ICU 2.0
 */
U_STABLE int32_t U_EXPORT2
ubrk_next(UBreakIterator *bi);

/**
 * Determine the text boundary preceding the current text boundary.
 *
 * @param bi The break iterator to use.
 * @return The character index of the preceding text boundary, or UBRK_DONE
 * if all text boundaries have been returned.
 * @see ubrk_next
 * @stable ICU 2.0
 */
U_STABLE int32_t U_EXPORT2
ubrk_previous(UBreakIterator *bi);

/**
 * Determine the index of the first character in the text being scanned.
 * This is not always the same as index 0 of the text.
 * @param bi The break iterator to use.
 * @return The character index of the first character in the text being scanned.
 * @see ubrk_last
 * @stable ICU 2.0
 */
U_STABLE int32_t U_EXPORT2
ubrk_first(UBreakIterator *bi);

/**
 * Determine the index immediately <EM>beyond</EM> the last character in the text being
 * scanned.
 * This is not the same as the last character.
 * @param bi The break iterator to use.
 * @return The character offset immediately <EM>beyond</EM> the last character in the
 * text being scanned.
 * @see ubrk_first
 * @stable ICU 2.0
 */
U_STABLE int32_t U_EXPORT2
ubrk_last(UBreakIterator *bi);

/**
 * Determine the text boundary preceding the specified offset.
 * The value returned is always smaller than offset, or UBRK_DONE.
 * @param bi The break iterator to use.
 * @param offset The offset to begin scanning.
 * @return The text boundary preceding offset, or UBRK_DONE.
 * @see ubrk_following
 * @stable ICU 2.0
 */
U_STABLE int32_t U_EXPORT2
ubrk_preceding(UBreakIterator *bi,
           int32_t offset);

/**
 * Determine the text boundary following the specified offset.
 * The value returned is always greater than offset, or UBRK_DONE.
 * @param bi The break iterator to use.
 * @param offset The offset to begin scanning.
 * @return The text boundary following offset, or UBRK_DONE.
 * @see ubrk_preceding
 * @stable ICU 2.0
 */
U_STABLE int32_t U_EXPORT2
ubrk_following(UBreakIterator *bi,
           int32_t offset);

/**
* Get a locale for which text breaking information is available.
* A UBreakIterator in a locale returned by this function will perform the correct
* text breaking for the locale.
* @param index The index of the desired locale.
* @return A locale for which number text breaking information is available, or 0 if none.
* @see ubrk_countAvailable
* @stable ICU 2.0
*/
U_STABLE const char* U_EXPORT2
ubrk_getAvailable(int32_t index);

/**
* Determine how many locales have text breaking information available.
* This function is most useful as determining the loop ending condition for
* calls to \ref ubrk_getAvailable.
* @return The number of locales for which text breaking information is available.
* @see ubrk_getAvailable
* @stable ICU 2.0
*/
U_STABLE int32_t U_EXPORT2
ubrk_countAvailable(void);


/**
* Returns true if the specfied position is a boundary position.  As a side
* effect, leaves the iterator pointing to the first boundary position at
* or after "offset".
* @param bi The break iterator to use.
* @param offset the offset to check.
* @return True if "offset" is a boundary position.
* @stable ICU 2.0
*/
U_STABLE  UBool U_EXPORT2
ubrk_isBoundary(UBreakIterator *bi, int32_t offset);

/**
 * Return the status from the break rule that determined the most recently
 * returned break position.  The values appear in the rule source
 * within brackets, {123}, for example.  For rules that do not specify a
 * status, a default value of 0 is returned.
 * <p>
 * For word break iterators, the possible values are defined in enum UWordBreak.
 * @stable ICU 2.2
 */
U_STABLE  int32_t U_EXPORT2
ubrk_getRuleStatus(UBreakIterator *bi);

/**
 * Get the statuses from the break rules that determined the most recently
 * returned break position.  The values appear in the rule source
 * within brackets, {123}, for example.  The default status value for rules
 * that do not explicitly provide one is zero.
 * <p>
 * For word break iterators, the possible values are defined in enum UWordBreak.
 * @param bi        The break iterator to use
 * @param fillInVec an array to be filled in with the status values.  
 * @param capacity  the length of the supplied vector.  A length of zero causes
 *                  the function to return the number of status values, in the
 *                  normal way, without attemtping to store any values.
 * @param status    receives error codes.  
 * @return          The number of rule status values from rules that determined 
 *                  the most recent boundary returned by the break iterator.
 * @draft ICU 3.0
 */
U_DRAFT  int32_t U_EXPORT2
ubrk_getRuleStatusVec(UBreakIterator *bi, int32_t *fillInVec, int32_t capacity, UErrorCode *status);

/**
 * Return the locale of the break iterator. You can choose between the valid and
 * the actual locale.
 * @param bi break iterator
 * @param type locale type (valid or actual)
 * @param status error code
 * @return locale string
 * @draft ICU 2.8 likely to change in ICU 3.0, based on feedback
 */
U_DRAFT const char* U_EXPORT2
ubrk_getLocaleByType(const UBreakIterator *bi, ULocDataLocaleType type, UErrorCode* status);


#endif /* #if !UCONFIG_NO_BREAK_ITERATION */

#endif
