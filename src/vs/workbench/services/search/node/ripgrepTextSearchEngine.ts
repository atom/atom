/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as cp from 'child_process';
import { EventEmitter } from 'events';
import * as path from 'path';
import { NodeStringDecoder, StringDecoder } from 'string_decoder';
import { createRegExp, startsWith, startsWithUTF8BOM, stripUTF8BOM } from 'vs/base/common/strings';
import { URI } from 'vs/base/common/uri';
import { IExtendedExtensionSearchOptions, SearchError, SearchErrorCode, serializeSearchError } from 'vs/platform/search/common/search';
import * as vscode from 'vscode';
import { rgPath } from 'vscode-ripgrep';
import { anchorGlob, createTextSearchResult, IOutputChannel, Maybe, Range } from './ripgrepSearchUtils';

// If vscode-ripgrep is in an .asar file, then the binary is unpacked.
const rgDiskPath = rgPath.replace(/\bnode_modules\.asar\b/, 'node_modules.asar.unpacked');

export class RipgrepTextSearchEngine {

	constructor(private outputChannel: IOutputChannel) { }

	provideTextSearchResults(query: vscode.TextSearchQuery, options: vscode.TextSearchOptions, progress: vscode.Progress<vscode.TextSearchResult>, token: vscode.CancellationToken): Thenable<vscode.TextSearchComplete> {
		this.outputChannel.appendLine(`provideTextSearchResults ${query.pattern}, ${JSON.stringify({
			...options,
			...{
				folder: options.folder.toString()
			}
		})}`);

		return new Promise((resolve, reject) => {
			token.onCancellationRequested(() => cancel());

			const rgArgs = getRgArgs(query, options);

			const cwd = options.folder.fsPath;

			const escapedArgs = rgArgs
				.map(arg => arg.match(/^-/) ? arg : `'${arg}'`)
				.join(' ');
			this.outputChannel.appendLine(`rg ${escapedArgs}\n - cwd: ${cwd}`);

			let rgProc: Maybe<cp.ChildProcess> = cp.spawn(rgDiskPath, rgArgs, { cwd });
			rgProc.on('error', e => {
				console.error(e);
				this.outputChannel.appendLine('Error: ' + (e && e.message));
				reject(serializeSearchError(new SearchError(e && e.message, SearchErrorCode.rgProcessError)));
			});

			let gotResult = false;
			const ripgrepParser = new RipgrepParser(options.maxResults, cwd, options.previewOptions);
			ripgrepParser.on('result', (match: vscode.TextSearchResult) => {
				gotResult = true;
				progress.report(match);
			});

			let isDone = false;
			const cancel = () => {
				isDone = true;

				if (rgProc) {
					rgProc.kill();
				}

				if (ripgrepParser) {
					ripgrepParser.cancel();
				}
			};

			let limitHit = false;
			ripgrepParser.on('hitLimit', () => {
				limitHit = true;
				cancel();
			});

			rgProc.stdout.on('data', data => {
				ripgrepParser.handleData(data);
			});

			let gotData = false;
			rgProc.stdout.once('data', () => gotData = true);

			let stderr = '';
			rgProc.stderr.on('data', data => {
				const message = data.toString();
				this.outputChannel.appendLine(message);
				stderr += message;
			});

			rgProc.on('close', () => {
				this.outputChannel.appendLine(gotData ? 'Got data from stdout' : 'No data from stdout');
				this.outputChannel.appendLine(gotResult ? 'Got result from parser' : 'No result from parser');
				this.outputChannel.appendLine('');
				if (isDone) {
					resolve({ limitHit });
				} else {
					// Trigger last result
					ripgrepParser.flush();
					rgProc = null;
					let searchError: Maybe<SearchError>;
					if (stderr && !gotData && (searchError = rgErrorMsgForDisplay(stderr))) {
						reject(serializeSearchError(new SearchError(searchError.message, searchError.code)));
					} else {
						resolve({ limitHit });
					}
				}
			});
		});
	}
}

