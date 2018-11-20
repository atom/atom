/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { mergeSort } from 'vs/base/common/arrays';
import { stringDiff } from 'vs/base/common/diff/diff';
import { FIN, Iterator, IteratorResult } from 'vs/base/common/iterator';
import { IDisposable } from 'vs/base/common/lifecycle';
import { globals } from 'vs/base/common/platform';
import { URI } from 'vs/base/common/uri';
import { IRequestHandler } from 'vs/base/common/worker/simpleWorker';
import { IPosition, Position } from 'vs/editor/common/core/position';
import { IRange, Range } from 'vs/editor/common/core/range';
import { DiffComputer } from 'vs/editor/common/diff/diffComputer';
import * as editorCommon from 'vs/editor/common/editorCommon';
import { EndOfLineSequence, IWordAtPosition } from 'vs/editor/common/model';
import { IModelChangedEvent, MirrorTextModel as BaseMirrorModel } from 'vs/editor/common/model/mirrorTextModel';
import { ensureValidWordDefinition, getWordAtText } from 'vs/editor/common/model/wordHelper';
import { CompletionItem, CompletionItemKind, CompletionList, IInplaceReplaceSupportResult, ILink, TextEdit } from 'vs/editor/common/modes';
import { ILinkComputerTarget, computeLinks } from 'vs/editor/common/modes/linkComputer';
import { BasicInplaceReplace } from 'vs/editor/common/modes/supports/inplaceReplaceSupport';
import { IDiffComputationResult } from 'vs/editor/common/services/editorWorkerService';
import { createMonacoBaseAPI } from 'vs/editor/common/standalone/standaloneBase';

export interface IMirrorModel {
	readonly uri: URI;
	readonly version: number;
	getValue(): string;
}

export interface IWorkerContext {
	/**
	 * Get all available mirror models in this worker.
	 */
	getMirrorModels(): IMirrorModel[];
}

/**
 * @internal
 */
export interface IRawModelData {
	url: string;
	versionId: number;
	lines: string[];
	EOL: string;
}

/**
 * @internal
 */
export interface ICommonModel extends ILinkComputerTarget, IMirrorModel {
	uri: URI;
	version: number;
	eol: string;
	getValue(): string;

	getLinesContent(): string[];
	getLineCount(): number;
	getLineContent(lineNumber: number): string;
	getLineWords(lineNumber: number, wordDefinition: RegExp): IWordAtPosition[];
	createWordIterator(wordDefinition: RegExp): Iterator<string>;
	getWordUntilPosition(position: IPosition, wordDefinition: RegExp): IWordAtPosition;
	getValueInRange(range: IRange): string;
	getWordAtPosition(position: IPosition, wordDefinition: RegExp): Range | null;
	offsetAt(position: IPosition): number;
	positionAt(offset: number): IPosition;
}

/**
 * Range of a word inside a model.
 * @internal
 */
interface IWordRange {
	/**
	 * The index where the word starts.
	 */
	readonly start: number;
	/**
	 * The index where the word ends.
	 */
	readonly end: number;
}

/**
 * @internal
 */
class MirrorModel extends BaseMirrorModel implements ICommonModel {

	public get uri(): URI {
		return this._uri;
	}

	public get version(): number {
		return this._versionId;
	}

	public get eol(): string {
		return this._eol;
	}

	public getValue(): string {
		return this.getText();
	}

	public getLinesContent(): string[] {
		return this._lines.slice(0);
	}

	public getLineCount(): number {
		return this._lines.length;
	}

	public getLineContent(lineNumber: number): string {
		return this._lines[lineNumber - 1];
	}

	public getWordAtPosition(position: IPosition, wordDefinition: RegExp): Range | null {

		let wordAtText = getWordAtText(
			position.column,
			ensureValidWordDefinition(wordDefinition),
			this._lines[position.lineNumber - 1],
			0
		);

		if (wordAtText) {
			return new Range(position.lineNumber, wordAtText.startColumn, position.lineNumber, wordAtText.endColumn);
		}

		return null;
	}

	public getWordUntilPosition(position: IPosition, wordDefinition: RegExp): IWordAtPosition {
		const wordAtPosition = this.getWordAtPosition(position, wordDefinition);
		if (!wordAtPosition) {
			return {
				word: '',
				startColumn: position.column,
				endColumn: position.column
			};
		}
		return {
			word: this._lines[position.lineNumber - 1].substring(wordAtPosition.startColumn - 1, position.column - 1),
			startColumn: wordAtPosition.startColumn,
			endColumn: position.column
		};
	}

