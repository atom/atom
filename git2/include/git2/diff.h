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
 * Overview
 * --------
 *
 * Calculating diffs is generally done in two phases: building a diff list
 * then traversing the diff list.  This makes is easier to share logic
 * across the various types of diffs (tree vs tree, workdir vs index, etc.),
 * and also allows you to insert optional diff list post-processing phases,
 * such as rename detected, in between the steps.  When you are done with a
 * diff list object, it must be freed.
 *
 * Terminology
 * -----------
 *
 * To understand the diff APIs, you should know the following terms:
 *
 * - A `diff` or `diff list` represents the cumulative list of differences
 *   between two snapshots of a repository (possibly filtered by a set of
 *   file name patterns).  This is the `git_diff_list` object.
 * - A `delta` is a file pair with an old and new revision.  The old version
 *   may be absent if the file was just created and the new version may be
 *   absent if the file was deleted.  A diff is mostly just a list of deltas.
 * - A `binary` file / delta is a file (or pair) for which no text diffs
 *   should be generated.  A diff list can contain delta entries that are
 *   binary, but no diff content will be output for those files.  There is
 *   a base heuristic for binary detection and you can further tune the
 *   behavior with git attributes or diff flags and option settings.
 * - A `hunk` is a span of modified lines in a delta along with some stable
 *   surrounding context.  You can configure the amount of context and other
 *   properties of how hunks are generated.  Each hunk also comes with a
 *   header that described where it starts and ends in both the old and new
 *   versions in the delta.
 * - A `line` is a range of characters inside a hunk.  It could be a context
 *   line (i.e. in both old and new versions), an added line (i.e. only in
 *   the new version), or a removed line (i.e. only in the old version).
 *   Unfortunately, we don't know anything about the encoding of data in the
 *   file being diffed, so we cannot tell you much about the line content.
 *   Line data will not be NUL-byte terminated, however, because it will be
 *   just a span of bytes inside the larger file.
 *
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Flags for diff options.  A combination of these flags can be passed
 * in via the `flags` value in the `git_diff_options`.
 */
typedef enum {
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
	/** Ignore file mode changes */
	GIT_DIFF_IGNORE_FILEMODE = (1 << 17),
} git_diff_option_t;

/**
 * Structure describing options about how the diff should be executed.
 *
 * Setting all values of the structure to zero will yield the default
 * values.  Similarly, passing NULL for the options structure will
 * give the defaults.  The default values are marked below.
 *
 * - `flags` is a combination of the `git_diff_option_t` values above
 * - `context_lines` is the number of unchanged lines that define the
 *    boundary of a hunk (and to display before and after)
 * - `interhunk_lines` is the maximum number of unchanged lines between
 *    hunk boundaries before the hunks will be merged into a one.
 * - `old_prefix` is the virtual "directory" to prefix to old file names
 *   in hunk headers (default "a")
 * - `new_prefix` is the virtual "directory" to prefix to new file names
 *   in hunk headers (default "b")
 * - `pathspec` is an array of paths / fnmatch patterns to constrain diff
 * - `max_size` is a file size (in bytes) above which a blob will be marked
 *   as binary automatically; pass a negative value to disable.
 */
typedef struct {
	unsigned int version;      /**< version for the struct */
	uint32_t flags;            /**< defaults to GIT_DIFF_NORMAL */
	uint16_t context_lines;    /**< defaults to 3 */
	uint16_t interhunk_lines;  /**< defaults to 0 */
	const char *old_prefix;    /**< defaults to "a" */
	const char *new_prefix;    /**< defaults to "b" */
	git_strarray pathspec;     /**< defaults to include all paths */
	git_off_t max_size;        /**< defaults to 512MB */
} git_diff_options;

#define GIT_DIFF_OPTIONS_VERSION 1
#define GIT_DIFF_OPTIONS_INIT {GIT_DIFF_OPTIONS_VERSION}

/**
 * The diff list object that contains all individual file deltas.
 *
 * This is an opaque structure which will be allocated by one of the diff
 * generator functions below (such as `git_diff_tree_to_tree`).  You are
 * responsible for releasing the object memory when done, using the
 * `git_diff_list_free()` function.
 */
typedef struct git_diff_list git_diff_list;

