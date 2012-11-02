/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_diff_h__
#define INCLUDE_git_diff_h__

#include "common.h"
#include "types.h"
#include "oid.h"
#include "tree.h"
#include "refs.h"

/**
 * @file git2/diff.h
 * @brief Git tree and file differencing routines.
 *
 * Calculating diffs is generally done in two phases: building a diff list
 * then traversing the diff list.  This makes is easier to share logic
 * across the various types of diffs (tree vs tree, workdir vs index, etc.),
 * and also allows you to insert optional diff list post-processing phases,
 * such as rename detected, in between the steps.  When you are done with a
 * diff list object, it must be freed.
 *
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Flags for diff options.  A combination of these flags can be passed
 * in via the `flags` value in the `git_diff_options`.
 */
enum {
	/** Normal diff, the default */
	GIT_DIFF_NORMAL = 0,
	/** Reverse the sides of the diff */
	GIT_DIFF_REVERSE = (1 << 0),
	/** Treat all files as text, disabling binary attributes & detection */
	GIT_DIFF_FORCE_TEXT = (1 << 1),
	/** Ignore all whitespace */
	GIT_DIFF_IGNORE_WHITESPACE = (1 << 2),
	/** Ignore changes in amount of whitespace */
	GIT_DIFF_IGNORE_WHITESPACE_CHANGE = (1 << 3),
	/** Ignore whitespace at end of line */
	GIT_DIFF_IGNORE_WHITESPACE_EOL = (1 << 4),
	/** Exclude submodules from the diff completely */
	GIT_DIFF_IGNORE_SUBMODULES = (1 << 5),
	/** Use the "patience diff" algorithm (currently unimplemented) */
	GIT_DIFF_PATIENCE = (1 << 6),
	/** Include ignored files in the diff list */
	GIT_DIFF_INCLUDE_IGNORED = (1 << 7),
	/** Include untracked files in the diff list */
	GIT_DIFF_INCLUDE_UNTRACKED = (1 << 8),
	/** Include unmodified files in the diff list */
	GIT_DIFF_INCLUDE_UNMODIFIED = (1 << 9),
	/** Even with the GIT_DIFF_INCLUDE_UNTRACKED flag, when an untracked
	 *  directory is found, only a single entry for the directory is added
	 *  to the diff list; with this flag, all files under the directory will
	 *  be included, too.
	 */
	GIT_DIFF_RECURSE_UNTRACKED_DIRS = (1 << 10),
	/** If the pathspec is set in the diff options, this flags means to
	 *  apply it as an exact match instead of as an fnmatch pattern.
	 */
	GIT_DIFF_DISABLE_PATHSPEC_MATCH = (1 << 11),
	/** Use case insensitive filename comparisons */
	GIT_DIFF_DELTAS_ARE_ICASE = (1 << 12),
	/** When generating patch text, include the content of untracked files */
	GIT_DIFF_INCLUDE_UNTRACKED_CONTENT = (1 << 13),
	/** Disable updating of the `binary` flag in delta records.  This is
	 *  useful when iterating over a diff if you don't need hunk and data
	 *  callbacks and want to avoid having to load file completely.
	 */
	GIT_DIFF_SKIP_BINARY_CHECK = (1 << 14),
	/** Normally, a type change between files will be converted into a
	 *  DELETED record for the old and an ADDED record for the new; this
	 *  options enabled the generation of TYPECHANGE delta records.
	 */
	GIT_DIFF_INCLUDE_TYPECHANGE = (1 << 15),
	/** Even with GIT_DIFF_INCLUDE_TYPECHANGE, blob->tree changes still
	 *  generally show as a DELETED blob.  This flag tries to correctly
	 *  label blob->tree transitions as TYPECHANGE records with new_file's
	 *  mode set to tree.  Note: the tree SHA will not be available.
	 */
	GIT_DIFF_INCLUDE_TYPECHANGE_TREES  = (1 << 16),
};