	public createWordIterator(wordDefinition: RegExp): Iterator<string> {
		let obj: { done: false; value: string; };
		let lineNumber = 0;
		let lineText: string;
		let wordRangesIdx = 0;
		let wordRanges: IWordRange[] = [];
		let next = (): IteratorResult<string> => {

			if (wordRangesIdx < wordRanges.length) {
				const value = lineText.substring(wordRanges[wordRangesIdx].start, wordRanges[wordRangesIdx].end);
				wordRangesIdx += 1;
				if (!obj) {
					obj = { done: false, value: value };
				} else {
					obj.value = value;
				}
				return obj;

			} else if (lineNumber >= this._lines.length) {
				return FIN;

			} else {
				lineText = this._lines[lineNumber];
				wordRanges = this._wordenize(lineText, wordDefinition);
				wordRangesIdx = 0;
				lineNumber += 1;
				return next();
			}
		};
		return { next };
	}

	public getLineWords(lineNumber: number, wordDefinition: RegExp): IWordAtPosition[] {
		let content = this._lines[lineNumber - 1];
		let ranges = this._wordenize(content, wordDefinition);
		let words: IWordAtPosition[] = [];
		for (const range of ranges) {
			words.push({
				word: content.substring(range.start, range.end),
				startColumn: range.start + 1,
				endColumn: range.end + 1
			});
		}
		return words;
	}

	private _wordenize(content: string, wordDefinition: RegExp): IWordRange[] {
		const result: IWordRange[] = [];
		let match: RegExpExecArray | null;

		wordDefinition.lastIndex = 0; // reset lastIndex just to be sure

		while (match = wordDefinition.exec(content)) {
			if (match[0].length === 0) {
				// it did match the empty string
				break;
			}
			result.push({ start: match.index, end: match.index + match[0].length });
		}
		return result;
	}

	public getValueInRange(range: IRange): string {
		range = this._validateRange(range);

		if (range.startLineNumber === range.endLineNumber) {
			return this._lines[range.startLineNumber - 1].substring(range.startColumn - 1, range.endColumn - 1);
		}

		let lineEnding = this._eol;
		let startLineIndex = range.startLineNumber - 1;
		let endLineIndex = range.endLineNumber - 1;
		let resultLines: string[] = [];

		resultLines.push(this._lines[startLineIndex].substring(range.startColumn - 1));
		for (let i = startLineIndex + 1; i < endLineIndex; i++) {
			resultLines.push(this._lines[i]);
		}
		resultLines.push(this._lines[endLineIndex].substring(0, range.endColumn - 1));

		return resultLines.join(lineEnding);
	}

	public offsetAt(position: IPosition): number {
		position = this._validatePosition(position);
		this._ensureLineStarts();
		return this._lineStarts!.getAccumulatedValue(position.lineNumber - 2) + (position.column - 1);
	}

	public positionAt(offset: number): IPosition {
		offset = Math.floor(offset);
		offset = Math.max(0, offset);

		this._ensureLineStarts();
		let out = this._lineStarts!.getIndexOf(offset);
		let lineLength = this._lines[out.index].length;

		// Ensure we return a valid position
		return {
			lineNumber: 1 + out.index,
			column: 1 + Math.min(out.remainder, lineLength)
		};
	}

	private _validateRange(range: IRange): IRange {

		const start = this._validatePosition({ lineNumber: range.startLineNumber, column: range.startColumn });
		const end = this._validatePosition({ lineNumber: range.endLineNumber, column: range.endColumn });

		if (start.lineNumber !== range.startLineNumber
			|| start.column !== range.startColumn
			|| end.lineNumber !== range.endLineNumber
			|| end.column !== range.endColumn) {

			return {
				startLineNumber: start.lineNumber,
				startColumn: start.column,
				endLineNumber: end.lineNumber,
				endColumn: end.column
			};
		}

		return range;
	}

