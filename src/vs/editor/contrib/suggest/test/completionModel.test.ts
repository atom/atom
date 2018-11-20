/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import * as assert from 'assert';
import { IPosition } from 'vs/editor/common/core/position';
import { CompletionList, CompletionItemProvider, CompletionItem, CompletionItemKind } from 'vs/editor/common/modes';
import { CompletionModel } from 'vs/editor/contrib/suggest/completionModel';
import { ISuggestionItem, getSuggestionComparator, ensureLowerCaseVariants } from 'vs/editor/contrib/suggest/suggest';
import { WordDistance } from 'vs/editor/contrib/suggest/wordDistance';

export function createSuggestItem(label: string, overwriteBefore: number, kind = CompletionItemKind.Property, incomplete: boolean = false, position: IPosition = { lineNumber: 1, column: 1 }): ISuggestionItem {

	return new class implements ISuggestionItem {

		position = position;

		suggestion: CompletionItem = {
			label,
			range: { startLineNumber: position.lineNumber, startColumn: position.column - overwriteBefore, endLineNumber: position.lineNumber, endColumn: position.column },
			insertText: label,
			kind
		};

		container: CompletionList = {
			incomplete,
			suggestions: [this.suggestion]
		};

		support: CompletionItemProvider = {
			provideCompletionItems(): any {
				return;
			}
		};

		resolve(): Promise<void> {
			return null;
		}
	};
}
suite('CompletionModel', function () {


	let model: CompletionModel;

	setup(function () {

		model = new CompletionModel([
			createSuggestItem('foo', 3),
			createSuggestItem('Foo', 3),
			createSuggestItem('foo', 2),
		], 1, {
				leadingLineContent: 'foo',
				characterCountDelta: 0
			}, WordDistance.None);
	});

	test('filtering - cached', function () {

		const itemsNow = model.items;
		let itemsThen = model.items;
		assert.ok(itemsNow === itemsThen);

		// still the same context
		model.lineContext = { leadingLineContent: 'foo', characterCountDelta: 0 };
		itemsThen = model.items;
		assert.ok(itemsNow === itemsThen);

		// different context, refilter
		model.lineContext = { leadingLineContent: 'foo1', characterCountDelta: 1 };
		itemsThen = model.items;
		assert.ok(itemsNow !== itemsThen);
	});


	test('complete/incomplete', () => {

		assert.equal(model.incomplete.size, 0);

		let incompleteModel = new CompletionModel([
			createSuggestItem('foo', 3, undefined, true),
			createSuggestItem('foo', 2),
		], 1, {
				leadingLineContent: 'foo',
				characterCountDelta: 0
			}, WordDistance.None);
		assert.equal(incompleteModel.incomplete.size, 1);
	});

	test('replaceIncomplete', () => {

		const completeItem = createSuggestItem('foobar', 1, undefined, false, { lineNumber: 1, column: 2 });
		const incompleteItem = createSuggestItem('foofoo', 1, undefined, true, { lineNumber: 1, column: 2 });

		const model = new CompletionModel([completeItem, incompleteItem], 2, { leadingLineContent: 'f', characterCountDelta: 0 }, WordDistance.None);
		assert.equal(model.incomplete.size, 1);
		assert.equal(model.items.length, 2);

		const { incomplete } = model;
		const complete = model.adopt(incomplete);

		assert.equal(incomplete.size, 1);
		assert.ok(incomplete.has(incompleteItem.support));
		assert.equal(complete.length, 1);
		assert.ok(complete[0] === completeItem);
	});

	test('Fuzzy matching of snippets stopped working with inline snippet suggestions #49895', function () {
		const completeItem1 = createSuggestItem('foobar1', 1, undefined, false, { lineNumber: 1, column: 2 });
		const completeItem2 = createSuggestItem('foobar2', 1, undefined, false, { lineNumber: 1, column: 2 });
		const completeItem3 = createSuggestItem('foobar3', 1, undefined, false, { lineNumber: 1, column: 2 });
		const completeItem4 = createSuggestItem('foobar4', 1, undefined, false, { lineNumber: 1, column: 2 });
		const completeItem5 = createSuggestItem('foobar5', 1, undefined, false, { lineNumber: 1, column: 2 });
		const incompleteItem1 = createSuggestItem('foofoo1', 1, undefined, true, { lineNumber: 1, column: 2 });

		const model = new CompletionModel(
			[
				completeItem1,
				completeItem2,
				completeItem3,
				completeItem4,
				completeItem5,
				incompleteItem1,
			], 2, { leadingLineContent: 'f', characterCountDelta: 0 }, WordDistance.None
		);
		assert.equal(model.incomplete.size, 1);
		assert.equal(model.items.length, 6);

		const { incomplete } = model;
		const complete = model.adopt(incomplete);

		assert.equal(incomplete.size, 1);
		assert.ok(incomplete.has(incompleteItem1.support));
		assert.equal(complete.length, 5);
	});

	test('proper current word when length=0, #16380', function () {

		model = new CompletionModel([
			createSuggestItem('    </div', 4),
			createSuggestItem('a', 0),
			createSuggestItem('p', 0),
			createSuggestItem('    </tag', 4),
			createSuggestItem('    XYZ', 4),
		], 1, {
				leadingLineContent: '   <',
				characterCountDelta: 0
			}, WordDistance.None);

		assert.equal(model.items.length, 4);

		const [a, b, c, d] = model.items;
		assert.equal(a.suggestion.label, '    </div');
		assert.equal(b.suggestion.label, '    </tag');
		assert.equal(c.suggestion.label, 'a');
		assert.equal(d.suggestion.label, 'p');
	});

	test('keep snippet sorting with prefix: top, #25495', function () {

		model = new CompletionModel([
			createSuggestItem('Snippet1', 1, CompletionItemKind.Snippet),
			createSuggestItem('tnippet2', 1, CompletionItemKind.Snippet),
			createSuggestItem('semver', 1, CompletionItemKind.Property),
		], 1, {
				leadingLineContent: 's',
				characterCountDelta: 0
			}, WordDistance.None, { snippets: 'top', snippetsPreventQuickSuggestions: true, filterGraceful: true, localityBonus: false });

		assert.equal(model.items.length, 2);
		const [a, b] = model.items;
		assert.equal(a.suggestion.label, 'Snippet1');
		assert.equal(b.suggestion.label, 'semver');
		assert.ok(a.score < b.score); // snippet really promoted

	});

	test('keep snippet sorting with prefix: bottom, #25495', function () {

		model = new CompletionModel([
			createSuggestItem('snippet1', 1, CompletionItemKind.Snippet),
			createSuggestItem('tnippet2', 1, CompletionItemKind.Snippet),
			createSuggestItem('Semver', 1, CompletionItemKind.Property),
		], 1, {
				leadingLineContent: 's',
				characterCountDelta: 0
			}, WordDistance.None, { snippets: 'bottom', snippetsPreventQuickSuggestions: true, filterGraceful: true, localityBonus: false });

		assert.equal(model.items.length, 2);
		const [a, b] = model.items;
		assert.equal(a.suggestion.label, 'Semver');
		assert.equal(b.suggestion.label, 'snippet1');
		assert.ok(a.score < b.score); // snippet really demoted
	});

	test('keep snippet sorting with prefix: inline, #25495', function () {

		model = new CompletionModel([
			createSuggestItem('snippet1', 1, CompletionItemKind.Snippet),
			createSuggestItem('tnippet2', 1, CompletionItemKind.Snippet),
			createSuggestItem('Semver', 1),
		], 1, {
				leadingLineContent: 's',
				characterCountDelta: 0
			}, WordDistance.None, { snippets: 'inline', snippetsPreventQuickSuggestions: true, filterGraceful: true, localityBonus: false });

		assert.equal(model.items.length, 2);
		const [a, b] = model.items;
		assert.equal(a.suggestion.label, 'snippet1');
		assert.equal(b.suggestion.label, 'Semver');
		assert.ok(a.score > b.score); // snippet really demoted
	});

	test('filterText seems ignored in autocompletion, #26874', function () {

		const item1 = createSuggestItem('Map - java.util', 1);
		item1.suggestion.filterText = 'Map';
		const item2 = createSuggestItem('Map - java.util', 1);

		model = new CompletionModel([item1, item2], 1, {
			leadingLineContent: 'M',
			characterCountDelta: 0
		}, WordDistance.None);

		assert.equal(model.items.length, 2);

		model.lineContext = {
			leadingLineContent: 'Map ',
			characterCountDelta: 3
		};
		assert.equal(model.items.length, 1);
	});

	test('Vscode 1.12 no longer obeys \'sortText\' in completion items (from language server), #26096', function () {

		const item1 = createSuggestItem('<- groups', 2, CompletionItemKind.Property, false, { lineNumber: 1, column: 3 });
		item1.suggestion.filterText = '  groups';
		item1.suggestion.sortText = '00002';

		const item2 = createSuggestItem('source', 0, CompletionItemKind.Property, false, { lineNumber: 1, column: 3 });
		item2.suggestion.filterText = 'source';
		item2.suggestion.sortText = '00001';

		ensureLowerCaseVariants(item1.suggestion);
		ensureLowerCaseVariants(item2.suggestion);

		const items = [item1, item2].sort(getSuggestionComparator('inline'));

		model = new CompletionModel(items, 3, {
			leadingLineContent: '  ',
			characterCountDelta: 0
		}, WordDistance.None);

		assert.equal(model.items.length, 2);

		const [first, second] = model.items;
		assert.equal(first.suggestion.label, 'source');
		assert.equal(second.suggestion.label, '<- groups');
	});

	test('Score only filtered items when typing more, score all when typing less', function () {
		model = new CompletionModel([
			createSuggestItem('console', 0),
			createSuggestItem('co_new', 0),
			createSuggestItem('bar', 0),
			createSuggestItem('car', 0),
			createSuggestItem('foo', 0),
		], 1, {
				leadingLineContent: '',
				characterCountDelta: 0
			}, WordDistance.None);

		assert.equal(model.items.length, 5);

		// narrow down once
		model.lineContext = { leadingLineContent: 'c', characterCountDelta: 1 };
		assert.equal(model.items.length, 3);

		// query gets longer, narrow down the narrow-down'ed-set from before
		model.lineContext = { leadingLineContent: 'cn', characterCountDelta: 2 };
		assert.equal(model.items.length, 2);

		// query gets shorter, refilter everything
		model.lineContext = { leadingLineContent: '', characterCountDelta: 0 };
		assert.equal(model.items.length, 5);
	});

	test('Have more relaxed suggest matching algorithm #15419', function () {
		model = new CompletionModel([
			createSuggestItem('result', 0),
			createSuggestItem('replyToUser', 0),
			createSuggestItem('randomLolut', 0),
			createSuggestItem('car', 0),
			createSuggestItem('foo', 0),
		], 1, {
				leadingLineContent: '',
				characterCountDelta: 0
			}, WordDistance.None);

		// query gets longer, narrow down the narrow-down'ed-set from before
		model.lineContext = { leadingLineContent: 'rlut', characterCountDelta: 4 };
		assert.equal(model.items.length, 3);

		const [first, second, third] = model.items;
		assert.equal(first.suggestion.label, 'result'); // best with `rult`
		assert.equal(second.suggestion.label, 'replyToUser');  // best with `rltu`
		assert.equal(third.suggestion.label, 'randomLolut');  // best with `rlut`
	});

	test('Emmet suggestion not appearing at the top of the list in jsx files, #39518', function () {
		model = new CompletionModel([
			createSuggestItem('from', 0),
			createSuggestItem('form', 0),
			createSuggestItem('form:get', 0),
			createSuggestItem('testForeignMeasure', 0),
			createSuggestItem('fooRoom', 0),
		], 1, {
				leadingLineContent: '',
				characterCountDelta: 0
			}, WordDistance.None);

		model.lineContext = { leadingLineContent: 'form', characterCountDelta: 4 };
		assert.equal(model.items.length, 5);
		const [first, second, third] = model.items;
		assert.equal(first.suggestion.label, 'form'); // best with `form`
		assert.equal(second.suggestion.label, 'form:get');  // best with `form`
		assert.equal(third.suggestion.label, 'from');  // best with `from`
	});
});