/**
 * Read the first line of stderr and return an error for display or undefined, based on a whitelist.
 * Ripgrep produces stderr output which is not from a fatal error, and we only want the search to be
 * "failed" when a fatal error was produced.
 */
export function rgErrorMsgForDisplay(msg: string): Maybe<SearchError> {
	const firstLine = msg.split('\n')[0].trim();

	if (startsWith(firstLine, 'regex parse error')) {
		return new SearchError('Regex parse error', SearchErrorCode.regexParseError);
	}

	let match = firstLine.match(/grep config error: unknown encoding: (.*)/);
	if (match) {
		return new SearchError(`Unknown encoding: ${match[1]}`, SearchErrorCode.unknownEncoding);
	}

	if (startsWith(firstLine, 'error parsing glob')) {
		// Uppercase first letter
		return new SearchError(firstLine.charAt(0).toUpperCase() + firstLine.substr(1), SearchErrorCode.globParseError);
	}

	if (startsWith(firstLine, 'the literal')) {
		// Uppercase first letter
		return new SearchError(firstLine.charAt(0).toUpperCase() + firstLine.substr(1), SearchErrorCode.invalidLiteral);
	}

	return undefined;
}

export class RipgrepParser extends EventEmitter {
	private remainder = '';
	private isDone = false;
	private hitLimit = false;
	private stringDecoder: NodeStringDecoder;

	private numResults = 0;

	constructor(private maxResults: number, private rootFolder: string, private previewOptions?: vscode.TextSearchPreviewOptions) {
		super();
		this.stringDecoder = new StringDecoder();
	}

	public cancel(): void {
		this.isDone = true;
	}

	public flush(): void {
		this.handleDecodedData(this.stringDecoder.end());
	}

	public handleData(data: Buffer | string): void {
		const dataStr = typeof data === 'string' ? data : this.stringDecoder.write(data);
		this.handleDecodedData(dataStr);
	}

	private handleDecodedData(decodedData: string): void {
		// If the previous data chunk didn't end in a newline, prepend it to this chunk
		const dataStr = this.remainder ?
			this.remainder + decodedData :
			decodedData;

		const dataLines: string[] = dataStr.split(/\r\n|\n/);
		this.remainder = dataLines[dataLines.length - 1] ? <string>dataLines.pop() : '';

		for (let l = 0; l < dataLines.length; l++) {
			const line = dataLines[l];
			if (line) { // Empty line at the end of each chunk
				this.handleLine(line);
			}
		}
	}

	private handleLine(outputLine: string): void {
		if (this.isDone) {
			return;
		}

		let parsedLine: IRgMessage;
		try {
			parsedLine = JSON.parse(outputLine);
		} catch (e) {
			throw new Error(`malformed line from rg: ${outputLine}`);
		}

		if (parsedLine.type === 'match') {
			const matchPath = bytesOrTextToString(parsedLine.data.path);
			const uri = URI.file(path.join(this.rootFolder, matchPath));
			const result = this.createTextSearchMatch(parsedLine.data, uri);
			this.onResult(result);

			if (this.hitLimit) {
				this.cancel();
				this.emit('hitLimit');
			}
		} else if (parsedLine.type === 'context') {
			const contextPath = bytesOrTextToString(parsedLine.data.path);
			const uri = URI.file(path.join(this.rootFolder, contextPath));
			const result = this.createTextSearchContext(parsedLine.data, uri);
			result.forEach(r => this.onResult(r));
		}
	}

