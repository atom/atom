/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { groupBy } from 'vs/base/common/arrays';
import { dispose } from 'vs/base/common/lifecycle';
import { getLeadingWhitespace } from 'vs/base/common/strings';
import 'vs/css!./snippetSession';
import { ICodeEditor } from 'vs/editor/browser/editorBrowser';
import { EditOperation } from 'vs/editor/common/core/editOperation';
import { IPosition } from 'vs/editor/common/core/position';
import { Range } from 'vs/editor/common/core/range';
import { Selection } from 'vs/editor/common/core/selection';
import { IIdentifiedSingleEditOperation, ITextModel, TrackedRangeStickiness } from 'vs/editor/common/model';
import { ModelDecorationOptions } from 'vs/editor/common/model/textModel';
import { IClipboardService } from 'vs/platform/clipboard/common/clipboardService';
import { optional } from 'vs/platform/instantiation/common/instantiation';
import { Choice, Placeholder, SnippetParser, Text, TextmateSnippet } from './snippetParser';
import { ClipboardBasedVariableResolver, CompositeSnippetVariableResolver, ModelBasedVariableResolver, SelectionBasedVariableResolver, TimeBasedVariableResolver } from './snippetVariables';
import { registerThemingParticipant } from 'vs/platform/theme/common/themeService';
import * as colors from 'vs/platform/theme/common/colorRegistry';

registerThemingParticipant((theme, collector) => {

	function getColorGraceful(name: string) {
		const color = theme.getColor(name);
		return color ? color.toString() : 'transparent';
	}

	collector.addRule(`.monaco-editor .snippet-placeholder { background-color: ${getColorGraceful(colors.snippetTabstopHighlightBackground)}; outline-color: ${getColorGraceful(colors.snippetTabstopHighlightBorder)}; }`);
	collector.addRule(`.monaco-editor .finish-snippet-placeholder { background-color: ${getColorGraceful(colors.snippetFinalTabstopHighlightBackground)}; outline-color: ${getColorGraceful(colors.snippetFinalTabstopHighlightBorder)}; }`);
});

export class OneSnippet {

	private readonly _editor: ICodeEditor;
	private readonly _snippet: TextmateSnippet;
	private readonly _offset: number;

	private _placeholderDecorations: Map<Placeholder, string>;
	private _placeholderGroups: Placeholder[][];
	_placeholderGroupsIdx: number;
	_nestingLevel: number = 1;

	private static readonly _decor = {
		active: ModelDecorationOptions.register({ stickiness: TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges, className: 'snippet-placeholder' }),
		inactive: ModelDecorationOptions.register({ stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, className: 'snippet-placeholder' }),
		activeFinal: ModelDecorationOptions.register({ stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, className: 'finish-snippet-placeholder' }),
		inactiveFinal: ModelDecorationOptions.register({ stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges, className: 'finish-snippet-placeholder' }),
	};

	constructor(editor: ICodeEditor, snippet: TextmateSnippet, offset: number) {
		this._editor = editor;
		this._snippet = snippet;
		this._offset = offset;

		this._placeholderGroups = groupBy(snippet.placeholders, Placeholder.compareByIndex);
		this._placeholderGroupsIdx = -1;
	}

	dispose(): void {
		if (this._placeholderDecorations) {
			let toRemove: string[] = [];
			this._placeholderDecorations.forEach(handle => toRemove.push(handle));
			this._editor.deltaDecorations(toRemove, []);
		}
		this._placeholderGroups.length = 0;
	}

