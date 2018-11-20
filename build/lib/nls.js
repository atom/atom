"use strict";
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
const ts = require("typescript");
const lazy = require("lazy.js");
const event_stream_1 = require("event-stream");
const File = require("vinyl");
const sm = require("source-map");
const path = require("path");
var CollectStepResult;
(function (CollectStepResult) {
    CollectStepResult[CollectStepResult["Yes"] = 0] = "Yes";
    CollectStepResult[CollectStepResult["YesAndRecurse"] = 1] = "YesAndRecurse";
    CollectStepResult[CollectStepResult["No"] = 2] = "No";
    CollectStepResult[CollectStepResult["NoAndRecurse"] = 3] = "NoAndRecurse";
})(CollectStepResult || (CollectStepResult = {}));
function collect(node, fn) {
    const result = [];
    function loop(node) {
        const stepResult = fn(node);
        if (stepResult === CollectStepResult.Yes || stepResult === CollectStepResult.YesAndRecurse) {
            result.push(node);
        }
        if (stepResult === CollectStepResult.YesAndRecurse || stepResult === CollectStepResult.NoAndRecurse) {
            ts.forEachChild(node, loop);
        }
    }
    loop(node);
    return result;
}
function clone(object) {
    const result = {};
    for (const id in object) {
        result[id] = object[id];
    }
    return result;
}
function template(lines) {
    let indent = '', wrap = '';
    if (lines.length > 1) {
        indent = '\t';
        wrap = '\n';
    }
    return `/*---------------------------------------------------------
 * Copyright (C) Microsoft Corporation. All rights reserved.
 *--------------------------------------------------------*/
define([], [${wrap + lines.map(l => indent + l).join(',\n') + wrap}]);`;
}
/**
 * Returns a stream containing the patched JavaScript and source maps.
 */
