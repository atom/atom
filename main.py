import argparse
import errno
import logging
import os
import platform
from collections import OrderedDict
from gettext import gettext

import requests
import sys
import signal
import webbrowser

from contextlib import closing
from distutils.version import StrictVersion
from functools import partial
from itertools import chain
from socks import __version__ as socks_version
from time import sleep
from websocket import __version__ as websocket_version

from streamlink import __version__ as streamlink_version
from streamlink import (Streamlink, StreamError, PluginError,
                        NoPluginError)
from streamlink.cache import Cache
from streamlink.exceptions import FatalPluginError
from streamlink.stream import StreamProcess
from streamlink.plugins.twitch import TWITCH_CLIENT_ID
from streamlink.plugin import PluginOptions
from streamlink.utils import LazyFormatter

import streamlink.logger as logger
from .argparser import build_parser
from .compat import stdout, is_win32
from streamlink.utils.encoding import maybe_encode
from .console import ConsoleOutput, ConsoleUserInputRequester
from .constants import CONFIG_FILES, PLUGINS_DIR, STREAM_SYNONYMS, DEFAULT_STREAM_METADATA
from .output import FileOutput, PlayerOutput
from .utils import NamedPipe, HTTPServer, ignored, progress, stream_to_url

ACCEPTABLE_ERRNO = (errno.EPIPE, errno.EINVAL, errno.ECONNRESET)
try:
    ACCEPTABLE_ERRNO += (errno.WSAECONNABORTED,)
except AttributeError:
    pass  # Not windows
QUIET_OPTIONS = ("json", "stream_url", "subprocess_cmdline", "quiet")

args = console = streamlink = plugin = stream_fd = output = None

log = logging.getLogger("streamlink.cli")


def check_file_output(filename, force):
    """Checks if file already exists and ask the user if it should
    be overwritten if it does."""

    log.debug("Checking file output")

    if os.path.isfile(filename) and not force:
        if sys.stdin.isatty():
            answer = console.ask("File {0} already exists! Overwrite it? [y/N] ",
                                 filename)

            if answer.lower() != "y":
                sys.exit()
        else:
            log.error("File {0} already exists, use --force to overwrite it.".format(filename))
            sys.exit()

    return FileOutput(filename)


def create_output(plugin):
    """Decides where to write the stream.

    Depending on arguments it can be one of these:
     - The stdout pipe
     - A subprocess' stdin pipe
     - A named pipe that the subprocess reads from
     - A regular file

    """

    if (args.output or args.stdout) and (args.record or args.record_and_pipe):
        console.exit("Cannot use record options with other file output options.")

    if args.output:
        if args.output == "-":
            out = FileOutput(fd=stdout)
        else:
            out = check_file_output(args.output, args.force)
    elif args.stdout:
        out = FileOutput(fd=stdout)
    elif args.record_and_pipe:
        record = check_file_output(args.record_and_pipe, args.force)
        out = FileOutput(fd=stdout, record=record)
    else:
        http = namedpipe = record = None

        if not args.player:
            console.exit("The default player (VLC) does not seem to be "
                         "installed. You must specify the path to a player "
                         "executable with --player.")

        if args.player_fifo:
            pipename = "streamlinkpipe-{0}".format(os.getpid())
            log.info("Creating pipe {0}".format(pipename))

            try:
                namedpipe = NamedPipe(pipename)
            except IOError as err:
                console.exit("Failed to create pipe: {0}", err)
        elif args.player_http:
            http = create_http_server()

        title = create_title(plugin)

        if args.record:
            record = check_file_output(args.record, args.force)

        log.info("Starting player: {0}".format(args.player))

        out = PlayerOutput(args.player, args=args.player_args,
                           quiet=not args.verbose_player,
                           kill=not args.player_no_close,
                           namedpipe=namedpipe, http=http,
                           record=record, title=title)

    return out


def create_http_server(host=None, port=0):
    """Creates a HTTP server listening on a given host and port.

    If host is empty, listen on all available interfaces, and if port is 0,
    listen on a random high port.
    """

    try:
        http = HTTPServer()
        http.bind(host=host, port=port)
    except OSError as err:
        console.exit("Failed to create HTTP server: {0}", err)

    return http


