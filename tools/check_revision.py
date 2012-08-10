# Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
# reserved. Use of this source code is governed by a BSD-style license that
# can be found in the LICENSE file.

from file_util import *
from optparse import OptionParser
from svn_util import *
import sys

# cannot be loaded as a module
if __name__ != "__main__":
    sys.stderr.write('This file cannot be loaded as a module!')
    sys.exit()


# parse command-line options
disc = """
This utility checks that the correct Chromium revision is being used.
"""

parser = OptionParser(description=disc)
parser.add_option('-q', '--quiet',
                  action='store_true', dest='quiet', default=False,
                  help='do not output detailed status information')
(options, args) = parser.parse_args()

# The CEF root directory is the parent directory of _this_ script.
cef_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir))

# Retrieve the CEF SVN info.
cef_info = get_svn_info(cef_dir)
if not options.quiet:
  sys.stdout.write('Using CEF revision '+cef_info['revision']+' @ '+\
      cef_info['url']+"\n")

# Retrieve the Chromium SVN info.
src_dir = os.path.join(cef_dir, os.pardir)
chromium_info = get_svn_info(src_dir)
if not options.quiet:
  sys.stdout.write('Using Chromium revision '+chromium_info['revision']+' @ '+\
      chromium_info['url']+"\n")

# Parse the compatibility file contents.
compat_file = os.path.join(cef_dir, 'CHROMIUM_BUILD_COMPATIBILITY.txt')
config = eval(read_file(compat_file), {'__builtins__': None}, None)

error = False

if 'release_url' in config:
  current_release_url = None
  path = os.path.join(os.path.join(src_dir, os.pardir), '.gclient')
  if os.path.exists(path):
    # read the .gclient file
    fp = open(path, 'r')
    data = fp.read()
    fp.close()

    # Parse the contents
    config_dict = {}
    try:
      exec(data, config_dict)
      current_release_url = config_dict['solutions'][0]['url']
    except Exception, e:
      sys.stderr.write('Failed to parse existing .glient file.\n')
      raise

  if not options.quiet:
    sys.stdout.write('Using Chromium release '+current_release_url+"\n")

  if current_release_url != config['release_url']:
    error = True
    sys.stderr.write("\nWARNING: Incorrect Chromium release URL; found "+\
        current_release_url+', expected '+config['release_url']+"\n")
else:
  if chromium_info['url'] != config['chromium_url']:
    error = True
    sys.stderr.write("\nWARNING: Incorrect Chromium URL; found "+\
        chromium_info['url']+', expected '+config['chromium_url']+"\n")

  if chromium_info['revision'] != config['chromium_revision']:
    error = True
    sys.stderr.write("\nWARNING: Incorrect Chromium revision; found "+\
        chromium_info['revision']+', expected '+config['chromium_revision']+"\n")

if error:
  sys.stderr.write("\nPlease see CHROMIUM_BUILD_COMPATIBILITY.txt for "\
      "instructions.\n")
