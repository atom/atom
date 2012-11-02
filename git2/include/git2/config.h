/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_config_h__
#define INCLUDE_git_config_h__

#include "common.h"
#include "types.h"

/**
 * @file git2/config.h
 * @brief Git config management routines
 * @defgroup git_config Git config management routines
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Priority level of a config file.
 * These priority levels correspond to the natural escalation logic
 * (from higher to lower) when searching for config entries in git.git.
 *
 * git_config_open_default() and git_repository_config() honor those
 * priority levels as well.
 */
enum {
	GIT_CONFIG_LEVEL_SYSTEM = 1,	/**< System-wide configuration file. */
	GIT_CONFIG_LEVEL_XDG = 2,		/**< XDG compatible configuration file (.config/git/config). */
	GIT_CONFIG_LEVEL_GLOBAL = 3,	/**< User-specific configuration file, also called Global configuration file. */
	GIT_CONFIG_LEVEL_LOCAL = 4,		/**< Repository specific configuration file. */
	GIT_CONFIG_HIGHEST_LEVEL = -1,	/**< Represents the highest level of a config file. */
};

typedef struct {
	const char *name;
	const char *value;
	unsigned int level;
} git_config_entry;

/**
 * Generic backend that implements the interface to
 * access a configuration file
 */
struct git_config_file {
	struct git_config *cfg;

	/* Open means open the file/database and parse if necessary */
	int (*open)(struct git_config_file *, unsigned int level);
	int (*get)(struct git_config_file *, const char *key, const git_config_entry **entry);
	int (*get_multivar)(struct git_config_file *, const char *key, const char *regexp, int (*fn)(const git_config_entry *, void *), void *data);
	int (*set)(struct git_config_file *, const char *key, const char *value);
	int (*set_multivar)(git_config_file *cfg, const char *name, const char *regexp, const char *value);
	int (*del)(struct git_config_file *, const char *key);
	int (*foreach)(struct git_config_file *, const char *, int (*fn)(const git_config_entry *, void *), void *data);
	void (*free)(struct git_config_file *);
};

typedef enum {
	GIT_CVAR_FALSE = 0,
	GIT_CVAR_TRUE = 1,
	GIT_CVAR_INT32,
	GIT_CVAR_STRING
} git_cvar_t;

typedef struct {
	git_cvar_t cvar_type;
	const char *str_match;
	int map_value;
} git_cvar_map;

/**
 * Locate the path to the global configuration file
 *
 * The user or global configuration file is usually
 * located in `$HOME/.gitconfig`.
 *
 * This method will try to guess the full path to that
 * file, if the file exists. The returned path
 * may be used on any `git_config` call to load the
 * global configuration file.
 *
 * This method will not guess the path to the xdg compatible
 * config file (.config/git/config).
 *
 * @param global_config_path Buffer of GIT_PATH_MAX length to store the path
 * @return 0 if a global configuration file has been
 *	found. Its path will be stored in `buffer`.
 */
GIT_EXTERN(int) git_config_find_global(char *global_config_path, size_t length);

/**
 * Locate the path to the global xdg compatible configuration file
 *
 * The xdg compatible configuration file is usually
 * located in `$HOME/.config/git/config`.
 *
 * This method will try to guess the full path to that
 * file, if the file exists. The returned path
 * may be used on any `git_config` call to load the
 * xdg compatible configuration file.
 *
 * @param xdg_config_path Buffer of GIT_PATH_MAX length to store the path
 * @return 0 if a xdg compatible configuration file has been
 *	found. Its path will be stored in `buffer`.
 */
GIT_EXTERN(int) git_config_find_xdg(char *xdg_config_path, size_t length);

/**
 * Locate the path to the system configuration file
 *
 * If /etc/gitconfig doesn't exist, it will look for
 * %PROGRAMFILES%\Git\etc\gitconfig.

 * @param system_config_path Buffer of GIT_PATH_MAX length to store the path
 * @return 0 if a system configuration file has been
 *	found. Its path will be stored in `buffer`.
 */
GIT_EXTERN(int) git_config_find_system(char *system_config_path, size_t length);