	private _initDecorations(): void {

		if (this._placeholderDecorations) {
			// already initialized
			return;
		}

		this._placeholderDecorations = new Map<Placeholder, string>();
		const model = this._editor.getModel();

		this._editor.changeDecorations(accessor => {
			// create a decoration for each placeholder
			for (const placeholder of this._snippet.placeholders) {
				const placeholderOffset = this._snippet.offset(placeholder);
				const placeholderLen = this._snippet.fullLen(placeholder);
				const range = Range.fromPositions(
					model.getPositionAt(this._offset + placeholderOffset),
					model.getPositionAt(this._offset + placeholderOffset + placeholderLen)
				);
				const options = placeholder.isFinalTabstop ? OneSnippet._decor.inactiveFinal : OneSnippet._decor.inactive;
				const handle = accessor.addDecoration(range, options);
				this._placeholderDecorations.set(placeholder, handle);
			}
		});
	}

	move(fwd: boolean | undefined): Selection[] {

		this._initDecorations();

		// Transform placeholder text if necessary
		if (this._placeholderGroupsIdx >= 0) {
			let operations: IIdentifiedSingleEditOperation[] = [];

			for (const placeholder of this._placeholderGroups[this._placeholderGroupsIdx]) {
				// Check if the placeholder has a transformation
				if (placeholder.transform) {
					const id = this._placeholderDecorations.get(placeholder);
					const range = this._editor.getModel().getDecorationRange(id);
					const currentValue = this._editor.getModel().getValueInRange(range);

					operations.push(EditOperation.replaceMove(range, placeholder.transform.resolve(currentValue)));
				}
			}
			if (operations.length > 0) {
				this._editor.executeEdits('snippet.placeholderTransform', operations);
			}
		}

		let skipThisPlaceholder = false;
		if (fwd === true && this._placeholderGroupsIdx < this._placeholderGroups.length - 1) {
			this._placeholderGroupsIdx += 1;
			skipThisPlaceholder = true;

		} else if (fwd === false && this._placeholderGroupsIdx > 0) {
			this._placeholderGroupsIdx -= 1;
			skipThisPlaceholder = true;

		} else {
			// the selection of the current placeholder might
			// not acurate any more -> simply restore it
		}

		const newSelections = this._editor.getModel().changeDecorations(accessor => {

			const activePlaceholders = new Set<Placeholder>();

			// change stickiness to always grow when typing at its edges
			// because these decorations represent the currently active
			// tabstop.
			// Special case #1: reaching the final tabstop
			// Special case #2: placeholders enclosing active placeholders
			const selections: Selection[] = [];
			for (const placeholder of this._placeholderGroups[this._placeholderGroupsIdx]) {
				const id = this._placeholderDecorations.get(placeholder);
				const range = this._editor.getModel().getDecorationRange(id);
				selections.push(new Selection(range.startLineNumber, range.startColumn, range.endLineNumber, range.endColumn));

				// consider to skip this placeholder index when the decoration
				// range is empty but when the placeholder wasn't. that's a strong
				// hint that the placeholder has been deleted. (all placeholder must match this)
				skipThisPlaceholder = skipThisPlaceholder && (range.isEmpty() && placeholder.toString().length > 0);

				accessor.changeDecorationOptions(id, placeholder.isFinalTabstop ? OneSnippet._decor.activeFinal : OneSnippet._decor.active);
				activePlaceholders.add(placeholder);

				for (const enclosingPlaceholder of this._snippet.enclosingPlaceholders(placeholder)) {
					const id = this._placeholderDecorations.get(enclosingPlaceholder);
					accessor.changeDecorationOptions(id, enclosingPlaceholder.isFinalTabstop ? OneSnippet._decor.activeFinal : OneSnippet._decor.active);
					activePlaceholders.add(enclosingPlaceholder);
				}
			}

			// change stickness to never grow when typing at its edges
			// so that in-active tabstops never grow
			this._placeholderDecorations.forEach((id, placeholder) => {
				if (!activePlaceholders.has(placeholder)) {
					accessor.changeDecorationOptions(id, placeholder.isFinalTabstop ? OneSnippet._decor.inactiveFinal : OneSnippet._decor.inactive);
				}
			});

			return selections;
		});

		return !skipThisPlaceholder ? newSelections : this.move(fwd);
	}

