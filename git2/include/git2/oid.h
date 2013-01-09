/*
 * Copyright (C) the libgit2 contributors. All rights reserved.
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_oid_h__
#define INCLUDE_git_oid_h__

#include "common.h"
#include "types.h"

/**
 * @file git2/oid.h
 * @brief Git object id routines
 * @defgroup git_oid Git object id routines
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/** Size (in bytes) of a raw/binary oid */
#define GIT_OID_RAWSZ 20

/** Size (in bytes) of a hex formatted oid */
#define GIT_OID_HEXSZ (GIT_OID_RAWSZ * 2)

/** Minimum length (in number of hex characters,
 * i.e. packets of 4 bits) of an oid prefix */
#define GIT_OID_MINPREFIXLEN 4

/** Unique identity of any object (commit, tree, blob, tag). */
typedef struct git_oid {
	/** raw binary formatted id */
	unsigned char id[GIT_OID_RAWSZ];
} git_oid;

/**
 * Parse a hex formatted object id into a git_oid.
 *
 * @param out oid structure the result is written into.
 * @param str input hex string; must be pointing at the start of
 *		the hex sequence and have at least the number of bytes
 *		needed for an oid encoded in hex (40 bytes).
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_oid_fromstr(git_oid *out, const char *str);

/**
 * Parse N characters of a hex formatted object id into a git_oid
 *
 * If N is odd, N-1 characters will be parsed instead.
 * The remaining space in the git_oid will be set to zero.
 *
 * @param out oid structure the result is written into.
 * @param str input hex string of at least size `length`
 * @param length length of the input string
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_oid_fromstrn(git_oid *out, const char *str, size_t length);

/**
 * Copy an already raw oid into a git_oid structure.
 *
 * @param out oid structure the result is written into.
 * @param raw the raw input bytes to be copied.
 */
GIT_EXTERN(void) git_oid_fromraw(git_oid *out, const unsigned char *raw);

/**
 * Format a git_oid into a hex string.
 *
 * @param out output hex string; must be pointing at the start of
 *		the hex sequence and have at least the number of bytes
 *		needed for an oid encoded in hex (40 bytes). Only the
 *		oid digits are written; a '\\0' terminator must be added
 *		by the caller if it is required.
 * @param oid oid structure to format.
 */
GIT_EXTERN(void) git_oid_fmt(char *out, const git_oid *id);

/**
 * Format a git_oid into a loose-object path string.
 *
 * The resulting string is "aa/...", where "aa" is the first two
 * hex digits of the oid and "..." is the remaining 38 digits.
 *
 * @param out output hex string; must be pointing at the start of
 *		the hex sequence and have at least the number of bytes
 *		needed for an oid encoded in hex (41 bytes). Only the
 *		oid digits are written; a '\\0' terminator must be added
 *		by the caller if it is required.
 * @param id oid structure to format.
 */
GIT_EXTERN(void) git_oid_pathfmt(char *out, const git_oid *id);

/**
 * Format a git_oid into a newly allocated c-string.
 *
 * @param oid the oid structure to format
 * @return the c-string; NULL if memory is exhausted. Caller must
 *			deallocate the string with git__free().
 */
GIT_EXTERN(char *) git_oid_allocfmt(const git_oid *id);

/**
 * Format a git_oid into a buffer as a hex format c-string.
 *
 * If the buffer is smaller than GIT_OID_HEXSZ+1, then the resulting
 * oid c-string will be truncated to n-1 characters. If there are
 * any input parameter errors (out == NULL, n == 0, oid == NULL),
 * then a pointer to an empty string is returned, so that the return
 * value can always be printed.
 *
 * @param out the buffer into which the oid string is output.
 * @param n the size of the out buffer.
 * @param id the oid structure to format.
 * @return the out buffer pointer, assuming no input parameter
 *			errors, otherwise a pointer to an empty string.
 */
