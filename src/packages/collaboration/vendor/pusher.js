/*!
 * Pusher JavaScript Library v2.1.1
 * http://pusherapp.com/
 *
 * Copyright 2013, Pusher
 * Released under the MIT licence.
 */

;(function() {
  function Pusher(app_key, options) {
    options = options || {};

    var self = this;

    this.key = app_key;
    this.config = Pusher.Util.extend(
      Pusher.getGlobalConfig(),
      options.cluster ? Pusher.getClusterConfig(options.cluster) : {},
      options
    );

    this.channels = new Pusher.Channels();
    this.global_emitter = new Pusher.EventsDispatcher();
    this.sessionID = Math.floor(Math.random() * 1000000000);

    checkAppKey(this.key);

    var getStrategy = function(options) {
      return Pusher.StrategyBuilder.build(
        Pusher.getDefaultStrategy(self.config),
        Pusher.Util.extend({}, self.config, options)
      );
    };
    var getTimeline = function() {
      return new Pusher.Timeline(self.key, self.sessionID, {
        features: Pusher.Util.getClientFeatures(),
        params: self.config.timelineParams || {},
        limit: 50,
        level: Pusher.Timeline.INFO,
        version: Pusher.VERSION
      });
    };
    var getTimelineSender = function(timeline, options) {
      if (self.config.disableStats) {
        return null;
      }
      return new Pusher.TimelineSender(timeline, {
        encrypted: self.isEncrypted() || !!options.encrypted,
        host: self.config.statsHost,
        path: "/timeline"
      });
    };

    this.connection = new Pusher.ConnectionManager(
      this.key,
      Pusher.Util.extend(
        { getStrategy: getStrategy,
          getTimeline: getTimeline,
          getTimelineSender: getTimelineSender,
          activityTimeout: this.config.activity_timeout,
          pongTimeout: this.config.pong_timeout,
          unavailableTimeout: this.config.unavailable_timeout
        },
        this.config,
        { encrypted: this.isEncrypted() }
      )
    );

    this.connection.bind('connected', function() {
      self.subscribeAll();
    });
    this.connection.bind('message', function(params) {
      var internal = (params.event.indexOf('pusher_internal:') === 0);
      if (params.channel) {
        var channel = self.channel(params.channel);
        if (channel) {
          channel.handleEvent(params.event, params.data);
        }
      }
      // Emit globaly [deprecated]
      if (!internal) self.global_emitter.emit(params.event, params.data);
    });
    this.connection.bind('disconnected', function() {
      self.channels.disconnect();
    });
    this.connection.bind('error', function(err) {
      Pusher.warn('Error', err);
    });

    Pusher.instances.push(this);

    if (Pusher.isReady) self.connect();
  }
  var prototype = Pusher.prototype;

  Pusher.instances = [];
  Pusher.isReady = false;

  // To receive log output provide a Pusher.log function, for example
  // Pusher.log = function(m){console.log(m)}
  Pusher.debug = function() {
    if (!Pusher.log) {
      return;
    }
    Pusher.log(Pusher.Util.stringify.apply(this, arguments));
  };

  Pusher.warn = function() {
    var message = Pusher.Util.stringify.apply(this, arguments);
    if (window.console) {
      if (window.console.warn) {
        window.console.warn(message);
      } else if (window.console.log) {
        window.console.log(message);
      }
    }
    if (Pusher.log) {
      Pusher.log(message);
    }
  };

  Pusher.ready = function() {
    Pusher.isReady = true;
    for (var i = 0, l = Pusher.instances.length; i < l; i++) {
      Pusher.instances[i].connect();
    }
  };

  prototype.channel = function(name) {
    return this.channels.find(name);
  };

  prototype.connect = function() {
    this.connection.connect();
  };

  prototype.disconnect = function() {
    this.connection.disconnect();
  };

  prototype.bind = function(event_name, callback) {
    this.global_emitter.bind(event_name, callback);
    return this;
  };

  prototype.bind_all = function(callback) {
    this.global_emitter.bind_all(callback);
    return this;
  };

  prototype.subscribeAll = function() {
    var channelName;
    for (channelName in this.channels.channels) {
      if (this.channels.channels.hasOwnProperty(channelName)) {
        this.subscribe(channelName);
      }
    }
  };

  prototype.subscribe = function(channel_name) {
    var self = this;
    var channel = this.channels.add(channel_name, this);

    if (this.connection.state === 'connected') {
      channel.authorize(this.connection.socket_id, function(err, data) {
        if (err) {
          channel.handleEvent('pusher:subscription_error', data);
        } else {
          self.send_event('pusher:subscribe', {
            channel: channel_name,
            auth: data.auth,
            channel_data: data.channel_data
          });
        }
      });
    }
    return channel;
  };

  prototype.unsubscribe = function(channel_name) {
    this.channels.remove(channel_name);
    if (this.connection.state === 'connected') {
      this.send_event('pusher:unsubscribe', {
        channel: channel_name
      });
    }
  };

  prototype.send_event = function(event_name, data, channel) {
    return this.connection.send_event(event_name, data, channel);
  };

  prototype.isEncrypted = function() {
    if (Pusher.Util.getDocumentLocation().protocol === "https:") {
      return true;
    } else {
      return !!this.config.encrypted;
    }
  };

  function checkAppKey(key) {
    if (key === null || key === undefined) {
      Pusher.warn(
        'Warning', 'You must pass your app key when you instantiate Pusher.'
      );
    }
  }

  this.Pusher = Pusher;
}).call(this);

;(function() {
  Pusher = this.Pusher;
  Pusher.Util = {
    now: function() {
      if (Date.now) {
        return Date.now();
      } else {
        return new Date().valueOf();
      }
    },

    /** Merges multiple objects into the target argument.
     *
     * For properties that are plain Objects, performs a deep-merge. For the
     * rest it just copies the value of the property.
     *
     * To extend prototypes use it as following:
     *   Pusher.Util.extend(Target.prototype, Base.prototype)
     *
     * You can also use it to merge objects without altering them:
     *   Pusher.Util.extend({}, object1, object2)
     *
     * @param  {Object} target
     * @return {Object} the target argument
     */
    extend: function(target) {
      for (var i = 1; i < arguments.length; i++) {
        var extensions = arguments[i];
        for (var property in extensions) {
          if (extensions[property] && extensions[property].constructor &&
              extensions[property].constructor === Object) {
            target[property] = Pusher.Util.extend(
              target[property] || {}, extensions[property]
            );
          } else {
            target[property] = extensions[property];
          }
        }
      }
      return target;
    },

    stringify: function() {
      var m = ["Pusher"];
      for (var i = 0; i < arguments.length; i++) {
        if (typeof arguments[i] === "string") {
          m.push(arguments[i]);
        } else {
          if (window.JSON === undefined) {
            m.push(arguments[i].toString());
          } else {
            m.push(JSON.stringify(arguments[i]));
          }
        }
      }
      return m.join(" : ");
    },

    arrayIndexOf: function(array, item) { // MSIE doesn't have array.indexOf
      var nativeIndexOf = Array.prototype.indexOf;
      if (array === null) {
        return -1;
      }
      if (nativeIndexOf && array.indexOf === nativeIndexOf) {
        return array.indexOf(item);
      }
      for (var i = 0, l = array.length; i < l; i++) {
        if (array[i] === item) {
          return i;
        }
      }
      return -1;
    },

    keys: function(object) {
      var result = [];
      for (var key in object) {
        if (Object.prototype.hasOwnProperty.call(object, key)) {
          result.push(key);
        }
      }
      return result;
    },

    /** Applies a function f to all elements of an array.
     *
     * Function f gets 3 arguments passed:
     * - element from the array
     * - index of the element
     * - reference to the array
     *
     * @param {Array} array
     * @param {Function} f
     */
    apply: function(array, f) {
      for (var i = 0; i < array.length; i++) {
        f(array[i], i, array);
      }
    },

    /** Applies a function f to all properties of an object.
     *
     * Function f gets 3 arguments passed:
     * - element from the object
     * - key of the element
     * - reference to the object
     *
     * @param {Object} object
     * @param {Function} f
     */
    objectApply: function(object, f) {
      for (var key in object) {
        if (Object.prototype.hasOwnProperty.call(object, key)) {
          f(object[key], key, object);
        }
      }
    },

    /** Maps all elements of the array and returns the result.
     *
     * Function f gets 4 arguments passed:
     * - element from the array
     * - index of the element
     * - reference to the source array
     * - reference to the destination array
     *
     * @param {Array} array
     * @param {Function} f
     */
    map: function(array, f) {
      var result = [];
      for (var i = 0; i < array.length; i++) {
        result.push(f(array[i], i, array, result));
      }
      return result;
    },

    /** Maps all elements of the object and returns the result.
     *
     * Function f gets 4 arguments passed:
     * - element from the object
     * - key of the element
     * - reference to the source object
     * - reference to the destination object
     *
     * @param {Object} object
     * @param {Function} f
     */
    mapObject: function(object, f) {
      var result = {};
      for (var key in object) {
        if (Object.prototype.hasOwnProperty.call(object, key)) {
          result[key] = f(object[key]);
        }
      }
      return result;
    },

    /** Filters elements of the array using a test function.
     *
     * Function test gets 4 arguments passed:
     * - element from the array
     * - index of the element
     * - reference to the source array
     * - reference to the destination array
     *
     * @param {Array} array
     * @param {Function} f
     */
    filter: function(array, test) {
      test = test || function(value) { return !!value; };

      var result = [];
      for (var i = 0; i < array.length; i++) {
        if (test(array[i], i, array, result)) {
          result.push(array[i]);
        }
      }
      return result;
    },

    /** Filters properties of the object using a test function.
     *
     * Function test gets 4 arguments passed:
     * - element from the object
     * - key of the element
     * - reference to the source object
     * - reference to the destination object
     *
     * @param {Object} object
     * @param {Function} f
     */
    filterObject: function(object, test) {
      test = test || function(value) { return !!value; };

      var result = {};
      for (var key in object) {
        if (Object.prototype.hasOwnProperty.call(object, key)) {
          if (test(object[key], key, object, result)) {
            result[key] = object[key];
          }
        }
      }
      return result;
    },

    /** Flattens an object into a two-dimensional array.
     *
     * @param  {Object} object
     * @return {Array} resulting array of [key, value] pairs
     */
    flatten: function(object) {
      var result = [];
      for (var key in object) {
        if (Object.prototype.hasOwnProperty.call(object, key)) {
          result.push([key, object[key]]);
        }
      }
      return result;
    },

    /** Checks whether any element of the array passes the test.
     *
     * Function test gets 3 arguments passed:
     * - element from the array
     * - index of the element
     * - reference to the source array
     *
     * @param {Array} array
     * @param {Function} f
     */
    any: function(array, test) {
      for (var i = 0; i < array.length; i++) {
        if (test(array[i], i, array)) {
          return true;
        }
      }
      return false;
    },

    /** Checks whether all elements of the array pass the test.
     *
     * Function test gets 3 arguments passed:
     * - element from the array
     * - index of the element
     * - reference to the source array
     *
     * @param {Array} array
     * @param {Function} f
     */
    all: function(array, test) {
      for (var i = 0; i < array.length; i++) {
        if (!test(array[i], i, array)) {
          return false;
        }
      }
      return true;
    },

    /** Builds a function that will proxy a method call to its first argument.
     *
     * Allows partial application of arguments, so additional arguments are
     * prepended to the argument list.
     *
     * @param  {String} name method name
     * @return {Function} proxy function
     */
    method: function(name) {
      var boundArguments = Array.prototype.slice.call(arguments, 1);
      return function(object) {
        return object[name].apply(object, boundArguments.concat(arguments));
      };
    },

    getDocument: function() {
      return document;
    },

    getDocumentLocation: function() {
      return Pusher.Util.getDocument().location;
    },

    getLocalStorage: function() {
      try {
        return window.localStorage;
      } catch (e) {
        return undefined;
      }
    },

    getClientFeatures: function() {
      return Pusher.Util.keys(
        Pusher.Util.filterObject(
          { "ws": Pusher.WSTransport, "flash": Pusher.FlashTransport },
          function (t) { return t.isSupported(); }
        )
      );
    }
  };
}).call(this);