/**
 * Flags for the file object on each side of a diff.
 *
 * Note: most of these flags are just for **internal** consumption by
 * libgit2, but some of them may be interesting to external users.
 */
typedef enum {
	GIT_DIFF_FILE_VALID_OID  = (1 << 0), /** `oid` value is known correct */
	GIT_DIFF_FILE_FREE_PATH  = (1 << 1), /** `path` is allocated memory */
	GIT_DIFF_FILE_BINARY     = (1 << 2), /** should be considered binary data */
	GIT_DIFF_FILE_NOT_BINARY = (1 << 3), /** should be considered text data */
	GIT_DIFF_FILE_FREE_DATA  = (1 << 4), /** internal file data is allocated */
	GIT_DIFF_FILE_UNMAP_DATA = (1 << 5), /** internal file data is mmap'ed */
	GIT_DIFF_FILE_NO_DATA    = (1 << 6), /** file data should not be loaded */
} git_diff_file_flag_t;

/**
 * What type of change is described by a git_diff_delta?
 *
 * `GIT_DELTA_RENAMED` and `GIT_DELTA_COPIED` will only show up if you run
 * `git_diff_find_similar()` on the diff list object.
 *
 * `GIT_DELTA_TYPECHANGE` only shows up given `GIT_DIFF_INCLUDE_TYPECHANGE`
 * in the option flags (otherwise type changes will be split into ADDED /
 * DELETED pairs).
 */
typedef enum {
	GIT_DELTA_UNMODIFIED = 0, /** no changes */
	GIT_DELTA_ADDED = 1,	  /** entry does not exist in old version */
	GIT_DELTA_DELETED = 2,	  /** entry does not exist in new version */
	GIT_DELTA_MODIFIED = 3,   /** entry content changed between old and new */
	GIT_DELTA_RENAMED = 4,    /** entry was renamed between old and new */
	GIT_DELTA_COPIED = 5,     /** entry was copied from another old entry */
	GIT_DELTA_IGNORED = 6,    /** entry is ignored item in workdir */
	GIT_DELTA_UNTRACKED = 7,  /** entry is untracked item in workdir */
	GIT_DELTA_TYPECHANGE = 8, /** type of entry changed between old and new */
} git_delta_t;

/**
 * Description of one side of a diff entry.
 *
 * Although this is called a "file", it may actually represent a file, a
 * symbolic link, a submodule commit id, or even a tree (although that only
 * if you are tracking type changes or ignored/untracked directories).
 *
 * The `oid` is the `git_oid` of the item.  If the entry represents an
 * absent side of a diff (e.g. the `old_file` of a `GIT_DELTA_ADDED` delta),
 * then the oid will be zeroes.
 *
 * `path` is the NUL-terminated path to the entry relative to the working
 * directory of the repository.
 *
 * `size` is the size of the entry in bytes.
 *
 * `flags` is a combination of the `git_diff_file_flag_t` types, but those
 * are largely internal values.
 *
 * `mode` is, roughly, the stat() `st_mode` value for the item.  This will
 * be restricted to one of the `git_filemode_t` values.
 */
typedef struct {
	git_oid oid;
	const char *path;
	git_off_t size;
	unsigned int flags;
	uint16_t mode;
} git_diff_file;

/**
 * Description of changes to one entry.
 *
 * When iterating over a diff list object, this will be passed to most
 * callback functions and you can use the contents to understand exactly
 * what has changed.
 *
 * The `old_file` repesents the "from" side of the diff and the `new_file`
 * repesents to "to" side of the diff.  What those means depend on the
 * function that was used to generate the diff and will be documented below.
 * You can also use the `GIT_DIFF_REVERSE` flag to flip it around.
 *
 * Although the two sides of the delta are named "old_file" and "new_file",
 * they actually may correspond to entries that represent a file, a symbolic
 * link, a submodule commit id, or even a tree (if you are tracking type
 * changes or ignored/untracked directories).
 *
 * Under some circumstances, in the name of efficiency, not all fields will
 * be filled in, but we generally try to fill in as much as possible.  One
 * example is that the "binary" field will not examine file contents if you
 * do not pass in hunk and/or line callbacks to the diff foreach iteration
 * function.  It will just use the git attributes for those files.
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
 *
 * @param delta A pointer to the delta data for the file
 * @param progress Goes from 0 to 1 over the diff list
 * @param payload User-specified pointer from foreach function
 */