	get isAtFirstPlaceholder() {
		return this._placeholderGroupsIdx <= 0 || this._placeholderGroups.length === 0;
	}

	get isAtLastPlaceholder() {
		return this._placeholderGroupsIdx === this._placeholderGroups.length - 1;
	}

	get hasPlaceholder() {
		return this._snippet.placeholders.length > 0;
	}

	computePossibleSelections() {
		const result = new Map<number, Range[]>();
		for (const placeholdersWithEqualIndex of this._placeholderGroups) {
			let ranges: Range[];

			for (const placeholder of placeholdersWithEqualIndex) {
				if (placeholder.isFinalTabstop) {
					// ignore those
					break;
				}

				if (!ranges) {
					ranges = [];
					result.set(placeholder.index, ranges);
				}

				const id = this._placeholderDecorations.get(placeholder);
				const range = this._editor.getModel().getDecorationRange(id);
				if (!range) {
					// one of the placeholder lost its decoration and
					// therefore we bail out and pretend the placeholder
					// (with its mirrors) doesn't exist anymore.
					result.delete(placeholder.index);
					break;
				}

				ranges.push(range);
			}
		}
		return result;
	}

	get choice(): Choice {
		return this._placeholderGroups[this._placeholderGroupsIdx][0].choice;
	}

	merge(others: OneSnippet[]): void {

		const model = this._editor.getModel();
		this._nestingLevel *= 10;

		this._editor.changeDecorations(accessor => {

			// For each active placeholder take one snippet and merge it
			// in that the placeholder (can be many for `$1foo$1foo`). Because
			// everything is sorted by editor selection we can simply remove
			// elements from the beginning of the array
			for (const placeholder of this._placeholderGroups[this._placeholderGroupsIdx]) {
				const nested = others.shift();
				console.assert(!nested._placeholderDecorations);

				// Massage placeholder-indicies of the nested snippet to be
				// sorted right after the insertion point. This ensures we move
				// through the placeholders in the correct order
				const indexLastPlaceholder = nested._snippet.placeholderInfo.last.index;

				for (const nestedPlaceholder of nested._snippet.placeholderInfo.all) {
					if (nestedPlaceholder.isFinalTabstop) {
						nestedPlaceholder.index = placeholder.index + ((indexLastPlaceholder + 1) / this._nestingLevel);
					} else {
						nestedPlaceholder.index = placeholder.index + (nestedPlaceholder.index / this._nestingLevel);
					}
				}
				this._snippet.replace(placeholder, nested._snippet.children);

				// Remove the placeholder at which position are inserting
				// the snippet and also remove its decoration.
				const id = this._placeholderDecorations.get(placeholder);
				accessor.removeDecoration(id);
				this._placeholderDecorations.delete(placeholder);

				// For each *new* placeholder we create decoration to monitor
				// how and if it grows/shrinks.
				for (const placeholder of nested._snippet.placeholders) {
					const placeholderOffset = nested._snippet.offset(placeholder);
					const placeholderLen = nested._snippet.fullLen(placeholder);
					const range = Range.fromPositions(
						model.getPositionAt(nested._offset + placeholderOffset),
						model.getPositionAt(nested._offset + placeholderOffset + placeholderLen)
					);
					const handle = accessor.addDecoration(range, OneSnippet._decor.inactive);
					this._placeholderDecorations.set(placeholder, handle);
				}
			}

			// Last, re-create the placeholder groups by sorting placeholders by their index.
			this._placeholderGroups = groupBy(this._snippet.placeholders, Placeholder.compareByIndex);
		});
	}

	public getEnclosingRange(): Range {
		let result: Range;
		const model = this._editor.getModel();
		this._placeholderDecorations.forEach((decorationId) => {
			const placeholderRange = model.getDecorationRange(decorationId);
			if (!result) {
				result = placeholderRange;
			} else {
				result = result.plusRange(placeholderRange);
			}
		});
		return result;
	}
}