/**
 * Open the global, XDG and system configuration files
 *
 * Utility wrapper that finds the global, XDG and system configuration files
 * and opens them into a single prioritized config object that can be
 * used when accessing default config data outside a repository.
 *
 * @param out Pointer to store the config instance
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_open_default(git_config **out);

/**
 * Create a configuration file backend for ondisk files
 *
 * These are the normal `.gitconfig` files that Core Git
 * processes. Note that you first have to add this file to a
 * configuration object before you can query it for configuration
 * variables.
 *
 * @param out the new backend
 * @param path where the config file is located
 */
GIT_EXTERN(int) git_config_file__ondisk(struct git_config_file **out, const char *path);

/**
 * Allocate a new configuration object
 *
 * This object is empty, so you have to add a file to it before you
 * can do anything with it.
 *
 * @param out pointer to the new configuration
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_new(git_config **out);

/**
 * Add a generic config file instance to an existing config
 *
 * Note that the configuration object will free the file
 * automatically.
 *
 * Further queries on this config object will access each
 * of the config file instances in order (instances with
 * a higher priority level will be accessed first).
 *
 * @param cfg the configuration to add the file to
 * @param file the configuration file (backend) to add
 * @param level the priority level of the backend
 * @param force if a config file already exists for the given
 *  priority level, replace it
 * @return 0 on success, GIT_EEXISTS when adding more than one file
 *  for a given priority level (and force_replace set to 0), or error code
 */
GIT_EXTERN(int) git_config_add_file(
	git_config *cfg,
	git_config_file *file,
	unsigned int level,
	int force);

/**
 * Add an on-disk config file instance to an existing config
 *
 * The on-disk file pointed at by `path` will be opened and
 * parsed; it's expected to be a native Git config file following
 * the default Git config syntax (see man git-config).
 *
 * Note that the configuration object will free the file
 * automatically.
 *
 * Further queries on this config object will access each
 * of the config file instances in order (instances with
 * a higher priority level will be accessed first).
 *
 * @param cfg the configuration to add the file to
 * @param path path to the configuration file (backend) to add
 * @param level the priority level of the backend
 * @param force if a config file already exists for the given
 *  priority level, replace it
 * @return 0 on success, GIT_EEXISTS when adding more than one file
 *  for a given priority level (and force_replace set to 0), or error code
 */
GIT_EXTERN(int) git_config_add_file_ondisk(
	git_config *cfg,
	const char *path,
	unsigned int level,
	int force);


/**
 * Create a new config instance containing a single on-disk file
 *
 * This method is a simple utility wrapper for the following sequence
 * of calls:
 *	- git_config_new
 *	- git_config_add_file_ondisk
 *
 * @param cfg The configuration instance to create
 * @param path Path to the on-disk file to open
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_open_ondisk(git_config **cfg, const char *path);

/**
 * Build a single-level focused config object from a multi-level one.
 *
 * The returned config object can be used to perform get/set/delete operations
 * on a single specific level.
 *
 * Getting several times the same level from the same parent multi-level config
 * will return different config instances, but containing the same config_file
 * instance.
 *
 * @return 0, GIT_ENOTFOUND if the passed level cannot be found in the
 * multi-level parent config, or an error code
 */
GIT_EXTERN(int) git_config_open_level(
    git_config **cfg_out,
    git_config *cfg_parent,
    unsigned int level);

/**
 * Free the configuration and its associated memory and files
 *
 * @param cfg the configuration to free
 */
GIT_EXTERN(void) git_config_free(git_config *cfg);

