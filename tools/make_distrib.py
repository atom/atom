# Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
# reserved. Use of this source code is governed by a BSD-style license that
# can be found in the LICENSE file.

from date_util import *
from file_util import *
from gclient_util import *
from optparse import OptionParser
import os
import re
import shlex
import subprocess
from svn_util import *
import sys
import zipfile

def create_archive(input_dir, zip_file):
  """ Creates a zip archive of the specified input directory. """
  zf = zipfile.ZipFile(zip_file, 'w', zipfile.ZIP_DEFLATED)
  def addDir(dir):
    for f in os.listdir(dir):
      full_path = os.path.join(dir, f)
      if os.path.isdir(full_path):
        addDir(full_path)
      else:
        zf.write(full_path, os.path.relpath(full_path, \
                 os.path.join(input_dir, os.pardir)))
  addDir(input_dir)
  zf.close()

def create_readme(src, output_dir, cef_url, cef_rev, cef_ver, chromium_url, \
                  chromium_rev, chromium_ver, date):
  """ Creates the README.TXT file. """
  data = read_file(src)
  data = data.replace('$CEF_URL$', cef_url)
  data = data.replace('$CEF_REV$', cef_rev)
  data = data.replace('$CEF_VER$', cef_ver)
  data = data.replace('$CHROMIUM_URL$', chromium_url)
  data = data.replace('$CHROMIUM_REV$', chromium_rev)
  data = data.replace('$CHROMIUM_VER$', chromium_ver)
  data = data.replace('$DATE$', date)
  write_file(os.path.join(output_dir, 'README.txt'), data)
  if not options.quiet:
    sys.stdout.write('Creating README.TXT file.\n')

def eval_file(src):
  """ Loads and evaluates the contents of the specified file. """
  return eval(read_file(src), {'__builtins__': None}, None)
    
def transfer_gypi_files(src_dir, gypi_paths, gypi_path_prefix, dst_dir, quiet):
  """ Transfer files from one location to another. """
  for path in gypi_paths:
    # skip gyp includes
    if path[:2] == '<@':
        continue
    src = os.path.join(src_dir, path)
    dst = os.path.join(dst_dir, path.replace(gypi_path_prefix, ''))
    dst_path = os.path.dirname(dst)
    make_dir(dst_path, quiet)
    copy_file(src, dst, quiet)

def normalize_headers(file, new_path = ''):
  """ Normalize headers post-processing. Remove the path component from any
      project include directives. """
  data = read_file(file)
  data = re.sub(r'''#include \"(?!include\/)[a-zA-Z0-9_\/]+\/+([a-zA-Z0-9_\.]+)\"''', \
                "// Include path modified for CEF Binary Distribution.\n#include \""+new_path+"\\1\"", data)
  write_file(file, data)

def transfer_files(cef_dir, script_dir, transfer_cfg, output_dir, quiet):
  """ Transfer files based on the specified configuration. """
  if not path_exists(transfer_cfg):
    return
  
  configs = eval_file(transfer_cfg)
  for cfg in configs:
    dst = os.path.join(output_dir, cfg['target'])
    
    # perform a copy if source is specified
    if not cfg['source'] is None:
      src = os.path.join(cef_dir, cfg['source'])
      dst_path = os.path.dirname(dst)
      make_dir(dst_path, quiet)
      copy_file(src, dst, quiet)
      
      # place a readme file in the destination directory
      readme = os.path.join(dst_path, 'README-TRANSFER.txt')
      if not path_exists(readme):
        copy_file(os.path.join(script_dir, 'distrib/README-TRANSFER.txt'), readme)
      open(readme, 'ab').write(cfg['source']+"\n")
    
    # perform any required post-processing
    if 'post-process' in cfg:
      post = cfg['post-process']
      if post == 'normalize_headers':
        new_path = ''
        if cfg.has_key('new_header_path'):
          new_path = cfg['new_header_path']
        normalize_headers(dst, new_path)

def generate_msvs_projects(version):
  """ Generate MSVS projects for the specified version. """
  sys.stdout.write('Generating '+version+' project files...')
  os.environ['GYP_MSVS_VERSION'] = version
  gyper = [ 'python', 'tools/gyp_cef', os.path.relpath(os.path.join(output_dir, 'cefclient.gyp'), cef_dir) ]
  RunAction(cef_dir, gyper);
  move_file(os.path.relpath(os.path.join(output_dir, 'cefclient.sln')), \
            os.path.relpath(os.path.join(output_dir, 'cefclient'+version+'.sln')))