def create_title(plugin=None):
    if args.title and plugin:
        title = LazyFormatter.format(
            maybe_encode(args.title),
            title=lambda: plugin.get_title() or DEFAULT_STREAM_METADATA["title"],
            author=lambda: plugin.get_author() or DEFAULT_STREAM_METADATA["author"],
            category=lambda: plugin.get_category() or DEFAULT_STREAM_METADATA["category"],
            game=lambda: plugin.get_category() or DEFAULT_STREAM_METADATA["game"],
            url=plugin.url
        )
    else:
        title = args.url
    return title


def iter_http_requests(server, player):
    """Repeatedly accept HTTP connections on a server.

    Forever if the serving externally, or while a player is running if it is not
    empty.
    """

    while not player or player.running:
        try:
            yield server.open(timeout=2.5)
        except OSError:
            continue


def output_stream_http(plugin, initial_streams, external=False, port=0):
    """Continuously output the stream over HTTP."""
    global output

    if not external:
        if not args.player:
            console.exit("The default player (VLC) does not seem to be "
                         "installed. You must specify the path to a player "
                         "executable with --player.")

        title = create_title(plugin)
        server = create_http_server()
        player = output = PlayerOutput(args.player, args=args.player_args,
                                       filename=server.url,
                                       quiet=not args.verbose_player,
                                       title=title)

        try:
            log.info("Starting player: {0}".format(args.player))
            if player:
                player.open()
        except OSError as err:
            console.exit("Failed to start player: {0} ({1})",
                         args.player, err)
    else:
        server = create_http_server(host=None, port=port)
        player = None

        log.info("Starting server, access with one of:")
        for url in server.urls:
            log.info(" " + url)

    for req in iter_http_requests(server, player):
        user_agent = req.headers.get("User-Agent") or "unknown player"
        log.info("Got HTTP request from {0}".format(user_agent))

        stream_fd = prebuffer = None
        while not stream_fd and (not player or player.running):
            try:
                streams = initial_streams or fetch_streams(plugin)
                initial_streams = None

                for stream_name in (resolve_stream_name(streams, s) for s in args.stream):
                    if stream_name in streams:
                        stream = streams[stream_name]
                        break
                else:
                    log.info("Stream not available, will re-fetch "
                             "streams in 10 sec")
                    sleep(10)
                    continue
            except PluginError as err:
                log.error(u"Unable to fetch new streams: {0}".format(err))
                continue

            try:
                log.info("Opening stream: {0} ({1})".format(stream_name,
                                                            type(stream).shortname()))
                stream_fd, prebuffer = open_stream(stream)
            except StreamError as err:
                log.error("{0}".format(err))

        if stream_fd and prebuffer:
            log.debug("Writing stream to player")
            read_stream(stream_fd, server, prebuffer)

        server.close(True)

    player.close()
    server.close()


def output_stream_passthrough(plugin, stream):
    """Prepares a filename to be passed to the player."""
    global output

    title = create_title(plugin)
    filename = '"{0}"'.format(stream_to_url(stream))
    output = PlayerOutput(args.player, args=args.player_args,
                          filename=filename, call=True,
                          quiet=not args.verbose_player,
                          title=title)

    try:
        log.info("Starting player: {0}".format(args.player))
        output.open()
    except OSError as err:
        console.exit("Failed to start player: {0} ({1})", args.player, err)
        return False

    return True


def open_stream(stream):
    """Opens a stream and reads 8192 bytes from it.

    This is useful to check if a stream actually has data
    before opening the output.

    """
    global stream_fd

    # Attempts to open the stream
    try:
        stream_fd = stream.open()
    except StreamError as err:
        raise StreamError("Could not open stream: {0}".format(err))

    # Read 8192 bytes before proceeding to check for errors.
    # This is to avoid opening the output unnecessarily.
    try:
        log.debug("Pre-buffering 8192 bytes")
        prebuffer = stream_fd.read(8192)
    except IOError as err:
        stream_fd.close()
        raise StreamError("Failed to read data from stream: {0}".format(err))

    if not prebuffer:
        stream_fd.close()
        raise StreamError("No data returned from stream")

    return stream_fd, prebuffer