/**
 * Get the git_config_entry of a config variable.
 *
 * The git_config_entry is owned by the config and should not be freed by the
 * user.

 * @param out pointer to the variable git_config_entry
 * @param cfg where to look for the variable
 * @param name the variable's name
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_get_config_entry(const git_config_entry **out, git_config *cfg, const char *name);

/**
 * Get the value of an integer config variable.
 *
 * All config files will be looked into, in the order of their
 * defined level. A higher level means a higher priority. The
 * first occurence of the variable will be returned here.
 *
 * @param out pointer to the variable where the value should be stored
 * @param cfg where to look for the variable
 * @param name the variable's name
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_get_int32(int32_t *out, git_config *cfg, const char *name);

/**
 * Get the value of a long integer config variable.
 *
 * All config files will be looked into, in the order of their
 * defined level. A higher level means a higher priority. The
 * first occurence of the variable will be returned here.
 *
 * @param out pointer to the variable where the value should be stored
 * @param cfg where to look for the variable
 * @param name the variable's name
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_get_int64(int64_t *out, git_config *cfg, const char *name);

/**
 * Get the value of a boolean config variable.
 *
 * This function uses the usual C convention of 0 being false and
 * anything else true.
 *
 * All config files will be looked into, in the order of their
 * defined level. A higher level means a higher priority. The
 * first occurence of the variable will be returned here.
 *
 * @param out pointer to the variable where the value should be stored
 * @param cfg where to look for the variable
 * @param name the variable's name
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_get_bool(int *out, git_config *cfg, const char *name);

/**
 * Get the value of a string config variable.
 *
 * The string is owned by the variable and should not be freed by the
 * user.
 *
 * All config files will be looked into, in the order of their
 * defined level. A higher level means a higher priority. The
 * first occurence of the variable will be returned here.
 *
 * @param out pointer to the variable's value
 * @param cfg where to look for the variable
 * @param name the variable's name
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_get_string(const char **out, git_config *cfg, const char *name);

/**
 * Get each value of a multivar.
 *
 * The callback will be called on each variable found
 *
 * @param cfg where to look for the variable
 * @param name the variable's name
 * @param regexp regular expression to filter which variables we're
 * interested in. Use NULL to indicate all
 * @param fn the function to be called on each value of the variable
 * @param data opaque pointer to pass to the callback
 */
GIT_EXTERN(int) git_config_get_multivar(git_config *cfg, const char *name, const char *regexp, int (*fn)(const git_config_entry *, void *), void *data);

/**
 * Set the value of an integer config variable in the config file
 * with the highest level (usually the local one).
 *
 * @param cfg where to look for the variable
 * @param name the variable's name
 * @param value Integer value for the variable
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_set_int32(git_config *cfg, const char *name, int32_t value);

/**
 * Set the value of a long integer config variable in the config file
 * with the highest level (usually the local one).
 *
 * @param cfg where to look for the variable
 * @param name the variable's name
 * @param value Long integer value for the variable
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_set_int64(git_config *cfg, const char *name, int64_t value);

/**
 * Set the value of a boolean config variable in the config file
 * with the highest level (usually the local one).
 *
 * @param cfg where to look for the variable
 * @param name the variable's name
 * @param value the value to store
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_set_bool(git_config *cfg, const char *name, int value);

/**
 * Set the value of a string config variable in the config file
 * with the highest level (usually the local one).
 *
 * A copy of the string is made and the user is free to use it
 * afterwards.
 *
 * @param cfg where to look for the variable
 * @param name the variable's name
 * @param value the string to store.
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_set_string(git_config *cfg, const char *name, const char *value);

/**
 * Set a multivar in the local config file.
 *
 * @param cfg where to look for the variable
 * @param name the variable's name
 * @param regexp a regular expression to indicate which values to replace
 * @param value the new value.
 */
GIT_EXTERN(int) git_config_set_multivar(git_config *cfg, const char *name, const char *regexp, const char *value);

/**
 * Delete a config variable from the config file
 * with the highest level (usually the local one).
 *
 * @param cfg the configuration
 * @param name the variable to delete
 */
GIT_EXTERN(int) git_config_delete(git_config *cfg, const char *name);

/**
 * Perform an operation on each config variable.
 *
 * The callback receives the normalized name and value of each variable
 * in the config backend, and the data pointer passed to this function.
 * As soon as one of the callback functions returns something other than 0,
 * this function stops iterating and returns `GIT_EUSER`.
 *
 * @param cfg where to get the variables from
 * @param callback the function to call on each variable
 * @param payload the data to pass to the callback
 * @return 0 on success, GIT_EUSER on non-zero callback, or error code
 */