	private createTextSearchMatch(data: IRgMatch, uri: vscode.Uri): vscode.TextSearchMatch {
		const lineNumber = data.line_number - 1;
		const fullText = bytesOrTextToString(data.lines);
		const fullTextBytes = Buffer.from(fullText);

		let prevMatchEnd = 0;
		let prevMatchEndCol = 0;
		let prevMatchEndLine = lineNumber;
		const ranges = data.submatches.map((match, i) => {
			if (this.hitLimit) {
				return null;
			}

			this.numResults++;
			if (this.numResults >= this.maxResults) {
				// Finish the line, then report the result below
				this.hitLimit = true;
			}

			let matchText = bytesOrTextToString(match.match);
			const inBetweenChars = fullTextBytes.slice(prevMatchEnd, match.start).toString().length;
			let startCol = prevMatchEndCol + inBetweenChars;

			const stats = getNumLinesAndLastNewlineLength(matchText);
			let startLineNumber = prevMatchEndLine;
			let endLineNumber = stats.numLines + startLineNumber;
			let endCol = stats.numLines > 0 ?
				stats.lastLineLength :
				stats.lastLineLength + startCol;

			if (lineNumber === 0 && i === 0 && startsWithUTF8BOM(matchText)) {
				matchText = stripUTF8BOM(matchText);
				startCol -= 3;
				endCol -= 3;
			}

			prevMatchEnd = match.end;
			prevMatchEndCol = endCol;
			prevMatchEndLine = endLineNumber;

			return new Range(startLineNumber, startCol, endLineNumber, endCol);
		})
			.filter(r => !!r);

		return createTextSearchResult(uri, fullText, <Range[]>ranges, this.previewOptions);
	}

	private createTextSearchContext(data: IRgMatch, uri: URI): vscode.TextSearchContext[] {
		const text = bytesOrTextToString(data.lines);
		const startLine = data.line_number;
		return text
			.replace(/\r?\n$/, '')
			.split('\n')
			.map((line, i) => {
				return {
					text: line,
					uri,
					lineNumber: startLine + i
				};
			});
	}

	private onResult(match: vscode.TextSearchResult): void {
		this.emit('result', match);
	}
}

function bytesOrTextToString(obj: any): string {
	return obj.bytes ?
		Buffer.from(obj.bytes, 'base64').toString() :
		obj.text;
}

function getNumLinesAndLastNewlineLength(text: string): { numLines: number, lastLineLength: number } {
	const re = /\n/g;
	let numLines = 0;
	let lastNewlineIdx = -1;
	let match: ReturnType<typeof re.exec>;
	while (match = re.exec(text)) {
		numLines++;
		lastNewlineIdx = match.index;
	}

	const lastLineLength = lastNewlineIdx >= 0 ?
		text.length - lastNewlineIdx - 1 :
		text.length;

	return { numLines, lastLineLength };
}

