/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { Emitter, Event } from 'vs/base/common/event';
import { IDisposable } from 'vs/base/common/lifecycle';
import { Range } from 'vs/editor/common/core/range';

export interface FindReplaceStateChangedEvent {
	moveCursor: boolean;
	updateHistory: boolean;

	searchString: boolean;
	replaceString: boolean;
	isRevealed: boolean;
	isReplaceRevealed: boolean;
	isRegex: boolean;
	wholeWord: boolean;
	matchCase: boolean;
	searchScope: boolean;
	matchesPosition: boolean;
	matchesCount: boolean;
	currentMatch: boolean;
}

export const enum FindOptionOverride {
	NotSet = 0,
	True = 1,
	False = 2
}

export interface INewFindReplaceState {
	searchString?: string;
	replaceString?: string;
	isRevealed?: boolean;
	isReplaceRevealed?: boolean;
	isRegex?: boolean;
	isRegexOverride?: FindOptionOverride;
	wholeWord?: boolean;
	wholeWordOverride?: FindOptionOverride;
	matchCase?: boolean;
	matchCaseOverride?: FindOptionOverride;
	searchScope?: Range;
}

function effectiveOptionValue(override: FindOptionOverride, value: boolean): boolean {
	if (override === FindOptionOverride.True) {
		return true;
	}
	if (override === FindOptionOverride.False) {
		return false;
	}
	return value;
}

export class FindReplaceState implements IDisposable {
	private _searchString: string;
	private _replaceString: string;
	private _isRevealed: boolean;
	private _isReplaceRevealed: boolean;
	private _isRegex: boolean;
	private _isRegexOverride: FindOptionOverride;
	private _wholeWord: boolean;
	private _wholeWordOverride: FindOptionOverride;
	private _matchCase: boolean;
	private _matchCaseOverride: FindOptionOverride;
	private _searchScope: Range | null;
	private _matchesPosition: number;
	private _matchesCount: number;
	private _currentMatch: Range | null;
	private readonly _onFindReplaceStateChange: Emitter<FindReplaceStateChangedEvent>;

	public get searchString(): string { return this._searchString; }
	public get replaceString(): string { return this._replaceString; }
	public get isRevealed(): boolean { return this._isRevealed; }
	public get isReplaceRevealed(): boolean { return this._isReplaceRevealed; }
	public get isRegex(): boolean { return effectiveOptionValue(this._isRegexOverride, this._isRegex); }
	public get wholeWord(): boolean { return effectiveOptionValue(this._wholeWordOverride, this._wholeWord); }
	public get matchCase(): boolean { return effectiveOptionValue(this._matchCaseOverride, this._matchCase); }

	public get actualIsRegex(): boolean { return this._isRegex; }
	public get actualWholeWord(): boolean { return this._wholeWord; }
	public get actualMatchCase(): boolean { return this._matchCase; }

	public get searchScope(): Range | null { return this._searchScope; }
	public get matchesPosition(): number { return this._matchesPosition; }
	public get matchesCount(): number { return this._matchesCount; }
	public get currentMatch(): Range | null { return this._currentMatch; }
	public get onFindReplaceStateChange(): Event<FindReplaceStateChangedEvent> { return this._onFindReplaceStateChange.event; }

	constructor() {
		this._searchString = '';
		this._replaceString = '';
		this._isRevealed = false;
		this._isReplaceRevealed = false;
		this._isRegex = false;
		this._isRegexOverride = FindOptionOverride.NotSet;
		this._wholeWord = false;
		this._wholeWordOverride = FindOptionOverride.NotSet;
		this._matchCase = false;
		this._matchCaseOverride = FindOptionOverride.NotSet;
		this._searchScope = null;
		this._matchesPosition = 0;
		this._matchesCount = 0;
		this._currentMatch = null;
		this._onFindReplaceStateChange = new Emitter<FindReplaceStateChangedEvent>();
	}

	public dispose(): void {
	}