GIT_EXTERN(int) git_config_foreach(
	git_config *cfg,
	int (*callback)(const git_config_entry *, void *payload),
	void *payload);

/**
 * Perform an operation on each config variable matching a regular expression.
 *
 * This behaviors like `git_config_foreach` with an additional filter of a
 * regular expression that filters which config keys are passed to the
 * callback.
 *
 * @param cfg where to get the variables from
 * @param regexp regular expression to match against config names
 * @param callback the function to call on each variable
 * @param payload the data to pass to the callback
 * @return 0 or the return value of the callback which didn't return 0
 */
GIT_EXTERN(int) git_config_foreach_match(
	git_config *cfg,
	const char *regexp,
	int (*callback)(const git_config_entry *entry, void *payload),
	void *payload);

/**
 * Query the value of a config variable and return it mapped to
 * an integer constant.
 *
 * This is a helper method to easily map different possible values
 * to a variable to integer constants that easily identify them.
 *
 * A mapping array looks as follows:
 *
 *	git_cvar_map autocrlf_mapping[] = {
 *		{GIT_CVAR_FALSE, NULL, GIT_AUTO_CRLF_FALSE},
 *		{GIT_CVAR_TRUE, NULL, GIT_AUTO_CRLF_TRUE},
 *		{GIT_CVAR_STRING, "input", GIT_AUTO_CRLF_INPUT},
 *		{GIT_CVAR_STRING, "default", GIT_AUTO_CRLF_DEFAULT}};
 *
 * On any "false" value for the variable (e.g. "false", "FALSE", "no"), the
 * mapping will store `GIT_AUTO_CRLF_FALSE` in the `out` parameter.
 *
 * The same thing applies for any "true" value such as "true", "yes" or "1", storing
 * the `GIT_AUTO_CRLF_TRUE` variable.
 *
 * Otherwise, if the value matches the string "input" (with case insensitive comparison),
 * the given constant will be stored in `out`, and likewise for "default".
 *
 * If not a single match can be made to store in `out`, an error code will be
 * returned.
 *
 * @param out place to store the result of the mapping
 * @param cfg config file to get the variables from
 * @param name name of the config variable to lookup
 * @param maps array of `git_cvar_map` objects specifying the possible mappings
 * @param map_n number of mapping objects in `maps`
 * @return 0 on success, error code otherwise
 */
GIT_EXTERN(int) git_config_get_mapped(int *out, git_config *cfg, const char *name, git_cvar_map *maps, size_t map_n);

/**
 * Maps a string value to an integer constant
 *
 * @param out place to store the result of the parsing
 * @param maps array of `git_cvar_map` objects specifying the possible mappings
 * @param map_n number of mapping objects in `maps`
 * @param value value to parse
 */
GIT_EXTERN(int) git_config_lookup_map_value(
	int *out,
	git_cvar_map *maps,
	size_t map_n,
	const char *value);

/**
 * Parse a string value as a bool.
 *
 * Valid values for true are: 'true', 'yes', 'on', 1 or any
 *  number different from 0
 * Valid values for false are: 'false', 'no', 'off', 0
 *
 * @param out place to store the result of the parsing
 * @param value value to parse
 */
GIT_EXTERN(int) git_config_parse_bool(int *out, const char *value);

/**
 * Parse a string value as an int64.
 *
 * An optional value suffix of 'k', 'm', or 'g' will
 * cause the value to be multiplied by 1024, 1048576,
 * or 1073741824 prior to output.
 *
 * @param out place to store the result of the parsing
 * @param value value to parse
 */
GIT_EXTERN(int) git_config_parse_int64(int64_t *out, const char *value);

/**
 * Parse a string value as an int32.
 *
 * An optional value suffix of 'k', 'm', or 'g' will
 * cause the value to be multiplied by 1024, 1048576,
 * or 1073741824 prior to output.
 *
 * @param out place to store the result of the parsing
 * @param value value to parse
 */
GIT_EXTERN(int) git_config_parse_int32(int32_t *out, const char *value);


/** @} */
GIT_END_DECL
#endif