/**
 * Structure describing options about how the diff should be executed.
 *
 * Setting all values of the structure to zero will yield the default
 * values.  Similarly, passing NULL for the options structure will
 * give the defaults.  The default values are marked below.
 *
 * - flags: a combination of the GIT_DIFF_... values above
 * - context_lines: number of lines of context to show around diffs
 * - interhunk_lines: min lines between diff hunks to merge them
 * - old_prefix: "directory" to prefix to old file names (default "a")
 * - new_prefix: "directory" to prefix to new file names (default "b")
 * - pathspec: array of paths / patterns to constrain diff
 * - max_size: maximum blob size to diff, above this treated as binary
 */
typedef struct {
	uint32_t flags;				/**< defaults to GIT_DIFF_NORMAL */
	uint16_t context_lines;		/**< defaults to 3 */
	uint16_t interhunk_lines;	/**< defaults to 0 */
	char *old_prefix;			/**< defaults to "a" */
	char *new_prefix;			/**< defaults to "b" */
	git_strarray pathspec;		/**< defaults to show all paths */
	git_off_t max_size;			/**< defaults to 512Mb */
} git_diff_options;

/**
 * The diff list object that contains all individual file deltas.
 */
typedef struct git_diff_list git_diff_list;

/**
 * Flags that can be set for the file on side of a diff.
 *
 * Most of the flags are just for internal consumption by libgit2,
 * but some of them may be interesting to external users.
 */
enum {
	GIT_DIFF_FILE_VALID_OID  = (1 << 0), /** `oid` value is known correct */
	GIT_DIFF_FILE_FREE_PATH  = (1 << 1), /** `path` is allocated memory */
	GIT_DIFF_FILE_BINARY     = (1 << 2), /** should be considered binary data */
	GIT_DIFF_FILE_NOT_BINARY = (1 << 3), /** should be considered text data */
	GIT_DIFF_FILE_FREE_DATA  = (1 << 4), /** internal file data is allocated */
	GIT_DIFF_FILE_UNMAP_DATA = (1 << 5), /** internal file data is mmap'ed */
	GIT_DIFF_FILE_NO_DATA    = (1 << 6), /** file data should not be loaded */
};

/**
 * What type of change is described by a git_diff_delta?
 */
typedef enum {
	GIT_DELTA_UNMODIFIED = 0,
	GIT_DELTA_ADDED = 1,
	GIT_DELTA_DELETED = 2,
	GIT_DELTA_MODIFIED = 3,
	GIT_DELTA_RENAMED = 4,
	GIT_DELTA_COPIED = 5,
	GIT_DELTA_IGNORED = 6,
	GIT_DELTA_UNTRACKED = 7,
	GIT_DELTA_TYPECHANGE = 8,
} git_delta_t;

/**
 * Description of one side of a diff.
 */
typedef struct {
	git_oid oid;
	const char *path;
	git_off_t size;
	unsigned int flags;
	uint16_t mode;
} git_diff_file;

/**
 * Description of changes to one file.
 *
 * When iterating over a diff list object, this will generally be passed to
 * most callback functions and you can use the contents to understand
 * exactly what has changed.
 *
 * Under some circumstances, not all fields will be filled in, but the code
 * generally tries to fill in as much as possible.  One example is that the
 * "binary" field will not actually look at file contents if you do not
 * pass in hunk and/or line callbacks to the diff foreach iteration function.
 * It will just use the git attributes for those files.
 */
typedef struct {
	git_diff_file old_file;
	git_diff_file new_file;
	git_delta_t   status;
	unsigned int  similarity; /**< for RENAMED and COPIED, value 0-100 */
	int           binary;
} git_diff_delta;

/**
 * When iterating over a diff, callback that will be made per file.
 */
typedef int (*git_diff_file_fn)(
	void *cb_data,
	const git_diff_delta *delta,
	float progress);

/**
 * Structure describing a hunk of a diff.
 */
typedef struct {
	int old_start;
	int old_lines;
	int new_start;
	int new_lines;
} git_diff_range;