	public changeMatchInfo(matchesPosition: number, matchesCount: number, currentMatch: Range | undefined): void {
		let changeEvent: FindReplaceStateChangedEvent = {
			moveCursor: false,
			updateHistory: false,
			searchString: false,
			replaceString: false,
			isRevealed: false,
			isReplaceRevealed: false,
			isRegex: false,
			wholeWord: false,
			matchCase: false,
			searchScope: false,
			matchesPosition: false,
			matchesCount: false,
			currentMatch: false
		};
		let somethingChanged = false;

		if (matchesCount === 0) {
			matchesPosition = 0;
		}
		if (matchesPosition > matchesCount) {
			matchesPosition = matchesCount;
		}

		if (this._matchesPosition !== matchesPosition) {
			this._matchesPosition = matchesPosition;
			changeEvent.matchesPosition = true;
			somethingChanged = true;
		}
		if (this._matchesCount !== matchesCount) {
			this._matchesCount = matchesCount;
			changeEvent.matchesCount = true;
			somethingChanged = true;
		}

		if (typeof currentMatch !== 'undefined') {
			if (!Range.equalsRange(this._currentMatch, currentMatch)) {
				this._currentMatch = currentMatch;
				changeEvent.currentMatch = true;
				somethingChanged = true;
			}
		}

		if (somethingChanged) {
			this._onFindReplaceStateChange.fire(changeEvent);
		}
	}

	public change(newState: INewFindReplaceState, moveCursor: boolean, updateHistory: boolean = true): void {
		let changeEvent: FindReplaceStateChangedEvent = {
			moveCursor: moveCursor,
			updateHistory: updateHistory,
			searchString: false,
			replaceString: false,
			isRevealed: false,
			isReplaceRevealed: false,
			isRegex: false,
			wholeWord: false,
			matchCase: false,
			searchScope: false,
			matchesPosition: false,
			matchesCount: false,
			currentMatch: false
		};
		let somethingChanged = false;

		const oldEffectiveIsRegex = this.isRegex;
		const oldEffectiveWholeWords = this.wholeWord;
		const oldEffectiveMatchCase = this.matchCase;

		if (typeof newState.searchString !== 'undefined') {
			if (this._searchString !== newState.searchString) {
				this._searchString = newState.searchString;
				changeEvent.searchString = true;
				somethingChanged = true;
			}
		}
		if (typeof newState.replaceString !== 'undefined') {
			if (this._replaceString !== newState.replaceString) {
				this._replaceString = newState.replaceString;
				changeEvent.replaceString = true;
				somethingChanged = true;
			}
		}
		if (typeof newState.isRevealed !== 'undefined') {
			if (this._isRevealed !== newState.isRevealed) {
				this._isRevealed = newState.isRevealed;
				changeEvent.isRevealed = true;
				somethingChanged = true;
			}
		}
		if (typeof newState.isReplaceRevealed !== 'undefined') {
			if (this._isReplaceRevealed !== newState.isReplaceRevealed) {
				this._isReplaceRevealed = newState.isReplaceRevealed;
				changeEvent.isReplaceRevealed = true;
				somethingChanged = true;
			}
		}
		if (typeof newState.isRegex !== 'undefined') {
			this._isRegex = newState.isRegex;
		}
		if (typeof newState.wholeWord !== 'undefined') {
			this._wholeWord = newState.wholeWord;
		}
		if (typeof newState.matchCase !== 'undefined') {
			this._matchCase = newState.matchCase;
		}
		if (typeof newState.searchScope !== 'undefined') {
			if (!Range.equalsRange(this._searchScope, newState.searchScope)) {
				this._searchScope = newState.searchScope;
				changeEvent.searchScope = true;
				somethingChanged = true;
			}
		}

		// Overrides get set when they explicitly come in and get reset anytime something else changes
		this._isRegexOverride = (typeof newState.isRegexOverride !== 'undefined' ? newState.isRegexOverride : FindOptionOverride.NotSet);
		this._wholeWordOverride = (typeof newState.wholeWordOverride !== 'undefined' ? newState.wholeWordOverride : FindOptionOverride.NotSet);
		this._matchCaseOverride = (typeof newState.matchCaseOverride !== 'undefined' ? newState.matchCaseOverride : FindOptionOverride.NotSet);

		if (oldEffectiveIsRegex !== this.isRegex) {
			somethingChanged = true;
			changeEvent.isRegex = true;
		}
		if (oldEffectiveWholeWords !== this.wholeWord) {
			somethingChanged = true;
			changeEvent.wholeWord = true;
		}
		if (oldEffectiveMatchCase !== this.matchCase) {
			somethingChanged = true;
			changeEvent.matchCase = true;
		}

		if (somethingChanged) {
			this._onFindReplaceStateChange.fire(changeEvent);
		}
	}
}