def output_stream(plugin, stream):
    """Open stream, create output and finally write the stream to output."""
    global output

    success_open = False
    for i in range(args.retry_open):
        try:
            stream_fd, prebuffer = open_stream(stream)
            success_open = True
            break
        except StreamError as err:
            log.error("Try {0}/{1}: Could not open stream {2} ({3})".format(
                i + 1, args.retry_open, stream, err))

    if not success_open:
        console.exit("Could not open stream {0}, tried {1} times, exiting", stream, args.retry_open)

    output = create_output(plugin)

    try:
        output.open()
    except (IOError, OSError) as err:
        if isinstance(output, PlayerOutput):
            console.exit("Failed to start player: {0} ({1})",
                         args.player, err)
        else:
            console.exit("Failed to open output: {0} ({1})",
                         args.output, err)

    with closing(output):
        log.debug("Writing stream to output")
        read_stream(stream_fd, output, prebuffer)

    return True


def read_stream(stream, output, prebuffer, chunk_size=8192):
    """Reads data from stream and then writes it to the output."""
    is_player = isinstance(output, PlayerOutput)
    is_http = isinstance(output, HTTPServer)
    is_fifo = is_player and output.namedpipe
    show_progress = isinstance(output, FileOutput) and output.fd is not stdout and sys.stdout.isatty()
    show_record_progress = hasattr(output, "record") and isinstance(output.record, FileOutput) and output.record.fd is not stdout and sys.stdout.isatty()

    stream_iterator = chain(
        [prebuffer],
        iter(partial(stream.read, chunk_size), b"")
    )
    if show_progress:
        stream_iterator = progress(stream_iterator,
                                   prefix=os.path.basename(args.output))
    elif show_record_progress:
        stream_iterator = progress(stream_iterator,
                                   prefix=os.path.basename(args.record))

    try:
        for data in stream_iterator:
            # We need to check if the player process still exists when
            # using named pipes on Windows since the named pipe is not
            # automatically closed by the player.
            if is_win32 and is_fifo:
                output.player.poll()

                if output.player.returncode is not None:
                    log.info("Player closed")
                    break

            try:
                output.write(data)
            except IOError as err:
                if is_player and err.errno in ACCEPTABLE_ERRNO:
                    log.info("Player closed")
                elif is_http and err.errno in ACCEPTABLE_ERRNO:
                    log.info("HTTP connection closed")
                else:
                    console.exit("Error when writing to output: {0}, exiting", err)

                break
    except IOError as err:
        console.exit("Error when reading from stream: {0}, exiting", err)
    finally:
        stream.close()
        log.info("Stream ended")


def handle_stream(plugin, streams, stream_name):
    """Decides what to do with the selected stream.

    Depending on arguments it can be one of these:
     - Output internal command-line
     - Output JSON represenation
     - Continuously output the stream over HTTP
     - Output stream data to selected output

    """

    stream_name = resolve_stream_name(streams, stream_name)
    stream = streams[stream_name]

    # Print internal command-line if this stream
    # uses a subprocess.
    if args.subprocess_cmdline:
        if isinstance(stream, StreamProcess):
            try:
                cmdline = stream.cmdline()
            except StreamError as err:
                console.exit("{0}", err)

            console.msg("{0}", cmdline)
        else:
            console.exit("The stream specified cannot be translated to a command")

    # Print JSON representation of the stream
    elif console.json:
        console.msg_json(stream)

    elif args.stream_url:
        try:
            console.msg("{0}", stream.to_url())
        except TypeError:
            console.exit("The stream specified cannot be translated to a URL")

    # Output the stream
    else:
        # Find any streams with a '_alt' suffix and attempt
        # to use these in case the main stream is not usable.
        alt_streams = list(filter(lambda k: stream_name + "_alt" in k,
                                  sorted(streams.keys())))
        file_output = args.output or args.stdout

        for stream_name in [stream_name] + alt_streams:
            stream = streams[stream_name]
            stream_type = type(stream).shortname()

            if stream_type in args.player_passthrough and not file_output:
                log.info("Opening stream: {0} ({1})".format(stream_name,
                                                            stream_type))
                success = output_stream_passthrough(plugin, stream)
            elif args.player_external_http:
                return output_stream_http(plugin, streams, external=True,
                                          port=args.player_external_http_port)
            elif args.player_continuous_http and not file_output:
                return output_stream_http(plugin, streams)
            else:
                log.info("Opening stream: {0} ({1})".format(stream_name,
                                                            stream_type))

                success = output_stream(plugin, stream)

            if success:
                break