/**
 * When iterating over a diff, callback that will be made per hunk.
 */
typedef int (*git_diff_hunk_fn)(
	void *cb_data,
	const git_diff_delta *delta,
	const git_diff_range *range,
	const char *header,
	size_t header_len);

/**
 * Line origin constants.
 *
 * These values describe where a line came from and will be passed to
 * the git_diff_data_fn when iterating over a diff.  There are some
 * special origin constants at the end that are used for the text
 * output callbacks to demarcate lines that are actually part of
 * the file or hunk headers.
 */
enum {
	/* These values will be sent to `git_diff_data_fn` along with the line */
	GIT_DIFF_LINE_CONTEXT   = ' ',
	GIT_DIFF_LINE_ADDITION  = '+',
	GIT_DIFF_LINE_DELETION  = '-',
	GIT_DIFF_LINE_ADD_EOFNL = '\n', /**< Removed line w/o LF & added one with */
	GIT_DIFF_LINE_DEL_EOFNL = '\0', /**< LF was removed at end of file */

	/* The following values will only be sent to a `git_diff_data_fn` when
	 * the content of a diff is being formatted (eg. through
	 * git_diff_print_patch() or git_diff_print_compact(), for instance).
	 */
	GIT_DIFF_LINE_FILE_HDR  = 'F',
	GIT_DIFF_LINE_HUNK_HDR  = 'H',
	GIT_DIFF_LINE_BINARY    = 'B'
};

/**
 * When iterating over a diff, callback that will be made per text diff
 * line. In this context, the provided range will be NULL.
 *
 * When printing a diff, callback that will be made to output each line
 * of text.  This uses some extra GIT_DIFF_LINE_... constants for output
 * of lines of file and hunk headers.
 */
typedef int (*git_diff_data_fn)(
	void *cb_data,
	const git_diff_delta *delta,
	const git_diff_range *range,
	char line_origin, /**< GIT_DIFF_LINE_... value from above */
	const char *content,
	size_t content_len);

/**
 * The diff patch is used to store all the text diffs for a delta.
 *
 * You can easily loop over the content of patches and get information about
 * them.
 */
typedef struct git_diff_patch git_diff_patch;


/** @name Diff List Generator Functions
 *
 * These are the functions you would use to create (or destroy) a
 * git_diff_list from various objects in a repository.
 */
/**@{*/

/**
 * Deallocate a diff list.
 */
GIT_EXTERN(void) git_diff_list_free(git_diff_list *diff);

/**
 * Compute a difference between two tree objects.
 *
 * This is equivalent to `git diff <treeish> <treeish>`
 *
 * @param repo The repository containing the trees.
 * @param opts Structure with options to influence diff or NULL for defaults.
 * @param old_tree A git_tree object to diff from.
 * @param new_tree A git_tree object to diff to.
 * @param diff A pointer to a git_diff_list pointer that will be allocated.
 */
GIT_EXTERN(int) git_diff_tree_to_tree(
	git_repository *repo,
	const git_diff_options *opts, /**< can be NULL for defaults */
	git_tree *old_tree,
	git_tree *new_tree,
	git_diff_list **diff);

/**
 * Compute a difference between a tree and the index.
 *
 * This is equivalent to `git diff --cached <treeish>` or if you pass
 * the HEAD tree, then like `git diff --cached`.
 *
 * @param repo The repository containing the tree and index.
 * @param opts Structure with options to influence diff or NULL for defaults.
 * @param old_tree A git_tree object to diff from.
 * @param diff A pointer to a git_diff_list pointer that will be allocated.
 */
GIT_EXTERN(int) git_diff_index_to_tree(
	git_repository *repo,
	const git_diff_options *opts, /**< can be NULL for defaults */
	git_tree *old_tree,
	git_diff_list **diff);