typedef int (*git_diff_file_cb)(
	const git_diff_delta *delta,
	float progress,
	void *payload);

/**
 * Structure describing a hunk of a diff.
 */
typedef struct {
	int old_start; /** Starting line number in old_file */
	int old_lines; /** Number of lines in old_file */
	int new_start; /** Starting line number in new_file */
	int new_lines; /** Number of lines in new_file */
} git_diff_range;

/**
 * When iterating over a diff, callback that will be made per hunk.
 */
typedef int (*git_diff_hunk_cb)(
	const git_diff_delta *delta,
	const git_diff_range *range,
	const char *header,
	size_t header_len,
	void *payload);

/**
 * Line origin constants.
 *
 * These values describe where a line came from and will be passed to
 * the git_diff_data_cb when iterating over a diff.  There are some
 * special origin constants at the end that are used for the text
 * output callbacks to demarcate lines that are actually part of
 * the file or hunk headers.
 */
typedef enum {
	/* These values will be sent to `git_diff_data_cb` along with the line */
	GIT_DIFF_LINE_CONTEXT   = ' ',
	GIT_DIFF_LINE_ADDITION  = '+',
	GIT_DIFF_LINE_DELETION  = '-',
	GIT_DIFF_LINE_ADD_EOFNL = '\n', /**< Removed line w/o LF & added one with */
	GIT_DIFF_LINE_DEL_EOFNL = '\0', /**< LF was removed at end of file */

	/* The following values will only be sent to a `git_diff_data_cb` when
	 * the content of a diff is being formatted (eg. through
	 * git_diff_print_patch() or git_diff_print_compact(), for instance).
	 */
	GIT_DIFF_LINE_FILE_HDR  = 'F',
	GIT_DIFF_LINE_HUNK_HDR  = 'H',
	GIT_DIFF_LINE_BINARY    = 'B'
} git_diff_line_t;

/**
 * When iterating over a diff, callback that will be made per text diff
 * line. In this context, the provided range will be NULL.
 *
 * When printing a diff, callback that will be made to output each line
 * of text.  This uses some extra GIT_DIFF_LINE_... constants for output
 * of lines of file and hunk headers.
 */
typedef int (*git_diff_data_cb)(
	const git_diff_delta *delta, /** delta that contains this data */
	const git_diff_range *range, /** range of lines containing this data */
	char line_origin,            /** git_diff_list_t value from above */
	const char *content,         /** diff data - not NUL terminated */
	size_t content_len,          /** number of bytes of diff data */
	void *payload);              /** user reference data */

/**
 * The diff patch is used to store all the text diffs for a delta.
 *
 * You can easily loop over the content of patches and get information about
 * them.
 */
typedef struct git_diff_patch git_diff_patch;

/**
 * Flags to control the behavior of diff rename/copy detection.
 */
typedef enum {
	/** look for renames? (`--find-renames`) */
	GIT_DIFF_FIND_RENAMES = (1 << 0),
	/** consider old size of modified for renames? (`--break-rewrites=N`) */
	GIT_DIFF_FIND_RENAMES_FROM_REWRITES = (1 << 1),

	/** look for copies? (a la `--find-copies`) */
	GIT_DIFF_FIND_COPIES = (1 << 2),
	/** consider unmodified as copy sources? (`--find-copies-harder`) */
	GIT_DIFF_FIND_COPIES_FROM_UNMODIFIED = (1 << 3),

	/** split large rewrites into delete/add pairs (`--break-rewrites=/M`) */
	GIT_DIFF_FIND_AND_BREAK_REWRITES = (1 << 4),
} git_diff_find_t;

/**
 * Control behavior of rename and copy detection
 */
typedef struct {
	unsigned int version;

	/** Combination of git_diff_find_t values (default FIND_RENAMES) */
	unsigned int flags;

	/** Similarity to consider a file renamed (default 50) */
	unsigned int rename_threshold;
	/** Similarity of modified to be eligible rename source (default 50) */
	unsigned int rename_from_rewrite_threshold;
	/** Similarity to consider a file a copy (default 50) */
	unsigned int copy_threshold;
	/** Similarity to split modify into delete/add pair (default 60) */
	unsigned int break_rewrite_threshold;

	/** Maximum similarity sources to examine (a la diff's `-l` option or
	 *  the `diff.renameLimit` config) (default 200)
	 */
	unsigned int target_limit;
} git_diff_find_options;