def fetch_streams(plugin):
    """Fetches streams using correct parameters."""

    return plugin.streams(stream_types=args.stream_types,
                          sorting_excludes=args.stream_sorting_excludes)


def fetch_streams_with_retry(plugin, interval, count):
    """Attempts to fetch streams repeatedly
       until some are returned or limit hit."""

    try:
        streams = fetch_streams(plugin)
    except PluginError as err:
        log.error(u"{0}".format(err))
        streams = None

    if not streams:
        log.info("Waiting for streams, retrying every {0} "
                 "second(s)".format(interval))
    attempts = 0

    while not streams:
        sleep(interval)

        try:
            streams = fetch_streams(plugin)
        except FatalPluginError as err:
            raise
        except PluginError as err:
            log.error(u"{0}".format(err))

        if count > 0:
            attempts += 1
            if attempts >= count:
                break

    return streams


def resolve_stream_name(streams, stream_name):
    """Returns the real stream name of a synonym."""

    if stream_name in STREAM_SYNONYMS and stream_name in streams:
        for name, stream in streams.items():
            if stream is streams[stream_name] and name not in STREAM_SYNONYMS:
                return name

    return stream_name


def format_valid_streams(plugin, streams):
    """Formats a dict of streams.

    Filters out synonyms and displays them next to
    the stream they point to.

    Streams are sorted according to their quality
    (based on plugin.stream_weight).

    """

    delimiter = ", "
    validstreams = []

    for name, stream in sorted(streams.items(),
                               key=lambda stream: plugin.stream_weight(stream[0])):
        if name in STREAM_SYNONYMS:
            continue

        def synonymfilter(n):
            return stream is streams[n] and n is not name

        synonyms = list(filter(synonymfilter, streams.keys()))

        if len(synonyms) > 0:
            joined = delimiter.join(synonyms)
            name = "{0} ({1})".format(name, joined)

        validstreams.append(name)

    return delimiter.join(validstreams)


def handle_url():
    """The URL handler.

    Attempts to resolve the URL to a plugin and then attempts
    to fetch a list of available streams.

    Proceeds to handle stream if user specified a valid one,
    otherwise output list of valid streams.

    """

    try:
        plugin = streamlink.resolve_url(args.url)
        setup_plugin_options(streamlink, plugin)
        log.info("Found matching plugin {0} for URL {1}".format(
                 plugin.module, args.url))

        plugin_args = []
        for parg in plugin.arguments:
            value = plugin.get_option(parg.dest)
            if value:
                plugin_args.append((parg, value))

        if plugin_args:
            log.debug("Plugin specific arguments:")
            for parg, value in plugin_args:
                log.debug(" {0}={1} ({2})".format(parg.argument_name(plugin.module),
                                                  value if not parg.sensitive else ("*" * 8),
                                                  parg.dest))

        if args.retry_max or args.retry_streams:
            retry_streams = 1
            retry_max = 0
            if args.retry_streams:
                retry_streams = args.retry_streams
            if args.retry_max:
                retry_max = args.retry_max
            streams = fetch_streams_with_retry(plugin, retry_streams,
                                               retry_max)
        else:
            streams = fetch_streams(plugin)
    except NoPluginError:
        console.exit("No plugin can handle URL: {0}", args.url)
    except PluginError as err:
        console.exit(u"{0}", err)

    if not streams:
        console.exit("No playable streams found on this URL: {0}", args.url)

    if args.default_stream and not args.stream and not args.json:
        args.stream = args.default_stream

    if args.stream:
        validstreams = format_valid_streams(plugin, streams)
        for stream_name in args.stream:
            if stream_name in streams:
                log.info("Available streams: {0}".format(validstreams))
                handle_stream(plugin, streams, stream_name)
                return

        err = ("The specified stream(s) '{0}' could not be "
               "found".format(", ".join(args.stream)))

        if console.json:
            console.msg_json(dict(streams=streams, plugin=plugin.module,
                                  error=err))
        else:
            console.exit("{0}.\n       Available streams: {1}",
                         err, validstreams)
    else:
        if console.json:
            console.msg_json(dict(streams=streams, plugin=plugin.module))
        else:
            validstreams = format_valid_streams(plugin, streams)
            console.msg("Available streams: {0}", validstreams)