/**
 * Compute a difference between the working directory and the index.
 *
 * This matches the `git diff` command.  See the note below on
 * `git_diff_workdir_to_tree` for a discussion of the difference between
 * `git diff` and `git diff HEAD` and how to emulate a `git diff <treeish>`
 * using libgit2.
 *
 * @param repo The repository.
 * @param opts Structure with options to influence diff or NULL for defaults.
 * @param diff A pointer to a git_diff_list pointer that will be allocated.
 */
GIT_EXTERN(int) git_diff_workdir_to_index(
	git_repository *repo,
	const git_diff_options *opts, /**< can be NULL for defaults */
	git_diff_list **diff);

/**
 * Compute a difference between the working directory and a tree.
 *
 * This is *NOT* the same as `git diff <treeish>`.  Running `git diff HEAD`
 * or the like actually uses information from the index, along with the tree
 * and workdir dir info.
 *
 * This function returns strictly the differences between the tree and the
 * files contained in the working directory, regardless of the state of
 * files in the index.  It may come as a surprise, but there is no direct
 * equivalent in core git.
 *
 * To emulate `git diff <treeish>`, you should call both
 * `git_diff_index_to_tree` and `git_diff_workdir_to_index`, then call
 * `git_diff_merge` on the results.  That will yield a `git_diff_list` that
 * matches the git output.
 *
 * If this seems confusing, take the case of a file with a staged deletion
 * where the file has then been put back into the working dir and modified.
 * The tree-to-workdir diff for that file is 'modified', but core git would
 * show status 'deleted' since there is a pending deletion in the index.
 *
 * @param repo The repository containing the tree.
 * @param opts Structure with options to influence diff or NULL for defaults.
 * @param old_tree A git_tree object to diff from.
 * @param diff A pointer to a git_diff_list pointer that will be allocated.
 */
GIT_EXTERN(int) git_diff_workdir_to_tree(
	git_repository *repo,
	const git_diff_options *opts, /**< can be NULL for defaults */
	git_tree *old_tree,
	git_diff_list **diff);

/**
 * Merge one diff list into another.
 *
 * This merges items from the "from" list into the "onto" list.  The
 * resulting diff list will have all items that appear in either list.
 * If an item appears in both lists, then it will be "merged" to appear
 * as if the old version was from the "onto" list and the new version
 * is from the "from" list (with the exception that if the item has a
 * pending DELETE in the middle, then it will show as deleted).
 *
 * @param onto Diff to merge into.
 * @param from Diff to merge.
 */
GIT_EXTERN(int) git_diff_merge(
	git_diff_list *onto,
	const git_diff_list *from);

/**@}*/


/** @name Diff List Processor Functions
 *
 * These are the functions you apply to a diff list to process it
 * or read it in some way.
 */
/**@{*/

/**
 * Loop over all deltas in a diff list issuing callbacks.
 *
 * This will iterate through all of the files described in a diff.  You
 * should provide a file callback to learn about each file.
 *
 * The "hunk" and "line" callbacks are optional, and the text diff of the
 * files will only be calculated if they are not NULL.  Of course, these
 * callbacks will not be invoked for binary files on the diff list or for
 * files whose only changed is a file mode change.
 *
 * Returning a non-zero value from any of the callbacks will terminate
 * the iteration and cause this return `GIT_EUSER`.
 *
 * @param diff A git_diff_list generated by one of the above functions.
 * @param cb_data Reference pointer that will be passed to your callbacks.
 * @param file_cb Callback function to make per file in the diff.
 * @param hunk_cb Optional callback to make per hunk of text diff.  This
 *                callback is called to describe a range of lines in the
 *                diff.  It will not be issued for binary files.
 * @param line_cb Optional callback to make per line of diff text.  This
 *                same callback will be made for context lines, added, and
 *                removed lines, and even for a deleted trailing newline.
 * @return 0 on success, GIT_EUSER on non-zero callback, or error code
 */
GIT_EXTERN(int) git_diff_foreach(
	git_diff_list *diff,
	void *cb_data,
	git_diff_file_fn file_cb,
	git_diff_hunk_fn hunk_cb,
	git_diff_data_fn line_cb);