def fix_msvs_projects():
  """ Fix the output directory path in all .vcproj and .vcxproj files. """
  files = []
  for file in get_files(os.path.join(output_dir, '*.vcproj')):
    files.append(file)
  for file in get_files(os.path.join(output_dir, '*.vcxproj')):
    files.append(file)
  for file in files:
    data = read_file(file)
    data = data.replace('../../..\\build\\', '')
    write_file(file, data)

def run(command_line, working_dir):
  """ Run a command. """
  sys.stdout.write('-------- Running "'+command_line+'" in "'+\
                   working_dir+'"...'+"\n")
  args = shlex.split(command_line.replace('\\', '\\\\'))
  return subprocess.check_call(args, cwd=working_dir, env=os.environ,
                               shell=(sys.platform == 'win32'))

# cannot be loaded as a module
if __name__ != "__main__":
  sys.stderr.write('This file cannot be loaded as a module!')
  sys.exit()

# parse command-line options
disc = """
This utility builds the CEF Binary Distribution.
"""

parser = OptionParser(description=disc)
parser.add_option('--output-dir', dest='outputdir', metavar='DIR',
                  help='output directory [required]')
parser.add_option('--allow-partial',
                  action='store_true', dest='allowpartial', default=False,
                  help='allow creation of partial distributions')
parser.add_option('--no-symbols',
                  action='store_true', dest='nosymbols', default=False,
                  help='do not create symbol files')
parser.add_option('-q', '--quiet',
                  action='store_true', dest='quiet', default=False,
                  help='do not output detailed status information')
(options, args) = parser.parse_args()

# the outputdir option is required
if options.outputdir is None:
  parser.print_help(sys.stdout)
  sys.exit()

# script directory
script_dir = os.path.dirname(__file__)

# CEF root directory
cef_dir = os.path.abspath(os.path.join(script_dir, os.pardir))

# src directory
src_dir = os.path.abspath(os.path.join(cef_dir, os.pardir))

# retrieve url, revision and date information
cef_info = get_svn_info(cef_dir)
cef_url = cef_info['url']
cef_rev = cef_info['revision']
chromium_info = get_svn_info(os.path.join(cef_dir, os.pardir))
chromium_url = chromium_info['url']
chromium_rev = chromium_info['revision']
date = get_date()

# Read and parse the version file (key=value pairs, one per line)
chrome = {}
lines = read_file(os.path.join(cef_dir, '../chrome/VERSION')).split("\n")
for line in lines:
  parts = line.split('=', 1)
  if len(parts) == 2:
    chrome[parts[0]] = parts[1]

cef_ver = '3.'+chrome['BUILD']+'.'+cef_rev
chromium_ver = chrome['MAJOR']+'.'+chrome['MINOR']+'.'+chrome['BUILD']+'.'+chrome['PATCH']

# Test the operating system.
platform = '';
if sys.platform == 'win32':
  platform = 'windows'
elif sys.platform == 'darwin':
  platform = 'macosx'
elif sys.platform.startswith('linux'):
  platform = 'linux'

# output directory
output_dir = os.path.abspath(os.path.join(options.outputdir, \
                                          'cef_binary_'+cef_ver+'_'+platform))
remove_dir(output_dir, options.quiet)
make_dir(output_dir, options.quiet)

if not options.nosymbols:
  # symbol directory
  symbol_dir = os.path.abspath(os.path.join(options.outputdir, \
                                            'cef_binary_'+cef_ver+'_'+platform+'_symbols'))
  remove_dir(symbol_dir, options.quiet)
  make_dir(symbol_dir, options.quiet)

# transfer the LICENSE.txt file
copy_file(os.path.join(cef_dir, 'LICENSE.txt'), output_dir, options.quiet)

# read the variables list from the autogenerated cef_paths.gypi file
cef_paths = eval_file(os.path.join(cef_dir, 'cef_paths.gypi'))
cef_paths = cef_paths['variables']