export class SnippetSession {

	static adjustWhitespace(model: ITextModel, position: IPosition, snippet: TextmateSnippet): void {
		const line = model.getLineContent(position.lineNumber);
		const lineLeadingWhitespace = getLeadingWhitespace(line, 0, position.column - 1);

		snippet.walk(marker => {
			if (marker instanceof Text && !(marker.parent instanceof Choice)) {
				// adjust indentation of text markers, except for choise elements
				// which get adjusted when being selected
				const lines = marker.value.split(/\r\n|\r|\n/);
				for (let i = 1; i < lines.length; i++) {
					let templateLeadingWhitespace = getLeadingWhitespace(lines[i]);
					lines[i] = model.normalizeIndentation(lineLeadingWhitespace + templateLeadingWhitespace) + lines[i].substr(templateLeadingWhitespace.length);
				}
				const newValue = lines.join(model.getEOL());
				if (newValue !== marker.value) {
					marker.parent.replace(marker, [new Text(newValue)]);
				}
			}
			return true;
		});
	}

	static adjustSelection(model: ITextModel, selection: Selection, overwriteBefore: number, overwriteAfter: number): Selection {
		if (overwriteBefore !== 0 || overwriteAfter !== 0) {
			// overwrite[Before|After] is compute using the position, not the whole
			// selection. therefore we adjust the selection around that position
			const { positionLineNumber, positionColumn } = selection;
			const positionColumnBefore = positionColumn - overwriteBefore;
			const positionColumnAfter = positionColumn + overwriteAfter;

			const range = model.validateRange({
				startLineNumber: positionLineNumber,
				startColumn: positionColumnBefore,
				endLineNumber: positionLineNumber,
				endColumn: positionColumnAfter
			});

			selection = Selection.createWithDirection(
				range.startLineNumber, range.startColumn,
				range.endLineNumber, range.endColumn,
				selection.getDirection()
			);
		}
		return selection;
	}

	static createEditsAndSnippets(editor: ICodeEditor, template: string, overwriteBefore: number, overwriteAfter: number, enforceFinalTabstop: boolean, adjustWhitespace: boolean): { edits: IIdentifiedSingleEditOperation[], snippets: OneSnippet[] } {

		const model = editor.getModel();
		const edits: IIdentifiedSingleEditOperation[] = [];
		const snippets: OneSnippet[] = [];

		const modelBasedVariableResolver = new ModelBasedVariableResolver(model);
		const clipboardService = editor.invokeWithinContext(accessor => accessor.get(IClipboardService, optional));

		let delta = 0;

		// know what text the overwrite[Before|After] extensions
		// of the primary curser have selected because only when
		// secondary selections extend to the same text we can grow them
		let firstBeforeText = model.getValueInRange(SnippetSession.adjustSelection(model, editor.getSelection(), overwriteBefore, 0));
		let firstAfterText = model.getValueInRange(SnippetSession.adjustSelection(model, editor.getSelection(), 0, overwriteAfter));

		// remember the first non-whitespace column to decide if
		// `keepWhitespace` should be overruled for secondary selections
		let firstLineFirstNonWhitespace = model.getLineFirstNonWhitespaceColumn(editor.getSelection().positionLineNumber);

		// sort selections by their start position but remeber
		// the original index. that allows you to create correct
		// offset-based selection logic without changing the
		// primary selection
		const indexedSelections = editor.getSelections()
			.map((selection, idx) => ({ selection, idx }))
			.sort((a, b) => Range.compareRangesUsingStarts(a.selection, b.selection));

		for (const { selection, idx } of indexedSelections) {

			// extend selection with the `overwriteBefore` and `overwriteAfter` and then
			// compare if this matches the extensions of the primary selection
			let extensionBefore = SnippetSession.adjustSelection(model, selection, overwriteBefore, 0);
			let extensionAfter = SnippetSession.adjustSelection(model, selection, 0, overwriteAfter);
			if (firstBeforeText !== model.getValueInRange(extensionBefore)) {
				extensionBefore = selection;
			}
			if (firstAfterText !== model.getValueInRange(extensionAfter)) {
				extensionAfter = selection;
			}

			// merge the before and after selection into one
			const snippetSelection = selection
				.setStartPosition(extensionBefore.startLineNumber, extensionBefore.startColumn)
				.setEndPosition(extensionAfter.endLineNumber, extensionAfter.endColumn);

			const snippet = new SnippetParser().parse(template, true, enforceFinalTabstop);

			// adjust the template string to match the indentation and
			// whitespace rules of this insert location (can be different for each cursor)
			// happens when being asked for (default) or when this is a secondary
			// cursor and the leading whitespace is different
			const start = snippetSelection.getStartPosition();
			if (adjustWhitespace || (idx > 0 && firstLineFirstNonWhitespace !== model.getLineFirstNonWhitespaceColumn(selection.positionLineNumber))) {
				SnippetSession.adjustWhitespace(model, start, snippet);
			}

			snippet.resolveVariables(new CompositeSnippetVariableResolver([
				modelBasedVariableResolver,
				new ClipboardBasedVariableResolver(clipboardService, idx, indexedSelections.length),
				new SelectionBasedVariableResolver(model, selection),
				new TimeBasedVariableResolver
			]));

			const offset = model.getOffsetAt(start) + delta;
			delta += snippet.toString().length - model.getValueLengthInRange(snippetSelection);

			// store snippets with the index of their originating selection.
			// that ensures the primiary cursor stays primary despite not being
			// the one with lowest start position
			edits[idx] = EditOperation.replace(snippetSelection, snippet.toString());
			snippets[idx] = new OneSnippet(editor, snippet, offset);
		}

		return { edits, snippets };
	}

