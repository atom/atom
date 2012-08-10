# Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
# reserved. Use of this source code is governed by a BSD-style license that
# can be found in the LICENSE file.

from optparse import OptionParser
import os
import re
import shlex
import shutil
import subprocess
import sys
import urllib

# default URL values
cef_url = 'http://chromiumembedded.googlecode.com/svn/trunk/cef3'
depot_tools_url = 'http://src.chromium.org/svn/trunk/tools/depot_tools'

def run(command_line, working_dir, depot_tools_dir=None):
  # add depot_tools to the path
  env = os.environ
  if not depot_tools_dir is None:
    env['PATH'] = depot_tools_dir+os.pathsep+env['PATH']
  
  sys.stdout.write('-------- Running "'+command_line+'" in "'+\
                   working_dir+'"...'+"\n")
  args = shlex.split(command_line.replace('\\', '\\\\'))
  return subprocess.check_call(args, cwd=working_dir, env=env,
                               shell=(sys.platform == 'win32'))

def check_url(url):
  """ Check the URL and raise an exception if invalid. """
  if ':' in url[:7]:
    parts = url.split(':', 1)
    if (parts[0] == 'http' or parts[0] == 'https') and \
        parts[1] == urllib.quote(parts[1]):
      return url
  sys.stderr.write('Invalid URL: '+url+"\n")
  raise Exception('Invalid URL: '+url)
                               
def get_svn_info(path):
  """ Retrieves the URL and revision from svn info. """
  url = 'None'
  rev = 'None'
  if path[0:4] == 'http' or os.path.exists(path):
    try:
      stream = os.popen('svn info '+path)
      for line in stream:
        if line[0:4] == "URL:":
          url = check_url(line[5:-1])
        elif line[0:9] == "Revision:":
          rev = str(int(line[10:-1]))
    except IOError, (errno, strerror):
      sys.stderr.write('Failed to read svn info: '+strerror+"\n")
      raise
  return {'url': url, 'revision': rev}
  
# cannot be loaded as a module
if __name__ != "__main__":
  sys.stderr.write('This file cannot be loaded as a module!')
  sys.exit()

# parse command-line options
disc = """
This utility implements automation for the download, update, build and
distribution of CEF.
"""

parser = OptionParser(description=disc)
parser.add_option('--download-dir', dest='downloaddir', metavar='DIR',
                  help='download directory with no spaces [required]')
parser.add_option('--revision', dest='revision', type="int",
                  help='CEF source revision')
parser.add_option('--url', dest='url',
                  help='CEF source URL')
parser.add_option('--force-config',
                  action='store_true', dest='forceconfig', default=False,
                  help='force Chromium configuration')
parser.add_option('--force-clean',
                  action='store_true', dest='forceclean', default=False,
                  help='force revert of all Chromium changes, deletion of '+\
                       'all unversioned files including the CEF folder and '+\
                       'trigger the force-update, force-build and '+\
                       'force-distrib options')
parser.add_option('--force-update',
                  action='store_true', dest='forceupdate', default=False,
                  help='force Chromium and CEF update')
parser.add_option('--force-build',
                  action='store_true', dest='forcebuild', default=False,
                  help='force CEF debug and release builds')
parser.add_option('--force-distrib',
                  action='store_true', dest='forcedistrib', default=False,
                  help='force creation of CEF binary distribution')
parser.add_option('--no-debug-build',
                  action='store_true', dest='nodebugbuild', default=False,
                  help="don't perform the CEF debug build")
parser.add_option('--no-release-build',
                  action='store_true', dest='noreleasebuild', default=False,
                  help="don't perform the CEF release build")
parser.add_option('--no-distrib',
                  action='store_true', dest='nodistrib', default=False,
                  help="don't create the CEF binary distribution")
(options, args) = parser.parse_args()

# the downloaddir option is required
if options.downloaddir is None:
  parser.print_help(sys.stderr)
  sys.exit()

# script directory
script_dir = os.path.dirname(__file__)

if not options.url is None:
  # set the CEF URL
  cef_url = check_url(options.url)