/**
 * Iterate over a diff generating text output like "git diff --name-status".
 *
 * Returning a non-zero value from the callbacks will terminate the
 * iteration and cause this return `GIT_EUSER`.
 *
 * @param diff A git_diff_list generated by one of the above functions.
 * @param cb_data Reference pointer that will be passed to your callback.
 * @param print_cb Callback to make per line of diff text.
 * @return 0 on success, GIT_EUSER on non-zero callback, or error code
 */
GIT_EXTERN(int) git_diff_print_compact(
	git_diff_list *diff,
	void *cb_data,
	git_diff_data_fn print_cb);

/**
 * Look up the single character abbreviation for a delta status code.
 *
 * When you call `git_diff_print_compact` it prints single letter codes into
 * the output such as 'A' for added, 'D' for deleted, 'M' for modified, etc.
 * It is sometimes convenient to convert a git_delta_t value into these
 * letters for your own purposes.  This function does just that.  By the
 * way, unmodified will return a space (i.e. ' ').
 *
 * @param delta_t The git_delta_t value to look up
 * @return The single character label for that code
 */
GIT_EXTERN(char) git_diff_status_char(git_delta_t status);

/**
 * Iterate over a diff generating text output like "git diff".
 *
 * This is a super easy way to generate a patch from a diff.
 *
 * Returning a non-zero value from the callbacks will terminate the
 * iteration and cause this return `GIT_EUSER`.
 *
 * @param diff A git_diff_list generated by one of the above functions.
 * @param cb_data Reference pointer that will be passed to your callbacks.
 * @param print_cb Callback function to output lines of the diff.  This
 *                 same function will be called for file headers, hunk
 *                 headers, and diff lines.  Fortunately, you can probably
 *                 use various GIT_DIFF_LINE constants to determine what
 *                 text you are given.
 * @return 0 on success, GIT_EUSER on non-zero callback, or error code
 */
GIT_EXTERN(int) git_diff_print_patch(
	git_diff_list *diff,
	void *cb_data,
	git_diff_data_fn print_cb);

/**
 * Query how many diff records are there in a diff list.
 *
 * @param diff A git_diff_list generated by one of the above functions
 * @return Count of number of deltas in the list
 */
GIT_EXTERN(size_t) git_diff_num_deltas(git_diff_list *diff);

/**
 * Query how many diff deltas are there in a diff list filtered by type.
 *
 * This works just like `git_diff_entrycount()` with an extra parameter
 * that is a `git_delta_t` and returns just the count of how many deltas
 * match that particular type.
 *
 * @param diff A git_diff_list generated by one of the above functions
 * @param type A git_delta_t value to filter the count
 * @return Count of number of deltas matching delta_t type
 */
GIT_EXTERN(size_t) git_diff_num_deltas_of_type(
	git_diff_list *diff,
	git_delta_t type);

/**
 * Return the diff delta and patch for an entry in the diff list.
 *
 * The `git_diff_patch` is a newly created object contains the text diffs
 * for the delta.  You have to call `git_diff_patch_free()` when you are
 * done with it.  You can use the patch object to loop over all the hunks
 * and lines in the diff of the one delta.
 *
 * For an unchanged file or a binary file, no `git_diff_patch` will be
 * created, the output will be set to NULL, and the `binary` flag will be
 * set true in the `git_diff_delta` structure.
 *
 * The `git_diff_delta` pointer points to internal data and you do not have
 * to release it when you are done with it.  It will go away when the
 * `git_diff_list` and `git_diff_patch` go away.
 *
 * It is okay to pass NULL for either of the output parameters; if you pass
 * NULL for the `git_diff_patch`, then the text diff will not be calculated.
 *
 * @param patch Output parameter for the delta patch object
 * @param delta Output parameter for the delta object
 * @param diff Diff list object
 * @param idx Index into diff list
 * @return 0 on success, other value < 0 on error
 */