	private readonly _editor: ICodeEditor;
	private readonly _template: string;
	private readonly _templateMerges: [number, number, string][] = [];
	private readonly _overwriteBefore: number;
	private readonly _overwriteAfter: number;
	private readonly _adjustWhitespace: boolean;
	private _snippets: OneSnippet[] = [];

	constructor(editor: ICodeEditor, template: string, overwriteBefore: number = 0, overwriteAfter: number = 0, adjustWhitespace: boolean = true) {
		this._editor = editor;
		this._template = template;
		this._overwriteBefore = overwriteBefore;
		this._overwriteAfter = overwriteAfter;
		this._adjustWhitespace = adjustWhitespace;
	}

	dispose(): void {
		dispose(this._snippets);
	}

	_logInfo(): string {
		return `template="${this._template}", merged_templates="${this._templateMerges.join(' -> ')}"`;
	}

	insert(): void {

		const model = this._editor.getModel();

		// make insert edit and start with first selections
		const { edits, snippets } = SnippetSession.createEditsAndSnippets(this._editor, this._template, this._overwriteBefore, this._overwriteAfter, false, this._adjustWhitespace);
		this._snippets = snippets;

		const selections = model.pushEditOperations(this._editor.getSelections(), edits, undoEdits => {
			if (this._snippets[0].hasPlaceholder) {
				return this._move(true);
			} else {
				return undoEdits.map(edit => Selection.fromPositions(edit.range.getEndPosition()));
			}
		});
		this._editor.setSelections(selections);
		this._editor.revealRange(selections[0]);
	}

	merge(template: string, overwriteBefore: number = 0, overwriteAfter: number = 0, adjustWhitespace: boolean = true): void {
		this._templateMerges.push([this._snippets[0]._nestingLevel, this._snippets[0]._placeholderGroupsIdx, template]);
		const { edits, snippets } = SnippetSession.createEditsAndSnippets(this._editor, template, overwriteBefore, overwriteAfter, true, adjustWhitespace);

		this._editor.setSelections(this._editor.getModel().pushEditOperations(this._editor.getSelections(), edits, undoEdits => {

			for (const snippet of this._snippets) {
				snippet.merge(snippets);
			}
			console.assert(snippets.length === 0);

			if (this._snippets[0].hasPlaceholder) {
				return this._move(undefined);
			} else {
				return undoEdits.map(edit => Selection.fromPositions(edit.range.getEndPosition()));
			}
		}));
	}