	private _validatePosition(position: IPosition): IPosition {
		if (!Position.isIPosition(position)) {
			throw new Error('bad position');
		}
		let { lineNumber, column } = position;
		let hasChanged = false;

		if (lineNumber < 1) {
			lineNumber = 1;
			column = 1;
			hasChanged = true;

		} else if (lineNumber > this._lines.length) {
			lineNumber = this._lines.length;
			column = this._lines[lineNumber - 1].length + 1;
			hasChanged = true;

		} else {
			let maxCharacter = this._lines[lineNumber - 1].length + 1;
			if (column < 1) {
				column = 1;
				hasChanged = true;
			}
			else if (column > maxCharacter) {
				column = maxCharacter;
				hasChanged = true;
			}
		}

		if (!hasChanged) {
			return position;
		} else {
			return { lineNumber, column };
		}
	}
}

/**
 * @internal
 */
export interface IForeignModuleFactory {
	(ctx: IWorkerContext, createData: any): any;
}

declare var require: any;

/**
 * @internal
 */
export abstract class BaseEditorSimpleWorker {
	private _foreignModuleFactory: IForeignModuleFactory | null;
	private _foreignModule: any;

	constructor(foreignModuleFactory: IForeignModuleFactory | null) {
		this._foreignModuleFactory = foreignModuleFactory;
		this._foreignModule = null;
	}

	protected abstract _getModel(uri: string): ICommonModel;
	protected abstract _getModels(): ICommonModel[];

	// ---- BEGIN diff --------------------------------------------------------------------------

	public computeDiff(originalUrl: string, modifiedUrl: string, ignoreTrimWhitespace: boolean): Promise<IDiffComputationResult | null> {
		const original = this._getModel(originalUrl);
		const modified = this._getModel(modifiedUrl);
		if (!original || !modified) {
			return Promise.resolve(null);
		}

		const originalLines = original.getLinesContent();
		const modifiedLines = modified.getLinesContent();
		const diffComputer = new DiffComputer(originalLines, modifiedLines, {
			shouldComputeCharChanges: true,
			shouldPostProcessCharChanges: true,
			shouldIgnoreTrimWhitespace: ignoreTrimWhitespace,
			shouldMakePrettyDiff: true
		});

		const changes = diffComputer.computeDiff();
		let identical = (changes.length > 0 ? false : this._modelsAreIdentical(original, modified));
		return Promise.resolve({
			identical: identical,
			changes: changes
		});
	}

	private _modelsAreIdentical(original: ICommonModel, modified: ICommonModel): boolean {
		const originalLineCount = original.getLineCount();
		const modifiedLineCount = modified.getLineCount();
		if (originalLineCount !== modifiedLineCount) {
			return false;
		}
		for (let line = 1; line <= originalLineCount; line++) {
			const originalLine = original.getLineContent(line);
			const modifiedLine = modified.getLineContent(line);
			if (originalLine !== modifiedLine) {
				return false;
			}
		}
		return true;
	}

	public computeDirtyDiff(originalUrl: string, modifiedUrl: string, ignoreTrimWhitespace: boolean): Promise<editorCommon.IChange[] | null> {
		let original = this._getModel(originalUrl);
		let modified = this._getModel(modifiedUrl);
		if (!original || !modified) {
			return Promise.resolve(null);
		}

		let originalLines = original.getLinesContent();
		let modifiedLines = modified.getLinesContent();
		let diffComputer = new DiffComputer(originalLines, modifiedLines, {
			shouldComputeCharChanges: false,
			shouldPostProcessCharChanges: false,
			shouldIgnoreTrimWhitespace: ignoreTrimWhitespace,
			shouldMakePrettyDiff: true
		});
		return Promise.resolve(diffComputer.computeDiff());
	}

	// ---- END diff --------------------------------------------------------------------------


	// ---- BEGIN minimal edits ---------------------------------------------------------------

	private static readonly _diffLimit = 10000;

