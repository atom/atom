/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
'use strict';
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------------------------
 *---------------------------------------------------------------------------------------------
 *---------------------------------------------------------------------------------------------
 *---------------------------------------------------------------------------------------------
 *---------------------------------------------------------------------------------------------
 * Please make sure to make edits in the .ts file at https://github.com/Microsoft/vscode-loader/
 *---------------------------------------------------------------------------------------------
 *---------------------------------------------------------------------------------------------
 *---------------------------------------------------------------------------------------------
 *---------------------------------------------------------------------------------------------
 *--------------------------------------------------------------------------------------------*/
var _amdLoaderGlobal = this;
var _commonjsGlobal = typeof global === 'object' ? global : {};
var AMDLoader;
(function (AMDLoader) {
    AMDLoader.global = _amdLoaderGlobal;
    var Environment = (function () {
        function Environment() {
            this._detected = false;
            this._isWindows = false;
            this._isNode = false;
            this._isElectronRenderer = false;
            this._isWebWorker = false;
        }
        Object.defineProperty(Environment.prototype, "isWindows", {
            get: function () {
                this._detect();
                return this._isWindows;
            },
            enumerable: true,
            configurable: true
        });
        Object.defineProperty(Environment.prototype, "isNode", {
            get: function () {
                this._detect();
                return this._isNode;
            },
            enumerable: true,
            configurable: true
        });
        Object.defineProperty(Environment.prototype, "isElectronRenderer", {
            get: function () {
                this._detect();
                return this._isElectronRenderer;
            },
            enumerable: true,
            configurable: true
        });
        Object.defineProperty(Environment.prototype, "isWebWorker", {
            get: function () {
                this._detect();
                return this._isWebWorker;
            },
            enumerable: true,
            configurable: true
        });
        Environment.prototype._detect = function () {
            if (this._detected) {
                return;
            }
            this._detected = true;
            this._isWindows = Environment._isWindows();
            this._isNode = (typeof module !== 'undefined' && !!module.exports);
            this._isElectronRenderer = (typeof process !== 'undefined' && typeof process.versions !== 'undefined' && typeof process.versions.electron !== 'undefined' && process.type === 'renderer');
            this._isWebWorker = (typeof AMDLoader.global.importScripts === 'function');
        };
        Environment._isWindows = function () {
            if (typeof navigator !== 'undefined') {
                if (navigator.userAgent && navigator.userAgent.indexOf('Windows') >= 0) {
                    return true;
                }
            }
            if (typeof process !== 'undefined') {
                return (process.platform === 'win32');
            }
            return false;
        };
        return Environment;
    }());
    AMDLoader.Environment = Environment;
})(AMDLoader || (AMDLoader = {}));
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
var AMDLoader;
(function (AMDLoader) {
    var LoaderEvent = (function () {
        function LoaderEvent(type, detail, timestamp) {
            this.type = type;
            this.detail = detail;
            this.timestamp = timestamp;
        }
        return LoaderEvent;
    }());
    AMDLoader.LoaderEvent = LoaderEvent;
    var LoaderEventRecorder = (function () {
        function LoaderEventRecorder(loaderAvailableTimestamp) {
            this._events = [new LoaderEvent(1 /* LoaderAvailable */, '', loaderAvailableTimestamp)];
        }
        LoaderEventRecorder.prototype.record = function (type, detail) {
            this._events.push(new LoaderEvent(type, detail, AMDLoader.Utilities.getHighPerformanceTimestamp()));
        };
        LoaderEventRecorder.prototype.getEvents = function () {
            return this._events;
        };
        return LoaderEventRecorder;
    }());
    AMDLoader.LoaderEventRecorder = LoaderEventRecorder;
    var NullLoaderEventRecorder = (function () {
        function NullLoaderEventRecorder() {
        }
        NullLoaderEventRecorder.prototype.record = function (type, detail) {
            // Nothing to do
        };
        NullLoaderEventRecorder.prototype.getEvents = function () {
            return [];
        };
        return NullLoaderEventRecorder;
    }());
    NullLoaderEventRecorder.INSTANCE = new NullLoaderEventRecorder();
    AMDLoader.NullLoaderEventRecorder = NullLoaderEventRecorder;
})(AMDLoader || (AMDLoader = {}));
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
var AMDLoader;
(function (AMDLoader) {
    var Utilities = (function () {
        function Utilities() {
        }
        /**
         * This method does not take care of / vs \
         */
        Utilities.fileUriToFilePath = function (isWindows, uri) {
            uri = decodeURI(uri).replace(/%23/g, '#');
            if (isWindows) {
                if (/^file:\/\/\//.test(uri)) {
                    // This is a URI without a hostname => return only the path segment
                    return uri.substr(8);
                }
                if (/^file:\/\//.test(uri)) {
                    return uri.substr(5);
                }
            }
            else {
                if (/^file:\/\//.test(uri)) {
                    return uri.substr(7);
                }
            }
            // Not sure...
            return uri;
        };
        Utilities.startsWith = function (haystack, needle) {
            return haystack.length >= needle.length && haystack.substr(0, needle.length) === needle;
        };
        Utilities.endsWith = function (haystack, needle) {
            return haystack.length >= needle.length && haystack.substr(haystack.length - needle.length) === needle;
        };
        // only check for "?" before "#" to ensure that there is a real Query-String
        Utilities.containsQueryString = function (url) {
            return /^[^\#]*\?/gi.test(url);
        };
        /**
         * Does `url` start with http:// or https:// or file:// or / ?
         */
        Utilities.isAbsolutePath = function (url) {
            return /^((http:\/\/)|(https:\/\/)|(file:\/\/)|(\/))/.test(url);
        };
        Utilities.forEachProperty = function (obj, callback) {
            if (obj) {
                var key = void 0;
                for (key in obj) {
                    if (obj.hasOwnProperty(key)) {
                        callback(key, obj[key]);
                    }
                }
            }
        };
        Utilities.isEmpty = function (obj) {
            var isEmpty = true;
            Utilities.forEachProperty(obj, function () {
                isEmpty = false;
            });
            return isEmpty;
        };
        Utilities.recursiveClone = function (obj) {
            if (!obj || typeof obj !== 'object') {
                return obj;
            }
            var result = Array.isArray(obj) ? [] : {};
            Utilities.forEachProperty(obj, function (key, value) {
                if (value && typeof value === 'object') {
                    result[key] = Utilities.recursiveClone(value);
                }
                else {
                    result[key] = value;
                }
            });
            return result;
        };
        Utilities.generateAnonymousModule = function () {
            return '===anonymous' + (Utilities.NEXT_ANONYMOUS_ID++) + '===';
        };
        Utilities.isAnonymousModule = function (id) {
            return Utilities.startsWith(id, '===anonymous');
        };
        Utilities.getHighPerformanceTimestamp = function () {
            if (!this.PERFORMANCE_NOW_PROBED) {
                this.PERFORMANCE_NOW_PROBED = true;
                this.HAS_PERFORMANCE_NOW = (AMDLoader.global.performance && typeof AMDLoader.global.performance.now === 'function');
            }
            return (this.HAS_PERFORMANCE_NOW ? AMDLoader.global.performance.now() : Date.now());
        };
        return Utilities;
    }());
    Utilities.NEXT_ANONYMOUS_ID = 1;
    Utilities.PERFORMANCE_NOW_PROBED = false;
    Utilities.HAS_PERFORMANCE_NOW = false;
    AMDLoader.Utilities = Utilities;
})(AMDLoader || (AMDLoader = {}));
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
var AMDLoader;
(function (AMDLoader) {
    var ConfigurationOptionsUtil = (function () {
        function ConfigurationOptionsUtil() {
        }
        /**
         * Ensure configuration options make sense
         */
        ConfigurationOptionsUtil.validateConfigurationOptions = function (options) {
            function defaultOnError(err) {
                if (err.errorCode === 'load') {
                    console.error('Loading "' + err.moduleId + '" failed');
                    console.error('Detail: ', err.detail);
                    if (err.detail && err.detail.stack) {
                        console.error(err.detail.stack);
                    }
                    console.error('Here are the modules that depend on it:');
                    console.error(err.neededBy);
                    return;
                }
                if (err.errorCode === 'factory') {
                    console.error('The factory method of "' + err.moduleId + '" has thrown an exception');
                    console.error(err.detail);
                    if (err.detail && err.detail.stack) {
                        console.error(err.detail.stack);
                    }
                    return;
                }
            }
            options = options || {};
            if (typeof options.baseUrl !== 'string') {
                options.baseUrl = '';
            }
            if (typeof options.isBuild !== 'boolean') {
                options.isBuild = false;
            }
            if (typeof options.paths !== 'object') {
                options.paths = {};
            }
            if (typeof options.config !== 'object') {
                options.config = {};
            }
            if (typeof options.catchError === 'undefined') {
                options.catchError = false;
            }
            if (typeof options.urlArgs !== 'string') {
                options.urlArgs = '';
            }
            if (typeof options.onError !== 'function') {
                options.onError = defaultOnError;
            }
            if (typeof options.ignoreDuplicateModules !== 'object' || !Array.isArray(options.ignoreDuplicateModules)) {
                options.ignoreDuplicateModules = [];
            }
            if (options.baseUrl.length > 0) {
                if (!AMDLoader.Utilities.endsWith(options.baseUrl, '/')) {
                    options.baseUrl += '/';
                }
            }
            if (typeof options.cspNonce !== 'string') {
                options.cspNonce = '';
            }
            if (!Array.isArray(options.nodeModules)) {
                options.nodeModules = [];
            }
            if (typeof options.nodeCachedDataWriteDelay !== 'number' || options.nodeCachedDataWriteDelay < 0) {
                options.nodeCachedDataWriteDelay = 1000 * 7;
            }
            if (typeof options.onNodeCachedData !== 'function') {
                options.onNodeCachedData = function (err, data) {
                    if (!err) {
                        // ignore
                    }
                    else if (err.errorCode === 'cachedDataRejected') {
                        console.warn('Rejected cached data from file: ' + err.path);
                    }
                    else if (err.errorCode === 'unlink' || err.errorCode === 'writeFile') {
                        console.error('Problems writing cached data file: ' + err.path);
                        console.error(err.detail);
                    }
                    else {
                        console.error(err);
                    }
                };
            }
            return options;
        };
        ConfigurationOptionsUtil.mergeConfigurationOptions = function (overwrite, base) {
            if (overwrite === void 0) { overwrite = null; }
            if (base === void 0) { base = null; }
            var result = AMDLoader.Utilities.recursiveClone(base || {});
            // Merge known properties and overwrite the unknown ones
            AMDLoader.Utilities.forEachProperty(overwrite, function (key, value) {
                if (key === 'ignoreDuplicateModules' && typeof result.ignoreDuplicateModules !== 'undefined') {
                    result.ignoreDuplicateModules = result.ignoreDuplicateModules.concat(value);
                }
                else if (key === 'paths' && typeof result.paths !== 'undefined') {
                    AMDLoader.Utilities.forEachProperty(value, function (key2, value2) { return result.paths[key2] = value2; });
                }
                else if (key === 'config' && typeof result.config !== 'undefined') {
                    AMDLoader.Utilities.forEachProperty(value, function (key2, value2) { return result.config[key2] = value2; });
                }
                else {
                    result[key] = AMDLoader.Utilities.recursiveClone(value);
                }
            });
            return ConfigurationOptionsUtil.validateConfigurationOptions(result);
        };
        return ConfigurationOptionsUtil;
    }());
    AMDLoader.ConfigurationOptionsUtil = ConfigurationOptionsUtil;
    var Configuration = (function () {
        function Configuration(env, options) {
            this._env = env;
            this.options = ConfigurationOptionsUtil.mergeConfigurationOptions(options);
            this._createIgnoreDuplicateModulesMap();
            this._createNodeModulesMap();
            this._createSortedPathsRules();
            if (this.options.baseUrl === '') {
                if (this.options.nodeRequire && this.options.nodeRequire.main && this.options.nodeRequire.main.filename && this._env.isNode) {
                    var nodeMain = this.options.nodeRequire.main.filename;
                    var dirnameIndex = Math.max(nodeMain.lastIndexOf('/'), nodeMain.lastIndexOf('\\'));
                    this.options.baseUrl = nodeMain.substring(0, dirnameIndex + 1);
                }
                if (this.options.nodeMain && this._env.isNode) {
                    var nodeMain = this.options.nodeMain;
                    var dirnameIndex = Math.max(nodeMain.lastIndexOf('/'), nodeMain.lastIndexOf('\\'));
                    this.options.baseUrl = nodeMain.substring(0, dirnameIndex + 1);
                }
            }
        }
        Configuration.prototype._createIgnoreDuplicateModulesMap = function () {
            // Build a map out of the ignoreDuplicateModules array
            this.ignoreDuplicateModulesMap = {};
            for (var i = 0; i < this.options.ignoreDuplicateModules.length; i++) {
                this.ignoreDuplicateModulesMap[this.options.ignoreDuplicateModules[i]] = true;
            }
        };
        Configuration.prototype._createNodeModulesMap = function () {
            // Build a map out of nodeModules array
            this.nodeModulesMap = Object.create(null);
            for (var _i = 0, _a = this.options.nodeModules; _i < _a.length; _i++) {
                var nodeModule = _a[_i];
                this.nodeModulesMap[nodeModule] = true;
            }
        };
        Configuration.prototype._createSortedPathsRules = function () {
            var _this = this;
            // Create an array our of the paths rules, sorted descending by length to
            // result in a more specific -> less specific order
            this.sortedPathsRules = [];
            AMDLoader.Utilities.forEachProperty(this.options.paths, function (from, to) {
                if (!Array.isArray(to)) {
                    _this.sortedPathsRules.push({
                        from: from,
                        to: [to]
                    });
                }
                else {
                    _this.sortedPathsRules.push({
                        from: from,
                        to: to
                    });
                }
            });
            this.sortedPathsRules.sort(function (a, b) {
                return b.from.length - a.from.length;
            });
        };
        /**
         * Clone current configuration and overwrite options selectively.
         * @param options The selective options to overwrite with.
         * @result A new configuration
         */
        Configuration.prototype.cloneAndMerge = function (options) {
            return new Configuration(this._env, ConfigurationOptionsUtil.mergeConfigurationOptions(options, this.options));
        };
        /**
         * Get current options bag. Useful for passing it forward to plugins.
         */
        Configuration.prototype.getOptionsLiteral = function () {
            return this.options;
        };
        Configuration.prototype._applyPaths = function (moduleId) {
            var pathRule;
            for (var i = 0, len = this.sortedPathsRules.length; i < len; i++) {
                pathRule = this.sortedPathsRules[i];
                if (AMDLoader.Utilities.startsWith(moduleId, pathRule.from)) {
                    var result = [];
                    for (var j = 0, lenJ = pathRule.to.length; j < lenJ; j++) {
                        result.push(pathRule.to[j] + moduleId.substr(pathRule.from.length));
                    }
                    return result;
                }
            }
            return [moduleId];
        };
        Configuration.prototype._addUrlArgsToUrl = function (url) {
            if (AMDLoader.Utilities.containsQueryString(url)) {
                return url + '&' + this.options.urlArgs;
            }
            else {
                return url + '?' + this.options.urlArgs;
            }
        };
        Configuration.prototype._addUrlArgsIfNecessaryToUrl = function (url) {
            if (this.options.urlArgs) {
                return this._addUrlArgsToUrl(url);
            }
            return url;
        };
        Configuration.prototype._addUrlArgsIfNecessaryToUrls = function (urls) {
            if (this.options.urlArgs) {
                for (var i = 0, len = urls.length; i < len; i++) {
                    urls[i] = this._addUrlArgsToUrl(urls[i]);
                }
            }
            return urls;
        };
        /**
         * Transform a module id to a location. Appends .js to module ids
         */
        Configuration.prototype.moduleIdToPaths = function (moduleId) {
            if (this.nodeModulesMap[moduleId] === true) {
                // This is a node module...
                if (this.isBuild()) {
                    // ...and we are at build time, drop it
                    return ['empty:'];
                }
                else {
                    // ...and at runtime we create a `shortcut`-path
                    return ['node|' + moduleId];
                }
            }
            var result = moduleId;
            var results;
            if (!AMDLoader.Utilities.endsWith(result, '.js') && !AMDLoader.Utilities.isAbsolutePath(result)) {
                results = this._applyPaths(result);
                for (var i = 0, len = results.length; i < len; i++) {
                    if (this.isBuild() && results[i] === 'empty:') {
                        continue;
                    }
                    if (!AMDLoader.Utilities.isAbsolutePath(results[i])) {
                        results[i] = this.options.baseUrl + results[i];
                    }
                    if (!AMDLoader.Utilities.endsWith(results[i], '.js') && !AMDLoader.Utilities.containsQueryString(results[i])) {
                        results[i] = results[i] + '.js';
                    }
                }
            }
            else {
                if (!AMDLoader.Utilities.endsWith(result, '.js') && !AMDLoader.Utilities.containsQueryString(result)) {
                    result = result + '.js';
                }
                results = [result];
            }
            return this._addUrlArgsIfNecessaryToUrls(results);
        };
        /**
         * Transform a module id or url to a location.
         */
        Configuration.prototype.requireToUrl = function (url) {
            var result = url;
            if (!AMDLoader.Utilities.isAbsolutePath(result)) {
                result = this._applyPaths(result)[0];
                if (!AMDLoader.Utilities.isAbsolutePath(result)) {
                    result = this.options.baseUrl + result;
                }
            }
            return this._addUrlArgsIfNecessaryToUrl(result);
        };
        /**
         * Flag to indicate if current execution is as part of a build.
         */
        Configuration.prototype.isBuild = function () {
            return this.options.isBuild;
        };
        /**
         * Test if module `moduleId` is expected to be defined multiple times
         */
        Configuration.prototype.isDuplicateMessageIgnoredFor = function (moduleId) {
            return this.ignoreDuplicateModulesMap.hasOwnProperty(moduleId);
        };
        /**
         * Get the configuration settings for the provided module id
         */
        Configuration.prototype.getConfigForModule = function (moduleId) {
            if (this.options.config) {
                return this.options.config[moduleId];
            }
        };
        /**
         * Should errors be caught when executing module factories?
         */
        Configuration.prototype.shouldCatchError = function () {
            return this.options.catchError;
        };
        /**
         * Should statistics be recorded?
         */
        Configuration.prototype.shouldRecordStats = function () {
            return this.options.recordStats;
        };
        /**
         * Forward an error to the error handler.
         */
        Configuration.prototype.onError = function (err) {
            this.options.onError(err);
        };
        return Configuration;
    }());
    AMDLoader.Configuration = Configuration;
})(AMDLoader || (AMDLoader = {}));
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
var AMDLoader;
(function (AMDLoader) {
    /**
     * Load `scriptSrc` only once (avoid multiple <script> tags)
     */
    var OnlyOnceScriptLoader = (function () {
        function OnlyOnceScriptLoader(env) {
            this._env = env;
            this._scriptLoader = null;
            this._callbackMap = {};
        }
        OnlyOnceScriptLoader.prototype.load = function (moduleManager, scriptSrc, callback, errorback) {
            var _this = this;
            if (!this._scriptLoader) {
                this._scriptLoader = (this._env.isWebWorker
                    ? new WorkerScriptLoader()
                    : this._env.isNode
                        ? new NodeScriptLoader(this._env)
                        : new BrowserScriptLoader());
            }
            var scriptCallbacks = {
                callback: callback,
                errorback: errorback
            };
            if (this._callbackMap.hasOwnProperty(scriptSrc)) {
                this._callbackMap[scriptSrc].push(scriptCallbacks);
                return;
            }
            this._callbackMap[scriptSrc] = [scriptCallbacks];
            this._scriptLoader.load(moduleManager, scriptSrc, function () { return _this.triggerCallback(scriptSrc); }, function (err) { return _this.triggerErrorback(scriptSrc, err); });
        };
        OnlyOnceScriptLoader.prototype.triggerCallback = function (scriptSrc) {
            var scriptCallbacks = this._callbackMap[scriptSrc];
            delete this._callbackMap[scriptSrc];
            for (var i = 0; i < scriptCallbacks.length; i++) {
                scriptCallbacks[i].callback();
            }
        };
        OnlyOnceScriptLoader.prototype.triggerErrorback = function (scriptSrc, err) {
            var scriptCallbacks = this._callbackMap[scriptSrc];
            delete this._callbackMap[scriptSrc];
            for (var i = 0; i < scriptCallbacks.length; i++) {
                scriptCallbacks[i].errorback(err);
            }
        };
        return OnlyOnceScriptLoader;
    }());
    var BrowserScriptLoader = (function () {
        function BrowserScriptLoader() {
        }
        /**
         * Attach load / error listeners to a script element and remove them when either one has fired.
         * Implemented for browssers supporting HTML5 standard 'load' and 'error' events.
         */
        BrowserScriptLoader.prototype.attachListeners = function (script, callback, errorback) {
            var unbind = function () {
                script.removeEventListener('load', loadEventListener);
                script.removeEventListener('error', errorEventListener);
            };
            var loadEventListener = function (e) {
                unbind();
                callback();
            };
            var errorEventListener = function (e) {
                unbind();
                errorback(e);
            };
            script.addEventListener('load', loadEventListener);
            script.addEventListener('error', errorEventListener);
        };
        BrowserScriptLoader.prototype.load = function (moduleManager, scriptSrc, callback, errorback) {
            var script = document.createElement('script');
            script.setAttribute('async', 'async');
            script.setAttribute('type', 'text/javascript');
            this.attachListeners(script, callback, errorback);
            script.setAttribute('src', scriptSrc);
            // Propagate CSP nonce to dynamically created script tag.
            var cspNonce = moduleManager.getConfig().getOptionsLiteral().cspNonce;
            if (cspNonce) {
                script.setAttribute('nonce', cspNonce);
            }
            document.getElementsByTagName('head')[0].appendChild(script);
        };
        return BrowserScriptLoader;
    }());
    var WorkerScriptLoader = (function () {
        function WorkerScriptLoader() {
        }
        WorkerScriptLoader.prototype.load = function (moduleManager, scriptSrc, callback, errorback) {
            try {
                importScripts(scriptSrc);
                callback();
            }
            catch (e) {
                errorback(e);
            }
        };
        return WorkerScriptLoader;
    }());
    var NodeScriptLoader = (function () {
        function NodeScriptLoader(env) {
            this._env = env;
            this._didInitialize = false;
            this._didPatchNodeRequire = false;
        }
        NodeScriptLoader.prototype._init = function (nodeRequire) {
            if (this._didInitialize) {
                return;
            }
            this._didInitialize = true;
            // capture node modules
            this._fs = nodeRequire('fs');
            this._vm = nodeRequire('vm');
            this._path = nodeRequire('path');
            this._crypto = nodeRequire('crypto');
            // js-flags have an impact on cached data
            this._jsflags = '';
            for (var _i = 0, _a = process.argv; _i < _a.length; _i++) {
                var arg = _a[_i];
                if (arg.indexOf('--js-flags=') === 0) {
                    this._jsflags = arg;
                    break;
                }
            }
        };
        // patch require-function of nodejs such that we can manually create a script
        // from cached data. this is done by overriding the `Module._compile` function
        NodeScriptLoader.prototype._initNodeRequire = function (nodeRequire, moduleManager) {
            var nodeCachedDataDir = moduleManager.getConfig().getOptionsLiteral().nodeCachedDataDir;
            if (!nodeCachedDataDir || this._didPatchNodeRequire) {
                return;
            }
            this._didPatchNodeRequire = true;
            var that = this;
            var Module = nodeRequire('module');
            function makeRequireFunction(mod) {
                var Module = mod.constructor;
                var require = function require(path) {
                    try {
                        return mod.require(path);
                    }
                    finally {
                        // nothing
                    }
                };
                require.resolve = function resolve(request) {
                    return Module._resolveFilename(request, mod);
                };
                require.main = process.mainModule;
                require.extensions = Module._extensions;
                require.cache = Module._cache;
                return require;
            }
            Module.prototype._compile = function (content, filename) {
                // remove shebang
                content = content.replace(/^#!.*/, '');
                // create wrapper function
                var wrapper = Module.wrap(content);
                var cachedDataPath = that._getCachedDataPath(nodeCachedDataDir, filename);
                var options = { filename: filename };
                try {
                    options.cachedData = that._fs.readFileSync(cachedDataPath);
                }
                catch (e) {
                    options.produceCachedData = true;
                }
                var script = new that._vm.Script(wrapper, options);
                var compileWrapper = script.runInThisContext(options);
                var dirname = that._path.dirname(filename);
                var require = makeRequireFunction(this);
                var args = [this.exports, require, this, filename, dirname, process, _commonjsGlobal, Buffer];
                var result = compileWrapper.apply(this.exports, args);
                that._processCachedData(moduleManager, script, cachedDataPath);
                return result;
            };
        };
        NodeScriptLoader.prototype.load = function (moduleManager, scriptSrc, callback, errorback) {
            var _this = this;
            var opts = moduleManager.getConfig().getOptionsLiteral();
            var nodeRequire = (opts.nodeRequire || AMDLoader.global.nodeRequire);
            var nodeInstrumenter = (opts.nodeInstrumenter || function (c) { return c; });
            this._init(nodeRequire);
            this._initNodeRequire(nodeRequire, moduleManager);
            var recorder = moduleManager.getRecorder();
            if (/^node\|/.test(scriptSrc)) {
                var pieces = scriptSrc.split('|');
                var moduleExports_1 = null;
                try {
                    moduleExports_1 = nodeRequire(pieces[1]);
                }
                catch (err) {
                    errorback(err);
                    return;
                }
                moduleManager.enqueueDefineAnonymousModule([], function () { return moduleExports_1; });
                callback();
            }
            else {
                scriptSrc = AMDLoader.Utilities.fileUriToFilePath(this._env.isWindows, scriptSrc);
                this._fs.readFile(scriptSrc, { encoding: 'utf8' }, function (err, data) {
                    if (err) {
                        errorback(err);
                        return;
                    }
                    var normalizedScriptSrc = _this._path.normalize(scriptSrc);
                    var vmScriptSrc = normalizedScriptSrc;
                    // Make the script src friendly towards electron
                    if (_this._env.isElectronRenderer) {
                        var driveLetterMatch = vmScriptSrc.match(/^([a-z])\:(.*)/i);
                        if (driveLetterMatch) {
                            // windows
                            vmScriptSrc = "file:///" + (driveLetterMatch[1].toUpperCase() + ':' + driveLetterMatch[2]).replace(/\\/g, '/');
                        }
                        else {
                            // nix
                            vmScriptSrc = "file://" + vmScriptSrc;
                        }
                    }
                    var contents, prefix = '(function (require, define, __filename, __dirname) { ', suffix = '\n});';
                    if (data.charCodeAt(0) === NodeScriptLoader._BOM) {
                        contents = prefix + data.substring(1) + suffix;
                    }
                    else {
                        contents = prefix + data + suffix;
                    }
                    contents = nodeInstrumenter(contents, normalizedScriptSrc);
                    if (!opts.nodeCachedDataDir) {
                        _this._loadAndEvalScript(moduleManager, scriptSrc, vmScriptSrc, contents, { filename: vmScriptSrc }, recorder, callback, errorback);
                    }
                    else {
                        var cachedDataPath_1 = _this._getCachedDataPath(opts.nodeCachedDataDir, scriptSrc);
                        _this._fs.readFile(cachedDataPath_1, function (err, cachedData) {
                            // create script options
                            var options = {
                                filename: vmScriptSrc,
                                produceCachedData: typeof cachedData === 'undefined',
                                cachedData: cachedData
                            };
                            var script = _this._loadAndEvalScript(moduleManager, scriptSrc, vmScriptSrc, contents, options, recorder, callback, errorback);
                            _this._processCachedData(moduleManager, script, cachedDataPath_1);
                        });
                    }
                });
            }
        };
        NodeScriptLoader.prototype._loadAndEvalScript = function (moduleManager, scriptSrc, vmScriptSrc, contents, options, recorder, callback, errorback) {
            // create script, run script
            recorder.record(31 /* NodeBeginEvaluatingScript */, scriptSrc);
            var script = new this._vm.Script(contents, options);
            var r = script.runInThisContext(options);
            var globalDefineFunc = moduleManager.getGlobalAMDDefineFunc();
            var receivedDefineCall = false;
            var localDefineFunc = function () {
                receivedDefineCall = true;
                return globalDefineFunc.apply(null, arguments);
            };
            localDefineFunc.amd = globalDefineFunc.amd;
            r.call(AMDLoader.global, moduleManager.getGlobalAMDRequireFunc(), localDefineFunc, vmScriptSrc, this._path.dirname(scriptSrc));
            // signal done
            recorder.record(32 /* NodeEndEvaluatingScript */, scriptSrc);
            if (receivedDefineCall) {
                callback();
            }
            else {
                errorback(new Error("Didn't receive define call in " + scriptSrc + "!"));
            }
            return script;
        };
        NodeScriptLoader.prototype._getCachedDataPath = function (basedir, filename) {
            var hash = this._crypto.createHash('md5').update(filename, 'utf8').update(this._jsflags, 'utf8').digest('hex');
            var basename = this._path.basename(filename).replace(/\.js$/, '');
            return this._path.join(basedir, basename + "-" + hash + ".code");
        };
        NodeScriptLoader.prototype._processCachedData = function (moduleManager, script, cachedDataPath) {
            var _this = this;
            if (script.cachedDataRejected) {
                // data rejected => delete cache file
                moduleManager.getConfig().getOptionsLiteral().onNodeCachedData({
                    errorCode: 'cachedDataRejected',
                    path: cachedDataPath
                });
                NodeScriptLoader._runSoon(function () {
                    return _this._fs.unlink(cachedDataPath, function (err) {
                        if (err) {
                            moduleManager.getConfig().getOptionsLiteral().onNodeCachedData({
                                errorCode: 'unlink',
                                path: cachedDataPath,
                                detail: err
                            });
                        }
                    });
                }, moduleManager.getConfig().getOptionsLiteral().nodeCachedDataWriteDelay);
            }
            else if (script.cachedDataProduced) {
                // data produced => tell outside world
                moduleManager.getConfig().getOptionsLiteral().onNodeCachedData(undefined, {
                    path: cachedDataPath,
                    length: script.cachedData.length
                });
                // data produced => write cache file
                NodeScriptLoader._runSoon(function () {
                    return _this._fs.writeFile(cachedDataPath, script.cachedData, function (err) {
                        if (err) {
                            moduleManager.getConfig().getOptionsLiteral().onNodeCachedData({
                                errorCode: 'writeFile',
                                path: cachedDataPath,
                                detail: err
                            });
                        }
                    });
                }, moduleManager.getConfig().getOptionsLiteral().nodeCachedDataWriteDelay);
            }
        };
        NodeScriptLoader._runSoon = function (callback, minTimeout) {
            var timeout = minTimeout + Math.ceil(Math.random() * minTimeout);
            setTimeout(callback, timeout);
        };
        return NodeScriptLoader;
    }());
    NodeScriptLoader._BOM = 0xFEFF;
    function createScriptLoader(env) {
        return new OnlyOnceScriptLoader(env);
    }
    AMDLoader.createScriptLoader = createScriptLoader;
})(AMDLoader || (AMDLoader = {}));
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
var AMDLoader;
(function (AMDLoader) {
    // ------------------------------------------------------------------------
    // ModuleIdResolver
    var ModuleIdResolver = (function () {
        function ModuleIdResolver(fromModuleId) {
            var lastSlash = fromModuleId.lastIndexOf('/');
            if (lastSlash !== -1) {
                this.fromModulePath = fromModuleId.substr(0, lastSlash + 1);
            }
            else {
                this.fromModulePath = '';
            }
        }
        /**
         * Normalize 'a/../name' to 'name', etc.
         */
        ModuleIdResolver._normalizeModuleId = function (moduleId) {
            var r = moduleId, pattern;
            // replace /./ => /
            pattern = /\/\.\//;
            while (pattern.test(r)) {
                r = r.replace(pattern, '/');
            }
            // replace ^./ => nothing
            r = r.replace(/^\.\//g, '');
            // replace /aa/../ => / (BUT IGNORE /../../)
            pattern = /\/(([^\/])|([^\/][^\/\.])|([^\/\.][^\/])|([^\/][^\/][^\/]+))\/\.\.\//;
            while (pattern.test(r)) {
                r = r.replace(pattern, '/');
            }
            // replace ^aa/../ => nothing (BUT IGNORE ../../)
            r = r.replace(/^(([^\/])|([^\/][^\/\.])|([^\/\.][^\/])|([^\/][^\/][^\/]+))\/\.\.\//, '');
            return r;
        };
        /**
         * Resolve relative module ids
         */
        ModuleIdResolver.prototype.resolveModule = function (moduleId) {
            var result = moduleId;
            if (!AMDLoader.Utilities.isAbsolutePath(result)) {
                if (AMDLoader.Utilities.startsWith(result, './') || AMDLoader.Utilities.startsWith(result, '../')) {
                    result = ModuleIdResolver._normalizeModuleId(this.fromModulePath + result);
                }
            }
            return result;
        };
        return ModuleIdResolver;
    }());
    ModuleIdResolver.ROOT = new ModuleIdResolver('');
    AMDLoader.ModuleIdResolver = ModuleIdResolver;
    // ------------------------------------------------------------------------
    // Module
    var Module = (function () {
        function Module(id, strId, dependencies, callback, errorback, moduleIdResolver) {
            this.id = id;
            this.strId = strId;
            this.dependencies = dependencies;
            this._callback = callback;
            this._errorback = errorback;
            this.moduleIdResolver = moduleIdResolver;
            this.exports = {};
            this.exportsPassedIn = false;
            this.unresolvedDependenciesCount = this.dependencies.length;
            this._isComplete = false;
        }
        Module._safeInvokeFunction = function (callback, args) {
            try {
                return {
                    returnedValue: callback.apply(AMDLoader.global, args),
                    producedError: null
                };
            }
            catch (e) {
                return {
                    returnedValue: null,
                    producedError: e
                };
            }
        };
        Module._invokeFactory = function (config, strModuleId, callback, dependenciesValues) {
            if (config.isBuild() && !AMDLoader.Utilities.isAnonymousModule(strModuleId)) {
                return {
                    returnedValue: null,
                    producedError: null
                };
            }
            if (config.shouldCatchError()) {
                return this._safeInvokeFunction(callback, dependenciesValues);
            }
            return {
                returnedValue: callback.apply(AMDLoader.global, dependenciesValues),
                producedError: null
            };
        };
        Module.prototype.complete = function (recorder, config, dependenciesValues) {
            this._isComplete = true;
            var producedError = null;
            if (this._callback) {
                if (typeof this._callback === 'function') {
                    recorder.record(21 /* BeginInvokeFactory */, this.strId);
                    var r = Module._invokeFactory(config, this.strId, this._callback, dependenciesValues);
                    producedError = r.producedError;
                    recorder.record(22 /* EndInvokeFactory */, this.strId);
                    if (!producedError && typeof r.returnedValue !== 'undefined' && (!this.exportsPassedIn || AMDLoader.Utilities.isEmpty(this.exports))) {
                        this.exports = r.returnedValue;
                    }
                }
                else {
                    this.exports = this._callback;
                }
            }
            if (producedError) {
                config.onError({
                    errorCode: 'factory',
                    moduleId: this.strId,
                    detail: producedError
                });
            }
            this.dependencies = null;
            this._callback = null;
            this._errorback = null;
            this.moduleIdResolver = null;
        };
        /**
         * One of the direct dependencies or a transitive dependency has failed to load.
         */
        Module.prototype.onDependencyError = function (err) {
            if (this._errorback) {
                this._errorback(err);
                return true;
            }
            return false;
        };
        /**
         * Is the current module complete?
         */
        Module.prototype.isComplete = function () {
            return this._isComplete;
        };
        return Module;
    }());
    AMDLoader.Module = Module;
    var ModuleIdProvider = (function () {
        function ModuleIdProvider() {
            this._nextId = 0;
            this._strModuleIdToIntModuleId = new Map();
            this._intModuleIdToStrModuleId = [];
            // Ensure values 0, 1, 2 are assigned accordingly with ModuleId
            this.getModuleId('exports');
            this.getModuleId('module');
            this.getModuleId('require');
        }
        ModuleIdProvider.prototype.getMaxModuleId = function () {
            return this._nextId;
        };
        ModuleIdProvider.prototype.getModuleId = function (strModuleId) {
            var id = this._strModuleIdToIntModuleId.get(strModuleId);
            if (typeof id === 'undefined') {
                id = this._nextId++;
                this._strModuleIdToIntModuleId.set(strModuleId, id);
                this._intModuleIdToStrModuleId[id] = strModuleId;
            }
            return id;
        };
        ModuleIdProvider.prototype.getStrModuleId = function (moduleId) {
            return this._intModuleIdToStrModuleId[moduleId];
        };
        return ModuleIdProvider;
    }());
    var RegularDependency = (function () {
        function RegularDependency(id) {
            this.id = id;
        }
        return RegularDependency;
    }());
    RegularDependency.EXPORTS = new RegularDependency(0 /* EXPORTS */);
    RegularDependency.MODULE = new RegularDependency(1 /* MODULE */);
    RegularDependency.REQUIRE = new RegularDependency(2 /* REQUIRE */);
    AMDLoader.RegularDependency = RegularDependency;
    var PluginDependency = (function () {
        function PluginDependency(id, pluginId, pluginParam) {
            this.id = id;
            this.pluginId = pluginId;
            this.pluginParam = pluginParam;
        }
        return PluginDependency;
    }());
    AMDLoader.PluginDependency = PluginDependency;
    var ModuleManager = (function () {
        function ModuleManager(env, scriptLoader, defineFunc, requireFunc, loaderAvailableTimestamp) {
            if (loaderAvailableTimestamp === void 0) { loaderAvailableTimestamp = 0; }
            this._env = env;
            this._scriptLoader = scriptLoader;
            this._loaderAvailableTimestamp = loaderAvailableTimestamp;
            this._defineFunc = defineFunc;
            this._requireFunc = requireFunc;
            this._moduleIdProvider = new ModuleIdProvider();
            this._config = new AMDLoader.Configuration(this._env);
            this._modules2 = [];
            this._knownModules2 = [];
            this._inverseDependencies2 = [];
            this._inversePluginDependencies2 = new Map();
            this._currentAnnonymousDefineCall = null;
            this._recorder = null;
            this._buildInfoPath = [];
            this._buildInfoDefineStack = [];
            this._buildInfoDependencies = [];
        }
        ModuleManager.prototype.reset = function () {
            return new ModuleManager(this._env, this._scriptLoader, this._defineFunc, this._requireFunc, this._loaderAvailableTimestamp);
        };
        ModuleManager.prototype.getGlobalAMDDefineFunc = function () {
            return this._defineFunc;
        };
        ModuleManager.prototype.getGlobalAMDRequireFunc = function () {
            return this._requireFunc;
        };
        ModuleManager._findRelevantLocationInStack = function (needle, stack) {
            var normalize = function (str) { return str.replace(/\\/g, '/'); };
            var normalizedPath = normalize(needle);
            var stackPieces = stack.split(/\n/);
            for (var i = 0; i < stackPieces.length; i++) {
                var m = stackPieces[i].match(/(.*):(\d+):(\d+)\)?$/);
                if (m) {
                    var stackPath = m[1];
                    var stackLine = m[2];
                    var stackColumn = m[3];
                    var trimPathOffset = Math.max(stackPath.lastIndexOf(' ') + 1, stackPath.lastIndexOf('(') + 1);
                    stackPath = stackPath.substr(trimPathOffset);
                    stackPath = normalize(stackPath);
                    if (stackPath === normalizedPath) {
                        var r = {
                            line: parseInt(stackLine, 10),
                            col: parseInt(stackColumn, 10)
                        };
                        if (r.line === 1) {
                            r.col -= '(function (require, define, __filename, __dirname) { '.length;
                        }
                        return r;
                    }
                }
            }
            throw new Error('Could not correlate define call site for needle ' + needle);
        };
        ModuleManager.prototype.getBuildInfo = function () {
            if (!this._config.isBuild()) {
                return null;
            }
            var result = [], resultLen = 0;
            for (var i = 0, len = this._modules2.length; i < len; i++) {
                var m = this._modules2[i];
                if (!m) {
                    continue;
                }
                var location_1 = this._buildInfoPath[m.id] || null;
                var defineStack = this._buildInfoDefineStack[m.id] || null;
                var dependencies = this._buildInfoDependencies[m.id];
                result[resultLen++] = {
                    id: m.strId,
                    path: location_1,
                    defineLocation: (location_1 && defineStack ? ModuleManager._findRelevantLocationInStack(location_1, defineStack) : null),
                    dependencies: dependencies,
                    shim: null,
                    exports: m.exports
                };
            }
            return result;
        };
        ModuleManager.prototype.getRecorder = function () {
            if (!this._recorder) {
                if (this._config.shouldRecordStats()) {
                    this._recorder = new AMDLoader.LoaderEventRecorder(this._loaderAvailableTimestamp);
                }
                else {
                    this._recorder = AMDLoader.NullLoaderEventRecorder.INSTANCE;
                }
            }
            return this._recorder;
        };
        ModuleManager.prototype.getLoaderEvents = function () {
            return this.getRecorder().getEvents();
        };
        /**
         * Defines an anonymous module (without an id). Its name will be resolved as we receive a callback from the scriptLoader.
         * @param dependecies @see defineModule
         * @param callback @see defineModule
         */
        ModuleManager.prototype.enqueueDefineAnonymousModule = function (dependencies, callback) {
            if (this._currentAnnonymousDefineCall !== null) {
                throw new Error('Can only have one anonymous define call per script file');
            }
            var stack = null;
            if (this._config.isBuild()) {
                stack = new Error('StackLocation').stack;
            }
            this._currentAnnonymousDefineCall = {
                stack: stack,
                dependencies: dependencies,
                callback: callback
            };
        };
        /**
         * Creates a module and stores it in _modules. The manager will immediately begin resolving its dependencies.
         * @param strModuleId An unique and absolute id of the module. This must not collide with another module's id
         * @param dependencies An array with the dependencies of the module. Special keys are: "require", "exports" and "module"
         * @param callback if callback is a function, it will be called with the resolved dependencies. if callback is an object, it will be considered as the exports of the module.
         */
        ModuleManager.prototype.defineModule = function (strModuleId, dependencies, callback, errorback, stack, moduleIdResolver) {
            var _this = this;
            if (moduleIdResolver === void 0) { moduleIdResolver = new ModuleIdResolver(strModuleId); }
            var moduleId = this._moduleIdProvider.getModuleId(strModuleId);
            if (this._modules2[moduleId]) {
                if (!this._config.isDuplicateMessageIgnoredFor(strModuleId)) {
                    console.warn('Duplicate definition of module \'' + strModuleId + '\'');
                }
                // Super important! Completely ignore duplicate module definition
                return;
            }
            var m = new Module(moduleId, strModuleId, this._normalizeDependencies(dependencies, moduleIdResolver), callback, errorback, moduleIdResolver);
            this._modules2[moduleId] = m;
            if (this._config.isBuild()) {
                this._buildInfoDefineStack[moduleId] = stack;
                this._buildInfoDependencies[moduleId] = m.dependencies.map(function (dep) { return _this._moduleIdProvider.getStrModuleId(dep.id); });
            }
            // Resolving of dependencies is immediate (not in a timeout). If there's a need to support a packer that concatenates in an
            // unordered manner, in order to finish processing the file, execute the following method in a timeout
            this._resolve(m);
        };
        ModuleManager.prototype._normalizeDependency = function (dependency, moduleIdResolver) {
            if (dependency === 'exports') {
                return RegularDependency.EXPORTS;
            }
            if (dependency === 'module') {
                return RegularDependency.MODULE;
            }
            if (dependency === 'require') {
                return RegularDependency.REQUIRE;
            }
            // Normalize dependency and then request it from the manager
            var bangIndex = dependency.indexOf('!');
            if (bangIndex >= 0) {
                var strPluginId = moduleIdResolver.resolveModule(dependency.substr(0, bangIndex));
                var pluginParam = moduleIdResolver.resolveModule(dependency.substr(bangIndex + 1));
                var dependencyId = this._moduleIdProvider.getModuleId(strPluginId + '!' + pluginParam);
                var pluginId = this._moduleIdProvider.getModuleId(strPluginId);
                return new PluginDependency(dependencyId, pluginId, pluginParam);
            }
            return new RegularDependency(this._moduleIdProvider.getModuleId(moduleIdResolver.resolveModule(dependency)));
        };
        ModuleManager.prototype._normalizeDependencies = function (dependencies, moduleIdResolver) {
            var result = [], resultLen = 0;
            for (var i = 0, len = dependencies.length; i < len; i++) {
                result[resultLen++] = this._normalizeDependency(dependencies[i], moduleIdResolver);
            }
            return result;
        };
        ModuleManager.prototype._relativeRequire = function (moduleIdResolver, dependencies, callback, errorback) {
            if (typeof dependencies === 'string') {
                return this.synchronousRequire(dependencies, moduleIdResolver);
            }
            this.defineModule(AMDLoader.Utilities.generateAnonymousModule(), dependencies, callback, errorback, null, moduleIdResolver);
        };
        /**
         * Require synchronously a module by its absolute id. If the module is not loaded, an exception will be thrown.
         * @param id The unique and absolute id of the required module
         * @return The exports of module 'id'
         */
        ModuleManager.prototype.synchronousRequire = function (_strModuleId, moduleIdResolver) {
            if (moduleIdResolver === void 0) { moduleIdResolver = new ModuleIdResolver(_strModuleId); }
            var dependency = this._normalizeDependency(_strModuleId, moduleIdResolver);
            var m = this._modules2[dependency.id];
            if (!m) {
                throw new Error('Check dependency list! Synchronous require cannot resolve module \'' + _strModuleId + '\'. This is the first mention of this module!');
            }
            if (!m.isComplete()) {
                throw new Error('Check dependency list! Synchronous require cannot resolve module \'' + _strModuleId + '\'. This module has not been resolved completely yet.');
            }
            return m.exports;
        };
        ModuleManager.prototype.configure = function (params, shouldOverwrite) {
            var oldShouldRecordStats = this._config.shouldRecordStats();
            if (shouldOverwrite) {
                this._config = new AMDLoader.Configuration(this._env, params);
            }
            else {
                this._config = this._config.cloneAndMerge(params);
            }
            if (this._config.shouldRecordStats() && !oldShouldRecordStats) {
                this._recorder = null;
            }
        };
        ModuleManager.prototype.getConfig = function () {
            return this._config;
        };
        /**
         * Callback from the scriptLoader when a module has been loaded.
         * This means its code is available and has been executed.
         */
        ModuleManager.prototype._onLoad = function (moduleId) {
            if (this._currentAnnonymousDefineCall !== null) {
                var defineCall = this._currentAnnonymousDefineCall;
                this._currentAnnonymousDefineCall = null;
                // Hit an anonymous define call
                this.defineModule(this._moduleIdProvider.getStrModuleId(moduleId), defineCall.dependencies, defineCall.callback, null, defineCall.stack);
            }
        };
        ModuleManager.prototype._createLoadError = function (moduleId, err) {
            var _this = this;
            var strModuleId = this._moduleIdProvider.getStrModuleId(moduleId);
            var neededBy = (this._inverseDependencies2[moduleId] || []).map(function (intModuleId) { return _this._moduleIdProvider.getStrModuleId(intModuleId); });
            return {
                errorCode: 'load',
                moduleId: strModuleId,
                neededBy: neededBy,
                detail: err
            };
        };
        /**
         * Callback from the scriptLoader when a module hasn't been loaded.
         * This means that the script was not found (e.g. 404) or there was an error in the script.
         */
        ModuleManager.prototype._onLoadError = function (moduleId, err) {
            var error = this._createLoadError(moduleId, err);
            // Find any 'local' error handlers, walk the entire chain of inverse dependencies if necessary.
            var seenModuleId = [];
            for (var i = 0, len = this._moduleIdProvider.getMaxModuleId(); i < len; i++) {
                seenModuleId[i] = false;
            }
            var someoneNotified = false;
            var queue = [];
            queue.push(moduleId);
            seenModuleId[moduleId] = true;
            while (queue.length > 0) {
                var queueElement = queue.shift();
                var m = this._modules2[queueElement];
                if (m) {
                    someoneNotified = m.onDependencyError(error) || someoneNotified;
                }
                var inverseDeps = this._inverseDependencies2[queueElement];
                if (inverseDeps) {
                    for (var i = 0, len = inverseDeps.length; i < len; i++) {
                        var inverseDep = inverseDeps[i];
                        if (!seenModuleId[inverseDep]) {
                            queue.push(inverseDep);
                            seenModuleId[inverseDep] = true;
                        }
                    }
                }
            }
            if (!someoneNotified) {
                this._config.onError(error);
            }
        };
        /**
         * Walks (recursively) the dependencies of 'from' in search of 'to'.
         * Returns true if there is such a path or false otherwise.
         * @param from Module id to start at
         * @param to Module id to look for
         */
        ModuleManager.prototype._hasDependencyPath = function (fromId, toId) {
            var from = this._modules2[fromId];
            if (!from) {
                return false;
            }
            var inQueue = [];
            for (var i = 0, len = this._moduleIdProvider.getMaxModuleId(); i < len; i++) {
                inQueue[i] = false;
            }
            var queue = [];
            // Insert 'from' in queue
            queue.push(from);
            inQueue[fromId] = true;
            while (queue.length > 0) {
                // Pop first inserted element of queue
                var element = queue.shift();
                var dependencies = element.dependencies;
                if (dependencies) {
                    // Walk the element's dependencies
                    for (var i = 0, len = dependencies.length; i < len; i++) {
                        var dependency = dependencies[i];
                        if (dependency.id === toId) {
                            // There is a path to 'to'
                            return true;
                        }
                        var dependencyModule = this._modules2[dependency.id];
                        if (dependencyModule && !inQueue[dependency.id]) {
                            // Insert 'dependency' in queue
                            inQueue[dependency.id] = true;
                            queue.push(dependencyModule);
                        }
                    }
                }
            }
            // There is no path to 'to'
            return false;
        };
        /**
         * Walks (recursively) the dependencies of 'from' in search of 'to'.
         * Returns cycle as array.
         * @param from Module id to start at
         * @param to Module id to look for
         */
        ModuleManager.prototype._findCyclePath = function (fromId, toId, depth) {
            if (fromId === toId || depth === 50) {
                return [fromId];
            }
            var from = this._modules2[fromId];
            if (!from) {
                return null;
            }
            // Walk the element's dependencies
            var dependencies = from.dependencies;
            for (var i = 0, len = dependencies.length; i < len; i++) {
                var path = this._findCyclePath(dependencies[i].id, toId, depth + 1);
                if (path !== null) {
                    path.push(fromId);
                    return path;
                }
            }
            return null;
        };
        /**
         * Create the local 'require' that is passed into modules
         */
        ModuleManager.prototype._createRequire = function (moduleIdResolver) {
            var _this = this;
            var result = (function (dependencies, callback, errorback) {
                return _this._relativeRequire(moduleIdResolver, dependencies, callback, errorback);
            });
            result.toUrl = function (id) {
                return _this._config.requireToUrl(moduleIdResolver.resolveModule(id));
            };
            result.getStats = function () {
                return _this.getLoaderEvents();
            };
            result.__$__nodeRequire = AMDLoader.global.nodeRequire;
            return result;
        };
        ModuleManager.prototype._loadModule = function (moduleId) {
            var _this = this;
            if (this._modules2[moduleId] || this._knownModules2[moduleId]) {
                // known module
                return;
            }
            this._knownModules2[moduleId] = true;
            var strModuleId = this._moduleIdProvider.getStrModuleId(moduleId);
            var paths = this._config.moduleIdToPaths(strModuleId);
            var scopedPackageRegex = /^@[^\/]+\/[^\/]+$/; // matches @scope/package-name
            if (this._env.isNode && (strModuleId.indexOf('/') === -1 || scopedPackageRegex.test(strModuleId))) {
                paths.push('node|' + strModuleId);
            }
            var lastPathIndex = -1;
            var loadNextPath = function (err) {
                lastPathIndex++;
                if (lastPathIndex >= paths.length) {
                    // No more paths to try
                    _this._onLoadError(moduleId, err);
                }
                else {
                    var currentPath_1 = paths[lastPathIndex];
                    var recorder_1 = _this.getRecorder();
                    if (_this._config.isBuild() && currentPath_1 === 'empty:') {
                        _this._buildInfoPath[moduleId] = currentPath_1;
                        _this.defineModule(_this._moduleIdProvider.getStrModuleId(moduleId), [], null, null, null);
                        _this._onLoad(moduleId);
                        return;
                    }
                    recorder_1.record(10 /* BeginLoadingScript */, currentPath_1);
                    _this._scriptLoader.load(_this, currentPath_1, function () {
                        if (_this._config.isBuild()) {
                            _this._buildInfoPath[moduleId] = currentPath_1;
                        }
                        recorder_1.record(11 /* EndLoadingScriptOK */, currentPath_1);
                        _this._onLoad(moduleId);
                    }, function (err) {
                        recorder_1.record(12 /* EndLoadingScriptError */, currentPath_1);
                        loadNextPath(err);
                    });
                }
            };
            loadNextPath(null);
        };
        /**
         * Resolve a plugin dependency with the plugin loaded & complete
         * @param module The module that has this dependency
         * @param pluginDependency The semi-normalized dependency that appears in the module. e.g. 'vs/css!./mycssfile'. Only the plugin part (before !) is normalized
         * @param plugin The plugin (what the plugin exports)
         */
        ModuleManager.prototype._loadPluginDependency = function (plugin, pluginDependency) {
            var _this = this;
            if (this._modules2[pluginDependency.id] || this._knownModules2[pluginDependency.id]) {
                // known module
                return;
            }
            this._knownModules2[pluginDependency.id] = true;
            // Delegate the loading of the resource to the plugin
            var load = (function (value) {
                _this.defineModule(_this._moduleIdProvider.getStrModuleId(pluginDependency.id), [], value, null, null);
            });
            load.error = function (err) {
                _this._config.onError(_this._createLoadError(pluginDependency.id, err));
            };
            plugin.load(pluginDependency.pluginParam, this._createRequire(ModuleIdResolver.ROOT), load, this._config.getOptionsLiteral());
        };
        /**
         * Examine the dependencies of module 'module' and resolve them as needed.
         */
        ModuleManager.prototype._resolve = function (module) {
            var _this = this;
            var dependencies = module.dependencies;
            for (var i = 0, len = dependencies.length; i < len; i++) {
                var dependency = dependencies[i];
                if (dependency === RegularDependency.EXPORTS) {
                    module.exportsPassedIn = true;
                    module.unresolvedDependenciesCount--;
                    continue;
                }
                if (dependency === RegularDependency.MODULE) {
                    module.unresolvedDependenciesCount--;
                    continue;
                }
                if (dependency === RegularDependency.REQUIRE) {
                    module.unresolvedDependenciesCount--;
                    continue;
                }
                var dependencyModule = this._modules2[dependency.id];
                if (dependencyModule && dependencyModule.isComplete()) {
                    module.unresolvedDependenciesCount--;
                    continue;
                }
                if (this._hasDependencyPath(dependency.id, module.id)) {
                    console.warn('There is a dependency cycle between \'' + this._moduleIdProvider.getStrModuleId(dependency.id) + '\' and \'' + this._moduleIdProvider.getStrModuleId(module.id) + '\'. The cyclic path follows:');
                    var cyclePath = this._findCyclePath(dependency.id, module.id, 0);
                    cyclePath.reverse();
                    cyclePath.push(dependency.id);
                    console.warn(cyclePath.map(function (id) { return _this._moduleIdProvider.getStrModuleId(id); }).join(' => \n'));
                    // Break the cycle
                    module.unresolvedDependenciesCount--;
                    continue;
                }
                // record inverse dependency
                this._inverseDependencies2[dependency.id] = this._inverseDependencies2[dependency.id] || [];
                this._inverseDependencies2[dependency.id].push(module.id);
                if (dependency instanceof PluginDependency) {
                    var plugin = this._modules2[dependency.pluginId];
                    if (plugin && plugin.isComplete()) {
                        this._loadPluginDependency(plugin.exports, dependency);
                        continue;
                    }
                    // Record dependency for when the plugin gets loaded
                    var inversePluginDeps = this._inversePluginDependencies2.get(dependency.pluginId);
                    if (!inversePluginDeps) {
                        inversePluginDeps = [];
                        this._inversePluginDependencies2.set(dependency.pluginId, inversePluginDeps);
                    }
                    inversePluginDeps.push(dependency);
                    this._loadModule(dependency.pluginId);
                    continue;
                }
                this._loadModule(dependency.id);
            }
            if (module.unresolvedDependenciesCount === 0) {
                this._onModuleComplete(module);
            }
        };
        ModuleManager.prototype._onModuleComplete = function (module) {
            var _this = this;
            var recorder = this.getRecorder();
            if (module.isComplete()) {
                // already done
                return;
            }
            var dependencies = module.dependencies;
            var dependenciesValues = [];
            for (var i = 0, len = dependencies.length; i < len; i++) {
                var dependency = dependencies[i];
                if (dependency === RegularDependency.EXPORTS) {
                    dependenciesValues[i] = module.exports;
                    continue;
                }
                if (dependency === RegularDependency.MODULE) {
                    dependenciesValues[i] = {
                        id: module.strId,
                        config: function () {
                            return _this._config.getConfigForModule(module.strId);
                        }
                    };
                    continue;
                }
                if (dependency === RegularDependency.REQUIRE) {
                    dependenciesValues[i] = this._createRequire(module.moduleIdResolver);
                    continue;
                }
                var dependencyModule = this._modules2[dependency.id];
                if (dependencyModule) {
                    dependenciesValues[i] = dependencyModule.exports;
                    continue;
                }
                dependenciesValues[i] = null;
            }
            module.complete(recorder, this._config, dependenciesValues);
            // Fetch and clear inverse dependencies
            var inverseDeps = this._inverseDependencies2[module.id];
            this._inverseDependencies2[module.id] = null;
            if (inverseDeps) {
                // Resolve one inverse dependency at a time, always
                // on the lookout for a completed module.
                for (var i = 0, len = inverseDeps.length; i < len; i++) {
                    var inverseDependencyId = inverseDeps[i];
                    var inverseDependency = this._modules2[inverseDependencyId];
                    inverseDependency.unresolvedDependenciesCount--;
                    if (inverseDependency.unresolvedDependenciesCount === 0) {
                        this._onModuleComplete(inverseDependency);
                    }
                }
            }
            var inversePluginDeps = this._inversePluginDependencies2.get(module.id);
            if (inversePluginDeps) {
                // This module is used as a plugin at least once
                // Fetch and clear these inverse plugin dependencies
                this._inversePluginDependencies2.delete(module.id);
                // Resolve plugin dependencies one at a time
                for (var i = 0, len = inversePluginDeps.length; i < len; i++) {
                    this._loadPluginDependency(module.exports, inversePluginDeps[i]);
                }
            }
        };
        return ModuleManager;
    }());
    AMDLoader.ModuleManager = ModuleManager;
})(AMDLoader || (AMDLoader = {}));
var define;
var AMDLoader;
(function (AMDLoader) {
    var env = new AMDLoader.Environment();
    var moduleManager = null;
    var DefineFunc = function (id, dependencies, callback) {
        if (typeof id !== 'string') {
            callback = dependencies;
            dependencies = id;
            id = null;
        }
        if (typeof dependencies !== 'object' || !Array.isArray(dependencies)) {
            callback = dependencies;
            dependencies = null;
        }
        if (!dependencies) {
            dependencies = ['require', 'exports', 'module'];
        }
        if (id) {
            moduleManager.defineModule(id, dependencies, callback, null, null);
        }
        else {
            moduleManager.enqueueDefineAnonymousModule(dependencies, callback);
        }
    };
    DefineFunc.amd = {
        jQuery: true
    };
    var _requireFunc_config = function (params, shouldOverwrite) {
        if (shouldOverwrite === void 0) { shouldOverwrite = false; }
        moduleManager.configure(params, shouldOverwrite);
    };
    var RequireFunc = function () {
        if (arguments.length === 1) {
            if ((arguments[0] instanceof Object) && !Array.isArray(arguments[0])) {
                _requireFunc_config(arguments[0]);
                return;
            }
            if (typeof arguments[0] === 'string') {
                return moduleManager.synchronousRequire(arguments[0]);
            }
        }
        if (arguments.length === 2 || arguments.length === 3) {
            if (Array.isArray(arguments[0])) {
                moduleManager.defineModule(AMDLoader.Utilities.generateAnonymousModule(), arguments[0], arguments[1], arguments[2], null);
                return;
            }
        }
        throw new Error('Unrecognized require call');
    };
    RequireFunc.config = _requireFunc_config;
    RequireFunc.getConfig = function () {
        return moduleManager.getConfig().getOptionsLiteral();
    };
    RequireFunc.reset = function () {
        moduleManager = moduleManager.reset();
    };
    RequireFunc.getBuildInfo = function () {
        return moduleManager.getBuildInfo();
    };
    RequireFunc.getStats = function () {
        return moduleManager.getLoaderEvents();
    };
    RequireFunc.define = function () {
        return DefineFunc.apply(null, arguments);
    };
    function init() {
        if (typeof AMDLoader.global.require !== 'undefined' || typeof require !== 'undefined') {
            var _nodeRequire_1 = (AMDLoader.global.require || require);
            if (typeof _nodeRequire_1 === 'function' && typeof _nodeRequire_1.resolve === 'function') {
                // re-expose node's require function
                var nodeRequire = function (what) {
                    moduleManager.getRecorder().record(33 /* NodeBeginNativeRequire */, what);
                    try {
                        return _nodeRequire_1(what);
                    }
                    finally {
                        moduleManager.getRecorder().record(34 /* NodeEndNativeRequire */, what);
                    }
                };
                AMDLoader.global.nodeRequire = nodeRequire;
                RequireFunc.nodeRequire = nodeRequire;
                RequireFunc.__$__nodeRequire = nodeRequire;
            }
        }
        if (env.isNode && !env.isElectronRenderer) {
            module.exports = RequireFunc;
            require = RequireFunc;
        }
        else {
            if (!env.isElectronRenderer) {
                AMDLoader.global.define = DefineFunc;
            }
            AMDLoader.global.require = RequireFunc;
        }
    }
    AMDLoader.init = init;
    if (typeof AMDLoader.global.define !== 'function' || !AMDLoader.global.define.amd) {
        moduleManager = new AMDLoader.ModuleManager(env, AMDLoader.createScriptLoader(env), DefineFunc, RequireFunc, AMDLoader.Utilities.getHighPerformanceTimestamp());
        // The global variable require can configure the loader
        if (typeof AMDLoader.global.require !== 'undefined' && typeof AMDLoader.global.require !== 'function') {
            RequireFunc.config(AMDLoader.global.require);
        }
        // This define is for the local closure defined in node in the case that the loader is concatenated
        define = function () {
            return DefineFunc.apply(null, arguments);
        };
        define.amd = DefineFunc.amd;
        if (typeof doNotInitLoader === 'undefined') {
            init();
        }
    }
})(AMDLoader || (AMDLoader = {}));
