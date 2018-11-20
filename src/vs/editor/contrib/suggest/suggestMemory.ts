/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { ICompletionItem } from 'vs/editor/contrib/suggest/completionModel';
import { LRUCache, TernarySearchTree } from 'vs/base/common/map';
import { IStorageService, StorageScope } from 'vs/platform/storage/common/storage';
import { ITextModel } from 'vs/editor/common/model';
import { IPosition } from 'vs/editor/common/core/position';
import { CompletionItemKind, completionKindFromLegacyString } from 'vs/editor/common/modes';
import { ICodeEditor } from 'vs/editor/browser/editorBrowser';
import { Disposable } from 'vs/base/common/lifecycle';

export abstract class Memory {

	select(model: ITextModel, pos: IPosition, items: ICompletionItem[]): number {
		if (items.length === 0) {
			return 0;
		}
		let topScore = items[0].score;
		for (let i = 1; i < items.length; i++) {
			const { score, suggestion } = items[i];
			if (score !== topScore) {
				// stop when leaving the group of top matches
				break;
			}
			if (suggestion.preselect) {
				// stop when seeing an auto-select-item
				return i;
			}
		}
		return 0;
	}

	abstract memorize(model: ITextModel, pos: IPosition, item: ICompletionItem): void;

	abstract toJSON(): object;

	abstract fromJSON(data: object): void;
}

export class NoMemory extends Memory {

	memorize(model: ITextModel, pos: IPosition, item: ICompletionItem): void {
		// no-op
	}

	toJSON() {
		return undefined;
	}

	fromJSON() {
		//
	}
}

export interface MemItem {
	type: string | CompletionItemKind;
	insertText: string;
	touch: number;
}

export class LRUMemory extends Memory {

	private _cache = new LRUCache<string, MemItem>(300, .66);
	private _seq = 0;

	memorize(model: ITextModel, pos: IPosition, item: ICompletionItem): void {
		const { label } = item.suggestion;
		const key = `${model.getLanguageIdentifier().language}/${label}`;
		this._cache.set(key, {
			touch: this._seq++,
			type: item.suggestion.kind,
			insertText: item.suggestion.insertText
		});
	}

	select(model: ITextModel, pos: IPosition, items: ICompletionItem[]): number {
		// in order of completions, select the first
		// that has been used in the past
		let { word } = model.getWordUntilPosition(pos);
		if (word.length !== 0) {
			return super.select(model, pos, items);
		}

		let lineSuffix = model.getLineContent(pos.lineNumber).substr(pos.column - 10, pos.column - 1);
		if (/\s$/.test(lineSuffix)) {
			return super.select(model, pos, items);
		}

		let res = -1;
		let seq = -1;
		for (let i = 0; i < items.length; i++) {
			const { suggestion } = items[i];
			const key = `${model.getLanguageIdentifier().language}/${suggestion.label}`;
			const item = this._cache.get(key);
			if (item && item.touch > seq && item.type === suggestion.kind && item.insertText === suggestion.insertText) {
				seq = item.touch;
				res = i;
			}
		}
		if (res === -1) {
			return super.select(model, pos, items);
		} else {
			return res;
		}
	}

	toJSON(): object {
		let data: [string, MemItem][] = [];
		this._cache.forEach((value, key) => {
			data.push([key, value]);
		});
		return data;
	}

	fromJSON(data: [string, MemItem][]): void {
		this._cache.clear();
		let seq = 0;
		for (const [key, value] of data) {
			value.touch = seq;
			value.type = typeof value.type === 'number' ? value.type : completionKindFromLegacyString(value.type);
			this._cache.set(key, value);
		}
		this._seq = this._cache.size;
	}
}


export class PrefixMemory extends Memory {

	private _trie = TernarySearchTree.forStrings<MemItem>();
	private _seq = 0;

	memorize(model: ITextModel, pos: IPosition, item: ICompletionItem): void {
		const { word } = model.getWordUntilPosition(pos);
		const key = `${model.getLanguageIdentifier().language}/${word}`;
		this._trie.set(key, {
			type: item.suggestion.kind,
			insertText: item.suggestion.insertText,
			touch: this._seq++
		});
	}

	select(model: ITextModel, pos: IPosition, items: ICompletionItem[]): number {
		let { word } = model.getWordUntilPosition(pos);
		if (!word) {
			return super.select(model, pos, items);
		}
		let key = `${model.getLanguageIdentifier().language}/${word}`;
		let item = this._trie.get(key);
		if (!item) {
			item = this._trie.findSubstr(key);
		}
		if (item) {
			for (let i = 0; i < items.length; i++) {
				let { kind, insertText } = items[i].suggestion;
				if (kind === item.type && insertText === item.insertText) {
					return i;
				}
			}
		}
		return super.select(model, pos, items);
	}

	toJSON(): object {

		let entries: [string, MemItem][] = [];
		this._trie.forEach((value, key) => entries.push([key, value]));

		// sort by last recently used (touch), then
		// take the top 200 item and normalize their
		// touch
		entries
			.sort((a, b) => -(a[1].touch - b[1].touch))
			.forEach((value, i) => value[1].touch = i);

		return entries.slice(0, 200);
	}

	fromJSON(data: [string, MemItem][]): void {
		this._trie.clear();
		if (data.length > 0) {
			this._seq = data[0][1].touch + 1;
			for (const [key, value] of data) {
				value.type = typeof value.type === 'number' ? value.type : completionKindFromLegacyString(value.type);
				this._trie.set(key, value);
			}
		}
	}
}

export type MemMode = 'first' | 'recentlyUsed' | 'recentlyUsedByPrefix';

export class SuggestMemories extends Disposable {

	private readonly _storagePrefix = 'suggest/memories';

	private _mode: MemMode;
	private _strategy: Memory;

	constructor(
		editor: ICodeEditor,
		@IStorageService private readonly _storageService: IStorageService,
	) {
		super();

		this._setMode(editor.getConfiguration().contribInfo.suggestSelection);
		this._register(editor.onDidChangeConfiguration(e => e.contribInfo && this._setMode(editor.getConfiguration().contribInfo.suggestSelection)));
		this._register(_storageService.onWillSaveState(() => this._saveState()));
	}

	private _setMode(mode: MemMode): void {
		if (this._mode === mode) {
			return;
		}
		this._mode = mode;
		this._strategy = mode === 'recentlyUsedByPrefix' ? new PrefixMemory() : mode === 'recentlyUsed' ? new LRUMemory() : new NoMemory();

		try {
			const raw = this._storageService.get(`${this._storagePrefix}/${this._mode}`, StorageScope.WORKSPACE);
			if (raw) {
				this._strategy.fromJSON(JSON.parse(raw));
			}
		} catch (e) {
			// things can go wrong with JSON...
		}
	}

	memorize(model: ITextModel, pos: IPosition, item: ICompletionItem): void {
		this._strategy.memorize(model, pos, item);
	}

	select(model: ITextModel, pos: IPosition, items: ICompletionItem[]): number {
		return this._strategy.select(model, pos, items);
	}

	private _saveState() {
		const raw = JSON.stringify(this._strategy);
		this._storageService.store(`${this._storagePrefix}/${this._mode}`, raw, StorageScope.WORKSPACE);
	}
}
