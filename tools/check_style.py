# Copyright (c) 2012 The Chromium Embedded Framework Authors.
# Portions copyright (c) 2011 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import os, re, string, sys
from file_util import *
import git_util as git
import svn_util as svn

# script directory
script_dir = os.path.dirname(__file__)

# CEF root directory
cef_dir = os.path.abspath(os.path.join(script_dir, os.pardir))

# Valid extensions for files we want to lint.
DEFAULT_LINT_WHITELIST_REGEX = r"(.*\.cpp|.*\.cc|.*\.h)"
DEFAULT_LINT_BLACKLIST_REGEX = r"$^"

try:
  # depot_tools may already be in the import path.
  import cpplint
  import cpplint_chromium
except ImportError, e:
  # Search the PATH environment variable to find the depot_tools folder.
  depot_tools = None;
  paths = os.environ.get('PATH').split(os.pathsep)
  for path in paths:
    if os.path.exists(os.path.join(path, 'cpplint_chromium.py')):
      depot_tools = path
      break

  if depot_tools is None:
    print >> sys.stderr, 'Error: could not find depot_tools in PATH.'
    sys.exit(2)

  # Add depot_tools to import path.
  sys.path.append(depot_tools)
  import cpplint
  import cpplint_chromium

# The default implementation of FileInfo.RepositoryName looks for the top-most
# directory that contains a .git or .svn folder. This is a problem for CEF
# because the CEF root folder (which may have an arbitrary name) lives inside
# the Chromium src folder. Reimplement in a dumb but sane way.
def patch_RepositoryName(self):
  fullname = self.FullName()
  project_dir = os.path.dirname(fullname)
  if os.path.exists(fullname):
    root_dir = project_dir
    while os.path.basename(project_dir) != "src":
      project_dir = os.path.dirname(project_dir)
    prefix = os.path.commonprefix([root_dir, project_dir])
    components = fullname[len(prefix) + 1:].split('/')
    return string.join(["cef"] + components[1:], '/')
  return fullname

def check_style(args, white_list = None, black_list = None):
  """ Execute cpplint with the specified arguments. """

  # Apply patches.
  cpplint.FileInfo.RepositoryName = patch_RepositoryName

  # Process cpplint arguments.
  filenames = cpplint.ParseArguments(args)

  if not white_list:
    white_list = DEFAULT_LINT_WHITELIST_REGEX
  white_regex = re.compile(white_list)
  if not black_list:
    black_list = DEFAULT_LINT_BLACKLIST_REGEX
  black_regex = re.compile(black_list)

  extra_check_functions = [cpplint_chromium.CheckPointerDeclarationWhitespace]

  for filename in filenames:
    if white_regex.match(filename):
      if black_regex.match(filename):
        print "Ignoring file %s" % filename
      else:
        cpplint.ProcessFile(filename, cpplint._cpplint_state.verbose_level,
                            extra_check_functions)
    else:
      print "Skipping file %s" % filename

  print "Total errors found: %d\n" % cpplint._cpplint_state.error_count
  return 1

def get_changed_files():
  """ Retrieve the list of changed files. """
  try:
    return svn.get_changed_files(cef_dir)
  except:
    return git.get_changed_files(cef_dir)

if __name__ == "__main__":
  # Start with the default parameters.
  args = [
    # * Disable the 'build/class' test because it errors uselessly with C
    #   structure pointers and template declarations.
    # * Disable the 'runtime/references' test because CEF allows non-const
    #   arguments passed by reference.
    # * Disable the 'runtime/sizeof' test because it has a high number of
    #   false positives and adds marginal value.
    '--filter=-build/class,-runtime/references,-runtime/sizeof',
  ]

  # Add anything passed on the command-line.
  args += sys.argv[1:]

  # Pre-process the arguments before passing to the linter.
  new_args = []
  changed = []
  for arg in args:
    if arg == '--changed':
      # Add any changed files.
      changed = get_changed_files()
    elif arg[:2] == '--' or not os.path.isdir(arg):
      # Pass argument unchanged.
      new_args.append(arg)
    else:
      # Add all files in the directory.
      new_args += get_files(os.path.join(arg, '*'))

  if len(changed) > 0:
    new_args += changed

  check_style(new_args)