if not options.revision is None:
  # set the CEF revision
  cef_rev = str(options.revision)
else:
  # retrieve the CEF revision from the remote repo
  info = get_svn_info(cef_url)
  cef_rev = info['revision']
  if cef_rev == 'None':
    sys.stderr.write('No SVN info for: '+cef_url+"\n")
    raise Exception('No SVN info for: '+cef_url)

# Retrieve the Chromium URL and revision from the CEF repo
compat_url = cef_url + "/CHROMIUM_BUILD_COMPATIBILITY.txt?r="+cef_rev

release_url = None
chromium_url = None
chromium_rev = None

try:
  # Read the remote URL contents
  handle = urllib.urlopen(compat_url)
  compat_value = handle.read().strip()
  handle.close()

  # Parse the contents
  config = eval(compat_value, {'__builtins__': None}, None)

  if 'release_url' in config:
    # building from a release
    release_url = check_url(config['release_url'])
  else:
    # building from chromium src
    if not 'chromium_url' in config:
      raise Exception("Missing chromium_url value")
    if not 'chromium_revision' in config:
      raise Exception("Missing chromium_revision value")

    chromium_url = check_url(config['chromium_url'])
    chromium_rev = str(int(config['chromium_revision']))
except Exception, e:
  sys.stderr.write('Failed to read URL and revision information from '+ \
                   compat_url+"\n")
  raise

download_dir = options.downloaddir
if not os.path.exists(download_dir):
  # create the download directory
  os.makedirs(download_dir)

# set the expected script extension
if sys.platform == 'win32':
  script_ext = '.bat'
else:
  script_ext = '.sh'

# check if the "depot_tools" directory exists
depot_tools_dir = os.path.join(download_dir, 'depot_tools')
if not os.path.exists(depot_tools_dir):
  # checkout depot_tools
  run('svn checkout '+depot_tools_url+' '+depot_tools_dir, download_dir)

# check if the "chromium" directory exists
chromium_dir = os.path.join(download_dir, 'chromium')
if not os.path.exists(chromium_dir):
  # create the "chromium" directory
  os.makedirs(chromium_dir)

chromium_src_dir = os.path.join(chromium_dir, 'src')
cef_src_dir = os.path.join(chromium_src_dir, 'cef')
cef_tools_dir = os.path.join(cef_src_dir, 'tools')

# retrieve the current CEF URL and revision
info = get_svn_info(cef_src_dir)
current_cef_url = info['url']
current_cef_rev = info['revision']

if release_url is None:
  # retrieve the current Chromium URL and revision
  info = get_svn_info(chromium_src_dir)
  current_chromium_url = info['url']
  current_chromium_rev = info['revision']

# test if the CEF URL changed
cef_url_changed = current_cef_url != cef_url
sys.stdout.write('CEF URL: '+current_cef_url+"\n")
if cef_url_changed:
  sys.stdout.write('  -> CHANGED TO: '+cef_url+"\n")

# test if the CEF revision changed
cef_rev_changed = current_cef_rev != cef_rev
sys.stdout.write('CEF Revision: '+current_cef_rev+"\n")
if cef_rev_changed:
  sys.stdout.write('  -> CHANGED TO: '+cef_rev+"\n")

release_url_changed = False
chromium_url_changed = False
chromium_rev_changed = False

if release_url is None:
  # test if the Chromium URL changed
  chromium_url_changed = current_chromium_url != chromium_url
  sys.stdout.write('Chromium URL: '+current_chromium_url+"\n")
  if chromium_url_changed:
    sys.stdout.write('  -> CHANGED TO: '+chromium_url+"\n")

  # test if the Chromium revision changed
  chromium_rev_changed = current_chromium_rev != chromium_rev
  sys.stdout.write('Chromium Revision: '+current_chromium_rev+"\n")
  if chromium_rev_changed:
    sys.stdout.write('  -> CHANGED TO: '+chromium_rev+"\n")
