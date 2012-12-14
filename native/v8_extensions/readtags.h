/*
*   $Id: readtags.h 443 2006-05-30 04:37:13Z darren $
*
*   Copyright (c) 1996-2003, Darren Hiebert
*
*   This source code is released for the public domain.
*
*   This file defines the public interface for looking up tag entries in tag
*   files.
*
*   The functions defined in this interface are intended to provide tag file
*   support to a software tool. The tag lookups provided are sufficiently fast
*   enough to permit opening a sorted tag file, searching for a matching tag,
*   then closing the tag file each time a tag is looked up (search times are
*   on the order of hundreths of a second, even for huge tag files). This is
*   the recommended use of this library for most tool applications. Adhering
*   to this approach permits a user to regenerate a tag file at will without
*   the tool needing to detect and resynchronize with changes to the tag file.
*   Even for an unsorted 24MB tag file, tag searches take about one second.
*/
#ifndef READTAGS_H
#define READTAGS_H

#ifdef __cplusplus
extern "C" {
#endif

/*
*  MACROS
*/

/* Options for tagsSetSortType() */
typedef enum {
	TAG_UNSORTED, TAG_SORTED, TAG_FOLDSORTED
} sortType ;

/* Options for tagsFind() */
#define TAG_FULLMATCH     0x0
#define TAG_PARTIALMATCH  0x1

#define TAG_OBSERVECASE   0x0
#define TAG_IGNORECASE    0x2

/*
*  DATA DECLARATIONS
*/

typedef enum { TagFailure = 0, TagSuccess = 1 } tagResult;

struct sTagFile;

typedef struct sTagFile tagFile;

/* This structure contains information about the tag file. */
typedef struct {

	struct {
			/* was the tag file successfully opened? */
		int opened;

			/* errno value when 'opened' is false */
		int error_number;
	} status;

		/* information about the structure of the tag file */
	struct {
				/* format of tag file (1 = original, 2 = extended) */
			short format;

				/* how is the tag file sorted? */
			sortType sort;
	} file;


		/* information about the program which created this tag file */
	struct {
			/* name of author of generating program (may be null) */
		const char *author;

			/* name of program (may be null) */
		const char *name;

			/* URL of distribution (may be null) */
		const char *url;

			/* program version (may be null) */
		const char *version;
	} program;

} tagFileInfo;

/* This structure contains information about an extension field for a tag.
 * These exist at the end of the tag in the form "key:value").
 */
typedef struct {

		/* the key of the extension field */
	const char *key;

		/* the value of the extension field (may be an empty string) */
	const char *value;

} tagExtensionField;

/* This structure contains information about a specific tag. */
typedef struct {

		/* name of tag */
	const char *name;

		/* path of source file containing definition of tag */
	const char *file;

		/* address for locating tag in source file */
	struct {
			/* pattern for locating source line
			 * (may be NULL if not present) */
		const char *pattern;

			/* line number in source file of tag definition
			 * (may be zero if not known) */
		unsigned long lineNumber;
	} address;

		/* kind of tag (may by name, character, or NULL if not known) */
	const char *kind;

		/* is tag of file-limited scope? */
	short fileScope;

		/* miscellaneous extension fields */
	struct {
			/* number of entries in `list' */
		unsigned short count;

			/* list of key value pairs */
		tagExtensionField *list;
	} fields;

} tagEntry;


/*
*  FUNCTION PROTOTYPES
*/

/*
*  This function must be called before calling other functions in this
*  library. It is passed the path to the tag file to read and a (possibly
*  null) pointer to a structure which, if not null, will be populated with
*  information about the tag file. If successful, the function will return a
*  handle which must be supplied to other calls to read information from the
*  tag file, and info.status.opened will be set to true. If unsuccessful,
*  info.status.opened will be set to false and info.status.error_number will
*  be set to the errno value representing the system error preventing the tag
*  file from being successfully opened.
*/
extern tagFile *tagsOpen (const char *const filePath, tagFileInfo *const info);

/*
*  This function allows the client to override the normal automatic detection
*  of how a tag file is sorted. Permissible values for `type' are
*  TAG_UNSORTED, TAG_SORTED, TAG_FOLDSORTED. Tag files in the new extended
*  format contain a key indicating whether or not they are sorted. However,
*  tag files in the original format do not contain such a key even when
*  sorted, preventing this library from taking advantage of fast binary
*  lookups. If the client knows that such an unmarked tag file is indeed
*  sorted (or not), it can override the automatic detection. Note that
*  incorrect lookup results will result if a tag file is marked as sorted when
*  it actually is not. The function will return TagSuccess if called on an
*  open tag file or TagFailure if not.
*/
extern tagResult tagsSetSortType (tagFile *const file, const sortType type);

/*
*  Reads the first tag in the file, if any. It is passed the handle to an
*  opened tag file and a (possibly null) pointer to a structure which, if not
*  null, will be populated with information about the first tag file entry.
*  The function will return TagSuccess another tag entry is found, or
*  TagFailure if not (i.e. it reached end of file).
*/
extern tagResult tagsFirst (tagFile *const file, tagEntry *const entry);

/*
*  Step to the next tag in the file, if any. It is passed the handle to an
*  opened tag file and a (possibly null) pointer to a structure which, if not
*  null, will be populated with information about the next tag file entry. The
*  function will return TagSuccess another tag entry is found, or TagFailure
*  if not (i.e. it reached end of file). It will always read the first tag in
*  the file immediately after calling tagsOpen().
*/
extern tagResult tagsNext (tagFile *const file, tagEntry *const entry);

/*
*  Retrieve the value associated with the extension field for a specified key.
*  It is passed a pointer to a structure already populated with values by a
*  previous call to tagsNext(), tagsFind(), or tagsFindNext(), and a string
*  containing the key of the desired extension field. If no such field of the
*  specified key exists, the function will return null.
*/
extern const char *tagsField (const tagEntry *const entry, const char *const key);

/*
*  Find the first tag matching `name'. The structure pointed to by `entry'
*  will be populated with information about the tag file entry. If a tag file
*  is sorted using the C locale, a binary search algorithm is used to search
*  the tag file, resulting in very fast tag lookups, even in huge tag files.
*  Various options controlling the matches can be combined by bit-wise or-ing
*  certain values together. The available values are:
*
*    TAG_PARTIALMATCH
*        Tags whose leading characters match `name' will qualify.
*
*    TAG_FULLMATCH
*        Only tags whose full lengths match `name' will qualify.
*
*    TAG_IGNORECASE
*        Matching will be performed in a case-insenstive manner. Note that
*        this disables binary searches of the tag file.
*
*    TAG_OBSERVECASE
*        Matching will be performed in a case-senstive manner. Note that
*        this enables binary searches of the tag file.
*
*  The function will return TagSuccess if a tag matching the name is found, or
*  TagFailure if not.
*/
extern tagResult tagsFind (tagFile *const file, tagEntry *const entry, const char *const name, const int options);

/*
*  Find the next tag matching the name and options supplied to the most recent
*  call to tagsFind() for the same tag file. The structure pointed to by
*  `entry' will be populated with information about the tag file entry. The
*  function will return TagSuccess if another tag matching the name is found,
*  or TagFailure if not.
*/
extern tagResult tagsFindNext (tagFile *const file, tagEntry *const entry);

/*
*  Call tagsTerminate() at completion of reading the tag file, which will
*  close the file and free any internal memory allocated. The function will
*  return TagFailure is no file is currently open, TagSuccess otherwise.
*/
extern tagResult tagsClose (tagFile *const file);

#ifdef __cplusplus
};
#endif

#endif

/* vi:set tabstop=4 shiftwidth=4: */