function nls() {
    const input = event_stream_1.through();
    const output = input.pipe(event_stream_1.through(function (f) {
        if (!f.sourceMap) {
            return this.emit('error', new Error(`File ${f.relative} does not have sourcemaps.`));
        }
        let source = f.sourceMap.sources[0];
        if (!source) {
            return this.emit('error', new Error(`File ${f.relative} does not have a source in the source map.`));
        }
        const root = f.sourceMap.sourceRoot;
        if (root) {
            source = path.join(root, source);
        }
        const typescript = f.sourceMap.sourcesContent[0];
        if (!typescript) {
            return this.emit('error', new Error(`File ${f.relative} does not have the original content in the source map.`));
        }
        nls.patchFiles(f, typescript).forEach(f => this.emit('data', f));
    }));
    return event_stream_1.duplex(input, output);
}
function isImportNode(node) {
    return node.kind === ts.SyntaxKind.ImportDeclaration || node.kind === ts.SyntaxKind.ImportEqualsDeclaration;
}
(function (nls_1) {
    function fileFrom(file, contents, path = file.path) {
        return new File({
            contents: Buffer.from(contents),
            base: file.base,
            cwd: file.cwd,
            path: path
        });
    }
    nls_1.fileFrom = fileFrom;
    function mappedPositionFrom(source, lc) {
        return { source, line: lc.line + 1, column: lc.character };
    }
    nls_1.mappedPositionFrom = mappedPositionFrom;
    function lcFrom(position) {
        return { line: position.line - 1, character: position.column };
    }
    nls_1.lcFrom = lcFrom;
    class SingleFileServiceHost {
        constructor(options, filename, contents) {
            this.options = options;
            this.filename = filename;
            this.getCompilationSettings = () => this.options;
            this.getScriptFileNames = () => [this.filename];
            this.getScriptVersion = () => '1';
            this.getScriptSnapshot = (name) => name === this.filename ? this.file : this.lib;
            this.getCurrentDirectory = () => '';
            this.getDefaultLibFileName = () => 'lib.d.ts';
            this.file = ts.ScriptSnapshot.fromString(contents);
            this.lib = ts.ScriptSnapshot.fromString('');
        }
    }
    nls_1.SingleFileServiceHost = SingleFileServiceHost;
    function isCallExpressionWithinTextSpanCollectStep(textSpan, node) {
        if (!ts.textSpanContainsTextSpan({ start: node.pos, length: node.end - node.pos }, textSpan)) {
            return CollectStepResult.No;
        }
        return node.kind === ts.SyntaxKind.CallExpression ? CollectStepResult.YesAndRecurse : CollectStepResult.NoAndRecurse;
    }
    function analyze(contents, options = {}) {
        const filename = 'file.ts';
        const serviceHost = new SingleFileServiceHost(Object.assign(clone(options), { noResolve: true }), filename, contents);
        const service = ts.createLanguageService(serviceHost);
        const sourceFile = ts.createSourceFile(filename, contents, ts.ScriptTarget.ES5, true);
        // all imports
        const imports = lazy(collect(sourceFile, n => isImportNode(n) ? CollectStepResult.YesAndRecurse : CollectStepResult.NoAndRecurse));
        // import nls = require('vs/nls');
        const importEqualsDeclarations = imports
            .filter(n => n.kind === ts.SyntaxKind.ImportEqualsDeclaration)
            .map(n => n)
            .filter(d => d.moduleReference.kind === ts.SyntaxKind.ExternalModuleReference)
            .filter(d => d.moduleReference.expression.getText() === '\'vs/nls\'');
        // import ... from 'vs/nls';
        const importDeclarations = imports
            .filter(n => n.kind === ts.SyntaxKind.ImportDeclaration)
            .map(n => n)
            .filter(d => d.moduleSpecifier.kind === ts.SyntaxKind.StringLiteral)
            .filter(d => d.moduleSpecifier.getText() === '\'vs/nls\'')
            .filter(d => !!d.importClause && !!d.importClause.namedBindings);
        const nlsExpressions = importEqualsDeclarations
            .map(d => d.moduleReference.expression)
            .concat(importDeclarations.map(d => d.moduleSpecifier))
            .map(d => ({
            start: ts.getLineAndCharacterOfPosition(sourceFile, d.getStart()),
            end: ts.getLineAndCharacterOfPosition(sourceFile, d.getEnd())
        }));
        // `nls.localize(...)` calls
        const nlsLocalizeCallExpressions = importDeclarations
            .filter(d => !!(d.importClause && d.importClause.namedBindings && d.importClause.namedBindings.kind === ts.SyntaxKind.NamespaceImport))
            .map(d => d.importClause.namedBindings.name)
            .concat(importEqualsDeclarations.map(d => d.name))
            // find read-only references to `nls`
            .map(n => service.getReferencesAtPosition(filename, n.pos + 1))
            .flatten()
            .filter(r => !r.isWriteAccess)
            // find the deepest call expressions AST nodes that contain those references
            .map(r => collect(sourceFile, n => isCallExpressionWithinTextSpanCollectStep(r.textSpan, n)))
            .map(a => lazy(a).last())
            .filter(n => !!n)
            .map(n => n)
            // only `localize` calls
            .filter(n => n.expression.kind === ts.SyntaxKind.PropertyAccessExpression && n.expression.name.getText() === 'localize');
        // `localize` named imports
        const allLocalizeImportDeclarations = importDeclarations
            .filter(d => !!(d.importClause && d.importClause.namedBindings && d.importClause.namedBindings.kind === ts.SyntaxKind.NamedImports))
            .map(d => [].concat(d.importClause.namedBindings.elements))
            .flatten();
        // `localize` read-only references
        const localizeReferences = allLocalizeImportDeclarations
            .filter(d => d.name.getText() === 'localize')
            .map(n => service.getReferencesAtPosition(filename, n.pos + 1))
            .flatten()
            .filter(r => !r.isWriteAccess);
        // custom named `localize` read-only references
        const namedLocalizeReferences = allLocalizeImportDeclarations
            .filter(d => d.propertyName && d.propertyName.getText() === 'localize')
            .map(n => service.getReferencesAtPosition(filename, n.name.pos + 1))
            .flatten()
            .filter(r => !r.isWriteAccess);
        // find the deepest call expressions AST nodes that contain those references
        const localizeCallExpressions = localizeReferences
            .concat(namedLocalizeReferences)
            .map(r => collect(sourceFile, n => isCallExpressionWithinTextSpanCollectStep(r.textSpan, n)))
            .map(a => lazy(a).last())
            .filter(n => !!n)
            .map(n => n);
        // collect everything
        const localizeCalls = nlsLocalizeCallExpressions
            .concat(localizeCallExpressions)
            .map(e => e.arguments)
            .filter(a => a.length > 1)
            .sort((a, b) => a[0].getStart() - b[0].getStart())
            .map(a => ({
            keySpan: { start: ts.getLineAndCharacterOfPosition(sourceFile, a[0].getStart()), end: ts.getLineAndCharacterOfPosition(sourceFile, a[0].getEnd()) },
            key: a[0].getText(),
            valueSpan: { start: ts.getLineAndCharacterOfPosition(sourceFile, a[1].getStart()), end: ts.getLineAndCharacterOfPosition(sourceFile, a[1].getEnd()) },
            value: a[1].getText()
        }));
        return {
            localizeCalls: localizeCalls.toArray(),
            nlsExpressions: nlsExpressions.toArray()
        };
    }
    nls_1.analyze = analyze;
    class TextModel {
        constructor(contents) {
            const regex = /\r\n|\r|\n/g;
            let index = 0;
            let match;
            this.lines = [];
            this.lineEndings = [];
            while (match = regex.exec(contents)) {
                this.lines.push(contents.substring(index, match.index));
                this.lineEndings.push(match[0]);
                index = regex.lastIndex;
            }
            if (contents.length > 0) {
                this.lines.push(contents.substring(index, contents.length));
                this.lineEndings.push('');
            }
        }
        get(index) {
            return this.lines[index];
        }
        set(index, line) {
            this.lines[index] = line;
        }
        get lineCount() {
            return this.lines.length;
        }
        /**
         * Applies patch(es) to the model.
         * Multiple patches must be ordered.
         * Does not support patches spanning multiple lines.
         */
        apply(patch) {
            const startLineNumber = patch.span.start.line;
            const endLineNumber = patch.span.end.line;
            const startLine = this.lines[startLineNumber] || '';
            const endLine = this.lines[endLineNumber] || '';
            this.lines[startLineNumber] = [
                startLine.substring(0, patch.span.start.character),
                patch.content,
                endLine.substring(patch.span.end.character)
            ].join('');
            for (let i = startLineNumber + 1; i <= endLineNumber; i++) {
                this.lines[i] = '';
            }
        }
        toString() {
            return lazy(this.lines).zip(this.lineEndings)
                .flatten().toArray().join('');
        }
    }
    nls_1.TextModel = TextModel;
    function patchJavascript(patches, contents, moduleId) {
        const model = new nls.TextModel(contents);
        // patch the localize calls
        lazy(patches).reverse().each(p => model.apply(p));
        // patch the 'vs/nls' imports
        const firstLine = model.get(0);
        const patchedFirstLine = firstLine.replace(/(['"])vs\/nls\1/g, `$1vs/nls!${moduleId}$1`);
        model.set(0, patchedFirstLine);
        return model.toString();
    }
    nls_1.patchJavascript = patchJavascript;
    function patchSourcemap(patches, rsm, smc) {
        const smg = new sm.SourceMapGenerator({
            file: rsm.file,
            sourceRoot: rsm.sourceRoot
        });
        patches = patches.reverse();
        let currentLine = -1;
        let currentLineDiff = 0;
        let source = null;
        smc.eachMapping(m => {
            const patch = patches[patches.length - 1];
            const original = { line: m.originalLine, column: m.originalColumn };
            const generated = { line: m.generatedLine, column: m.generatedColumn };
            if (currentLine !== generated.line) {
                currentLineDiff = 0;
            }
            currentLine = generated.line;
            generated.column += currentLineDiff;
            if (patch && m.generatedLine - 1 === patch.span.end.line && m.generatedColumn === patch.span.end.character) {
                const originalLength = patch.span.end.character - patch.span.start.character;
                const modifiedLength = patch.content.length;
                const lengthDiff = modifiedLength - originalLength;
                currentLineDiff += lengthDiff;
                generated.column += lengthDiff;
                patches.pop();
            }
            source = rsm.sourceRoot ? path.relative(rsm.sourceRoot, m.source) : m.source;
            source = source.replace(/\\/g, '/');
            smg.addMapping({ source, name: m.name, original, generated });
        }, null, sm.SourceMapConsumer.GENERATED_ORDER);
        if (source) {
            smg.setSourceContent(source, smc.sourceContentFor(source));
        }
        return JSON.parse(smg.toString());
    }
    nls_1.patchSourcemap = patchSourcemap;
    function patch(moduleId, typescript, javascript, sourcemap) {
        const { localizeCalls, nlsExpressions } = analyze(typescript);
        if (localizeCalls.length === 0) {
            return { javascript, sourcemap };
        }
        const nlsKeys = template(localizeCalls.map(lc => lc.key));
        const nls = template(localizeCalls.map(lc => lc.value));
        const smc = new sm.SourceMapConsumer(sourcemap);
        const positionFrom = mappedPositionFrom.bind(null, sourcemap.sources[0]);
        let i = 0;
        // build patches
        const patches = lazy(localizeCalls)
            .map(lc => ([
            { range: lc.keySpan, content: '' + (i++) },
            { range: lc.valueSpan, content: 'null' }
        ]))
            .flatten()
            .map(c => {
            const start = lcFrom(smc.generatedPositionFor(positionFrom(c.range.start)));
            const end = lcFrom(smc.generatedPositionFor(positionFrom(c.range.end)));
            return { span: { start, end }, content: c.content };
        })
            .toArray();
        javascript = patchJavascript(patches, javascript, moduleId);
        // since imports are not within the sourcemap information,
        // we must do this MacGyver style
        if (nlsExpressions.length) {
            javascript = javascript.replace(/^define\(.*$/m, line => {
                return line.replace(/(['"])vs\/nls\1/g, `$1vs/nls!${moduleId}$1`);
            });
        }
        sourcemap = patchSourcemap(patches, sourcemap, smc);
        return { javascript, sourcemap, nlsKeys, nls };
    }
    nls_1.patch = patch;
    function patchFiles(javascriptFile, typescript) {
        // hack?
        const moduleId = javascriptFile.relative
            .replace(/\.js$/, '')
            .replace(/\\/g, '/');
        const { javascript, sourcemap, nlsKeys, nls } = patch(moduleId, typescript, javascriptFile.contents.toString(), javascriptFile.sourceMap);
        const result = [fileFrom(javascriptFile, javascript)];
        result[0].sourceMap = sourcemap;
        if (nlsKeys) {
            result.push(fileFrom(javascriptFile, nlsKeys, javascriptFile.path.replace(/\.js$/, '.nls.keys.js')));
        }
        if (nls) {
            result.push(fileFrom(javascriptFile, nls, javascriptFile.path.replace(/\.js$/, '.nls.js')));
        }
        return result;
    }
    nls_1.patchFiles = patchFiles;
})(nls || (nls = {}));
module.exports = nls;