else:
  # test if the release URL changed
  current_release_url = 'None'

  path = os.path.join(chromium_dir, '.gclient')
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

  release_url_changed = current_release_url != release_url
  sys.stdout.write('Release URL: '+current_release_url+"\n")
  if release_url_changed:
    sys.stdout.write('  -> CHANGED TO: '+release_url+"\n")

# true if anything changed
any_changed = release_url_changed or chromium_url_changed or \
              chromium_rev_changed or cef_url_changed or cef_rev_changed
if not any_changed:
  sys.stdout.write("No changes.\n")
              
if release_url_changed or chromium_url_changed or options.forceconfig:
  if release_url is None:
    url = chromium_url
  else:
    url = release_url

  # run gclient config to create the .gclient file
  run('gclient config '+url, chromium_dir, depot_tools_dir)

  path = os.path.join(chromium_dir, '.gclient')
  if not os.path.exists(path):
    sys.stderr.write(".gclient file was not created\n")
    raise Exception('.gclient file was not created')

  # read the resulting .gclient file
  fp = open(path, 'r')
  data = fp.read()
  fp.close()

  custom_deps = \
      "\n      "+'"src/third_party/WebKit/LayoutTests": None,'+\
      "\n      "+'"src/chrome_frame/tools/test/reference_build/chrome": None,'+\
      "\n      "+'"src/chrome/tools/test/reference_build/chrome_mac": None,'+\
      "\n      "+'"src/chrome/tools/test/reference_build/chrome_win": None,'+\
      "\n      "+'"src/chrome/tools/test/reference_build/chrome_linux": None,'

  if not release_url is None:
    # TODO: Read the DEPS file and exclude all non-src directories.
    custom_deps += \
      "\n      "+'"chromeos": None,'+\
      "\n      "+'"depot_tools": None,'

  # populate "custom_deps" section
  data = data.replace('"custom_deps" : {', '"custom_deps" : {'+custom_deps)

  # write the new .gclient file
  fp = open(path, 'w')
  fp.write(data)
  fp.close()

if options.forceclean:
  if os.path.exists(chromium_src_dir):
    # revert all Chromium changes and delete all unversioned files
    run('gclient revert -n', chromium_dir, depot_tools_dir)

  # force update, build and distrib steps
  options.forceupdate = True
  options.forcebuild = True
  options.forcedistrib = True

if release_url is None:
  if chromium_url_changed or chromium_rev_changed or options.forceupdate:
    # download/update the Chromium source code
    run('gclient sync --revision src@'+chromium_rev+' --jobs 8 --force', \
        chromium_dir, depot_tools_dir)
elif release_url_changed or options.forceupdate:
  # download/update the release source code
  run('gclient sync --jobs 8 --force', chromium_dir, depot_tools_dir)

if not os.path.exists(cef_src_dir) or cef_url_changed:
  if cef_url_changed and os.path.exists(cef_src_dir):
    # delete the cef directory (it will be re-downloaded)
    shutil.rmtree(cef_src_dir)

  # download the CEF source code
  run('svn checkout '+cef_url+' -r '+cef_rev+' '+cef_src_dir, download_dir)
elif cef_rev_changed or options.forceupdate:
  # update the CEF source code
  run('svn update -r '+cef_rev+' '+cef_src_dir, download_dir)

if any_changed or options.forceupdate:
  # create CEF projects
  path = os.path.join(cef_src_dir, 'cef_create_projects'+script_ext)
  run(path, cef_src_dir, depot_tools_dir)

if any_changed or options.forcebuild:
  path = os.path.join(cef_tools_dir, 'build_projects'+script_ext)

  if not options.nodebugbuild:
    # make CEF Debug build
    run(path+' Debug', cef_tools_dir, depot_tools_dir)

  if not options.noreleasebuild:
    # make CEF Release build
    run(path+' Release', cef_tools_dir, depot_tools_dir)

if any_changed or options.forcedistrib:
  if not options.nodistrib:
    # make CEF binary distribution
    path = os.path.join(cef_tools_dir, 'make_distrib'+script_ext)
    run(path, cef_tools_dir, depot_tools_dir)
