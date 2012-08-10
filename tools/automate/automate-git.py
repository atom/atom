# Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
# reserved. Use of this source code is governed by a BSD-style license that
# can be found in the LICENSE file.

from optparse import OptionParser
from subprocess import Popen, PIPE, STDOUT
from tempfile import mktemp
import os
import shlex
import shutil
import sys
import urllib

# default URL values
chromium_url = 'http://git.chromium.org/chromium/src.git'
depot_tools_url = 'http://src.chromium.org/svn/trunk/tools/depot_tools'

def check_url(url):
    """ Check the URL and raise an exception if invalid. """
    if ':' in url[:7]:
        parts = url.split(':', 1)
        if (parts[0] in ["http", "https", "git"] and \
                parts[1] == urllib.quote(parts[1])):
            return url
    sys.stderr.write('Invalid URL: '+url+"\n")
    raise Exception('Invalid URL: '+url)

def get_exec_environ():
    env = os.environ
    env['PATH'] = depot_tools_dir + os.pathsep + env['PATH']
    return env

def run(args, **kwargs):
    '''Run a command and capture the output iteratively'''
    if isinstance(args, str):
        args = shlex.split(args.replace('\\', '\\\\'))
    cwd = kwargs.get("cwd", os.getcwd())
    quiet = kwargs.get("quiet", False)
    print "-> Running '%s' in %s" % (" ".join(args), os.path.relpath(cwd))
    cmd = Popen(args, cwd=cwd, stdout=PIPE, stderr=STDOUT,
                env=kwargs.get("env", get_exec_environ()),
                shell=(sys.platform == 'win32'))
    output = ''
    while True:
        out = cmd.stdout.read(1)
        if out == '' and cmd.poll() != None:
            break
        output += out
        if not quiet:
            sys.stdout.write(out)
    if cmd.wait() != 0:
        raise Exception("Command failed: \"%s\"" % " ".join(args), output)
    return output

def get_current_branch(path):
    return run("git rev-parse --abbrev-ref HEAD", cwd=path, quiet=True)

def get_chromium_compat_rev(cef_url, path, cef_rev):
    if not os.path.isdir(path):
        path = mktemp()
        run("git clone --depth 1 %s %s" % (cef_url, path), quiet = True)
    if cef_rev == "None":
        cef_rev = get_git_rev(path, get_current_branch(path))
    compat_cmd = "git cat-file -p %s:CHROMIUM_BUILD_COMPATIBILITY.txt" % cef_rev
    compat_value = run(compat_cmd, cwd = path, quiet = True)
    config = eval(compat_value, {'__builtins__': None}, None)
    if not 'chromium_revision' in config:
        raise Exception("Missing chromium_revision value")
    return str(int(config['chromium_revision']))

def get_svn_rev(path, branch):
    svn_rev = "None"
    cmd = ("git log --grep=^git-svn-id: -n 1 %s" % branch).split()
    try:
        process = Popen(cmd, cwd=path, stdout = PIPE, stderr = PIPE)
        for line in process.stdout:
            if line.find("git-svn-id") > 0:
                svn_rev = line.split("@")[1].split()[0]
                break
    except IOError, (errno, strerror):
        sys.stderr.write('Failed to read git log: ' + strerror + "\n")
        raise
    return svn_rev

def get_git_rev_for_svn_rvn(path, svn_rev):
    git_rev = "None"
    cmd = ("git log --grep=^git-svn-id:.*@%s --oneline" % svn_rev).split()
    try:
        process = Popen(cmd, cwd=path, stdout = PIPE, stderr = PIPE)
        git_rev = process.communicate()[0].split()[0]
    except IOError, (errno, strerror):
        sys.stderr.write('Failed to read git log: ' + strerror + "\n")
        raise
    return git_rev

def get_git_rev(path, branch):
    git_rev = "None"
    cmd = ("git describe --always %s" % branch).split()
    try:
        process = Popen(cmd, cwd=path, stdout = PIPE, stderr = PIPE)
        git_rev = process.communicate()[0].strip()
    except IOError, (errno, strerror):
        sys.stderr.write('Failed to read git log: ' + strerror + "\n")
        raise
    return git_rev

