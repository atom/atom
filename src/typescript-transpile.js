// From https://github.com/teppeis/typescript-simple/blob/master/index.js
// with https://github.com/teppeis/typescript-simple/pull/7

var fs = require('fs');
var os = require('os');
var path = require('path');
var ts = require('typescript');
var FILENAME_TS = 'file.ts';
function tss(code, options) {
    if (options) {
        return new tss.TypeScriptSimple(options).compile(code);
    }
    else {
        return defaultTss.compile(code);
    }
}
var tss;
(function (tss) {
    var TypeScriptSimple = (function () {
        /**
         * @param {ts.CompilerOptions=} options TypeScript compile options (some options are ignored)
         */
        function TypeScriptSimple(options, doSemanticChecks) {
            if (options === void 0) { options = {}; }
            if (doSemanticChecks === void 0) { doSemanticChecks = true; }
            this.doSemanticChecks = doSemanticChecks;
            this.service = null;
            this.outputs = {};
            this.files = {};
            if (options.target == null) {
                options.target = ts.ScriptTarget.ES5;
            }
            if (options.module == null) {
                options.module = ts.ModuleKind.None;
            }
            this.options = options;
        }
        /**
         * @param {string} code TypeScript source code to compile
         * @param {string} only needed if you plan to use sourceMaps. Provide the complete filePath relevant to you
         * @return {string} The JavaScript with inline sourceMaps if sourceMaps were enabled
         */
        TypeScriptSimple.prototype.compile = function (code, filename) {
            if (filename === void 0) { filename = FILENAME_TS; }
            if (!this.service) {
                this.service = this.createService();
            }
            var file = this.files[FILENAME_TS];
            file.text = code;
            file.version++;
            return this.toJavaScript(this.service, filename);
        };
        TypeScriptSimple.prototype.createService = function () {
            var _this = this;
            var defaultLib = this.getDefaultLibFilename(this.options);
            var defaultLibPath = path.join(this.getTypeScriptBinDir(), defaultLib);
            this.files[defaultLib] = { version: 0, text: fs.readFileSync(defaultLibPath).toString() };
            this.files[FILENAME_TS] = { version: 0, text: '' };
            var servicesHost = {
                getScriptFileNames: function () { return [_this.getDefaultLibFilename(_this.options), FILENAME_TS]; },
                getScriptVersion: function (filename) { return _this.files[filename] && _this.files[filename].version.toString(); },
                getScriptSnapshot: function (filename) {
                    var file = _this.files[filename];
                    return {
                        getText: function (start, end) { return file.text.substring(start, end); },
                        getLength: function () { return file.text.length; },
                        getLineStartPositions: function () { return []; },
                        getChangeRange: function (oldSnapshot) { return undefined; }
                    };
                },
                getCurrentDirectory: function () { return process.cwd(); },
                getScriptIsOpen: function () { return true; },
                getCompilationSettings: function () { return _this.options; },
                getDefaultLibFilename: function (options) {
                    return _this.getDefaultLibFilename(options);
                },
                log: function (message) { return console.log(message); }
            };
            return ts.createLanguageService(servicesHost, ts.createDocumentRegistry());
        };
        TypeScriptSimple.prototype.getTypeScriptBinDir = function () {
            return path.dirname(require.resolve('typescript'));
        };
        TypeScriptSimple.prototype.getDefaultLibFilename = function (options) {
            if (options.target === ts.ScriptTarget.ES6) {
                return 'lib.es6.d.ts';
            }
            else {
                return 'lib.d.ts';
            }
        };
        /**
         * converts {"version":3,"file":"file.js","sourceRoot":"","sources":["file.ts"],"names":[],"mappings":"AAAA,IAAI,CAAC,GAAG,MAAM,CAAC"}
         * to {"version":3,"sources":["foo/test.ts"],"names":[],"mappings":"AAAA,IAAI,CAAC,GAAG,MAAM,CAAC","file":"foo/test.ts","sourcesContent":["var x = 'test';"]}
         * derived from : https://github.com/thlorenz/convert-source-map
         */
        TypeScriptSimple.prototype.getInlineSourceMap = function (mapText, filename) {
            var sourceMap = JSON.parse(mapText);
            sourceMap.file = filename;
            sourceMap.sources = [filename];
            sourceMap.sourcesContent = [this.files[FILENAME_TS].text];
            delete sourceMap.sourceRoot;
            return JSON.stringify(sourceMap);
        };
        TypeScriptSimple.prototype.toJavaScript = function (service, filename) {
            if (filename === void 0) { filename = FILENAME_TS; }
            var output = service.getEmitOutput(FILENAME_TS);
            // Meaning of succeeded is driven by whether we need to check for semantic errors or not
            var succeeded = output.emitOutputStatus === ts.EmitReturnStatus.Succeeded;
            if (!this.doSemanticChecks) {
                // We have an output. It implies syntactic success
                if (!succeeded)
                    succeeded = !!output.outputFiles.length;
            }
            if (succeeded) {
                var outputFilename = FILENAME_TS.replace(/ts$/, 'js');
                var file = output.outputFiles.filter(function (file) { return file.name === outputFilename; })[0];
                // Fixed in v1.5 https://github.com/Microsoft/TypeScript/issues/1653
                var text = file.text.replace(/\r\n/g, os.EOL);
                // If we have sourceMaps convert them to inline sourceMaps
                if (this.options.sourceMap) {
                    var sourceMapFilename = FILENAME_TS.replace(/ts$/, 'js.map');
                    var sourceMapFile = output.outputFiles.filter(function (file) { return file.name === sourceMapFilename; })[0];
                    // Transform sourcemap
                    var sourceMapText = sourceMapFile.text;
                    sourceMapText = this.getInlineSourceMap(sourceMapText, filename);
                    var base64SourceMapText = new Buffer(sourceMapText).toString('base64');
                    text = text.replace('//# sourceMappingURL=' + sourceMapFilename, '//# sourceMappingURL=data:application/json;base64,' + base64SourceMapText);
                }
                return text;
            }
            var allDiagnostics = service.getCompilerOptionsDiagnostics().concat(service.getSyntacticDiagnostics(FILENAME_TS));
            if (this.doSemanticChecks)
                allDiagnostics = allDiagnostics.concat(service.getSemanticDiagnostics(FILENAME_TS));
            throw new Error(this.formatDiagnostics(allDiagnostics));
        };
        TypeScriptSimple.prototype.formatDiagnostics = function (diagnostics) {
            return diagnostics.map(function (d) {
                if (d.file) {
                    return 'L' + d.file.getLineAndCharacterFromPosition(d.start).line + ': ' + d.messageText;
                }
                else {
                    return d.messageText;
                }
            }).join(os.EOL);
        };
        return TypeScriptSimple;
    })();
    tss.TypeScriptSimple = TypeScriptSimple;
})(tss || (tss = {}));
var defaultTss = new tss.TypeScriptSimple();
module.exports = tss;