GIT_EXTERN(int) git_diff_get_patch(
	git_diff_patch **patch,
	const git_diff_delta **delta,
	git_diff_list *diff,
	size_t idx);

/**
 * Free a git_diff_patch object.
 */
GIT_EXTERN(void) git_diff_patch_free(
	git_diff_patch *patch);

/**
 * Get the delta associated with a patch
 */
GIT_EXTERN(const git_diff_delta *) git_diff_patch_delta(
	git_diff_patch *patch);

/**
 * Get the number of hunks in a patch
 */
GIT_EXTERN(size_t) git_diff_patch_num_hunks(
	git_diff_patch *patch);

/**
 * Get the information about a hunk in a patch
 *
 * Given a patch and a hunk index into the patch, this returns detailed
 * information about that hunk.  Any of the output pointers can be passed
 * as NULL if you don't care about that particular piece of information.
 *
 * @param range Output pointer to git_diff_range of hunk
 * @param header Output pointer to header string for hunk.  Unlike the
 *               content pointer for each line, this will be NUL-terminated
 * @param header_len Output value of characters in header string
 * @param lines_in_hunk Output count of total lines in this hunk
 * @param patch Input pointer to patch object
 * @param hunk_idx Input index of hunk to get information about
 * @return 0 on success, GIT_ENOTFOUND if hunk_idx out of range, <0 on error
 */
GIT_EXTERN(int) git_diff_patch_get_hunk(
	const git_diff_range **range,
	const char **header,
	size_t *header_len,
	size_t *lines_in_hunk,
	git_diff_patch *patch,
	size_t hunk_idx);

/**
 * Get the number of lines in a hunk.
 *
 * @param patch The git_diff_patch object
 * @param hunk_idx Index of the hunk
 * @return Number of lines in hunk or -1 if invalid hunk index
 */
GIT_EXTERN(int) git_diff_patch_num_lines_in_hunk(
	git_diff_patch *patch,
	size_t hunk_idx);

/**
 * Get data about a line in a hunk of a patch.
 *
 * Given a patch, a hunk index, and a line index in the hunk, this
 * will return a lot of details about that line.  If you pass a hunk
 * index larger than the number of hunks or a line index larger than
 * the number of lines in the hunk, this will return -1.
 *
 * @param line_origin A GIT_DIFF_LINE constant from above
 * @param content Pointer to content of diff line, not NUL-terminated
 * @param content_len Number of characters in content
 * @param old_lineno Line number in old file or -1 if line is added
 * @param new_lineno Line number in new file or -1 if line is deleted
 * @param patch The patch to look in
 * @param hunk_idx The index of the hunk
 * @param line_of_index The index of the line in the hunk
 * @return 0 on success, <0 on failure
 */
GIT_EXTERN(int) git_diff_patch_get_line_in_hunk(
	char *line_origin,
	const char **content,
	size_t *content_len,
	int *old_lineno,
	int *new_lineno,
	git_diff_patch *patch,
	size_t hunk_idx,
	size_t line_of_hunk);

/**@}*/


/*
 * Misc
 */

/**
 * Directly run a text diff on two blobs.
 *
 * Compared to a file, a blob lacks some contextual information. As such,
 * the `git_diff_file` parameters of the callbacks will be filled
 * accordingly to the following: `mode` will be set to 0, `path` will be set
 * to NULL. When dealing with a NULL blob, `oid` will be set to 0.
 *
 * When at least one of the blobs being dealt with is binary, the
 * `git_diff_delta` binary attribute will be set to 1 and no call to the
 * hunk_cb nor line_cb will be made.
 *
 * @return 0 on success, GIT_EUSER on non-zero callback, or error code
 */
GIT_EXTERN(int) git_diff_blobs(
	git_blob *old_blob,
	git_blob *new_blob,
	const git_diff_options *options,
	void *cb_data,
	git_diff_file_fn file_cb,
	git_diff_hunk_fn hunk_cb,
	git_diff_data_fn line_cb);

GIT_END_DECL

/** @} */

#endif