def print_plugins():
    """Outputs a list of all plugins Streamlink has loaded."""

    pluginlist = list(streamlink.get_plugins().keys())
    pluginlist_formatted = ", ".join(sorted(pluginlist))

    if console.json:
        console.msg_json(pluginlist)
    else:
        console.msg("Loaded plugins: {0}", pluginlist_formatted)


def authenticate_twitch_oauth():
    """Opens a web browser to allow the user to grant Streamlink
       access to their Twitch account."""

    client_id = TWITCH_CLIENT_ID
    redirect_uri = "https://streamlink.github.io/twitch_oauth.html"
    url = ("https://api.twitch.tv/kraken/oauth2/authorize"
           "?response_type=token"
           "&client_id={0}"
           "&redirect_uri={1}"
           "&scope=user_read+user_subscriptions"
           "&force_verify=true").format(client_id, redirect_uri)

    console.msg("Attempting to open a browser to let you authenticate "
                "Streamlink with Twitch")

    try:
        if not webbrowser.open_new_tab(url):
            raise webbrowser.Error
    except webbrowser.Error:
        console.exit("Unable to open a web browser, try accessing this URL "
                     "manually instead:\n{0}".format(url))


def load_plugins(dirs):
    """Attempts to load plugins from a list of directories."""

    dirs = [os.path.expanduser(d) for d in dirs]

    for directory in dirs:
        if os.path.isdir(directory):
            streamlink.load_plugins(directory)
        else:
            log.warning("Plugin path {0} does not exist or is not "
                        "a directory!".format(directory))


def setup_args(parser, config_files=[], ignore_unknown=False):
    """Parses arguments."""
    global args
    arglist = sys.argv[1:]

    # Load arguments from config files
    for config_file in filter(os.path.isfile, config_files):
        arglist.insert(0, "@" + config_file)

    args, unknown = parser.parse_known_args(arglist)
    if unknown and not ignore_unknown:
        msg = gettext('unrecognized arguments: %s')
        parser.error(msg % ' '.join(unknown))

    # Force lowercase to allow case-insensitive lookup
    if args.stream:
        args.stream = [stream.lower() for stream in args.stream]

    if not args.url and args.url_param:
        args.url = args.url_param


def setup_config_args(parser):
    config_files = []

    if args.url:
        with ignored(NoPluginError):
            plugin = streamlink.resolve_url(args.url)
            config_files += ["{0}.{1}".format(fn, plugin.module) for fn in CONFIG_FILES]

    if args.config:
        # We want the config specified last to get highest priority
        config_files += list(reversed(args.config))
    else:
        # Only load first available default config
        for config_file in filter(os.path.isfile, CONFIG_FILES):
            config_files.append(config_file)
            break

    if config_files:
        setup_args(parser, config_files)


def setup_console(output):
    """Console setup."""
    global console

    # All console related operations is handled via the ConsoleOutput class
    console = ConsoleOutput(output, streamlink)
    console.json = args.json

    # Handle SIGTERM just like SIGINT
    signal.signal(signal.SIGTERM, signal.default_int_handler)