;(function() {
  Pusher.VERSION = '2.1.1';
  Pusher.PROTOCOL = 6;

  // DEPRECATED: WS connection parameters
  Pusher.host = 'ws.pusherapp.com';
  Pusher.ws_port = 80;
  Pusher.wss_port = 443;
  // DEPRECATED: SockJS fallback parameters
  Pusher.sockjs_host = 'sockjs.pusher.com';
  Pusher.sockjs_http_port = 80;
  Pusher.sockjs_https_port = 443;
  Pusher.sockjs_path = "/pusher";
  // DEPRECATED: Stats
  Pusher.stats_host = 'stats.pusher.com';
  // DEPRECATED: Other settings
  Pusher.channel_auth_endpoint = '/pusher/auth';
  Pusher.channel_auth_transport = 'ajax';
  Pusher.activity_timeout = 120000;
  Pusher.pong_timeout = 30000;
  Pusher.unavailable_timeout = 10000;
  // CDN configuration
  Pusher.cdn_http = 'http://js.pusher.com/';
  Pusher.cdn_https = 'https://d3dy5gmtp8yhk7.cloudfront.net/';
  Pusher.dependency_suffix = '';

  Pusher.getDefaultStrategy = function(config) {
    return [
      [":def", "ws_options", {
        hostUnencrypted: config.wsHost + ":" + config.wsPort,
        hostEncrypted: config.wsHost + ":" + config.wssPort
      }],
      [":def", "sockjs_options", {
        hostUnencrypted: config.httpHost + ":" + config.httpPort,
        hostEncrypted: config.httpHost + ":" + config.httpsPort
      }],
      [":def", "timeouts", {
        loop: true,
        timeout: 15000,
        timeoutLimit: 60000
      }],

      [":def", "ws_manager", [":transport_manager", {
        lives: 2,
        minPingDelay: 10000,
        maxPingDelay: config.activity_timeout
      }]],

      [":def_transport", "ws", "ws", 3, ":ws_options", ":ws_manager"],
      [":def_transport", "flash", "flash", 2, ":ws_options", ":ws_manager"],
      [":def_transport", "sockjs", "sockjs", 1, ":sockjs_options"],
      [":def", "ws_loop", [":sequential", ":timeouts", ":ws"]],
      [":def", "flash_loop", [":sequential", ":timeouts", ":flash"]],
      [":def", "sockjs_loop", [":sequential", ":timeouts", ":sockjs"]],

      [":def", "strategy",
        [":cached", 1800000,
          [":first_connected",
            [":if", [":is_supported", ":ws"], [
                ":best_connected_ever", ":ws_loop", [":delayed", 2000, [":sockjs_loop"]]
              ], [":if", [":is_supported", ":flash"], [
                ":best_connected_ever", ":flash_loop", [":delayed", 2000, [":sockjs_loop"]]
              ], [
                ":sockjs_loop"
              ]
            ]]
          ]
        ]
      ]
    ];
  };
}).call(this);

;(function() {
  Pusher.getGlobalConfig = function() {
    return {
      wsHost: Pusher.host,
      wsPort: Pusher.ws_port,
      wssPort: Pusher.wss_port,
      httpHost: Pusher.sockjs_host,
      httpPort: Pusher.sockjs_http_port,
      httpsPort: Pusher.sockjs_https_port,
      httpPath: Pusher.sockjs_path,
      statsHost: Pusher.stats_host,
      authEndpoint: Pusher.channel_auth_endpoint,
      authTransport: Pusher.channel_auth_transport,
      // TODO make this consistent with other options in next major version
      activity_timeout: Pusher.activity_timeout,
      pong_timeout: Pusher.pong_timeout,
      unavailable_timeout: Pusher.unavailable_timeout
    };
  };

  Pusher.getClusterConfig = function(clusterName) {
    return {
      wsHost: "ws-" + clusterName + ".pusher.com",
      httpHost: "sockjs-" + clusterName + ".pusher.com"
    };
  };
}).call(this);

;(function() {
  function buildExceptionClass(name) {
    var klass = function(message) {
      Error.call(this, message);
      this.name = name;
    };
    Pusher.Util.extend(klass.prototype, Error.prototype);

    return klass;
  }

  /** Error classes used throughout pusher-js library. */
  Pusher.Errors = {
    UnsupportedTransport: buildExceptionClass("UnsupportedTransport"),
    UnsupportedStrategy: buildExceptionClass("UnsupportedStrategy"),
    TransportPriorityTooLow: buildExceptionClass("TransportPriorityTooLow"),
    TransportClosed: buildExceptionClass("TransportClosed")
  };
}).call(this);

;(function() {
  /** Manages callback bindings and event emitting.
   *
   * @param Function failThrough called when no listeners are bound to an event
   */
  function EventsDispatcher(failThrough) {
    this.callbacks = new CallbackRegistry();
    this.global_callbacks = [];
    this.failThrough = failThrough;
  }
  var prototype = EventsDispatcher.prototype;

  prototype.bind = function(eventName, callback) {
    this.callbacks.add(eventName, callback);
    return this;
  };

  prototype.bind_all = function(callback) {
    this.global_callbacks.push(callback);
    return this;
  };

  prototype.unbind = function(eventName, callback) {
    this.callbacks.remove(eventName, callback);
    return this;
  };

  prototype.emit = function(eventName, data) {
    var i;

    for (i = 0; i < this.global_callbacks.length; i++) {
      this.global_callbacks[i](eventName, data);
    }

    var callbacks = this.callbacks.get(eventName);
    if (callbacks && callbacks.length > 0) {
      for (i = 0; i < callbacks.length; i++) {
        callbacks[i](data);
      }
    } else if (this.failThrough) {
      this.failThrough(eventName, data);
    }

    return this;
  };

  /** Callback registry helper. */

  function CallbackRegistry() {
    this._callbacks = {};
  }

  CallbackRegistry.prototype.get = function(eventName) {
    return this._callbacks[this._prefix(eventName)];
  };

  CallbackRegistry.prototype.add = function(eventName, callback) {
    var prefixedEventName = this._prefix(eventName);
    this._callbacks[prefixedEventName] = this._callbacks[prefixedEventName] || [];
    this._callbacks[prefixedEventName].push(callback);
  };

  CallbackRegistry.prototype.remove = function(eventName, callback) {
    if(this.get(eventName)) {
      var index = Pusher.Util.arrayIndexOf(this.get(eventName), callback);
      if (index !== -1){
        var callbacksCopy = this._callbacks[this._prefix(eventName)].slice(0);
        callbacksCopy.splice(index, 1);
        this._callbacks[this._prefix(eventName)] = callbacksCopy;
      }
    }
  };

  CallbackRegistry.prototype._prefix = function(eventName) {
    return "_" + eventName;
  };

  Pusher.EventsDispatcher = EventsDispatcher;
}).call(this);