GIT_EXTERN(char *) git_oid_tostr(char *out, size_t n, const git_oid *id);

/**
 * Copy an oid from one structure to another.
 *
 * @param out oid structure the result is written into.
 * @param src oid structure to copy from.
 */
GIT_EXTERN(void) git_oid_cpy(git_oid *out, const git_oid *src);

/**
 * Compare two oid structures.
 *
 * @param a first oid structure.
 * @param b second oid structure.
 * @return <0, 0, >0 if a < b, a == b, a > b.
 */
GIT_INLINE(int) git_oid_cmp(const git_oid *a, const git_oid *b)
{
	const unsigned char *sha1 = a->id;
	const unsigned char *sha2 = b->id;
	int i;

	for (i = 0; i < GIT_OID_RAWSZ; i++, sha1++, sha2++) {
		if (*sha1 != *sha2)
			return *sha1 - *sha2;
	}

	return 0;
}

/**
 * Compare two oid structures for equality
 *
 * @param a first oid structure.
 * @param b second oid structure.
 * @return true if equal, false otherwise
 */
GIT_INLINE(int) git_oid_equal(const git_oid *a, const git_oid *b)
{
	return !git_oid_cmp(a, b);
}

/**
 * Compare the first 'len' hexadecimal characters (packets of 4 bits)
 * of two oid structures.
 *
 * @param a first oid structure.
 * @param b second oid structure.
 * @param len the number of hex chars to compare
 * @return 0 in case of a match
 */
GIT_EXTERN(int) git_oid_ncmp(const git_oid *a, const git_oid *b, size_t len);

/**
 * Check if an oid equals an hex formatted object id.
 *
 * @param id oid structure.
 * @param str input hex string of an object id.
 * @return GIT_ENOTOID if str is not a valid hex string,
 * 0 in case of a match, GIT_ERROR otherwise.
 */
GIT_EXTERN(int) git_oid_streq(const git_oid *id, const char *str);

/**
 * Check is an oid is all zeros.
 *
 * @return 1 if all zeros, 0 otherwise.
 */
GIT_EXTERN(int) git_oid_iszero(const git_oid *id);

/**
 * OID Shortener object
 */
typedef struct git_oid_shorten git_oid_shorten;

/**
 * Create a new OID shortener.
 *
 * The OID shortener is used to process a list of OIDs
 * in text form and return the shortest length that would
 * uniquely identify all of them.
 *
 * E.g. look at the result of `git log --abbrev`.
 *
 * @param min_length The minimal length for all identifiers,
 *		which will be used even if shorter OIDs would still
 *		be unique.
 *	@return a `git_oid_shorten` instance, NULL if OOM
 */
GIT_EXTERN(git_oid_shorten *) git_oid_shorten_new(size_t min_length);

/**
 * Add a new OID to set of shortened OIDs and calculate
 * the minimal length to uniquely identify all the OIDs in
 * the set.
 *
 * The OID is expected to be a 40-char hexadecimal string.
 * The OID is owned by the user and will not be modified
 * or freed.
 *
 * For performance reasons, there is a hard-limit of how many
 * OIDs can be added to a single set (around ~22000, assuming
 * a mostly randomized distribution), which should be enough
 * for any kind of program, and keeps the algorithm fast and
 * memory-efficient.
 *
 * Attempting to add more than those OIDs will result in a
 * GIT_ENOMEM error
 *
 * @param os a `git_oid_shorten` instance
 * @param text_id an OID in text form
 * @return the minimal length to uniquely identify all OIDs
 *		added so far to the set; or an error code (<0) if an
 *		error occurs.
 */
GIT_EXTERN(int) git_oid_shorten_add(git_oid_shorten *os, const char *text_id);

/**
 * Free an OID shortener instance
 *
 * @param os a `git_oid_shorten` instance
 */
GIT_EXTERN(void) git_oid_shorten_free(git_oid_shorten *os);

/** @} */
GIT_END_DECL
#endif