def get_git_origin(path):
    git_origin = "None"
    get_origin_cmd = "git remote show origin -n".split()
    try:
        process = Popen(get_origin_cmd, cwd=path, stdout = PIPE, stderr = PIPE)
        for line in process.stdout:
            if line.startswith("  Fetch URL: "):
                git_origin = line.replace("  Fetch URL: ", "").strip()
                break
    except IOError, (errno, strerror):
        sys.stderr.write('Failed to read git log: ' + strerror + "\n")
        raise
    return git_origin

def get_checkout_info(path, fetch_latest = True):
    """ Retrieves the origin URL, git HEAD revision and last SVN revision """
    url = 'None'
    origin_svn_rev = 'None'
    origin_git_rev = 'None'
    local_svn_rev = 'None'
    local_git_rev = 'None'
    if os.path.isdir(path):
        if fetch_latest:
            run("git fetch", cwd = path, quiet = True)
        url = get_git_origin(path)
        branch = get_current_branch(path)
        origin_svn_rev = get_svn_rev(path, "origin/%s" % branch)
        origin_git_rev = get_git_rev(path, "origin/%s" % branch)
        local_svn_rev = get_svn_rev(path, branch)
        local_git_rev = get_git_rev(path, branch)
    return {
        'url' : url,
        'local' : {
            'svn-revision' : local_svn_rev,
            'git-revision' : local_git_rev
            },
        'origin' : {
            'svn-revision' : origin_svn_rev,
            'git-revision' : origin_git_rev
            }
        }

# cannot be loaded as a module
if __name__ != "__main__":
    sys.stderr.write('This file cannot be loaded as a module!')
    sys.exit()

# parse command-line options
desc = """
This utility implements automation for the download, update, build and
distribution of CEF.
"""

parser = OptionParser(description=desc)
parser.add_option('--url', dest='url',
                  help='CEF source URL')
parser.add_option('--download-dir', dest='downloaddir', metavar='DIR',
                  help='download directory with no spaces [required]')
parser.add_option('--revision', dest='revision',
                  help='CEF source revision')
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

# the downloaddir and url options are required
if options.downloaddir is None:
    print "ERROR: Download directory is required"
    parser.print_help(sys.stderr)
    sys.exit()
if options.url is None:
    print "ERROR: CEF URL is required"
    parser.print_help(sys.stderr)
    sys.exit()

cef_url = check_url(options.url)
download_dir = os.path.abspath(options.downloaddir)
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
    run('svn checkout %s %s' % (depot_tools_url, depot_tools_dir),
        cwd = download_dir, quiet = True)

chromium_dir = os.path.join(download_dir, 'chromium')
if not os.path.exists(chromium_dir):
    # create the "chromium" directory
    os.makedirs(chromium_dir)

chromium_src_dir = os.path.join(chromium_dir, 'src')
cef_src_dir = os.path.join(chromium_src_dir, 'cef')
cef_tools_dir = os.path.join(cef_src_dir, 'tools')

# retrieve the current CEF URL and revision
info = get_checkout_info(cef_src_dir)
cef_rev = info['origin']['git-revision']
if not options.revision is None:
    cef_rev = str(options.revision)
current_cef_url = info['url']
current_cef_rev = info['local']['git-revision']

# retrieve the compatible Chromium revision
chromium_rev = get_chromium_compat_rev(cef_url, cef_src_dir, cef_rev)

# retrieve the current Chromium URL and revision
info = get_checkout_info(chromium_src_dir, False)
current_chromium_url = info['url']
current_chromium_rev = info['local']['svn-revision']

# test if the CEF URL changed
cef_url_changed = current_cef_url != cef_url
print "-- CEF URL: %s" % current_cef_url
if cef_url_changed:
    print "\t-> CHANGED TO: %s" % cef_url

# test if the CEF revision changed
cef_rev_changed = current_cef_rev != cef_rev
print "-- CEF Revision: %s" % current_cef_rev
if cef_url_changed:
    print "\t-> CHANGED TO: %s" % cef_rev

# test if the Chromium URL changed
chromium_url_changed = current_chromium_url != chromium_url
print "-- Chromium URL: %s" % current_chromium_url
if cef_url_changed:
    print "\t-> CHANGED TO: %s" % chromium_url