# read the variables list from the manually edited cef_paths2.gypi file
cef_paths2 = eval_file(os.path.join(cef_dir, 'cef_paths2.gypi'))
cef_paths2 = cef_paths2['variables']

# create the include directory
include_dir = os.path.join(output_dir, 'include')
make_dir(include_dir, options.quiet)

# create the cefclient directory
cefclient_dir = os.path.join(output_dir, 'cefclient')
make_dir(cefclient_dir, options.quiet)

# create the libcef_dll_wrapper directory
wrapper_dir = os.path.join(output_dir, 'libcef_dll')
make_dir(wrapper_dir, options.quiet)

# transfer common include files
transfer_gypi_files(cef_dir, cef_paths2['includes_common'], \
                    'include/', include_dir, options.quiet)
transfer_gypi_files(cef_dir, cef_paths2['includes_capi'], \
                    'include/', include_dir, options.quiet)
transfer_gypi_files(cef_dir, cef_paths2['includes_wrapper'], \
                    'include/', include_dir, options.quiet)
transfer_gypi_files(cef_dir, cef_paths['autogen_cpp_includes'], \
                    'include/', include_dir, options.quiet)
transfer_gypi_files(cef_dir, cef_paths['autogen_capi_includes'], \
                    'include/', include_dir, options.quiet)

# transfer common cefclient files
transfer_gypi_files(cef_dir, cef_paths2['cefclient_sources_common'], \
                    'tests/cefclient/', cefclient_dir, options.quiet)

# transfer common libcef_dll_wrapper files
transfer_gypi_files(cef_dir, cef_paths2['libcef_dll_wrapper_sources_common'], \
                    'libcef_dll/', wrapper_dir, options.quiet)
transfer_gypi_files(cef_dir, cef_paths['autogen_client_side'], \
                    'libcef_dll/', wrapper_dir, options.quiet)

# transfer gyp files
copy_file(os.path.join(script_dir, 'distrib/cefclient.gyp'), output_dir, options.quiet)
paths_gypi = os.path.join(cef_dir, 'cef_paths2.gypi')
data = read_file(paths_gypi)
data = data.replace('tests/cefclient/', 'cefclient/')
write_file(os.path.join(output_dir, 'cef_paths2.gypi'), data)
copy_file(os.path.join(cef_dir, 'cef_paths.gypi'), \
          os.path.join(output_dir, 'cef_paths.gypi'), options.quiet)

# transfer additional files
transfer_files(cef_dir, script_dir, os.path.join(script_dir, 'distrib/transfer.cfg'), \
               output_dir, options.quiet)