function getRgArgs(query: vscode.TextSearchQuery, options: vscode.TextSearchOptions): string[] {
	const args = ['--hidden'];
	args.push(query.isCaseSensitive ? '--case-sensitive' : '--ignore-case');

	options.includes
		.map(anchorGlob)
		.forEach(globArg => args.push('-g', globArg));

	options.excludes
		.map(anchorGlob)
		.forEach(rgGlob => args.push('-g', `!${rgGlob}`));

	if (options.maxFileSize) {
		args.push('--max-filesize', options.maxFileSize + '');
	}

	if (options.useIgnoreFiles) {
		args.push('--no-ignore-parent');
	} else {
		// Don't use .gitignore or .ignore
		args.push('--no-ignore');
	}

	if (options.followSymlinks) {
		args.push('--follow');
	}

	if (options.encoding && options.encoding !== 'utf8') {
		args.push('--encoding', options.encoding);
	}

	let pattern = query.pattern;

	// Ripgrep handles -- as a -- arg separator. Only --.
	// - is ok, --- is ok, --some-flag is also ok. Need to special case.
	if (pattern === '--') {
		query.isRegExp = true;
		pattern = '\\-\\-';
	}

	if ((<IExtendedExtensionSearchOptions>options).usePCRE2) {
		args.push('--pcre2');

		if (query.isRegExp) {
			pattern = unicodeEscapesToPCRE2(pattern);
		}
	}

	let searchPatternAfterDoubleDashes: Maybe<string>;
	if (query.isWordMatch) {
		const regexp = createRegExp(pattern, !!query.isRegExp, { wholeWord: query.isWordMatch });
		const regexpStr = regexp.source.replace(/\\\//g, '/'); // RegExp.source arbitrarily returns escaped slashes. Search and destroy.
		args.push('--regexp', regexpStr);
	} else if (query.isRegExp) {
		let fixedRegexpQuery = fixRegexEndingPattern(query.pattern);
		fixedRegexpQuery = fixRegexNewline(fixedRegexpQuery);
		fixedRegexpQuery = fixRegexCRMatchingNonWordClass(fixedRegexpQuery, !!query.isMultiline);
		fixedRegexpQuery = fixRegexCRMatchingWhitespaceClass(fixedRegexpQuery, !!query.isMultiline);
		args.push('--regexp', fixedRegexpQuery);
	} else {
		searchPatternAfterDoubleDashes = pattern;
		args.push('--fixed-strings');
	}

	args.push('--no-config');
	if (!options.useGlobalIgnoreFiles) {
		args.push('--no-ignore-global');
	}

	args.push('--json');

	if (query.isMultiline) {
		args.push('--multiline');
	}

	if (options.beforeContext) {
		args.push('--before-context', options.beforeContext + '');
	}

	if (options.afterContext) {
		args.push('--after-context', options.afterContext + '');
	}

	// Folder to search
	args.push('--');

	if (searchPatternAfterDoubleDashes) {
		// Put the query after --, in case the query starts with a dash
		args.push(searchPatternAfterDoubleDashes);
	}

	args.push('.');

	return args;
}

export function unicodeEscapesToPCRE2(pattern: string): string {
	const reg = /((?:[^\\]|^)(?:\\\\)*)\\u([a-z0-9]{4})(?!\d)/g;
	// Replace an unescaped $ at the end of the pattern with \r?$
	// Match $ preceeded by none or even number of literal \
	while (pattern.match(reg)) {
		pattern = pattern.replace(reg, `$1\\x{$2}`);
	}

	return pattern;
}

interface IRgMessage {
	type: 'match' | 'context' | string;
	data: IRgMatch;
}

interface IRgMatch {
	path: IRgBytesOrText;
	lines: IRgBytesOrText;
	line_number: number;
	absolute_offset: number;
	submatches: IRgSubmatch[];
}

interface IRgSubmatch {
	match: IRgBytesOrText;
	start: number;
	end: number;
}

type IRgBytesOrText = { bytes: string } | { text: string };

export function fixRegexEndingPattern(pattern: string): string {
	// Replace an unescaped $ at the end of the pattern with \r?$
	// Match $ preceeded by none or even number of literal \
	return pattern.match(/([^\\]|^)(\\\\)*\$$/) ?
		pattern.replace(/\$$/, '\\r?$') :
		pattern;
}

export function fixRegexNewline(pattern: string): string {
	// Replace an unescaped $ at the end of the pattern with \r?$
	// Match $ preceeded by none or even number of literal \
	return pattern.replace(/([^\\]|^)(\\\\)*\\n/g, '$1$2\\r?\\n');
}

export function fixRegexCRMatchingWhitespaceClass(pattern: string, isMultiline: boolean): string {
	return isMultiline ?
		pattern.replace(/([^\\]|^)((?:\\\\)*)\\s/g, '$1$2(\\r?\\n|[^\\S\\r])') :
		pattern.replace(/([^\\]|^)((?:\\\\)*)\\s/g, '$1$2[ \\t\\f]');
}

export function fixRegexCRMatchingNonWordClass(pattern: string, isMultiline: boolean): string {
	return isMultiline ?
		pattern.replace(/([^\\]|^)((?:\\\\)*)\\W/g, '$1$2(\\r?\\n|[^\\w\\r])') :
		pattern.replace(/([^\\]|^)((?:\\\\)*)\\W/g, '$1$2[^\\w\\r]');
}