	public computeMoreMinimalEdits(modelUrl: string, edits: TextEdit[]): Promise<TextEdit[]> {
		const model = this._getModel(modelUrl);
		if (!model) {
			return Promise.resolve(edits);
		}

		const result: TextEdit[] = [];
		let lastEol: EndOfLineSequence | undefined = undefined;

		edits = mergeSort(edits, (a, b) => {
			if (a.range && b.range) {
				return Range.compareRangesUsingStarts(a.range, b.range);
			}
			// eol only changes should go to the end
			let aRng = a.range ? 0 : 1;
			let bRng = b.range ? 0 : 1;
			return aRng - bRng;
		});

		for (let { range, text, eol } of edits) {

			if (typeof eol === 'number') {
				lastEol = eol;
			}

			if (Range.isEmpty(range) && !text) {
				// empty change
				continue;
			}

			const original = model.getValueInRange(range);
			text = text!.replace(/\r\n|\n|\r/g, model.eol);

			if (original === text) {
				// noop
				continue;
			}

			// make sure diff won't take too long
			if (Math.max(text.length, original.length) > BaseEditorSimpleWorker._diffLimit) {
				result.push({ range, text });
				continue;
			}

			// compute diff between original and edit.text
			const changes = stringDiff(original, text, false);
			const editOffset = model.offsetAt(Range.lift(range).getStartPosition());

			for (const change of changes) {
				const start = model.positionAt(editOffset + change.originalStart);
				const end = model.positionAt(editOffset + change.originalStart + change.originalLength);
				const newEdit: TextEdit = {
					text: text.substr(change.modifiedStart, change.modifiedLength),
					range: { startLineNumber: start.lineNumber, startColumn: start.column, endLineNumber: end.lineNumber, endColumn: end.column }
				};

				if (model.getValueInRange(newEdit.range) !== newEdit.text) {
					result.push(newEdit);
				}
			}
		}

		if (typeof lastEol === 'number') {
			result.push({ eol: lastEol, text: '', range: { startLineNumber: 0, startColumn: 0, endLineNumber: 0, endColumn: 0 } });
		}

		return Promise.resolve(result);
	}

	// ---- END minimal edits ---------------------------------------------------------------

	public computeLinks(modelUrl: string): Promise<ILink[] | null> {
		let model = this._getModel(modelUrl);
		if (!model) {
			return Promise.resolve(null);
		}

		return Promise.resolve(computeLinks(model));
	}

	// ---- BEGIN suggest --------------------------------------------------------------------------

	private static readonly _suggestionsLimit = 10000;

	public textualSuggest(modelUrl: string, position: IPosition, wordDef: string, wordDefFlags: string): Promise<CompletionList | null> {
		const model = this._getModel(modelUrl);
		if (!model) {
			return Promise.resolve(null);
		}

		const suggestions: CompletionItem[] = [];
		const wordDefRegExp = new RegExp(wordDef, wordDefFlags);
		const currentWord = model.getWordUntilPosition(position, wordDefRegExp);

		const seen: Record<string, boolean> = Object.create(null);
		seen[currentWord.word] = true;

		for (
			let iter = model.createWordIterator(wordDefRegExp), e = iter.next();
			!e.done && suggestions.length <= BaseEditorSimpleWorker._suggestionsLimit;
			e = iter.next()
		) {
			const word = e.value;
			if (seen[word]) {
				continue;
			}
			seen[word] = true;
			if (!isNaN(Number(word))) {
				continue;
			}

			suggestions.push({
				kind: CompletionItemKind.Text,
				label: word,
				insertText: word,
				range: { startLineNumber: position.lineNumber, startColumn: currentWord.startColumn, endLineNumber: position.lineNumber, endColumn: currentWord.endColumn }
			});
		}

		return Promise.resolve({ suggestions });
	}


	// ---- END suggest --------------------------------------------------------------------------

	//#region -- word ranges --

	computeWordRanges(modelUrl: string, range: IRange, wordDef: string, wordDefFlags: string): Promise<{ [word: string]: IRange[] }> {
		let model = this._getModel(modelUrl);
		if (!model) {
			return Promise.resolve(Object.create(null));
		}
		const wordDefRegExp = new RegExp(wordDef, wordDefFlags);
		const result: { [word: string]: IRange[] } = Object.create(null);
		for (let line = range.startLineNumber; line < range.endLineNumber; line++) {
			let words = model.getLineWords(line, wordDefRegExp);
			for (const word of words) {
				if (!isNaN(Number(word.word))) {
					continue;
				}
				let array = result[word.word];
				if (!array) {
					array = [];
					result[word.word] = array;
				}
				array.push({
					startLineNumber: line,
					startColumn: word.startColumn,
					endLineNumber: line,
					endColumn: word.endColumn
				});
			}
		}
		return Promise.resolve(result);
	}

	//#endregion