# test if the Chromium revision changed
chromium_rev_changed = current_chromium_rev != chromium_rev
print "-- Chromium Revision: %s" % current_chromium_rev
if cef_url_changed:
    print "\t-> CHANGED TO: %s" % chromium_rev

# true if anything changed
any_changed = chromium_url_changed or chromium_rev_changed or \
              cef_url_changed or cef_rev_changed
if not any_changed:
    print "*** NO CHANGE ***"

if chromium_url_changed or options.forceconfig:
    # run gclient config to create the .gclient file
    run('gclient config %s --git-deps' % chromium_url, cwd = chromium_dir)

    path = os.path.join(chromium_dir, '.gclient')
    if not os.path.exists(path):
        raise Exception('.gclient file was not created')

    # read the resulting .gclient file
    fp = open(path, 'r')
    data = fp.read()
    fp.close()

    # populate "custom_deps" section
    data = data.replace('"custom_deps" : {', '"custom_deps" : {'+\
                        "\n      "+'"src/third_party/WebKit/LayoutTests": None,'+\
                        "\n      "+'"src/chrome_frame/tools/test/reference_build/chrome": None,'+\
                        "\n      "+'"src/chrome/tools/test/reference_build/chrome_mac": None,'+\
                        "\n      "+'"src/chrome/tools/test/reference_build/chrome_win": None,'+\
                        "\n      "+'"src/chrome/tools/test/reference_build/chrome_linux": None,')

    # write the new .gclient file
    fp = open(path, 'w')
    fp.write(data)
    fp.close()

if options.forceclean:
    if os.path.exists(chromium_src_dir):
        # revert all Chromium changes and delete all unversioned files
        run('gclient revert -n', cwd = chromium_dir)

    # force update, build and distrib steps
    options.forceupdate = True
    options.forcebuild = True
    options.forcedistrib = True

if chromium_url_changed or chromium_rev_changed or options.forceupdate:
    # download/update the Chromium source cod
    fetch_rev = "HEAD"
    if os.path.isdir(chromium_src_dir):
        fetch_rev = get_git_rev_for_svn_rvn(
            chromium_src_dir, current_chromium_rev)
    run('gclient sync --jobs 8 -n --force --revision=src@%s' % fetch_rev,
        cwd = chromium_dir)
    checkout_rev = get_git_rev_for_svn_rvn(chromium_src_dir, chromium_rev)
    run('gclient sync --jobs 8 --revision=src@%s' % checkout_rev,
        cwd = chromium_dir)

if not os.path.exists(cef_src_dir) or cef_url_changed:
    if cef_url_changed and os.path.exists(cef_src_dir):
        # delete the cef directory (it will be re-downloaded)
        shutil.rmtree(cef_src_dir)
    # download the CEF source code
    run("git clone %s %s" % (cef_url, cef_src_dir))
elif cef_rev_changed or options.forceupdate:
    # update the CEF source code
    stashed = run("git stash", cwd = cef_src_dir).find(
        "No local changes to save") < 0
    ref = cef_rev
    if ref == "None":
        ref = "origin/%s" % get_current_branch(cef_src_dir)
    run("git fetch origin", cwd = cef_src_dir)
    run("git reset --hard %s" % ref, cwd = cef_src_dir)
    if stashed:
        run("git stash pop", cwd = cef_src_dir)

if any_changed or options.forceupdate:
    # create CEF projects
    path = os.path.join(cef_src_dir, 'cef_create_projects' + script_ext)
    run(path, cwd = cef_src_dir, quiet = True)

if any_changed or options.forcebuild:
    path = os.path.join(cef_tools_dir, 'build_projects' + script_ext)
    if not options.nodebugbuild:
        run(path +' Debug', cwd = cef_tools_dir)
    if not options.noreleasebuild:
        run(path +' Release', cwd = cef_tools_dir)

if any_changed or options.forcedistrib:
    if not options.nodistrib:
        # make CEF binary distribution
        path = os.path.join(cef_tools_dir, 'make_distrib' + script_ext)
        run(path, cwd = cef_tools_dir)
