/*
 * Copyright (C) the libgit2 contributors. All rights reserved.
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_note_h__
#define INCLUDE_git_note_h__

#include "oid.h"

/**
 * @file git2/notes.h
 * @brief Git notes management routines
 * @defgroup git_note Git notes management routines
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Callback for git_note_foreach.
 *
 * Receives:
 * - blob_id: Oid of the blob containing the message
 * - annotated_object_id: Oid of the git object being annotated
 * - payload: Payload data passed to `git_note_foreach`
 */
typedef int (*git_note_foreach_cb)(
	const git_oid *blob_id, const git_oid *annotated_object_id, void *payload);

/**
 * Read the note for an object
 *
 * The note must be freed manually by the user.
 *
 * @param out pointer to the read note; NULL in case of error
 * @param repo repository where to look up the note
 * @param notes_ref canonical name of the reference to use (optional); defaults to
 *                  "refs/notes/commits"
 * @param oid OID of the git object to read the note from
 *
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_note_read(
	git_note **out,
	git_repository *repo,
	const char *notes_ref,
	const git_oid *oid);

/**
 * Get the note message
 *
 * @param note
 * @return the note message
 */
GIT_EXTERN(const char *) git_note_message(const git_note *note);


/**
 * Get the note object OID
 *
 * @param note
 * @return the note object OID
 */
GIT_EXTERN(const git_oid *) git_note_oid(const git_note *note);

/**
 * Add a note for an object
 *
 * @param out pointer to store the OID (optional); NULL in case of error
 * @param repo repository where to store the note
 * @param author signature of the notes commit author
 * @param committer signature of the notes commit committer
 * @param notes_ref canonical name of the reference to use (optional);
 *					defaults to "refs/notes/commits"
 * @param oid OID of the git object to decorate
 * @param note Content of the note to add for object oid
 * @param force Overwrite existing note
 *
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_note_create(
	git_oid *out,
	git_repository *repo,
	const git_signature *author,
	const git_signature *committer,
	const char *notes_ref,
	const git_oid *oid,
	const char *note,
	int force);


/**
 * Remove the note for an object
 *
 * @param repo repository where the note lives
 * @param notes_ref canonical name of the reference to use (optional);
 *					defaults to "refs/notes/commits"
 * @param author signature of the notes commit author
 * @param committer signature of the notes commit committer
 * @param oid OID of the git object to remove the note from
 *
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_note_remove(
	git_repository *repo,
	const char *notes_ref,
	const git_signature *author,
	const git_signature *committer,
	const git_oid *oid);

/**
 * Free a git_note object
 *
 * @param note git_note object
 */
GIT_EXTERN(void) git_note_free(git_note *note);

/**
 * Get the default notes reference for a repository
 *
 * @param out Pointer to the default notes reference
 * @param repo The Git repository
 *
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_note_default_ref(const char **out, git_repository *repo);

/**
 * Loop over all the notes within a specified namespace
 * and issue a callback for each one.
 *
 * @param repo Repository where to find the notes.
 *
 * @param notes_ref Reference to read from (optional); defaults to
 *        "refs/notes/commits".
 *
 * @param note_cb Callback to invoke per found annotation.  Return non-zero
 *        to stop looping.
 *
 * @param payload Extra parameter to callback function.
 *
 * @return 0 on success, GIT_EUSER on non-zero callback, or error code
 */
GIT_EXTERN(int) git_note_foreach(
	git_repository *repo,
	const char *notes_ref,
	git_note_foreach_cb note_cb,
	void *payload);

/** @} */
GIT_END_DECL
#endif