#define GIT_DIFF_FIND_OPTIONS_VERSION 1
#define GIT_DIFF_FIND_OPTIONS_INIT {GIT_DIFF_FIND_OPTIONS_VERSION}

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
 * Create a diff list with the difference between two tree objects.
 *
 * This is equivalent to `git diff <old-tree> <new-tree>`
 *
 * The first tree will be used for the "old_file" side of the delta and the
 * second tree will be used for the "new_file" side of the delta.
 *
 * @param diff Output pointer to a git_diff_list pointer to be allocated.
 * @param repo The repository containing the trees.
 * @param old_tree A git_tree object to diff from.
 * @param new_tree A git_tree object to diff to.
 * @param opts Structure with options to influence diff or NULL for defaults.
 */
GIT_EXTERN(int) git_diff_tree_to_tree(
	git_diff_list **diff,
	git_repository *repo,
	git_tree *old_tree,
	git_tree *new_tree,
	const git_diff_options *opts); /**< can be NULL for defaults */

/**
 * Create a diff list between a tree and repository index.
 *
 * This is equivalent to `git diff --cached <treeish>` or if you pass
 * the HEAD tree, then like `git diff --cached`.
 *
 * The tree you pass will be used for the "old_file" side of the delta, and
 * the index will be used for the "new_file" side of the delta.
 *
 * @param diff Output pointer to a git_diff_list pointer to be allocated.
 * @param repo The repository containing the tree and index.
 * @param old_tree A git_tree object to diff from.
 * @param index The index to diff with; repo index used if NULL.
 * @param opts Structure with options to influence diff or NULL for defaults.
 */
GIT_EXTERN(int) git_diff_tree_to_index(
	git_diff_list **diff,
	git_repository *repo,
	git_tree *old_tree,
	git_index *index,
	const git_diff_options *opts); /**< can be NULL for defaults */

/**
 * Create a diff list between the repository index and the workdir directory.
 *
 * This matches the `git diff` command.  See the note below on
 * `git_diff_tree_to_workdir` for a discussion of the difference between
 * `git diff` and `git diff HEAD` and how to emulate a `git diff <treeish>`
 * using libgit2.
 *
 * The index will be used for the "old_file" side of the delta, and the
 * working directory will be used for the "new_file" side of the delta.
 *
 * @param diff Output pointer to a git_diff_list pointer to be allocated.
 * @param repo The repository.
 * @param index The index to diff from; repo index used if NULL.
 * @param opts Structure with options to influence diff or NULL for defaults.
 */
GIT_EXTERN(int) git_diff_index_to_workdir(
	git_diff_list **diff,
	git_repository *repo,
	git_index *index,
	const git_diff_options *opts); /**< can be NULL for defaults */

/**
 * Create a diff list between a tree and the working directory.
 *
 * The tree you provide will be used for the "old_file" side of the delta,
 * and the working directory will be used for the "new_file" side.
 *
 * Please note: this is *NOT* the same as `git diff <treeish>`.  Running
 * `git diff HEAD` or the like actually uses information from the index,
 * along with the tree and working directory info.
 *
 * This function returns strictly the differences between the tree and the
 * files contained in the working directory, regardless of the state of
 * files in the index.  It may come as a surprise, but there is no direct
 * equivalent in core git.
 *
 * To emulate `git diff <treeish>`, call both `git_diff_tree_to_index` and
 * `git_diff_index_to_workdir`, then call `git_diff_merge` on the results.
 * That will yield a `git_diff_list` that matches the git output.
 *
 * If this seems confusing, take the case of a file with a staged deletion
 * where the file has then been put back into the working dir and modified.
 * The tree-to-workdir diff for that file is 'modified', but core git would
 * show status 'deleted' since there is a pending deletion in the index.
 *
 * @param diff A pointer to a git_diff_list pointer that will be allocated.
 * @param repo The repository containing the tree.
 * @param old_tree A git_tree object to diff from.
 * @param opts Structure with options to influence diff or NULL for defaults.
 */