	next(): void {
		const newSelections = this._move(true);
		this._editor.setSelections(newSelections);
		this._editor.revealPositionInCenterIfOutsideViewport(newSelections[0].getPosition());
	}

	prev(): void {
		const newSelections = this._move(false);
		this._editor.setSelections(newSelections);
		this._editor.revealPositionInCenterIfOutsideViewport(newSelections[0].getPosition());
	}

	private _move(fwd: boolean | undefined): Selection[] {
		const selections: Selection[] = [];
		for (const snippet of this._snippets) {
			const oneSelection = snippet.move(fwd);
			selections.push(...oneSelection);
		}
		return selections;
	}

	get isAtFirstPlaceholder() {
		return this._snippets[0].isAtFirstPlaceholder;
	}

	get isAtLastPlaceholder() {
		return this._snippets[0].isAtLastPlaceholder;
	}

	get hasPlaceholder() {
		return this._snippets[0].hasPlaceholder;
	}

	get choice(): Choice {
		return this._snippets[0].choice;
	}

	isSelectionWithinPlaceholders(): boolean {

		if (!this.hasPlaceholder) {
			return false;
		}

		const selections = this._editor.getSelections();
		if (selections.length < this._snippets.length) {
			// this means we started snippet mode with N
			// selections and have M (N > M) selections.
			// So one snippet is without selection -> cancel
			return false;
		}

		let allPossibleSelections: Map<number, Range[]>;
		for (const snippet of this._snippets) {

			const possibleSelections = snippet.computePossibleSelections();

			// for the first snippet find the placeholder (and its ranges)
			// that contain at least one selection. for all remaining snippets
			// the same placeholder (and their ranges) must be used.
			if (!allPossibleSelections) {
				allPossibleSelections = new Map<number, Range[]>();
				possibleSelections.forEach((ranges, index) => {

					ranges.sort(Range.compareRangesUsingStarts);
					for (const selection of selections) {
						if (ranges[0].containsRange(selection)) {
							allPossibleSelections.set(index, []);
							break;
						}
					}
				});
			}

			if (allPossibleSelections.size === 0) {
				// return false if we couldn't associate a selection to
				// this (the first) snippet
				return false;
			}

			// add selections from 'this' snippet so that we know all
			// selections for this placeholder
			allPossibleSelections.forEach((array, index) => {
				array.push(...possibleSelections.get(index));
			});
		}

		// sort selections (and later placeholder-ranges). then walk both
		// arrays and make sure the placeholder-ranges contain the corresponding
		// selection
		selections.sort(Range.compareRangesUsingStarts);

		allPossibleSelections.forEach((ranges, index) => {

			if (ranges.length !== selections.length) {
				allPossibleSelections.delete(index);
				return;
			}

			ranges.sort(Range.compareRangesUsingStarts);

			for (let i = 0; i < ranges.length; i++) {
				if (!ranges[i].containsRange(selections[i])) {
					allPossibleSelections.delete(index);
					return;
				}
			}
		});

		// from all possible selections we have deleted those
		// that don't match with the current selection. if we don't
		// have any left, we don't have a selection anymore
		return allPossibleSelections.size > 0;
	}

	public getEnclosingRange(): Range {
		let result: Range;
		for (const snippet of this._snippets) {
			const snippetRange = snippet.getEnclosingRange();
			if (!result) {
				result = snippetRange;
			} else {
				result = result.plusRange(snippetRange);
			}
		}
		return result;
	}
}