def setup_http_session():
    """Sets the global HTTP settings, such as proxy and headers."""
    if args.http_proxy:
        streamlink.set_option("http-proxy", args.http_proxy)

    if args.https_proxy:
        streamlink.set_option("https-proxy", args.https_proxy)

    if args.http_cookie:
        streamlink.set_option("http-cookies", dict(args.http_cookie))

    if args.http_header:
        streamlink.set_option("http-headers", dict(args.http_header))

    if args.http_query_param:
        streamlink.set_option("http-query-params", dict(args.http_query_param))

    if args.http_ignore_env:
        streamlink.set_option("http-trust-env", False)

    if args.http_no_ssl_verify:
        streamlink.set_option("http-ssl-verify", False)

    if args.http_disable_dh:
        streamlink.set_option("http-disable-dh", True)

    if args.http_ssl_cert:
        streamlink.set_option("http-ssl-cert", args.http_ssl_cert)

    if args.http_ssl_cert_crt_key:
        streamlink.set_option("http-ssl-cert", tuple(args.http_ssl_cert_crt_key))

    if args.http_timeout:
        streamlink.set_option("http-timeout", args.http_timeout)

    if args.http_cookies:
        streamlink.set_option("http-cookies", args.http_cookies)

    if args.http_headers:
        streamlink.set_option("http-headers", args.http_headers)

    if args.http_query_params:
        streamlink.set_option("http-query-params", args.http_query_params)


def setup_plugins(extra_plugin_dir=None):
    """Loads any additional plugins."""
    if os.path.isdir(PLUGINS_DIR):
        load_plugins([PLUGINS_DIR])

    if extra_plugin_dir:
        load_plugins(extra_plugin_dir)


def setup_streamlink():
    """Creates the Streamlink session."""
    global streamlink

    streamlink = Streamlink({"user-input-requester": ConsoleUserInputRequester(console)})


def setup_options():
    """Sets Streamlink options."""
    if args.hls_live_edge:
        streamlink.set_option("hls-live-edge", args.hls_live_edge)

    if args.hls_segment_attempts:
        streamlink.set_option("hls-segment-attempts", args.hls_segment_attempts)

    if args.hls_playlist_reload_attempts:
        streamlink.set_option("hls-playlist-reload-attempts", args.hls_playlist_reload_attempts)

    if args.hls_segment_threads:
        streamlink.set_option("hls-segment-threads", args.hls_segment_threads)

    if args.hls_segment_timeout:
        streamlink.set_option("hls-segment-timeout", args.hls_segment_timeout)

    if args.hls_segment_ignore_names:
        streamlink.set_option("hls-segment-ignore-names", args.hls_segment_ignore_names)

    if args.hls_segment_key_uri:
        streamlink.set_option("hls-segment-key-uri", args.hls_segment_key_uri)

    if args.hls_timeout:
        streamlink.set_option("hls-timeout", args.hls_timeout)

    if args.hls_audio_select:
        streamlink.set_option("hls-audio-select", args.hls_audio_select)

    if args.hls_start_offset:
        streamlink.set_option("hls-start-offset", args.hls_start_offset)

    if args.hls_duration:
        streamlink.set_option("hls-duration", args.hls_duration)

    if args.hls_live_restart:
        streamlink.set_option("hls-live-restart", args.hls_live_restart)

    if args.hds_live_edge:
        streamlink.set_option("hds-live-edge", args.hds_live_edge)

    if args.hds_segment_attempts:
        streamlink.set_option("hds-segment-attempts", args.hds_segment_attempts)

    if args.hds_segment_threads:
        streamlink.set_option("hds-segment-threads", args.hds_segment_threads)

    if args.hds_segment_timeout:
        streamlink.set_option("hds-segment-timeout", args.hds_segment_timeout)

    if args.hds_timeout:
        streamlink.set_option("hds-timeout", args.hds_timeout)

    if args.http_stream_timeout:
        streamlink.set_option("http-stream-timeout", args.http_stream_timeout)

    if args.ringbuffer_size:
        streamlink.set_option("ringbuffer-size", args.ringbuffer_size)

    if args.rtmp_proxy:
        streamlink.set_option("rtmp-proxy", args.rtmp_proxy)

    if args.rtmp_rtmpdump:
        streamlink.set_option("rtmp-rtmpdump", args.rtmp_rtmpdump)

    if args.rtmp_timeout:
        streamlink.set_option("rtmp-timeout", args.rtmp_timeout)

    if args.stream_segment_attempts:
        streamlink.set_option("stream-segment-attempts", args.stream_segment_attempts)

    if args.stream_segment_threads:
        streamlink.set_option("stream-segment-threads", args.stream_segment_threads)

    if args.stream_segment_timeout:
        streamlink.set_option("stream-segment-timeout", args.stream_segment_timeout)

    if args.stream_timeout:
        streamlink.set_option("stream-timeout", args.stream_timeout)

    if args.ffmpeg_ffmpeg:
        streamlink.set_option("ffmpeg-ffmpeg", args.ffmpeg_ffmpeg)
    if args.ffmpeg_verbose:
        streamlink.set_option("ffmpeg-verbose", args.ffmpeg_verbose)
    if args.ffmpeg_verbose_path:
        streamlink.set_option("ffmpeg-verbose-path", args.ffmpeg_verbose_path)
    if args.ffmpeg_fout:
        streamlink.set_option("ffmpeg-fout", args.ffmpeg_fout)
    if args.ffmpeg_video_transcode:
        streamlink.set_option("ffmpeg-video-transcode", args.ffmpeg_video_transcode)
    if args.ffmpeg_audio_transcode:
        streamlink.set_option("ffmpeg-audio-transcode", args.ffmpeg_audio_transcode)
    if args.ffmpeg-start-at-zero:
        streamlink.set_option("ffmpeg-start-at-zero", args.ffmpeg-start-at-zero)

    streamlink.set_option("subprocess-errorlog", args.subprocess_errorlog)
    streamlink.set_option("subprocess-errorlog-path", args.subprocess_errorlog_path)
    streamlink.set_option("locale", args.locale)