GIT_EXTERN(int) git_diff_tree_to_workdir(
	git_diff_list **diff,
	git_repository *repo,
	git_tree *old_tree,
	const git_diff_options *opts); /**< can be NULL for defaults */

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

/**
 * Transform a diff list marking file renames, copies, etc.
 *
 * This modifies a diff list in place, replacing old entries that look
 * like renames or copies with new entries reflecting those changes.
 * This also will, if requested, break modified files into add/remove
 * pairs if the amount of change is above a threshold.
 *
 * @param diff Diff list to run detection algorithms on
 * @param options Control how detection should be run, NULL for defaults
 * @return 0 on success, -1 on failure
 */
GIT_EXTERN(int) git_diff_find_similar(
	git_diff_list *diff,
	git_diff_find_options *options);

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
 * @param file_cb Callback function to make per file in the diff.
 * @param hunk_cb Optional callback to make per hunk of text diff.  This
 *                callback is called to describe a range of lines in the
 *                diff.  It will not be issued for binary files.
 * @param line_cb Optional callback to make per line of diff text.  This
 *                same callback will be made for context lines, added, and
 *                removed lines, and even for a deleted trailing newline.
 * @param payload Reference pointer that will be passed to your callbacks.
 * @return 0 on success, GIT_EUSER on non-zero callback, or error code
 */
GIT_EXTERN(int) git_diff_foreach(
	git_diff_list *diff,
	git_diff_file_cb file_cb,
	git_diff_hunk_cb hunk_cb,
	git_diff_data_cb line_cb,
	void *payload);

/**
 * Iterate over a diff generating text output like "git diff --name-status".
 *
 * Returning a non-zero value from the callbacks will terminate the
 * iteration and cause this return `GIT_EUSER`.
 *
 * @param diff A git_diff_list generated by one of the above functions.
 * @param print_cb Callback to make per line of diff text.
 * @param payload Reference pointer that will be passed to your callback.
 * @return 0 on success, GIT_EUSER on non-zero callback, or error code
 */
GIT_EXTERN(int) git_diff_print_compact(
	git_diff_list *diff,
	git_diff_data_cb print_cb,
	void *payload);

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
 * @param payload Reference pointer that will be passed to your callbacks.
 * @param print_cb Callback function to output lines of the diff.  This
 *                 same function will be called for file headers, hunk
 *                 headers, and diff lines.  Fortunately, you can probably
 *                 use various GIT_DIFF_LINE constants to determine what
 *                 text you are given.
 * @return 0 on success, GIT_EUSER on non-zero callback, or error code
 */
GIT_EXTERN(int) git_diff_print_patch(
	git_diff_list *diff,
	git_diff_data_cb print_cb,
	void *payload);

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
 * @param patch_out Output parameter for the delta patch object
 * @param delta_out Output parameter for the delta object
 * @param diff Diff list object
 * @param idx Index into diff list
 * @return 0 on success, other value < 0 on error
 */
GIT_EXTERN(int) git_diff_get_patch(
	git_diff_patch **patch_out,
	const git_diff_delta **delta_out,
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

/**
 * Serialize the patch to text via callback.
 *
 * Returning a non-zero value from the callback will terminate the iteration
 * and cause this return `GIT_EUSER`.
 *
 * @param patch A git_diff_patch representing changes to one file
 * @param print_cb Callback function to output lines of the patch.  Will be
 *                 called for file headers, hunk headers, and diff lines.
 * @param payload Reference pointer that will be passed to your callbacks.
 * @return 0 on success, GIT_EUSER on non-zero callback, or error code
 */
GIT_EXTERN(int) git_diff_patch_print(
	git_diff_patch *patch,
	git_diff_data_cb print_cb,
	void *payload);

/**
 * Get the content of a patch as a single diff text.
 *
 * @param string Allocated string; caller must free.
 * @param patch A git_diff_patch representing changes to one file
 * @return 0 on success, <0 on failure.
 */
GIT_EXTERN(int) git_diff_patch_to_str(
	char **string,
	git_diff_patch *patch);

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
	git_diff_file_cb file_cb,
	git_diff_hunk_cb hunk_cb,
	git_diff_data_cb line_cb,
	void *payload);

GIT_END_DECL

/** @} */

#endif