;(function() {
  /** Handles loading dependency files.
   *
   * Options:
   * - cdn_http - url to HTTP CND
   * - cdn_https - url to HTTPS CDN
   * - version - version of pusher-js
   * - suffix - suffix appended to all names of dependency files
   *
   * @param {Object} options
   */
  function DependencyLoader(options) {
    this.options = options;
    this.loading = {};
    this.loaded = {};
  }
  var prototype = DependencyLoader.prototype;

  /** Loads the dependency from CDN.
   *
   * @param  {String} name
   * @param  {Function} callback
   */
  prototype.load = function(name, callback) {
    var self = this;

    if (this.loaded[name]) {
      callback();
      return;
    }

    if (!this.loading[name]) {
      this.loading[name] = [];
    }
    this.loading[name].push(callback);
    if (this.loading[name].length > 1) {
      return;
    }

    require(this.getPath(name), function() {
      for (var i = 0; i < self.loading[name].length; i++) {
        self.loading[name][i]();
      }
      delete self.loading[name];
      self.loaded[name] = true;
    });
  };

  /** Returns a root URL for pusher-js CDN.
   *
   * @returns {String}
   */
  prototype.getRoot = function(options) {
    var cdn;
    var protocol = Pusher.Util.getDocumentLocation().protocol;
    if ((options && options.encrypted) || protocol === "https:") {
      cdn = this.options.cdn_https;
    } else {
      cdn = this.options.cdn_http;
    }
    // make sure there are no double slashes
    return cdn.replace(/\/*$/, "") + "/" + this.options.version;
  };

  /** Returns a full path to a dependency file.
   *
   * @param {String} name
   * @returns {String}
   */
  prototype.getPath = function(name, options) {
    return this.getRoot(options) + '/' + name + this.options.suffix + '.js';
  };

  function handleScriptLoaded(elem, callback) {
    if (Pusher.Util.getDocument().addEventListener) {
      elem.addEventListener('load', callback, false);
    } else {
      elem.attachEvent('onreadystatechange', function () {
        if (elem.readyState === 'loaded' || elem.readyState === 'complete') {
          callback();
        }
      });
    }
  }

  function require(src, callback) {
    var document = Pusher.Util.getDocument();
    var head = document.getElementsByTagName('head')[0];
    var script = document.createElement('script');

    script.setAttribute('src', src);
    script.setAttribute("type","text/javascript");
    script.setAttribute('async', true);

    handleScriptLoaded(script, function() {
      // workaround for an Opera issue
      setTimeout(callback, 0);
    });

    head.appendChild(script);
  }

  Pusher.DependencyLoader = DependencyLoader;
}).call(this);

;(function() {
  Pusher.Dependencies = new Pusher.DependencyLoader({
    cdn_http: Pusher.cdn_http,
    cdn_https: Pusher.cdn_https,
    version: Pusher.VERSION,
    suffix: Pusher.dependency_suffix
  });

  // Support Firefox versions which prefix WebSocket
  if (!window.WebSocket && window.MozWebSocket) {
    window.WebSocket = window.MozWebSocket;
  }

  function initialize() {
    Pusher.ready();
  }

  // Allows calling a function when the document body is available
   function onDocumentBody(callback) {
    if (document.body) {
      callback();
    } else {
      setTimeout(function() {
        onDocumentBody(callback);
      }, 0);
    }
  }

  function initializeOnDocumentBody() {
    onDocumentBody(initialize);
  }

  if (!window.JSON) {
    Pusher.Dependencies.load("json2", initializeOnDocumentBody);
  } else {
    initializeOnDocumentBody();
  }
})();

;(function() {
  /** Cross-browser compatible timer abstraction.
   *
   * @param {Number} delay
   * @param {Function} callback
   */
  function Timer(delay, callback) {
    var self = this;

    this.timeout = setTimeout(function() {
      if (self.timeout !== null) {
        callback();
        self.timeout = null;
      }
    }, delay);
  }
  var prototype = Timer.prototype;

  /** Returns whether the timer is still running.
   *
   * @return {Boolean}
   */
  prototype.isRunning = function() {
    return this.timeout !== null;
  };

  /** Aborts a timer when it's running. */
  prototype.ensureAborted = function() {
    if (this.timeout) {
      clearTimeout(this.timeout);
      this.timeout = null;
    }
  };

  Pusher.Timer = Timer;
}).call(this);

(function() {

  var Base64 = {
    encode: function (s) {
      return btoa(utob(s));
    }
  };

  var fromCharCode = String.fromCharCode;

  var b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  var b64tab = {};

  for (var i = 0, l = b64chars.length; i < l; i++) {
    b64tab[b64chars.charAt(i)] = i;
  }

  var cb_utob = function(c) {
    var cc = c.charCodeAt(0);
    return cc < 0x80 ? c
        : cc < 0x800 ? fromCharCode(0xc0 | (cc >>> 6)) +
                       fromCharCode(0x80 | (cc & 0x3f))
        : fromCharCode(0xe0 | ((cc >>> 12) & 0x0f)) +
          fromCharCode(0x80 | ((cc >>>  6) & 0x3f)) +
          fromCharCode(0x80 | ( cc         & 0x3f));
  };

  var utob = function(u) {
    return u.replace(/[^\x00-\x7F]/g, cb_utob);
  };

  var cb_encode = function(ccc) {
    var padlen = [0, 2, 1][ccc.length % 3];
    var ord = ccc.charCodeAt(0) << 16
      | ((ccc.length > 1 ? ccc.charCodeAt(1) : 0) << 8)
      | ((ccc.length > 2 ? ccc.charCodeAt(2) : 0));
    var chars = [
      b64chars.charAt( ord >>> 18),
      b64chars.charAt((ord >>> 12) & 63),
      padlen >= 2 ? '=' : b64chars.charAt((ord >>> 6) & 63),
      padlen >= 1 ? '=' : b64chars.charAt(ord & 63)
    ];
    return chars.join('');
  };

  var btoa = window.btoa || function(b) {
    return b.replace(/[\s\S]{1,3}/g, cb_encode);
  };

  Pusher.Base64 = Base64;

}).call(this);

(function() {

  function JSONPRequest(options) {
    this.options = options;
  }

  JSONPRequest.send = function(options, callback) {
    var request = new Pusher.JSONPRequest({
      url: options.url,
      receiver: options.receiverName,
      tagPrefix: options.tagPrefix
    });
    var id = options.receiver.register(function(error, result) {
      request.cleanup();
      callback(error, result);
    });

    return request.send(id, options.data, function(error) {
      var callback = options.receiver.unregister(id);
      if (callback) {
        callback(error);
      }
    });
  };

  var prototype = JSONPRequest.prototype;

  prototype.send = function(id, data, callback) {
    if (this.script) {
      return false;
    }

    var tagPrefix = this.options.tagPrefix || "_pusher_jsonp_";

    var params = Pusher.Util.extend(
      {}, data, { receiver: this.options.receiver }
    );
    var query = Pusher.Util.map(
      Pusher.Util.flatten(
        encodeData(
          Pusher.Util.filterObject(params, function(value) {
            return value !== undefined;
          })
        )
      ),
      Pusher.Util.method("join", "=")
    ).join("&");

    this.script = document.createElement("script");
    this.script.id = tagPrefix + id;
    this.script.src = this.options.url + "/" + id + "?" + query;
    this.script.type = "text/javascript";
    this.script.charset = "UTF-8";
    this.script.onerror = this.script.onload = callback;

    // Opera<11.6 hack for missing onerror callback
    if (this.script.async === undefined && document.attachEvent) {
      if (/opera/i.test(navigator.userAgent)) {
        var receiverName = this.options.receiver || "Pusher.JSONP.receive";
        this.errorScript = document.createElement("script");
        this.errorScript.text = receiverName + "(" + id + ", true);";
        this.script.async = this.errorScript.async = false;
      }
    }

    var self = this;
    this.script.onreadystatechange = function() {
      if (self.script && /loaded|complete/.test(self.script.readyState)) {
        callback(true);
      }
    };

    var head = document.getElementsByTagName('head')[0];
    head.insertBefore(this.script, head.firstChild);
    if (this.errorScript) {
      head.insertBefore(this.errorScript, this.script.nextSibling);
    }

    return true;
  };

  prototype.cleanup = function() {
    if (this.script && this.script.parentNode) {
      this.script.parentNode.removeChild(this.script);
      this.script = null;
    }
    if (this.errorScript && this.errorScript.parentNode) {
      this.errorScript.parentNode.removeChild(this.errorScript);
      this.errorScript = null;
    }
  };

  function encodeData(data) {
    return Pusher.Util.mapObject(data, function(value) {
      if (typeof value === "object") {
        value = JSON.stringify(value);
      }
      return encodeURIComponent(Pusher.Base64.encode(value.toString()));
    });
  }

  Pusher.JSONPRequest = JSONPRequest;

}).call(this);

(function() {

  function JSONPReceiver() {
    this.lastId = 0;
    this.callbacks = {};
  }

  var prototype = JSONPReceiver.prototype;

  prototype.register = function(callback) {
    this.lastId++;
    var id = this.lastId;
    this.callbacks[id] = callback;
    return id;
  };

  prototype.unregister = function(id) {
    if (this.callbacks[id]) {
      var callback = this.callbacks[id];
      delete this.callbacks[id];
      return callback;
    } else {
      return null;
    }
  };

  prototype.receive = function(id, error, data) {
    var callback = this.unregister(id);
    if (callback) {
      callback(error, data);
    }
  };

  Pusher.JSONPReceiver = JSONPReceiver;
  Pusher.JSONP = new JSONPReceiver();

}).call(this);

(function() {
  function Timeline(key, session, options) {
    this.key = key;
    this.session = session;
    this.events = [];
    this.options = options || {};
    this.sent = 0;
    this.uniqueID = 0;
  }
  var prototype = Timeline.prototype;

  // Log levels
  Timeline.ERROR = 3;
  Timeline.INFO = 6;
  Timeline.DEBUG = 7;

  prototype.log = function(level, event) {
    if (this.options.level === undefined || level <= this.options.level) {
      this.events.push(
        Pusher.Util.extend({}, event, {
          timestamp: Pusher.Util.now(),
          level: level
        })
      );
      if (this.options.limit && this.events.length > this.options.limit) {
        this.events.shift();
      }
    }
  };

  prototype.error = function(event) {
    this.log(Timeline.ERROR, event);
  };

  prototype.info = function(event) {
    this.log(Timeline.INFO, event);
  };

  prototype.debug = function(event) {
    this.log(Timeline.DEBUG, event);
  };

  prototype.isEmpty = function() {
    return this.events.length === 0;
  };

  prototype.send = function(sendJSONP, callback) {
    var self = this;

    var data = {};
    if (this.sent === 0) {
      data = Pusher.Util.extend({
        key: this.key,
        features: this.options.features,
        version: this.options.version
      }, this.options.params || {});
    }
    data.session = this.session;
    data.timeline = this.events;
    data = Pusher.Util.filterObject(data, function(v) {
      return v !== undefined;
    });

    this.events = [];
    sendJSONP(data, function(error, result) {
      if (!error) {
        self.sent++;
      }
      callback(error, result);
    });

    return true;
  };

  prototype.generateUniqueID = function() {
    this.uniqueID++;
    return this.uniqueID;
  };

  Pusher.Timeline = Timeline;
}).call(this);

(function() {
  function TimelineSender(timeline, options) {
    this.timeline = timeline;
    this.options = options || {};
  }
  var prototype = TimelineSender.prototype;

  prototype.send = function(callback) {
    if (this.timeline.isEmpty()) {
      return;
    }

    var options = this.options;
    var scheme = "http" + (this.isEncrypted() ? "s" : "") + "://";

    var sendJSONP = function(data, callback) {
      return Pusher.JSONPRequest.send({
        data: data,
        url: scheme + options.host + options.path,
        receiver: Pusher.JSONP
      }, callback);
    };
    this.timeline.send(sendJSONP, callback);
  };

  prototype.isEncrypted = function() {
    return !!this.options.encrypted;
  };

  Pusher.TimelineSender = TimelineSender;
}).call(this);

;(function() {
  /** Launches all substrategies and emits prioritized connected transports.
   *
   * @param {Array} strategies
   */
  function BestConnectedEverStrategy(strategies) {
    this.strategies = strategies;
  }
  var prototype = BestConnectedEverStrategy.prototype;

  prototype.isSupported = function() {
    return Pusher.Util.any(this.strategies, Pusher.Util.method("isSupported"));
  };

  prototype.connect = function(minPriority, callback) {
    return connect(this.strategies, minPriority, function(i, runners) {
      return function(error, handshake) {
        runners[i].error = error;
        if (error) {
          if (allRunnersFailed(runners)) {
            callback(true);
          }
          return;
        }
        Pusher.Util.apply(runners, function(runner) {
          runner.forceMinPriority(handshake.transport.priority);
        });
        callback(null, handshake);
      };
    });
  };

  /** Connects to all strategies in parallel.
   *
   * Callback builder should be a function that takes two arguments: index
   * and a list of runners. It should return another function that will be
   * passed to the substrategy with given index. Runners can be aborted using
   * abortRunner(s) functions from this class.
   *
   * @param  {Array} strategies
   * @param  {Function} callbackBuilder
   * @return {Object} strategy runner
   */
  function connect(strategies, minPriority, callbackBuilder) {
    var runners = Pusher.Util.map(strategies, function(strategy, i, _, rs) {
      return strategy.connect(minPriority, callbackBuilder(i, rs));
    });
    return {
      abort: function() {
        Pusher.Util.apply(runners, abortRunner);
      },
      forceMinPriority: function(p) {
        Pusher.Util.apply(runners, function(runner) {
          runner.forceMinPriority(p);
        });
      }
    };
  }

  function allRunnersFailed(runners) {
    return Pusher.Util.all(runners, function(runner) {
      return Boolean(runner.error);
    });
  }

  function abortRunner(runner) {
    if (!runner.error && !runner.aborted) {
      runner.abort();
      runner.aborted = true;
    }
  }

  Pusher.BestConnectedEverStrategy = BestConnectedEverStrategy;
}).call(this);

;(function() {
  /** Caches last successful transport and uses it for following attempts.
   *
   * @param {Strategy} strategy
   * @param {Object} transports
   * @param {Object} options
   */
  function CachedStrategy(strategy, transports, options) {
    this.strategy = strategy;
    this.transports = transports;
    this.ttl = options.ttl || 1800*1000;
    this.timeline = options.timeline;
  }
  var prototype = CachedStrategy.prototype;

  prototype.isSupported = function() {
    return this.strategy.isSupported();
  };

  prototype.connect = function(minPriority, callback) {
    var info = fetchTransportInfo();

    var strategies = [this.strategy];
    if (info && info.timestamp + this.ttl >= Pusher.Util.now()) {
      var transport = this.transports[info.transport];
      if (transport) {
        this.timeline.info({ cached: true, transport: info.transport });
        strategies.push(new Pusher.SequentialStrategy([transport], {
          timeout: info.latency * 2,
          failFast: true
        }));
      }
    }

    var startTimestamp = Pusher.Util.now();
    var runner = strategies.pop().connect(
      minPriority,
      function cb(error, handshake) {
        if (error) {
          flushTransportInfo();
          if (strategies.length > 0) {
            startTimestamp = Pusher.Util.now();
            runner = strategies.pop().connect(minPriority, cb);
          } else {
            callback(error);
          }
        } else {
          var latency = Pusher.Util.now() - startTimestamp;
          storeTransportInfo(handshake.transport.name, latency);
          callback(null, handshake);
        }
      }
    );

    return {
      abort: function() {
        runner.abort();
      },
      forceMinPriority: function(p) {
        minPriority = p;
        if (runner) {
          runner.forceMinPriority(p);
        }
      }
    };
  };

  function fetchTransportInfo() {
    var storage = Pusher.Util.getLocalStorage();
    if (storage) {
      var info = storage.pusherTransport;
      if (info) {
        return JSON.parse(storage.pusherTransport);
      }
    }
    return null;
  }

  function storeTransportInfo(transport, latency) {
    var storage = Pusher.Util.getLocalStorage();
    if (storage) {
      try {
        storage.pusherTransport = JSON.stringify({
          timestamp: Pusher.Util.now(),
          transport: transport,
          latency: latency
        });
      } catch(e) {
        // catch over quota exceptions raised by localStorage
      }
    }
  }

  function flushTransportInfo() {
    var storage = Pusher.Util.getLocalStorage();
    if (storage && storage.pusherTransport) {
      try {
        delete storage.pusherTransport;
      } catch(e) {
        storage.pusherTransport = undefined;
      }
    }
  }

  Pusher.CachedStrategy = CachedStrategy;
}).call(this);

;(function() {
  /** Runs substrategy after specified delay.
   *
   * Options:
   * - delay - time in miliseconds to delay the substrategy attempt
   *
   * @param {Strategy} strategy
   * @param {Object} options
   */
  function DelayedStrategy(strategy, options) {
    this.strategy = strategy;
    this.options = { delay: options.delay };
  }
  var prototype = DelayedStrategy.prototype;

  prototype.isSupported = function() {
    return this.strategy.isSupported();
  };

  prototype.connect = function(minPriority, callback) {
    var strategy = this.strategy;
    var runner;
    var timer = new Pusher.Timer(this.options.delay, function() {
      runner = strategy.connect(minPriority, callback);
    });

    return {
      abort: function() {
        timer.ensureAborted();
        if (runner) {
          runner.abort();
        }
      },
      forceMinPriority: function(p) {
        minPriority = p;
        if (runner) {
          runner.forceMinPriority(p);
        }
      }
    };
  };

  Pusher.DelayedStrategy = DelayedStrategy;
}).call(this);

;(function() {
  /** Launches the substrategy and terminates on the first open connection.
   *
   * @param {Strategy} strategy
   */
  function FirstConnectedStrategy(strategy) {
    this.strategy = strategy;
  }
  var prototype = FirstConnectedStrategy.prototype;

  prototype.isSupported = function() {
    return this.strategy.isSupported();
  };

  prototype.connect = function(minPriority, callback) {
    var runner = this.strategy.connect(
      minPriority,
      function(error, handshake) {
        if (handshake) {
          runner.abort();
        }
        callback(error, handshake);
      }
    );
    return runner;
  };

  Pusher.FirstConnectedStrategy = FirstConnectedStrategy;
}).call(this);

;(function() {
  /** Proxies method calls to one of substrategies basing on the test function.
   *
   * @param {Function} test
   * @param {Strategy} trueBranch strategy used when test returns true
   * @param {Strategy} falseBranch strategy used when test returns false
   */
  function IfStrategy(test, trueBranch, falseBranch) {
    this.test = test;
    this.trueBranch = trueBranch;
    this.falseBranch = falseBranch;
  }
  var prototype = IfStrategy.prototype;

  prototype.isSupported = function() {
    var branch = this.test() ? this.trueBranch : this.falseBranch;
    return branch.isSupported();
  };

  prototype.connect = function(minPriority, callback) {
    var branch = this.test() ? this.trueBranch : this.falseBranch;
    return branch.connect(minPriority, callback);
  };

  Pusher.IfStrategy = IfStrategy;
}).call(this);

;(function() {
  /** Loops through strategies with optional timeouts.
   *
   * Options:
   * - loop - whether it should loop through the substrategy list
   * - timeout - initial timeout for a single substrategy
   * - timeoutLimit - maximum timeout
   *
   * @param {Strategy[]} strategies
   * @param {Object} options
   */
  function SequentialStrategy(strategies, options) {
    this.strategies = strategies;
    this.loop = Boolean(options.loop);
    this.failFast = Boolean(options.failFast);
    this.timeout = options.timeout;
    this.timeoutLimit = options.timeoutLimit;
  }
  var prototype = SequentialStrategy.prototype;

  prototype.isSupported = function() {
    return Pusher.Util.any(this.strategies, Pusher.Util.method("isSupported"));
  };

  prototype.connect = function(minPriority, callback) {
    var self = this;

    var strategies = this.strategies;
    var current = 0;
    var timeout = this.timeout;
    var runner = null;

    var tryNextStrategy = function(error, handshake) {
      if (handshake) {
        callback(null, handshake);
      } else {
        current = current + 1;
        if (self.loop) {
          current = current % strategies.length;
        }

        if (current < strategies.length) {
          if (timeout) {
            timeout = timeout * 2;
            if (self.timeoutLimit) {
              timeout = Math.min(timeout, self.timeoutLimit);
            }
          }
          runner = self.tryStrategy(
            strategies[current],
            minPriority,
            { timeout: timeout, failFast: self.failFast },
            tryNextStrategy
          );
        } else {
          callback(true);
        }
      }
    };

    runner = this.tryStrategy(
      strategies[current],
      minPriority,
      { timeout: timeout, failFast: this.failFast },
      tryNextStrategy
    );

    return {
      abort: function() {
        runner.abort();
      },
      forceMinPriority: function(p) {
        minPriority = p;
        if (runner) {
          runner.forceMinPriority(p);
        }
      }
    };
  };

  /** @private */
  prototype.tryStrategy = function(strategy, minPriority, options, callback) {
    var timer = null;
    var runner = null;

    runner = strategy.connect(minPriority, function(error, handshake) {
      if (error && timer && timer.isRunning() && !options.failFast) {
        // advance to the next strategy after the timeout
        return;
      }
      if (timer) {
        timer.ensureAborted();
      }
      callback(error, handshake);
    });

    if (options.timeout > 0) {
      timer = new Pusher.Timer(options.timeout, function() {
        runner.abort();
        callback(true);
      });
    }

    return {
      abort: function() {
        if (timer) {
          timer.ensureAborted();
        }
        runner.abort();
      },
      forceMinPriority: function(p) {
        runner.forceMinPriority(p);
      }
    };
  };

  Pusher.SequentialStrategy = SequentialStrategy;
}).call(this);

;(function() {
  /** Provides a strategy interface for transports.
   *
   * @param {String} name
   * @param {Number} priority
   * @param {Class} transport
   * @param {Object} options
   */
  function TransportStrategy(name, priority, transport, options) {
    this.name = name;
    this.priority = priority;
    this.transport = transport;
    this.options = options || {};
  }
  var prototype = TransportStrategy.prototype;

  /** Returns whether the transport is supported in the browser.
   *
   * @returns {Boolean}
   */
  prototype.isSupported = function() {
    return this.transport.isSupported({
      disableFlash: !!this.options.disableFlash
    });
  };

  /** Launches a connection attempt and returns a strategy runner.
   *
   * @param  {Function} callback
   * @return {Object} strategy runner
   */
  prototype.connect = function(minPriority, callback) {
    if (!this.transport.isSupported()) {
      return failAttempt(new Pusher.Errors.UnsupportedStrategy(), callback);
    } else if (this.priority < minPriority) {
      return failAttempt(new Pusher.Errors.TransportPriorityTooLow(), callback);
    }

    var self = this;
    var connected = false;

    var transport = this.transport.createConnection(
      this.name, this.priority, this.options.key, this.options
    );
    var handshake = null;

    var onInitialized = function() {
      transport.unbind("initialized", onInitialized);
      transport.connect();
    };
    var onOpen = function() {
      handshake = new Pusher.Handshake(transport, function(result) {
        connected = true;
        unbindListeners();
        callback(null, result);
      });
    };
    var onError = function(error) {
      unbindListeners();
      callback(error);
    };
    var onClosed = function() {
      unbindListeners();
      callback(new Pusher.Errors.TransportClosed(transport));
    };

    var unbindListeners = function() {
      transport.unbind("initialized", onInitialized);
      transport.unbind("open", onOpen);
      transport.unbind("error", onError);
      transport.unbind("closed", onClosed);
    };

    transport.bind("initialized", onInitialized);
    transport.bind("open", onOpen);
    transport.bind("error", onError);
    transport.bind("closed", onClosed);

    // connect will be called automatically after initialization
    transport.initialize();

    return {
      abort: function() {
        if (connected) {
          return;
        }
        unbindListeners();
        if (handshake) {
          handshake.close();
        } else {
          transport.close();
        }
      },
      forceMinPriority: function(p) {
        if (connected) {
          return;
        }
        if (self.priority < p) {
          if (handshake) {
            handshake.close();
          } else {
            transport.close();
          }
        }
      }
    };
  };

  function failAttempt(error, callback) {
    new Pusher.Timer(0, function() {
      callback(error);
    });
    return {
      abort: function() {},
      forceMinPriority: function() {}
    };
  }

  Pusher.TransportStrategy = TransportStrategy;
}).call(this);

;(function() {
  /** Handles common logic for all transports.
   *
   * Transport is a low-level connection object that wraps a connection method
   * and exposes a simple evented interface for the connection state and
   * messaging. It does not implement Pusher-specific WebSocket protocol.
   *
   * Additionally, it fetches resources needed for transport to work and exposes
   * an interface for querying transport support and its features.
   *
   * This is an abstract class, please do not instantiate it.
   *
   * States:
   * - new - initial state after constructing the object
   * - initializing - during initialization phase, usually fetching resources
   * - intialized - ready to establish a connection
   * - connection - when connection is being established
   * - open - when connection ready to be used
   * - closed - after connection was closed be either side
   *
   * Emits:
   * - error - after the connection raised an error
   *
   * Options:
   * - encrypted - whether connection should use ssl
   * - hostEncrypted - host to connect to when connection is encrypted
   * - hostUnencrypted - host to connect to when connection is not encrypted
   *
   * @param {String} key application key
   * @param {Object} options
   */
  function AbstractTransport(name, priority, key, options) {
    Pusher.EventsDispatcher.call(this);

    this.name = name;
    this.priority = priority;
    this.key = key;
    this.state = "new";
    this.timeline = options.timeline;
    this.id = this.timeline.generateUniqueID();

    this.options = {
      encrypted: Boolean(options.encrypted),
      hostUnencrypted: options.hostUnencrypted,
      hostEncrypted: options.hostEncrypted
    };
  }
  var prototype = AbstractTransport.prototype;
  Pusher.Util.extend(prototype, Pusher.EventsDispatcher.prototype);

  /** Checks whether the transport is supported in the browser.
   *
   * @returns {Boolean}
   */
  AbstractTransport.isSupported = function() {
    return false;
  };

  /** Checks whether the transport handles ping/pong on itself.
   *
   * @return {Boolean}
   */
  prototype.supportsPing = function() {
    return false;
  };

  /** Initializes the transport.
   *
   * Fetches resources if needed and then transitions to initialized.
   */
  prototype.initialize = function() {
    this.timeline.info(this.buildTimelineMessage({
      transport: this.name + (this.options.encrypted ? "s" : "")
    }));
    this.timeline.debug(this.buildTimelineMessage({ method: "initialize" }));

    this.changeState("initialized");
  };

  /** Tries to establish a connection.
   *
   * @returns {Boolean} false if transport is in invalid state
   */
  prototype.connect = function() {
    var url = this.getURL(this.key, this.options);
    this.timeline.debug(this.buildTimelineMessage({
      method: "connect",
      url: url
    }));

    if (this.socket || this.state !== "initialized") {
      return false;
    }

    try {
      this.socket = this.createSocket(url);
    } catch (e) {
      var self = this;
      new Pusher.Timer(0, function() {
        self.onError(e);
        self.changeState("closed");
      });
      return false;
    }

    this.bindListeners();

    Pusher.debug("Connecting", { transport: this.name, url: url });
    this.changeState("connecting");
    return true;
  };

  /** Closes the connection.
   *
   * @return {Boolean} true if there was a connection to close
   */
  prototype.close = function() {
    this.timeline.debug(this.buildTimelineMessage({ method: "close" }));

    if (this.socket) {
      this.socket.close();
      return true;
    } else {
      return false;
    }
  };

  /** Sends data over the open connection.
   *
   * @param {String} data
   * @return {Boolean} true only when in the "open" state
   */
  prototype.send = function(data) {
    this.timeline.debug(this.buildTimelineMessage({
      method: "send",
      data: data
    }));

    if (this.state === "open") {
      // Workaround for MobileSafari bug (see https://gist.github.com/2052006)
      var self = this;
      setTimeout(function() {
        self.socket.send(data);
      }, 0);
      return true;
    } else {
      return false;
    }
  };

  prototype.requestPing = function() {
    this.emit("ping_request");
  };

  /** @protected */
  prototype.onOpen = function() {
    this.changeState("open");
    this.socket.onopen = undefined;
  };

  /** @protected */
  prototype.onError = function(error) {
    this.emit("error", { type: 'WebSocketError', error: error });
    this.timeline.error(this.buildTimelineMessage({}));
  };

  /** @protected */
  prototype.onClose = function(closeEvent) {
    if (closeEvent) {
      this.changeState("closed", {
        code: closeEvent.code,
        reason: closeEvent.reason,
        wasClean: closeEvent.wasClean
      });
    } else {
      this.changeState("closed");
    }
    this.socket = undefined;
  };

  /** @protected */
  prototype.onMessage = function(message) {
    this.timeline.debug(this.buildTimelineMessage({ message: message.data }));
    this.emit("message", message);
  };

  /** @protected */
  prototype.bindListeners = function() {
    var self = this;

    this.socket.onopen = function() { self.onOpen(); };
    this.socket.onerror = function(error) { self.onError(error); };
    this.socket.onclose = function(closeEvent) { self.onClose(closeEvent); };
    this.socket.onmessage = function(message) { self.onMessage(message); };
  };

  /** @protected */
  prototype.createSocket = function(url) {
    return null;
  };

  /** @protected */
  prototype.getScheme = function() {
    return this.options.encrypted ? "wss" : "ws";
  };

  /** @protected */
  prototype.getBaseURL = function() {
    var host;
    if (this.options.encrypted) {
      host = this.options.hostEncrypted;
    } else {
      host = this.options.hostUnencrypted;
    }
    return this.getScheme() + "://" + host;
  };

  /** @protected */
  prototype.getPath = function() {
    return "/app/" + this.key;
  };

  /** @protected */
  prototype.getQueryString = function() {
    return "?protocol=" + Pusher.PROTOCOL +
      "&client=js&version=" + Pusher.VERSION;
  };

  /** @protected */
  prototype.getURL = function() {
    return this.getBaseURL() + this.getPath() + this.getQueryString();
  };

  /** @protected */
  prototype.changeState = function(state, params) {
    this.state = state;
    this.timeline.info(this.buildTimelineMessage({
      state: state,
      params: params
    }));
    this.emit(state, params);
  };

  /** @protected */
  prototype.buildTimelineMessage = function(message) {
    return Pusher.Util.extend({ cid: this.id }, message);
  };

  Pusher.AbstractTransport = AbstractTransport;
}).call(this);

;(function() {
  /** Transport using Flash to emulate WebSockets.
   *
   * @see AbstractTransport
   */
  function FlashTransport(name, priority, key, options) {
    Pusher.AbstractTransport.call(this, name, priority, key, options);
  }
  var prototype = FlashTransport.prototype;
  Pusher.Util.extend(prototype, Pusher.AbstractTransport.prototype);

  /** Creates a new instance of FlashTransport.
   *
   * @param  {String} key
   * @param  {Object} options
   * @return {FlashTransport}
   */
  FlashTransport.createConnection = function(name, priority, key, options) {
    return new FlashTransport(name, priority, key, options);
  };

  /** Checks whether Flash is supported in the browser.
   *
   * It is possible to disable flash by passing an envrionment object with the
   * disableFlash property set to true.
   *
   * @see AbstractTransport.isSupported
   * @param {Object} environment
   * @returns {Boolean}
   */
  FlashTransport.isSupported = function(environment) {
    if (environment && environment.disableFlash) {
      return false;
    }
    try {
      return Boolean(new ActiveXObject('ShockwaveFlash.ShockwaveFlash'));
    } catch (e) {
      return Boolean(
        navigator &&
        navigator.mimeTypes &&
        navigator.mimeTypes["application/x-shockwave-flash"] !== undefined
      );
    }
  };

  /** Fetches flashfallback dependency if needed.
   *
   * Sets WEB_SOCKET_SUPPRESS_CROSS_DOMAIN_SWF_ERROR to true (if not set before)
   * and WEB_SOCKET_SWF_LOCATION to Pusher's cdn before loading Flash resources.
   *
   * @see AbstractTransport.prototype.initialize
   */
  prototype.initialize = function() {
    var self = this;

    this.timeline.info(this.buildTimelineMessage({
      transport: this.name + (this.options.encrypted ? "s" : "")
    }));
    this.timeline.debug(this.buildTimelineMessage({ method: "initialize" }));
    this.changeState("initializing");

    if (window.WEB_SOCKET_SUPPRESS_CROSS_DOMAIN_SWF_ERROR === undefined) {
      window.WEB_SOCKET_SUPPRESS_CROSS_DOMAIN_SWF_ERROR = true;
    }
    window.WEB_SOCKET_SWF_LOCATION = Pusher.Dependencies.getRoot() +
      "/WebSocketMain.swf";
    Pusher.Dependencies.load("flashfallback", function() {
      self.changeState("initialized");
    });
  };

  /** @protected */
  prototype.createSocket = function(url) {
    return new FlashWebSocket(url);
  };

  /** @protected */
  prototype.getQueryString = function() {
    return Pusher.AbstractTransport.prototype.getQueryString.call(this) +
      "&flash=true";
  };

  Pusher.FlashTransport = FlashTransport;
}).call(this);

;(function() {
  /** Fallback transport using SockJS.
   *
   * @see AbstractTransport
   */
  function SockJSTransport(name, priority, key, options) {
    Pusher.AbstractTransport.call(this, name, priority, key, options);
    this.options.ignoreNullOrigin = options.ignoreNullOrigin;
  }
  var prototype = SockJSTransport.prototype;
  Pusher.Util.extend(prototype, Pusher.AbstractTransport.prototype);

  /** Creates a new instance of SockJSTransport.
   *
   * @param  {String} key
   * @param  {Object} options
   * @return {SockJSTransport}
   */
  SockJSTransport.createConnection = function(name, priority, key, options) {
    return new SockJSTransport(name, priority, key, options);
  };

  /** Assumes that SockJS is always supported.
   *
   * @returns {Boolean} always true
   */
  SockJSTransport.isSupported = function() {
    return true;
  };

  /** Fetches sockjs dependency if needed.
   *
   * @see AbstractTransport.prototype.initialize
   */
  prototype.initialize = function() {
    var self = this;

    this.timeline.info(this.buildTimelineMessage({
      transport: this.name + (this.options.encrypted ? "s" : "")
    }));
    this.timeline.debug(this.buildTimelineMessage({ method: "initialize" }));

    this.changeState("initializing");
    Pusher.Dependencies.load("sockjs", function() {
      self.changeState("initialized");
    });
  };

  /** Always returns true, since SockJS handles ping on its own.
   *
   * @returns {Boolean} always true
   */
  prototype.supportsPing = function() {
    return true;
  };

  /** @protected */
  prototype.createSocket = function(url) {
    return new SockJS(url, null, {
      js_path: Pusher.Dependencies.getPath("sockjs", {
        encrypted: this.options.encrypted
      }),
      ignore_null_origin: this.options.ignoreNullOrigin
    });
  };

  /** @protected */
  prototype.getScheme = function() {
    return this.options.encrypted ? "https" : "http";
  };

  /** @protected */
  prototype.getPath = function() {
    return this.options.httpPath || "/pusher";
  };

  /** @protected */
  prototype.getQueryString = function() {
    return "";
  };

  /** Handles opening a SockJS connection to Pusher.
   *
   * Since SockJS does not handle custom paths, we send it immediately after
   * establishing the connection.
   *
   * @protected
   */
  prototype.onOpen = function() {
    this.socket.send(JSON.stringify({
      path: Pusher.AbstractTransport.prototype.getPath.call(this) +
        Pusher.AbstractTransport.prototype.getQueryString.call(this)
    }));
    this.changeState("open");
    this.socket.onopen = undefined;
  };

  Pusher.SockJSTransport = SockJSTransport;
}).call(this);

;(function() {
  /** WebSocket transport.
   *
   * @see AbstractTransport
   */
  function WSTransport(name, priority, key, options) {
    Pusher.AbstractTransport.call(this, name, priority, key, options);
  }
  var prototype = WSTransport.prototype;
  Pusher.Util.extend(prototype, Pusher.AbstractTransport.prototype);

  /** Creates a new instance of WSTransport.
   *
   * @param  {String} key
   * @param  {Object} options
   * @return {WSTransport}
   */
  WSTransport.createConnection = function(name, priority, key, options) {
    return new WSTransport(name, priority, key, options);
  };

  /** Checks whether the browser supports WebSockets in any form.
   *
   * @returns {Boolean} true if browser supports WebSockets
   */
  WSTransport.isSupported = function() {
    return window.WebSocket !== undefined || window.MozWebSocket !== undefined;
  };

  /** @protected */
  prototype.createSocket = function(url) {
    var constructor = window.WebSocket || window.MozWebSocket;
    return new constructor(url);
  };

  /** @protected */
  prototype.getQueryString = function() {
    return Pusher.AbstractTransport.prototype.getQueryString.call(this) +
      "&flash=false";
  };

  Pusher.WSTransport = WSTransport;
}).call(this);

;(function() {
  function AssistantToTheTransportManager(manager, transport, options) {
    this.manager = manager;
    this.transport = transport;
    this.minPingDelay = options.minPingDelay;
    this.maxPingDelay = options.maxPingDelay;
    this.pingDelay = null;
  }
  var prototype = AssistantToTheTransportManager.prototype;

  prototype.createConnection = function(name, priority, key, options) {
    var connection = this.transport.createConnection(
      name, priority, key, options
    );

    var self = this;
    var openTimestamp = null;
    var pingTimer = null;

    var onOpen = function() {
      connection.unbind("open", onOpen);

      openTimestamp = Pusher.Util.now();
      if (self.pingDelay) {
        pingTimer = setInterval(function() {
          if (pingTimer) {
            connection.requestPing();
          }
        }, self.pingDelay);
      }

      connection.bind("closed", onClosed);
    };
    var onClosed = function(closeEvent) {
      connection.unbind("closed", onClosed);
      if (pingTimer) {
        clearInterval(pingTimer);
        pingTimer = null;
      }

      if (closeEvent.code === 1002 || closeEvent.code === 1003) {
        // we don't want to use transports not obeying the protocol
        self.manager.reportDeath();
      } else if (!closeEvent.wasClean && openTimestamp) {
        // report deaths only for short-living transport
        var lifespan = Pusher.Util.now() - openTimestamp;
        if (lifespan < 2 * self.maxPingDelay) {
          self.manager.reportDeath();
          self.pingDelay = Math.max(lifespan / 2, self.minPingDelay);
        }
      }
    };

    connection.bind("open", onOpen);
    return connection;
  };

  prototype.isSupported = function(environment) {
    return this.manager.isAlive() && this.transport.isSupported(environment);
  };

  Pusher.AssistantToTheTransportManager = AssistantToTheTransportManager;
}).call(this);

;(function() {
  function TransportManager(options) {
    this.options = options || {};
    this.livesLeft = this.options.lives || Infinity;
  }
  var prototype = TransportManager.prototype;

  prototype.getAssistant = function(transport) {
    return new Pusher.AssistantToTheTransportManager(this, transport, {
      minPingDelay: this.options.minPingDelay,
      maxPingDelay: this.options.maxPingDelay
    });
  };

  prototype.isAlive = function() {
    return this.livesLeft > 0;
  };

  prototype.reportDeath = function() {
    this.livesLeft -= 1;
  };

  Pusher.TransportManager = TransportManager;
}).call(this);

;(function() {
  var StrategyBuilder = {
    /** Transforms a JSON scheme to a strategy tree.
     *
     * @param {Array} scheme JSON strategy scheme
     * @param {Object} options a hash of symbols to be included in the scheme
     * @returns {Strategy} strategy tree that's represented by the scheme
     */
    build: function(scheme, options) {
      var context = Pusher.Util.extend({}, globalContext, options);
      return evaluate(scheme, context)[1].strategy;
    }
  };

  var transports = {
    ws: Pusher.WSTransport,
    flash: Pusher.FlashTransport,
    sockjs: Pusher.SockJSTransport
  };

  // DSL bindings

  function returnWithOriginalContext(f) {
    return function(context) {
      return [f.apply(this, arguments), context];
    };
  }

  var globalContext = {
    def: function(context, name, value) {
      if (context[name] !== undefined) {
        throw "Redefining symbol " + name;
      }
      context[name] = value;
      return [undefined, context];
    },

    def_transport: function(context, name, type, priority, options, manager) {
      var transportClass = transports[type];
      if (!transportClass) {
        throw new Pusher.Errors.UnsupportedTransport(type);
      }
      var transportOptions = Pusher.Util.extend({}, {
        key: context.key,
        encrypted: context.encrypted,
        timeline: context.timeline,
        disableFlash: context.disableFlash,
        ignoreNullOrigin: context.ignoreNullOrigin
      }, options);
      if (manager) {
        transportClass = manager.getAssistant(transportClass);
      }
      var transport = new Pusher.TransportStrategy(
        name, priority, transportClass, transportOptions
      );
      var newContext = context.def(context, name, transport)[1];
      newContext.transports = context.transports || {};
      newContext.transports[name] = transport;
      return [undefined, newContext];
    },

    transport_manager: returnWithOriginalContext(function(_, options) {
      return new Pusher.TransportManager(options);
    }),

    sequential: returnWithOriginalContext(function(_, options) {
      var strategies = Array.prototype.slice.call(arguments, 2);
      return new Pusher.SequentialStrategy(strategies, options);
    }),

    cached: returnWithOriginalContext(function(context, ttl, strategy){
      return new Pusher.CachedStrategy(strategy, context.transports, {
        ttl: ttl,
        timeline: context.timeline
      });
    }),

    first_connected: returnWithOriginalContext(function(_, strategy) {
      return new Pusher.FirstConnectedStrategy(strategy);
    }),

    best_connected_ever: returnWithOriginalContext(function() {
      var strategies = Array.prototype.slice.call(arguments, 1);
      return new Pusher.BestConnectedEverStrategy(strategies);
    }),

    delayed: returnWithOriginalContext(function(_, delay, strategy) {
      return new Pusher.DelayedStrategy(strategy, { delay: delay });
    }),

    "if": returnWithOriginalContext(function(_, test, trueBranch, falseBranch) {
      return new Pusher.IfStrategy(test, trueBranch, falseBranch);
    }),

    is_supported: returnWithOriginalContext(function(_, strategy) {
      return function() {
        return strategy.isSupported();
      };
    })
  };

  // DSL interpreter

  function isSymbol(expression) {
    return (typeof expression === "string") && expression.charAt(0) === ":";
  }

  function getSymbolValue(expression, context) {
    return context[expression.slice(1)];
  }

  function evaluateListOfExpressions(expressions, context) {
    if (expressions.length === 0) {
      return [[], context];
    }
    var head = evaluate(expressions[0], context);
    var tail = evaluateListOfExpressions(expressions.slice(1), head[1]);
    return [[head[0]].concat(tail[0]), tail[1]];
  }

  function evaluateString(expression, context) {
    if (!isSymbol(expression)) {
      return [expression, context];
    }
    var value = getSymbolValue(expression, context);
    if (value === undefined) {
      throw "Undefined symbol " + expression;
    }
    return [value, context];
  }

  function evaluateArray(expression, context) {
    if (isSymbol(expression[0])) {
      var f = getSymbolValue(expression[0], context);
      if (expression.length > 1) {
        if (typeof f !== "function") {
          throw "Calling non-function " + expression[0];
        }
        var args = [Pusher.Util.extend({}, context)].concat(
          Pusher.Util.map(expression.slice(1), function(arg) {
            return evaluate(arg, Pusher.Util.extend({}, context))[0];
          })
        );
        return f.apply(this, args);
      } else {
        return [f, context];
      }
    } else {
      return evaluateListOfExpressions(expression, context);
    }
  }

  function evaluate(expression, context) {
    var expressionType = typeof expression;
    if (typeof expression === "string") {
      return evaluateString(expression, context);
    } else if (typeof expression === "object") {
      if (expression instanceof Array && expression.length > 0) {
        return evaluateArray(expression, context);
      }
    }
    return [expression, context];
  }

  Pusher.StrategyBuilder = StrategyBuilder;
}).call(this);

;(function() {
  /**
   * Provides functions for handling Pusher protocol-specific messages.
   */
  Protocol = {};

  /**
   * Decodes a message in a Pusher format.
   *
   * Throws errors when messages are not parse'able.
   *
   * @param  {Object} message
   * @return {Object}
   */
  Protocol.decodeMessage = function(message) {
    try {
      var params = JSON.parse(message.data);
      if (typeof params.data === 'string') {
        try {
          params.data = JSON.parse(params.data);
        } catch (e) {
          if (!(e instanceof SyntaxError)) {
            // TODO looks like unreachable code
            // https://developer.mozilla.org/en-US/docs/JavaScript/Reference/Global_Objects/JSON/parse
            throw e;
          }
        }
      }
      return params;
    } catch (e) {
      throw { type: 'MessageParseError', error: e, data: message.data};
    }
  };

  /**
   * Encodes a message to be sent.
   *
   * @param  {Object} message
   * @return {String}
   */
  Protocol.encodeMessage = function(message) {
    return JSON.stringify(message);
  };

  /** Processes a handshake message and returns appropriate actions.
   *
   * Returns an object with an 'action' and other action-specific properties.
   *
   * There are three outcomes when calling this function. First is a successful
   * connection attempt, when pusher:connection_established is received, which
   * results in a 'connected' action with an 'id' property. When passed a
   * pusher:error event, it returns a result with action appropriate to the
   * close code and an error. Otherwise, it raises an exception.
   *
   * @param {String} message
   * @result Object
   */
  Protocol.processHandshake = function(message) {
    message = this.decodeMessage(message);

    if (message.event === "pusher:connection_established") {
      return { action: "connected", id: message.data.socket_id };
    } else if (message.event === "pusher:error") {
      // From protocol 6 close codes are sent only once, so this only
      // happens when connection does not support close codes
      return {
        action: this.getCloseAction(message.data),
        error: this.getCloseError(message.data)
      };
    } else {
      throw "Invalid handshake";
    }
  };

  /**
   * Dispatches the close event and returns an appropriate action name.
   *
   * See:
   * 1. https://developer.mozilla.org/en-US/docs/WebSockets/WebSockets_reference/CloseEvent
   * 2. http://pusher.com/docs/pusher_protocol
   *
   * @param  {CloseEvent} closeEvent
   * @return {String} close action name
   */
  Protocol.getCloseAction = function(closeEvent) {
    if (closeEvent.code < 4000) {
      // ignore 1000 CLOSE_NORMAL, 1001 CLOSE_GOING_AWAY,
      //        1005 CLOSE_NO_STATUS, 1006 CLOSE_ABNORMAL
      // ignore 1007...3999
      // handle 1002 CLOSE_PROTOCOL_ERROR, 1003 CLOSE_UNSUPPORTED,
      //        1004 CLOSE_TOO_LARGE
      if (closeEvent.code >= 1002 && closeEvent.code <= 1004) {
        return "backoff";
      } else {
        return null;
      }
    } else if (closeEvent.code === 4000) {
      return "ssl_only";
    } else if (closeEvent.code < 4100) {
      return "refused";
    } else if (closeEvent.code < 4200) {
      return "backoff";
    } else if (closeEvent.code < 4300) {
      return "retry";
    } else {
      // unknown error
      return "refused";
    }
  };

  /**
   * Returns an error or null basing on the close event.
   *
   * Null is returned when connection was closed cleanly. Otherwise, an object
   * with error details is returned.
   *
   * @param  {CloseEvent} closeEvent
   * @return {Object} error object
   */
  Protocol.getCloseError = function(closeEvent) {
    if (closeEvent.code !== 1000 && closeEvent.code !== 1001) {
      return {
        type: 'PusherError',
        data: {
          code: closeEvent.code,
          message: closeEvent.reason || closeEvent.message
        }
      };
    } else {
      return null;
    }
  };

  Pusher.Protocol = Protocol;
}).call(this);

;(function() {
  /**
   * Provides Pusher protocol interface for transports.
   *
   * Emits following events:
   * - message - on received messages
   * - ping - on ping requests
   * - pong - on pong responses
   * - error - when the transport emits an error
   * - closed - after closing the transport
   *
   * It also emits more events when connection closes with a code.
   * See Protocol.getCloseAction to get more details.
   *
   * @param {Number} id
   * @param {AbstractTransport} transport
   */
  function Connection(id, transport) {
    Pusher.EventsDispatcher.call(this);

    this.id = id;
    this.transport = transport;
    this.bindListeners();
  }
  var prototype = Connection.prototype;
  Pusher.Util.extend(prototype, Pusher.EventsDispatcher.prototype);

  /** Returns whether used transport handles ping/pong by itself
   *
   * @returns {Boolean} true if ping is handled by the transport
   */
  prototype.supportsPing = function() {
    return this.transport.supportsPing();
  };

  /** Sends raw data.
   *
   * @param {String} data
   */
  prototype.send = function(data) {
    return this.transport.send(data);
  };

  /** Sends an event.
   *
   * @param {String} name
   * @param {String} data
   * @param {String} [channel]
   * @returns {Boolean} whether message was sent or not
   */
  prototype.send_event = function(name, data, channel) {
    var message = { event: name, data: data };
    if (channel) {
      message.channel = channel;
    }
    Pusher.debug('Event sent', message);
    return this.send(Pusher.Protocol.encodeMessage(message));
  };

  /** Closes the connection. */
  prototype.close = function() {
    this.transport.close();
  };

  /** @private */
  prototype.bindListeners = function() {
    var self = this;

    var onMessage = function(m) {
      var message;
      try {
        message = Pusher.Protocol.decodeMessage(m);
      } catch(e) {
        self.emit('error', {
          type: 'MessageParseError',
          error: e,
          data: m.data
        });
      }

      if (message !== undefined) {
        Pusher.debug('Event recd', message);

        switch (message.event) {
          case 'pusher:error':
            self.emit('error', { type: 'PusherError', data: message.data });
            break;
          case 'pusher:ping':
            self.emit("ping");
            break;
          case 'pusher:pong':
            self.emit("pong");
            break;
        }
        self.emit('message', message);
      }
    };
    var onPingRequest = function() {
      self.emit("ping_request");
    };
    var onError = function(error) {
      self.emit("error", { type: "WebSocketError", error: error });
    };
    var onClosed = function(closeEvent) {
      unbindListeners();

      if (closeEvent && closeEvent.code) {
        self.handleCloseEvent(closeEvent);
      }

      self.transport = null;
      self.emit("closed");
    };

    var unbindListeners = function() {
      self.transport.unbind("closed", onClosed);
      self.transport.unbind("error", onError);
      self.transport.unbind("ping_request", onPingRequest);
      self.transport.unbind("message", onMessage);
    };

    self.transport.bind("message", onMessage);
    self.transport.bind("ping_request", onPingRequest);
    self.transport.bind("error", onError);
    self.transport.bind("closed", onClosed);
  };

  /** @private */
  prototype.handleCloseEvent = function(closeEvent) {
    var action = Pusher.Protocol.getCloseAction(closeEvent);
    var error = Pusher.Protocol.getCloseError(closeEvent);
    if (error) {
      this.emit('error', error);
    }
    if (action) {
      this.emit(action);
    }
  };

  Pusher.Connection = Connection;
}).call(this);

;(function() {
  /**
   * Handles Pusher protocol handshakes for transports.
   *
   * Calls back with a result object after handshake is completed. Results
   * always have two fields:
   * - action - string describing action to be taken after the handshake
   * - transport - the transport object passed to the constructor
   *
   * Different actions can set different additional properties on the result.
   * In the case of 'connected' action, there will be a 'connection' property
   * containing a Connection object for the transport. Other actions should
   * carry an 'error' property.
   *
   * @param {AbstractTransport} transport
   * @param {Function} callback
   */
  function Handshake(transport, callback) {
    this.transport = transport;
    this.callback = callback;
    this.bindListeners();
  }
  var prototype = Handshake.prototype;

  prototype.close = function() {
    this.unbindListeners();
    this.transport.close();
  };

  /** @private */
  prototype.bindListeners = function() {
    var self = this;

    self.onMessage = function(m) {
      self.unbindListeners();

      try {
        var result = Pusher.Protocol.processHandshake(m);
        if (result.action === "connected") {
          self.finish("connected", {
            connection: new Pusher.Connection(result.id, self.transport)
          });
        } else {
          self.finish(result.action, { error: result.error });
          self.transport.close();
        }
      } catch (e) {
        self.finish("error", { error: e });
        self.transport.close();
      }
    };

    self.onClosed = function(closeEvent) {
      self.unbindListeners();

      var action = Pusher.Protocol.getCloseAction(closeEvent) || "backoff";
      var error = Pusher.Protocol.getCloseError(closeEvent);
      self.finish(action, { error: error });
    };

    self.transport.bind("message", self.onMessage);
    self.transport.bind("closed", self.onClosed);
  };

  /** @private */
  prototype.unbindListeners = function() {
    this.transport.unbind("message", this.onMessage);
    this.transport.unbind("closed", this.onClosed);
  };

  /** @private */
  prototype.finish = function(action, params) {
    this.callback(
      Pusher.Util.extend({ transport: this.transport, action: action }, params)
    );
  };

  Pusher.Handshake = Handshake;
}).call(this);

;(function() {
  /** Manages connection to Pusher.
   *
   * Uses a strategy (currently only default), timers and network availability
   * info to establish a connection and export its state. In case of failures,
   * manages reconnection attempts.
   *
   * Exports state changes as following events:
   * - "state_change", { previous: p, current: state }
   * - state
   *
   * States:
   * - initialized - initial state, never transitioned to
   * - connecting - connection is being established
   * - connected - connection has been fully established
   * - disconnected - on requested disconnection or before reconnecting
   * - unavailable - after connection timeout or when there's no network
   *
   * Options:
   * - unavailableTimeout - time to transition to unavailable state
   * - activityTimeout - time after which ping message should be sent
   * - pongTimeout - time for Pusher to respond with pong before reconnecting
   *
   * @param {String} key application key
   * @param {Object} options
   */
  function ConnectionManager(key, options) {
    Pusher.EventsDispatcher.call(this);

    this.key = key;
    this.options = options || {};
    this.state = "initialized";
    this.connection = null;
    this.encrypted = !!options.encrypted;
    this.timeline = this.options.getTimeline();

    this.connectionCallbacks = this.buildConnectionCallbacks();
    this.errorCallbacks = this.buildErrorCallbacks();
    this.handshakeCallbacks = this.buildHandshakeCallbacks(this.errorCallbacks);

    var self = this;

    Pusher.Network.bind("online", function() {
      self.timeline.info({ netinfo: "online" });
      if (self.state === "unavailable") {
        self.connect();
      }
    });
    Pusher.Network.bind("offline", function() {
      self.timeline.info({ netinfo: "offline" });
      if (self.shouldRetry()) {
        self.disconnect();
        self.updateState("unavailable");
      }
    });

    var sendTimeline = function() {
      if (self.timelineSender) {
        self.timelineSender.send(function() {});
      }
    };
    this.bind("connected", sendTimeline);
    setInterval(sendTimeline, 60000);

    this.updateStrategy();
  }
  var prototype = ConnectionManager.prototype;

  Pusher.Util.extend(prototype, Pusher.EventsDispatcher.prototype);

  /** Establishes a connection to Pusher.
   *
   * Does nothing when connection is already established. See top-level doc
   * to find events emitted on connection attempts.
   */
  prototype.connect = function() {
    var self = this;

    if (self.connection) {
      return;
    }
    if (self.state === "connecting") {
      return;
    }

    if (!self.strategy.isSupported()) {
      self.updateState("failed");
      return;
    }
    if (Pusher.Network.isOnline() === false) {
      self.updateState("unavailable");
      return;
    }

    self.updateState("connecting");
    self.timelineSender = self.options.getTimelineSender(
      self.timeline,
      { encrypted: self.encrypted },
      self
    );

    var callback = function(error, handshake) {
      if (error) {
        self.runner = self.strategy.connect(0, callback);
      } else {
        if (handshake.action === "error") {
          self.timeline.error({ handshakeError: handshake.error });
        } else {
          // we don't support switching connections yet
          self.runner.abort();
          self.handshakeCallbacks[handshake.action](handshake);
        }
      }
    };
    self.runner = self.strategy.connect(0, callback);

    self.setUnavailableTimer();
  };

  /** Sends raw data.
   *
   * @param {String} data
   */
  prototype.send = function(data) {
    if (this.connection) {
      return this.connection.send(data);
    } else {
      return false;
    }
  };

  /** Sends an event.
   *
   * @param {String} name
   * @param {String} data
   * @param {String} [channel]
   * @returns {Boolean} whether message was sent or not
   */
  prototype.send_event = function(name, data, channel) {
    if (this.connection) {
      return this.connection.send_event(name, data, channel);
    } else {
      return false;
    }
  };

  /** Closes the connection. */
  prototype.disconnect = function() {
    if (this.runner) {
      this.runner.abort();
    }
    this.clearRetryTimer();
    this.clearUnavailableTimer();
    this.stopActivityCheck();
    this.updateState("disconnected");
    // we're in disconnected state, so closing will not cause reconnecting
    if (this.connection) {
      this.connection.close();
      this.abandonConnection();
    }
  };

  /** @private */
  prototype.updateStrategy = function() {
    this.strategy = this.options.getStrategy({
      key: this.key,
      timeline: this.timeline,
      encrypted: this.encrypted
    });
  };

  /** @private */
  prototype.retryIn = function(delay) {
    var self = this;
    self.timeline.info({ action: "retry", delay: delay });
    if (delay > 0) {
      self.emit("connecting_in", Math.round(delay / 1000));
    }
    self.retryTimer = new Pusher.Timer(delay || 0, function() {
      self.disconnect();
      self.connect();
    });
  };

  /** @private */
  prototype.clearRetryTimer = function() {
    if (this.retryTimer) {
      this.retryTimer.ensureAborted();
    }
  };

  /** @private */
  prototype.setUnavailableTimer = function() {
    var self = this;
    self.unavailableTimer = new Pusher.Timer(
      self.options.unavailableTimeout,
      function() {
        self.updateState("unavailable");
      }
    );
  };

  /** @private */
  prototype.clearUnavailableTimer = function() {
    if (this.unavailableTimer) {
      this.unavailableTimer.ensureAborted();
    }
  };

  /** @private */
  prototype.resetActivityCheck = function() {
    this.stopActivityCheck();
    // send ping after inactivity
    if (!this.connection.supportsPing()) {
      var self = this;
      self.activityTimer = new Pusher.Timer(
        self.options.activityTimeout,
        function() {
          self.send_event('pusher:ping', {});
          // wait for pong response
          self.activityTimer = new Pusher.Timer(
            self.options.pongTimeout,
            function() {
              self.connection.close();
            }
          );
        }
      );
    }
  };

  /** @private */
  prototype.stopActivityCheck = function() {
    if (this.activityTimer) {
      this.activityTimer.ensureAborted();
    }
  };

  /** @private */
  prototype.buildConnectionCallbacks = function() {
    var self = this;
    return {
      message: function(message) {
        // includes pong messages from server
        self.resetActivityCheck();
        self.emit('message', message);
      },
      ping: function() {
        self.send_event('pusher:pong', {});
      },
      ping_request: function() {
        self.send_event('pusher:ping', {});
      },
      error: function(error) {
        // just emit error to user - socket will already be closed by browser
        self.emit("error", { type: "WebSocketError", error: error });
      },
      closed: function() {
        self.abandonConnection();
        if (self.shouldRetry()) {
          self.retryIn(1000);
        }
      }
    };
  };

  /** @private */
  prototype.buildHandshakeCallbacks = function(errorCallbacks) {
    var self = this;
    return Pusher.Util.extend({}, errorCallbacks, {
      connected: function(handshake) {
        self.clearUnavailableTimer();
        self.setConnection(handshake.connection);
        self.socket_id = self.connection.id;
        self.updateState("connected");
      }
    });
  };

  /** @private */
  prototype.buildErrorCallbacks = function() {
    var self = this;

    function withErrorEmitted(callback) {
      return function(result) {
        if (result.error) {
          self.emit("error", { type: "WebSocketError", error: result.error });
        }
        callback(result);
      };
    }

    return {
      ssl_only: withErrorEmitted(function() {
        self.encrypted = true;
        self.updateStrategy();
        self.retryIn(0);
      }),
      refused: withErrorEmitted(function() {
        self.disconnect();
      }),
      backoff: withErrorEmitted(function() {
        self.retryIn(1000);
      }),
      retry: withErrorEmitted(function() {
        self.retryIn(0);
      })
    };
  };

  /** @private */
  prototype.setConnection = function(connection) {
    this.connection = connection;
    for (var event in this.connectionCallbacks) {
      this.connection.bind(event, this.connectionCallbacks[event]);
    }
    this.resetActivityCheck();
  };

  /** @private */
  prototype.abandonConnection = function() {
    if (!this.connection) {
      return;
    }
    for (var event in this.connectionCallbacks) {
      this.connection.unbind(event, this.connectionCallbacks[event]);
    }
    this.connection = null;
  };

  /** @private */
  prototype.updateState = function(newState, data) {
    var previousState = this.state;

    this.state = newState;
    // Only emit when the state changes
    if (previousState !== newState) {
      Pusher.debug('State changed', previousState + ' -> ' + newState);

      this.timeline.info({ state: newState });
      this.emit('state_change', { previous: previousState, current: newState });
      this.emit(newState, data);
    }
  };

  /** @private */
  prototype.shouldRetry = function() {
    return this.state === "connecting" || this.state === "connected";
  };

  Pusher.ConnectionManager = ConnectionManager;
}).call(this);

;(function() {
  /** Really basic interface providing network availability info.
   *
   * Emits:
   * - online - when browser goes online
   * - offline - when browser goes offline
   */
  function NetInfo() {
    Pusher.EventsDispatcher.call(this);

    var self = this;
    // This is okay, as IE doesn't support this stuff anyway.
    if (window.addEventListener !== undefined) {
      window.addEventListener("online", function() {
        self.emit('online');
      }, false);
      window.addEventListener("offline", function() {
        self.emit('offline');
      }, false);
    }
  }
  Pusher.Util.extend(NetInfo.prototype, Pusher.EventsDispatcher.prototype);

  var prototype = NetInfo.prototype;

  /** Returns whether browser is online or not
   *
   * Offline means definitely offline (no connection to router).
   * Inverse does NOT mean definitely online (only currently supported in Safari
   * and even there only means the device has a connection to the router).
   *
   * @return {Boolean}
   */
  prototype.isOnline = function() {
    if (window.navigator.onLine === undefined) {
      return true;
    } else {
      return window.navigator.onLine;
    }
  };

  Pusher.NetInfo = NetInfo;
  Pusher.Network = new NetInfo();
}).call(this);

;(function() {
  /** Represents a collection of members of a presence channel. */
  function Members() {
    this.reset();
  }
  var prototype = Members.prototype;

  /** Returns member's info for given id.
   *
   * Resulting object containts two fields - id and info.
   *
   * @param {Number} id
   * @return {Object} member's info or null
   */
  prototype.get = function(id) {
    if (Object.prototype.hasOwnProperty.call(this.members, id)) {
      return {
        id: id,
        info: this.members[id]
      };
    } else {
      return null;
    }
  };

  /** Calls back for each member in unspecified order.
   *
   * @param  {Function} callback
   */
  prototype.each = function(callback) {
    var self = this;
    Pusher.Util.objectApply(self.members, function(member, id) {
      callback(self.get(id));
    });
  };

  /** Updates the id for connected member. For internal use only. */
  prototype.setMyID = function(id) {
    this.myID = id;
  };

  /** Handles subscription data. For internal use only. */
  prototype.onSubscription = function(subscriptionData) {
    this.members = subscriptionData.presence.hash;
    this.count = subscriptionData.presence.count;
    this.me = this.get(this.myID);
  };

  /** Adds a new member to the collection. For internal use only. */
  prototype.addMember = function(memberData) {
    if (this.get(memberData.user_id) === null) {
      this.count++;
    }
    this.members[memberData.user_id] = memberData.user_info;
    return this.get(memberData.user_id);
  };

  /** Adds a member from the collection. For internal use only. */
  prototype.removeMember = function(memberData) {
    var member = this.get(memberData.user_id);
    if (member) {
      delete this.members[memberData.user_id];
      this.count--;
    }
    return member;
  };

  /** Resets the collection to the initial state. For internal use only. */
  prototype.reset = function() {
    this.members = {};
    this.count = 0;
    this.myID = null;
    this.me = null;
  };

  Pusher.Members = Members;
}).call(this);

;(function() {
  /** Provides base public channel interface with an event emitter.
   *
   * Emits:
   * - pusher:subscription_succeeded - after subscribing successfully
   * - other non-internal events
   *
   * @param {String} name
   * @param {Pusher} pusher
   */
  function Channel(name, pusher) {
    Pusher.EventsDispatcher.call(this, function(event, data) {
      Pusher.debug('No callbacks on ' + name + ' for ' + event);
    });

    this.name = name;
    this.pusher = pusher;
    this.subscribed = false;
  }
  var prototype = Channel.prototype;
  Pusher.Util.extend(prototype, Pusher.EventsDispatcher.prototype);

  /** Skips authorization, since public channels don't require it.
   *
   * @param {Function} callback
   */
  prototype.authorize = function(socketId, callback) {
    return callback(false, {});
  };

  /** Triggers an event */
  prototype.trigger = function(event, data) {
    return this.pusher.send_event(event, data, this.name);
  };

  /** Signals disconnection to the channel. For internal use only. */
  prototype.disconnect = function() {
    this.subscribed = false;
  };

  /** Handles an event. For internal use only.
   *
   * @param {String} event
   * @param {*} data
   */
  prototype.handleEvent = function(event, data) {
    if (event.indexOf("pusher_internal:") === 0) {
      if (event === "pusher_internal:subscription_succeeded") {
        this.subscribed = true;
        this.emit("pusher:subscription_succeeded", data);
      }
    } else {
      this.emit(event, data);
    }
  };

  Pusher.Channel = Channel;
}).call(this);

;(function() {
  /** Extends public channels to provide private channel interface.
   *
   * @param {String} name
   * @param {Pusher} pusher
   */
  function PrivateChannel(name, pusher) {
    Pusher.Channel.call(this, name, pusher);
  }
  var prototype = PrivateChannel.prototype;
  Pusher.Util.extend(prototype, Pusher.Channel.prototype);

  /** Authorizes the connection to use the channel.
   *
   * @param  {String} socketId
   * @param  {Function} callback
   */
  prototype.authorize = function(socketId, callback) {
    var authorizer = new Pusher.Channel.Authorizer(this, this.pusher.config);
    return authorizer.authorize(socketId, callback);
  };

  Pusher.PrivateChannel = PrivateChannel;
}).call(this);

;(function() {
  /** Adds presence channel functionality to private channels.
   *
   * @param {String} name
   * @param {Pusher} pusher
   */
  function PresenceChannel(name, pusher) {
    Pusher.PrivateChannel.call(this, name, pusher);
    this.members = new Pusher.Members();
  }
  var prototype = PresenceChannel.prototype;
  Pusher.Util.extend(prototype, Pusher.PrivateChannel.prototype);

  /** Authenticates the connection as a member of the channel.
   *
   * @param  {String} socketId
   * @param  {Function} callback
   */
  prototype.authorize = function(socketId, callback) {
    var _super = Pusher.PrivateChannel.prototype.authorize;
    var self = this;
    _super.call(self, socketId, function(error, authData) {
      if (!error) {
        if (authData.channel_data === undefined) {
          Pusher.warn(
            "Invalid auth response for channel '" +
            self.name +
            "', expected 'channel_data' field"
          );
          callback("Invalid auth response");
          return;
        }
        var channelData = JSON.parse(authData.channel_data);
        self.members.setMyID(channelData.user_id);
      }
      callback(error, authData);
    });
  };

  /** Handles presence and subscription events. For internal use only.
   *
   * @param {String} event
   * @param {*} data
   */
  prototype.handleEvent = function(event, data) {
    switch (event) {
      case "pusher_internal:subscription_succeeded":
        this.members.onSubscription(data);
        this.subscribed = true;
        this.emit("pusher:subscription_succeeded", this.members);
        break;
      case "pusher_internal:member_added":
        var addedMember = this.members.addMember(data);
        this.emit('pusher:member_added', addedMember);
        break;
      case "pusher_internal:member_removed":
        var removedMember = this.members.removeMember(data);
        if (removedMember) {
          this.emit('pusher:member_removed', removedMember);
        }
        break;
      default:
        Pusher.PrivateChannel.prototype.handleEvent.call(this, event, data);
    }
  };

  /** Resets the channel state, including members map. For internal use only. */
  prototype.disconnect = function() {
    this.members.reset();
    Pusher.PrivateChannel.prototype.disconnect.call(this);
  };

  Pusher.PresenceChannel = PresenceChannel;
}).call(this);

;(function() {
  /** Handles a channel map. */
  function Channels() {
    this.channels = {};
  }
  var prototype = Channels.prototype;

  /** Creates or retrieves an existing channel by its name.
   *
   * @param {String} name
   * @param {Pusher} pusher
   * @return {Channel}
   */
  prototype.add = function(name, pusher) {
    if (!this.channels[name]) {
      this.channels[name] = createChannel(name, pusher);
    }
    return this.channels[name];
  };

  /** Finds a channel by its name.
   *
   * @param {String} name
   * @return {Channel} channel or null if it doesn't exist
   */
  prototype.find = function(name) {
    return this.channels[name];
  };

  /** Removes a channel from the map.
   *
   * @param {String} name
   */
  prototype.remove = function(name) {
    delete this.channels[name];
  };

  /** Proxies disconnection signal to all channels. */
  prototype.disconnect = function() {
    Pusher.Util.objectApply(this.channels, function(channel) {
      channel.disconnect();
    });
  };

  function createChannel(name, pusher) {
    if (name.indexOf('private-') === 0) {
      return new Pusher.PrivateChannel(name, pusher);
    } else if (name.indexOf('presence-') === 0) {
      return new Pusher.PresenceChannel(name, pusher);
    } else {
      return new Pusher.Channel(name, pusher);
    }
  }

  Pusher.Channels = Channels;
}).call(this);

;(function() {
  Pusher.Channel.Authorizer = function(channel, options) {
    this.channel = channel;
    this.type = options.authTransport;

    this.options = options;
    this.authOptions = (options || {}).auth || {};
  };

  Pusher.Channel.Authorizer.prototype = {
    composeQuery: function(socketId) {
      var query = '&socket_id=' + encodeURIComponent(socketId) +
        '&channel_name=' + encodeURIComponent(this.channel.name);

      for(var i in this.authOptions.params) {
        query += "&" + encodeURIComponent(i) + "=" + encodeURIComponent(this.authOptions.params[i]);
      }

      return query;
    },

    authorize: function(socketId, callback) {
      return Pusher.authorizers[this.type].call(this, socketId, callback);
    }
  };

  var nextAuthCallbackID = 1;

  Pusher.auth_callbacks = {};
  Pusher.authorizers = {
    ajax: function(socketId, callback){
      var self = this, xhr;

      if (Pusher.XHR) {
        xhr = new Pusher.XHR();
      } else {
        xhr = (window.XMLHttpRequest ? new window.XMLHttpRequest() : new ActiveXObject("Microsoft.XMLHTTP"));
      }

      xhr.open("POST", self.options.authEndpoint, true);

      // add request headers
      xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
      for(var headerName in this.authOptions.headers) {
        xhr.setRequestHeader(headerName, this.authOptions.headers[headerName]);
      }

      xhr.onreadystatechange = function() {
        if (xhr.readyState == 4) {
          if (xhr.status == 200) {
            var data, parsed = false;

            try {
              data = JSON.parse(xhr.responseText);
              parsed = true;
            } catch (e) {
              callback(true, 'JSON returned from webapp was invalid, yet status code was 200. Data was: ' + xhr.responseText);
            }

            if (parsed) { // prevents double execution.
              callback(false, data);
            }
          } else {
            Pusher.warn("Couldn't get auth info from your webapp", xhr.status);
            callback(true, xhr.status);
          }
        }
      };

      xhr.send(this.composeQuery(socketId));
      return xhr;
    },

    jsonp: function(socketId, callback){
      if(this.authOptions.headers !== undefined) {
        Pusher.warn("Warn", "To send headers with the auth request, you must use AJAX, rather than JSONP.");
      }

      var callbackName = nextAuthCallbackID.toString();
      nextAuthCallbackID++;

      var script = document.createElement("script");
      // Hacked wrapper.
      Pusher.auth_callbacks[callbackName] = function(data) {
        callback(false, data);
      };

      var callback_name = "Pusher.auth_callbacks['" + callbackName + "']";
      script.src = this.options.authEndpoint +
        '?callback=' +
        encodeURIComponent(callback_name) +
        this.composeQuery(socketId);

      var head = document.getElementsByTagName("head")[0] || document.documentElement;
      head.insertBefore( script, head.firstChild );
    }
  };
}).call(this);

module.exports = this.Pusher;
