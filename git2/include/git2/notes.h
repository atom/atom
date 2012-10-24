/*
 * Copyright (C) 2009-2012 the libgit2 contributors
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
 * Read the note for an object
 *
 * The note must be freed manually by the user.
 *
 * @param note the note; NULL in case of error
 * @param repo the Git repository
 * @param notes_ref OID reference to use (optional); defaults to "refs/notes/commits"
 * @param oid OID of the object
 *
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_note_read(git_note **note, git_repository *repo,
			      const char *notes_ref, const git_oid *oid);

/**
 * Get the note message
 *
 * @param note
 * @return the note message
 */
GIT_EXTERN(const char *) git_note_message(git_note *note);


/**
 * Get the note object OID
 *
 * @param note
 * @return the note object OID
 */
GIT_EXTERN(const git_oid *) git_note_oid(git_note *note);


/**
 * Add a note for an object
 *
 * @param oid pointer to store the OID (optional); NULL in case of error
 * @param repo the Git repository
 * @param author signature of the notes commit author
 * @param committer signature of the notes commit committer
 * @param notes_ref OID reference to update (optional); defaults to "refs/notes/commits"
 * @param oid The OID of the object
 * @param oid The note to add for object oid
 *
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_note_create(git_oid *out, git_repository *repo,
				git_signature *author, git_signature *committer,
				const char *notes_ref, const git_oid *oid,
				 const char *note);


/**
 * Remove the note for an object
 *
 * @param repo the Git repository
 * @param notes_ref OID reference to use (optional); defaults to "refs/notes/commits"
 * @param author signature of the notes commit author
 * @param committer signature of the notes commit committer
 * @param oid the oid which note's to be removed
 *
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_note_remove(git_repository *repo, const char *notes_ref,
				git_signature *author, git_signature *committer,
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
 * Basic components of a note
 *
 *  - Oid of the blob containing the message
 *  - Oid of the git object being annotated
 */
typedef struct {
	git_oid blob_oid;
	git_oid annotated_object_oid;
} git_note_data;

/**
 * Loop over all the notes within a specified namespace
 * and issue a callback for each one.
 *
 * @param repo Repository where to find the notes.
 *
 * @param notes_ref OID reference to read from (optional); defaults to "refs/notes/commits".
 *
 * @param note_cb Callback to invoke per found annotation.
 *
 * @param payload Extra parameter to callback function.
 *
 * @return 0 or an error code.
 */
GIT_EXTERN(int) git_note_foreach(
		git_repository *repo,
		const char *notes_ref,
		int (*note_cb)(git_note_data *note_data, void *payload),
		void *payload
);

/** @} */
GIT_END_DECL
#endif