def setup_plugin_args(session, parser):
    """Sets Streamlink plugin options."""

    plugin_args = parser.add_argument_group("Plugin options")
    for pname, plugin in session.plugins.items():
        defaults = {}
        for parg in plugin.arguments:
            plugin_args.add_argument(parg.argument_name(pname), **parg.options)
            defaults[parg.dest] = parg.default

        plugin.options = PluginOptions(defaults)


def setup_plugin_options(session, plugin):
    """Sets Streamlink plugin options."""
    pname = plugin.module
    required = OrderedDict({})
    for parg in plugin.arguments:
        if parg.options.get("help") != argparse.SUPPRESS:
            if parg.required:
                required[parg.name] = parg
            value = getattr(args, parg.namespace_dest(pname))
            session.set_plugin_option(pname, parg.dest, value)
            # if the value is set, check to see if any of the required arguments are not set
            if parg.required or value:
                try:
                    for rparg in plugin.arguments.requires(parg.name):
                        required[rparg.name] = rparg
                except RuntimeError:
                    log.error("{0} plugin has a configuration error and the arguments "
                                         "cannot be parsed".format(pname))
                    break
    if required:
        for req in required.values():
            if not session.get_plugin_option(pname, req.dest):
                prompt = req.prompt or "Enter {0} {1}".format(pname, req.name)
                session.set_plugin_option(pname, req.dest,
                                          console.askpass(prompt + ": ")
                                          if req.sensitive else
                                          console.ask(prompt + ": "))


def check_root():
    if hasattr(os, "getuid"):
        if os.geteuid() == 0:
            log.info("streamlink is running as root! Be careful!")


def log_current_versions():
    """Show current installed versions"""
    if logger.root.isEnabledFor(logging.DEBUG):
        # MAC OS X
        if sys.platform == "darwin":
            os_version = "macOS {0}".format(platform.mac_ver()[0])
        # Windows
        elif sys.platform.startswith("win"):
            os_version = "{0} {1}".format(platform.system(), platform.release())
        # linux / other
        else:
            os_version = platform.platform()

        log.debug("OS:         {0}".format(os_version))
        log.debug("Python:     {0}".format(platform.python_version()))
        log.debug("Streamlink: {0}".format(streamlink_version))
        log.debug("Requests({0}), Socks({1}), Websocket({2})".format(
            requests.__version__, socks_version, websocket_version))