if platform == 'windows':
  # create the README.TXT file
  create_readme(os.path.join(script_dir, 'distrib/win/README.txt'), output_dir, cef_url, \
                cef_rev, cef_ver, chromium_url, chromium_rev, chromium_ver, date)

  # transfer include files
  transfer_gypi_files(cef_dir, cef_paths2['includes_win'], \
                      'include/', include_dir, options.quiet)

  # transfer cefclient files
  transfer_gypi_files(cef_dir, cef_paths2['cefclient_sources_win'], \
                      'tests/cefclient/', cefclient_dir, options.quiet)

  # transfer build/Debug files
  build_dir = os.path.join(src_dir, 'build/Debug');
  if not options.allowpartial or path_exists(build_dir):
    dst_dir = os.path.join(output_dir, 'Debug')
    make_dir(dst_dir, options.quiet)
    copy_files(os.path.join(script_dir, 'distrib/win/*.dll'), dst_dir, options.quiet)
    copy_files(os.path.join(build_dir, '*.dll'), dst_dir, options.quiet)
    copy_file(os.path.join(build_dir, 'cefclient.exe'), dst_dir, options.quiet)
    copy_file(os.path.join(build_dir, 'cef.pak'), dst_dir, options.quiet)
    copy_dir(os.path.join(build_dir, 'locales'), os.path.join(dst_dir, 'locales'), \
             options.quiet)
  
    # transfer lib/Debug files
    dst_dir = os.path.join(output_dir, 'lib/Debug')
    make_dir(dst_dir, options.quiet)
    copy_file(os.path.join(build_dir, 'lib/libcef.lib'), dst_dir, options.quiet)
  else:
    sys.stderr.write("No Debug build files.\n")

  # transfer build/Release files
  build_dir = os.path.join(src_dir, 'build/Release');
  if not options.allowpartial or path_exists(build_dir):
    dst_dir = os.path.join(output_dir, 'Release')
    make_dir(dst_dir, options.quiet)
    copy_files(os.path.join(script_dir, 'distrib/win/*.dll'), dst_dir, options.quiet)
    copy_files(os.path.join(build_dir, '*.dll'), dst_dir, options.quiet)
    copy_file(os.path.join(build_dir, 'cefclient.exe'), dst_dir, options.quiet)
    copy_file(os.path.join(build_dir, 'cef.pak'), dst_dir, options.quiet)
    copy_dir(os.path.join(build_dir, 'locales'), os.path.join(dst_dir, 'locales'), \
             options.quiet)

    # transfer lib/Release files
    dst_dir = os.path.join(output_dir, 'lib/Release')
    make_dir(dst_dir, options.quiet)
    copy_file(os.path.join(build_dir, 'lib/libcef.lib'), dst_dir, options.quiet)

    if not options.nosymbols:
      # transfer symbols
      copy_file(os.path.join(build_dir, 'libcef.pdb'), symbol_dir, options.quiet)
  else:
    sys.stderr.write("No Release build files.\n")

  # generate doc files
  os.popen('make_cppdocs.bat '+cef_rev)

  # transfer docs files
  dst_dir = os.path.join(output_dir, 'docs')
  src_dir = os.path.join(cef_dir, 'docs')
  if path_exists(src_dir):
    copy_dir(src_dir, dst_dir, options.quiet)

  # transfer additional files, if any
  transfer_files(cef_dir, script_dir, os.path.join(script_dir, 'distrib/win/transfer.cfg'), \
                 output_dir, options.quiet)

  # generate the project files
  generate_msvs_projects('2005');
  generate_msvs_projects('2008');
  generate_msvs_projects('2010');
  fix_msvs_projects();

elif platform == 'macosx':
  # create the README.TXT file
  create_readme(os.path.join(script_dir, 'distrib/mac/README.txt'), output_dir, cef_url, \
                cef_rev, cef_ver, chromium_url, chromium_rev, chromium_ver, date)
  
  # transfer include files
  transfer_gypi_files(cef_dir, cef_paths2['includes_mac'], \
                      'include/', include_dir, options.quiet)

  # transfer cefclient files
  transfer_gypi_files(cef_dir, cef_paths2['cefclient_sources_mac'], \
                      'tests/cefclient/', cefclient_dir, options.quiet)
  transfer_gypi_files(cef_dir, cef_paths2['cefclient_sources_mac_helper'], \
                      'tests/cefclient/', cefclient_dir, options.quiet)

  # transfer cefclient/mac files
  copy_dir(os.path.join(cef_dir, 'tests/cefclient/mac/'), os.path.join(output_dir, 'cefclient/mac/'), \
           options.quiet)

  # transfer xcodebuild/Debug files
  build_dir = os.path.join(src_dir, 'xcodebuild/Debug')
  if not options.allowpartial or path_exists(build_dir):
    dst_dir = os.path.join(output_dir, 'Debug')
    make_dir(dst_dir, options.quiet)
    copy_file(os.path.join(build_dir, 'ffmpegsumo.so'), dst_dir, options.quiet)
    copy_file(os.path.join(build_dir, 'libcef.dylib'), dst_dir, options.quiet)
  else:
    build_dir = None
  
  # transfer xcodebuild/Release files
  build_dir = os.path.join(src_dir, 'xcodebuild/Release')
  if not options.allowpartial or path_exists(build_dir):
    dst_dir = os.path.join(output_dir, 'Release')
    make_dir(dst_dir, options.quiet)
    copy_file(os.path.join(build_dir, 'ffmpegsumo.so'), dst_dir, options.quiet)
    copy_file(os.path.join(build_dir, 'libcef.dylib'), dst_dir, options.quiet)

    if not options.nosymbols:
      # create the real dSYM file from the "fake" dSYM file
      sys.stdout.write("Creating the real dSYM file...\n")
      src_path = os.path.join(build_dir, 'libcef.dylib.dSYM/Contents/Resources/DWARF/libcef.dylib')
      dst_path = os.path.join(symbol_dir, 'libcef.dylib.dSYM')
      run('dsymutil '+src_path+' -o '+dst_path, cef_dir)
  else:
    build_dir = None

  if not build_dir is None:
    # transfer resource files
    dst_dir = os.path.join(output_dir, 'Resources')
    make_dir(dst_dir, options.quiet)
    copy_files(os.path.join(build_dir, 'cefclient.app/Contents/Frameworks/Chromium Embedded Framework.framework/Resources/*.*'), \
               dst_dir, options.quiet)
  
  # transfer additional files, if any
  transfer_files(cef_dir, script_dir, os.path.join(script_dir, 'distrib/mac/transfer.cfg'), \
                output_dir, options.quiet)

  # Generate Xcode project files
  sys.stdout.write('Generating Xcode project files...')
  gyper = [ 'python', 'tools/gyp_cef', os.path.relpath(os.path.join(output_dir, 'cefclient.gyp'), cef_dir) ]
  RunAction(cef_dir, gyper);

  # Post-process the Xcode project to fix file paths
  src_file = os.path.join(output_dir, 'cefclient.xcodeproj/project.pbxproj')
  data = read_file(src_file)
  data = data.replace('../../../build/mac/', 'tools/')
  data = data.replace('../../../build', 'build')
  data = data.replace('../../../xcodebuild', 'xcodebuild')
  write_file(src_file, data)