	public navigateValueSet(modelUrl: string, range: IRange, up: boolean, wordDef: string, wordDefFlags: string): Promise<IInplaceReplaceSupportResult | null> {
		let model = this._getModel(modelUrl);
		if (!model) {
			return Promise.resolve(null);
		}

		let wordDefRegExp = new RegExp(wordDef, wordDefFlags);

		if (range.startColumn === range.endColumn) {
			range = {
				startLineNumber: range.startLineNumber,
				startColumn: range.startColumn,
				endLineNumber: range.endLineNumber,
				endColumn: range.endColumn + 1
			};
		}

		let selectionText = model.getValueInRange(range);

		let wordRange = model.getWordAtPosition({ lineNumber: range.startLineNumber, column: range.startColumn }, wordDefRegExp);
		if (!wordRange) {
			return Promise.resolve(null);
		}
		let word = model.getValueInRange(wordRange);
		let result = BasicInplaceReplace.INSTANCE.navigateValueSet(range, selectionText, wordRange, word, up);
		return Promise.resolve(result);
	}

	// ---- BEGIN foreign module support --------------------------------------------------------------------------

	public loadForeignModule(moduleId: string, createData: any): Promise<string[]> {
		let ctx: IWorkerContext = {
			getMirrorModels: (): IMirrorModel[] => {
				return this._getModels();
			}
		};

		if (this._foreignModuleFactory) {
			this._foreignModule = this._foreignModuleFactory(ctx, createData);
			// static foreing module
			let methods: string[] = [];
			for (let prop in this._foreignModule) {
				if (typeof this._foreignModule[prop] === 'function') {
					methods.push(prop);
				}
			}
			return Promise.resolve(methods);
		}
		// ESM-comment-begin
		return new Promise<any>((resolve, reject) => {
			require([moduleId], (foreignModule: { create: IForeignModuleFactory }) => {
				this._foreignModule = foreignModule.create(ctx, createData);

				let methods: string[] = [];
				for (let prop in this._foreignModule) {
					if (typeof this._foreignModule[prop] === 'function') {
						methods.push(prop);
					}
				}

				resolve(methods);

			}, reject);
		});
		// ESM-comment-end

		// ESM-uncomment-begin
		// return Promise.reject(new Error(`Unexpected usage`));
		// ESM-uncomment-end
	}

	// foreign method request
	public fmr(method: string, args: any[]): Promise<any> {
		if (!this._foreignModule || typeof this._foreignModule[method] !== 'function') {
			return Promise.reject(new Error('Missing requestHandler or method: ' + method));
		}

		try {
			return Promise.resolve(this._foreignModule[method].apply(this._foreignModule, args));
		} catch (e) {
			return Promise.reject(e);
		}
	}

	// ---- END foreign module support --------------------------------------------------------------------------
}

/**
 * @internal
 */
export class EditorSimpleWorkerImpl extends BaseEditorSimpleWorker implements IRequestHandler, IDisposable {
	_requestHandlerBrand: any;

	private _models: { [uri: string]: MirrorModel; };

	constructor(foreignModuleFactory: IForeignModuleFactory | null) {
		super(foreignModuleFactory);
		this._models = Object.create(null);
	}

	public dispose(): void {
		this._models = Object.create(null);
	}

	protected _getModel(uri: string): ICommonModel {
		return this._models[uri];
	}

	protected _getModels(): ICommonModel[] {
		let all: MirrorModel[] = [];
		Object.keys(this._models).forEach((key) => all.push(this._models[key]));
		return all;
	}

	public acceptNewModel(data: IRawModelData): void {
		this._models[data.url] = new MirrorModel(URI.parse(data.url), data.lines, data.EOL, data.versionId);
	}

	public acceptModelChanged(strURL: string, e: IModelChangedEvent): void {
		if (!this._models[strURL]) {
			return;
		}
		let model = this._models[strURL];
		model.onEvents(e);
	}

	public acceptRemovedModel(strURL: string): void {
		if (!this._models[strURL]) {
			return;
		}
		delete this._models[strURL];
	}
}

/**
 * Called on the worker side
 * @internal
 */
export function create(): IRequestHandler {
	return new EditorSimpleWorkerImpl(null);
}

// This is only available in a Web Worker
declare function importScripts(...urls: string[]): void;

if (typeof importScripts === 'function') {
	// Running in a web worker
	globals.monaco = createMonacoBaseAPI();
}