def check_version(force=False):
    cache = Cache(filename="cli.json")
    latest_version = cache.get("latest_version")

    if force or not latest_version:
        res = requests.get("https://pypi.python.org/pypi/streamlink/json")
        data = res.json()
        latest_version = data.get("info").get("version")
        cache.set("latest_version", latest_version, (60 * 60 * 24))

    version_info_printed = cache.get("version_info_printed")
    if not force and version_info_printed:
        return

    installed_version = StrictVersion(streamlink.version)
    latest_version = StrictVersion(latest_version)

    if latest_version > installed_version:
        log.info("A new version of Streamlink ({0}) is "
                 "available!".format(latest_version))
        cache.set("version_info_printed", True, (60 * 60 * 6))
    elif force:
        log.info("Your Streamlink version ({0}) is up to date!".format(
                 installed_version))

    if force:
        sys.exit()


def setup_logging(stream=sys.stdout, level="info"):
    fmt = ("[{asctime},{msecs:0.0f}]" if level == "trace" else "") + "[{name}][{levelname}] {message}"
    logger.basicConfig(stream=stream, level=level,
                       format=fmt, style="{",
                       datefmt="%H:%M:%S")


def main():
    error_code = 0
    parser = build_parser()

    setup_args(parser, ignore_unknown=True)

    # Console output should be on stderr if we are outputting
    # a stream to stdout.
    if args.stdout or args.output == "-" or args.record_and_pipe:
        console_out = sys.stderr
    else:
        console_out = sys.stdout

    # We don't want log output when we are printing JSON or a command-line.
    silent_log = any(getattr(args, attr) for attr in QUIET_OPTIONS)
    log_level = args.loglevel if not silent_log else "none"
    setup_logging(console_out, log_level)
    setup_console(console_out)

    setup_streamlink()
    # load additional plugins
    setup_plugins(args.plugin_dirs)
    setup_plugin_args(streamlink, parser)
    # call setup args again once the plugin specific args have been added
    setup_args(parser)
    setup_config_args(parser)

    # update the logging level if changed by a plugin specific config
    log_level = args.loglevel if not silent_log else "none"
    logger.root.setLevel(log_level)

    setup_http_session()
    check_root()
    log_current_versions()

    if args.version_check or (not args.no_version_check and args.auto_version_check):
        with ignored(Exception):
            check_version(force=args.version_check)

    if args.plugins:
        print_plugins()
    elif args.can_handle_url:
        try:
            streamlink.resolve_url(args.can_handle_url)
        except NoPluginError:
            error_code = 1
        except KeyboardInterrupt:
            error_code = 130
    elif args.can_handle_url_no_redirect:
        try:
            streamlink.resolve_url_no_redirect(args.can_handle_url_no_redirect)
        except NoPluginError:
            error_code = 1
        except KeyboardInterrupt:
            error_code = 130
    elif args.url:
        try:
            setup_options()
            handle_url()
        except KeyboardInterrupt:
            # Close output
            if output:
                output.close()
            console.msg("Interrupted! Exiting...")
            error_code = 130
        finally:
            if stream_fd:
                try:
                    log.info("Closing currently open stream...")
                    stream_fd.close()
                except KeyboardInterrupt:
                    error_code = 130
    elif args.twitch_oauth_authenticate:
        authenticate_twitch_oauth()
    elif args.help:
        parser.print_help()
    else:
        usage = parser.format_usage()
        msg = (
            "{usage}\nUse -h/--help to see the available options or "
            "read the manual at https://streamlink.github.io"
        ).format(usage=usage)
        console.msg(msg)

    sys.exit(error_code)


def parser_helper():
    session = Streamlink()
    parser = build_parser()
    setup_plugin_args(session, parser)
    return parser