elif platform == 'linux':
  # create the README.TXT file
  create_readme(os.path.join(script_dir, 'distrib/linux/README.txt'), output_dir, cef_url, \
                cef_rev, cef_ver, chromium_url, chromium_rev, chromium_ver, date)

  # transfer out/Debug files
  build_dir = os.path.join(src_dir, 'out/Debug');
  if not options.allowpartial or path_exists(build_dir):
    dst_dir = os.path.join(output_dir, 'Debug')
    make_dir(dst_dir, options.quiet)
    copy_dir(os.path.join(build_dir, 'lib.target'), os.path.join(dst_dir, 'lib.target'), options.quiet)
    copy_file(os.path.join(build_dir, 'cefclient'), dst_dir, options.quiet)
    copy_file(os.path.join(build_dir, 'cef.pak'), dst_dir, options.quiet)
    copy_dir(os.path.join(build_dir, 'locales'), os.path.join(dst_dir, 'locales'), options.quiet)
  else:
    sys.stderr.write("No Debug build files.\n")

  # transfer out/Release files
  build_dir = os.path.join(src_dir, 'out/Release');
  if not options.allowpartial or path_exists(build_dir):
    dst_dir = os.path.join(output_dir, 'Release')
    make_dir(dst_dir, options.quiet)
    copy_dir(os.path.join(build_dir, 'lib.target'), os.path.join(dst_dir, 'lib.target'), options.quiet)
    copy_file(os.path.join(build_dir, 'cefclient'), dst_dir, options.quiet)
    copy_file(os.path.join(build_dir, 'cef.pak'), dst_dir, options.quiet)
    copy_dir(os.path.join(build_dir, 'locales'), os.path.join(dst_dir, 'locales'), options.quiet)
  else:
    sys.stderr.write("No Release build files.\n")

  # transfer include files
  transfer_gypi_files(cef_dir, cef_paths2['includes_linux'], \
                      'include/', include_dir, options.quiet)

  # transfer cefclient files
  transfer_gypi_files(cef_dir, cef_paths2['cefclient_sources_linux'], \
                      'tests/cefclient/', cefclient_dir, options.quiet)

  # transfer additional files, if any
  transfer_files(cef_dir, script_dir, os.path.join(script_dir, 'distrib/linux/transfer.cfg'), \
                output_dir, options.quiet)

# Create an archive of the output directory
zip_file = os.path.split(output_dir)[1] + '.zip'
if not options.quiet:
  sys.stdout.write('Creating '+zip_file+"...\n")
create_archive(output_dir, os.path.join(output_dir, os.pardir, zip_file))

if not options.nosymbols:
  # Create an archive of the symbol directory
  zip_file = os.path.split(symbol_dir)[1] + '.zip'
  if not options.quiet:
    sys.stdout.write('Creating '+zip_file+"...\n")
  create_archive(symbol_dir, os.path.join(symbol_dir, os.pardir, zip_file))
