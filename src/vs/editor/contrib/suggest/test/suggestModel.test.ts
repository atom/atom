/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import * as assert from 'assert';
import { Event } from 'vs/base/common/event';
import { Disposable, IDisposable, dispose } from 'vs/base/common/lifecycle';
import { URI } from 'vs/base/common/uri';
import { CoreEditingCommands } from 'vs/editor/browser/controller/coreCommands';
import { EditOperation } from 'vs/editor/common/core/editOperation';
import { Range } from 'vs/editor/common/core/range';
import { Selection } from 'vs/editor/common/core/selection';
import { TokenizationResult2 } from 'vs/editor/common/core/token';
import { Handler } from 'vs/editor/common/editorCommon';
import { TextModel } from 'vs/editor/common/model/textModel';
import { IState, CompletionList, CompletionItemProvider, LanguageIdentifier, MetadataConsts, CompletionProviderRegistry, CompletionTriggerKind, TokenizationRegistry, CompletionItemKind } from 'vs/editor/common/modes';
import { LanguageConfigurationRegistry } from 'vs/editor/common/modes/languageConfigurationRegistry';
import { NULL_STATE } from 'vs/editor/common/modes/nullMode';
import { SnippetController2 } from 'vs/editor/contrib/snippet/snippetController2';
import { SuggestController } from 'vs/editor/contrib/suggest/suggestController';
import { LineContext, SuggestModel } from 'vs/editor/contrib/suggest/suggestModel';
import { ISelectedSuggestion } from 'vs/editor/contrib/suggest/suggestWidget';
import { TestCodeEditor, createTestCodeEditor } from 'vs/editor/test/browser/testCodeEditor';
import { MockMode } from 'vs/editor/test/common/mocks/mockMode';
import { ServiceCollection } from 'vs/platform/instantiation/common/serviceCollection';
import { IStorageService, InMemoryStorageService } from 'vs/platform/storage/common/storage';
import { ITelemetryService } from 'vs/platform/telemetry/common/telemetry';
import { NullTelemetryService } from 'vs/platform/telemetry/common/telemetryUtils';
import { IEditorWorkerService } from 'vs/editor/common/services/editorWorkerService';

export interface Ctor<T> {
	new(): T;
}

export function mock<T>(): Ctor<T> {
	return function () { } as any;
}


function createMockEditor(model: TextModel): TestCodeEditor {
	let editor = createTestCodeEditor({
		model: model,
		serviceCollection: new ServiceCollection(
			[ITelemetryService, NullTelemetryService],
			[IStorageService, InMemoryStorageService]
		),
	});
	editor.registerAndInstantiateContribution(SnippetController2);
	return editor;
}

suite('SuggestModel - Context', function () {
	const OUTER_LANGUAGE_ID = new LanguageIdentifier('outerMode', 3);
	const INNER_LANGUAGE_ID = new LanguageIdentifier('innerMode', 4);

	class OuterMode extends MockMode {
		constructor() {
			super(OUTER_LANGUAGE_ID);
			this._register(LanguageConfigurationRegistry.register(this.getLanguageIdentifier(), {}));

			this._register(TokenizationRegistry.register(this.getLanguageIdentifier().language, {
				getInitialState: (): IState => NULL_STATE,
				tokenize: undefined,
				tokenize2: (line: string, state: IState): TokenizationResult2 => {
					const tokensArr: number[] = [];
					let prevLanguageId: LanguageIdentifier | undefined = undefined;
					for (let i = 0; i < line.length; i++) {
						const languageId = (line.charAt(i) === 'x' ? INNER_LANGUAGE_ID : OUTER_LANGUAGE_ID);
						if (prevLanguageId !== languageId) {
							tokensArr.push(i);
							tokensArr.push((languageId.id << MetadataConsts.LANGUAGEID_OFFSET));
						}
						prevLanguageId = languageId;
					}

					const tokens = new Uint32Array(tokensArr.length);
					for (let i = 0; i < tokens.length; i++) {
						tokens[i] = tokensArr[i];
					}
					return new TokenizationResult2(tokens, state);
				}
			}));
		}
	}

	class InnerMode extends MockMode {
		constructor() {
			super(INNER_LANGUAGE_ID);
			this._register(LanguageConfigurationRegistry.register(this.getLanguageIdentifier(), {}));
		}
	}

	const assertAutoTrigger = (model: TextModel, offset: number, expected: boolean, message?: string): void => {
		const pos = model.getPositionAt(offset);
		const editor = createMockEditor(model);
		editor.setPosition(pos);
		assert.equal(LineContext.shouldAutoTrigger(editor), expected, message);
		editor.dispose();
	};

	let disposables: Disposable[] = [];

	setup(() => {
		disposables = [];
	});

	teardown(function () {
		dispose(disposables);
		disposables = [];
	});

	test('Context - shouldAutoTrigger', function () {
		const model = TextModel.createFromString('Das Pferd frisst keinen Gurkensalat - Philipp Reis 1861.\nWer hat\'s erfunden?');
		disposables.push(model);

		assertAutoTrigger(model, 3, true, 'end of word, Das|');
		assertAutoTrigger(model, 4, false, 'no word Das |');
		assertAutoTrigger(model, 1, false, 'middle of word D|as');
		assertAutoTrigger(model, 55, false, 'number, 1861|');
	});

	test('shouldAutoTrigger at embedded language boundaries', () => {
		const outerMode = new OuterMode();
		const innerMode = new InnerMode();
		disposables.push(outerMode, innerMode);

		const model = TextModel.createFromString('a<xx>a<x>', undefined, outerMode.getLanguageIdentifier());
		disposables.push(model);

		assertAutoTrigger(model, 1, true, 'a|<x — should trigger at end of word');
		assertAutoTrigger(model, 2, false, 'a<|x — should NOT trigger at start of word');
		assertAutoTrigger(model, 3, false, 'a<x|x —  should NOT trigger in middle of word');
		assertAutoTrigger(model, 4, true, 'a<xx|> — should trigger at boundary between languages');
		assertAutoTrigger(model, 5, false, 'a<xx>|a — should NOT trigger at start of word');
		assertAutoTrigger(model, 6, true, 'a<xx>a|< — should trigger at end of word');
		assertAutoTrigger(model, 8, true, 'a<xx>a<x|> — should trigger at end of word at boundary');
	});
});

suite('SuggestModel - TriggerAndCancelOracle', function () {


	const alwaysEmptySupport: CompletionItemProvider = {
		provideCompletionItems(doc, pos): CompletionList {
			return {
				incomplete: false,
				suggestions: []
			};
		}
	};

	const alwaysSomethingSupport: CompletionItemProvider = {
		provideCompletionItems(doc, pos): CompletionList {
			return {
				incomplete: false,
				suggestions: [{
					label: doc.getWordUntilPosition(pos).word,
					kind: CompletionItemKind.Property,
					insertText: 'foofoo'
				}]
			};
		}
	};

	let disposables: IDisposable[] = [];
	let model: TextModel;

	setup(function () {
		disposables = dispose(disposables);
		model = TextModel.createFromString('abc def', undefined, undefined, URI.parse('test:somefile.ttt'));
		disposables.push(model);
	});

	function withOracle(callback: (model: SuggestModel, editor: TestCodeEditor) => any): Promise<any> {

		return new Promise((resolve, reject) => {
			const editor = createMockEditor(model);
			const oracle = new SuggestModel(editor, new class extends mock<IEditorWorkerService>() {
				computeWordRanges() {
					return Promise.resolve({});
				}

			});
			disposables.push(oracle, editor);

			try {
				resolve(callback(oracle, editor));
			} catch (err) {
				reject(err);
			}
		});
	}

	function assertEvent<E>(event: Event<E>, action: () => any, assert: (e: E) => any) {
		return new Promise((resolve, reject) => {
			const sub = event(e => {
				sub.dispose();
				try {
					resolve(assert(e));
				} catch (err) {
					reject(err);
				}
			});
			try {
				action();
			} catch (err) {
				reject(err);
			}
		});
	}

	test('events - cancel/trigger', function () {
		return withOracle(model => {

			return Promise.all([
				assertEvent(model.onDidCancel, function () {
					model.cancel();
				}, function (event) {
					assert.equal(event.retrigger, false);
				}),

				assertEvent(model.onDidCancel, function () {
					model.cancel(true);
				}, function (event) {
					assert.equal(event.retrigger, true);
				}),

				// cancel on trigger
				assertEvent(model.onDidCancel, function () {
					model.trigger({ auto: false });
				}, function (event) {
					assert.equal(event.retrigger, false);
				}),

				assertEvent(model.onDidCancel, function () {
					model.trigger({ auto: false }, true);
				}, function (event) {
					assert.equal(event.retrigger, true);
				}),

				assertEvent(model.onDidTrigger, function () {
					model.trigger({ auto: true });
				}, function (event) {
					assert.equal(event.auto, true);
				}),

				assertEvent(model.onDidTrigger, function () {
					model.trigger({ auto: false });
				}, function (event) {
					assert.equal(event.auto, false);
				})
			]);
		});
	});


	test('events - suggest/empty', function () {

		disposables.push(CompletionProviderRegistry.register({ scheme: 'test' }, alwaysEmptySupport));

		return withOracle(model => {
			return Promise.all([
				assertEvent(model.onDidCancel, function () {
					model.trigger({ auto: true });
				}, function (event) {
					assert.equal(event.retrigger, false);
				}),
				assertEvent(model.onDidSuggest, function () {
					model.trigger({ auto: false });
				}, function (event) {
					assert.equal(event.auto, false);
					assert.equal(event.isFrozen, false);
					assert.equal(event.completionModel.items.length, 0);
				})
			]);
		});
	});

	test('trigger - on type', function () {

		disposables.push(CompletionProviderRegistry.register({ scheme: 'test' }, alwaysSomethingSupport));

		return withOracle((model, editor) => {
			return assertEvent(model.onDidSuggest, () => {
				editor.setPosition({ lineNumber: 1, column: 4 });
				editor.trigger('keyboard', Handler.Type, { text: 'd' });

			}, event => {
				assert.equal(event.auto, true);
				assert.equal(event.completionModel.items.length, 1);
				const [first] = event.completionModel.items;

				assert.equal(first.support, alwaysSomethingSupport);
			});
		});
	});

	test('#17400: Keep filtering suggestModel.ts after space', function () {

		disposables.push(CompletionProviderRegistry.register({ scheme: 'test' }, {
			provideCompletionItems(doc, pos): CompletionList {
				return {
					incomplete: false,
					suggestions: [{
						label: 'My Table',
						kind: CompletionItemKind.Property,
						insertText: 'My Table'
					}]
				};
			}
		}));

		model.setValue('');

		return withOracle((model, editor) => {

			return assertEvent(model.onDidSuggest, () => {
				// make sure completionModel starts here!
				model.trigger({ auto: true });
			}, event => {

				return assertEvent(model.onDidSuggest, () => {
					editor.setPosition({ lineNumber: 1, column: 1 });
					editor.trigger('keyboard', Handler.Type, { text: 'My' });

				}, event => {
					assert.equal(event.auto, true);
					assert.equal(event.completionModel.items.length, 1);
					const [first] = event.completionModel.items;
					assert.equal(first.suggestion.label, 'My Table');

					return assertEvent(model.onDidSuggest, () => {
						editor.setPosition({ lineNumber: 1, column: 3 });
						editor.trigger('keyboard', Handler.Type, { text: ' ' });

					}, event => {
						assert.equal(event.auto, true);
						assert.equal(event.completionModel.items.length, 1);
						const [first] = event.completionModel.items;
						assert.equal(first.suggestion.label, 'My Table');
					});
				});
			});
		});
	});

	test('#21484: Trigger character always force a new completion session', function () {

		disposables.push(CompletionProviderRegistry.register({ scheme: 'test' }, {
			provideCompletionItems(doc, pos): CompletionList {
				return {
					incomplete: false,
					suggestions: [{
						label: 'foo.bar',
						kind: CompletionItemKind.Property,
						insertText: 'foo.bar',
						range: Range.fromPositions(pos.with(undefined, 1), pos)
					}]
				};
			}
		}));

		disposables.push(CompletionProviderRegistry.register({ scheme: 'test' }, {
			triggerCharacters: ['.'],
			provideCompletionItems(doc, pos): CompletionList {
				return {
					incomplete: false,
					suggestions: [{
						label: 'boom',
						kind: CompletionItemKind.Property,
						insertText: 'boom',
						range: Range.fromPositions(
							pos.delta(0, doc.getLineContent(pos.lineNumber)[pos.column - 2] === '.' ? 0 : -1),
							pos
						)
					}]
				};
			}
		}));

		model.setValue('');

		return withOracle((model, editor) => {

			return assertEvent(model.onDidSuggest, () => {
				editor.setPosition({ lineNumber: 1, column: 1 });
				editor.trigger('keyboard', Handler.Type, { text: 'foo' });

			}, event => {
				assert.equal(event.auto, true);
				assert.equal(event.completionModel.items.length, 1);
				const [first] = event.completionModel.items;
				assert.equal(first.suggestion.label, 'foo.bar');

				return assertEvent(model.onDidSuggest, () => {
					editor.trigger('keyboard', Handler.Type, { text: '.' });

				}, event => {
					assert.equal(event.auto, true);
					assert.equal(event.completionModel.items.length, 2);
					const [first, second] = event.completionModel.items;
					assert.equal(first.suggestion.label, 'foo.bar');
					assert.equal(second.suggestion.label, 'boom');
				});
			});
		});
	});

	test('Intellisense Completion doesn\'t respect space after equal sign (.html file), #29353 [1/2]', function () {

		disposables.push(CompletionProviderRegistry.register({ scheme: 'test' }, alwaysSomethingSupport));

		return withOracle((model, editor) => {

			editor.getModel().setValue('fo');
			editor.setPosition({ lineNumber: 1, column: 3 });

			return assertEvent(model.onDidSuggest, () => {
				model.trigger({ auto: false });
			}, event => {
				assert.equal(event.auto, false);
				assert.equal(event.isFrozen, false);
				assert.equal(event.completionModel.items.length, 1);

				return assertEvent(model.onDidCancel, () => {
					editor.trigger('keyboard', Handler.Type, { text: '+' });
				}, event => {
					assert.equal(event.retrigger, false);
				});
			});
		});
	});

	test('Intellisense Completion doesn\'t respect space after equal sign (.html file), #29353 [2/2]', function () {

		disposables.push(CompletionProviderRegistry.register({ scheme: 'test' }, alwaysSomethingSupport));

		return withOracle((model, editor) => {

			editor.getModel().setValue('fo');
			editor.setPosition({ lineNumber: 1, column: 3 });

			return assertEvent(model.onDidSuggest, () => {
				model.trigger({ auto: false });
			}, event => {
				assert.equal(event.auto, false);
				assert.equal(event.isFrozen, false);
				assert.equal(event.completionModel.items.length, 1);

				return assertEvent(model.onDidCancel, () => {
					editor.trigger('keyboard', Handler.Type, { text: ' ' });
				}, event => {
					assert.equal(event.retrigger, false);
				});
			});
		});
	});

	test('Incomplete suggestion results cause re-triggering when typing w/o further context, #28400 (1/2)', function () {

		disposables.push(CompletionProviderRegistry.register({ scheme: 'test' }, {
			provideCompletionItems(doc, pos): CompletionList {
				return {
					incomplete: true,
					suggestions: [{
						label: 'foo',
						kind: CompletionItemKind.Property,
						insertText: 'foo',
						range: Range.fromPositions(pos.with(undefined, 1), pos)
					}]
				};
			}
		}));

		return withOracle((model, editor) => {

			editor.getModel().setValue('foo');
			editor.setPosition({ lineNumber: 1, column: 4 });

			return assertEvent(model.onDidSuggest, () => {
				model.trigger({ auto: false });
			}, event => {
				assert.equal(event.auto, false);
				assert.equal(event.completionModel.incomplete.size, 1);
				assert.equal(event.completionModel.items.length, 1);

				return assertEvent(model.onDidCancel, () => {
					editor.trigger('keyboard', Handler.Type, { text: ';' });
				}, event => {
					assert.equal(event.retrigger, false);
				});
			});
		});
	});

	test('Incomplete suggestion results cause re-triggering when typing w/o further context, #28400 (2/2)', function () {

		disposables.push(CompletionProviderRegistry.register({ scheme: 'test' }, {
			provideCompletionItems(doc, pos): CompletionList {
				return {
					incomplete: true,
					suggestions: [{
						label: 'foo;',
						kind: CompletionItemKind.Property,
						insertText: 'foo',
						range: Range.fromPositions(pos.with(undefined, 1), pos)
					}]
				};
			}
		}));

		return withOracle((model, editor) => {

			editor.getModel().setValue('foo');
			editor.setPosition({ lineNumber: 1, column: 4 });

			return assertEvent(model.onDidSuggest, () => {
				model.trigger({ auto: false });
			}, event => {
				assert.equal(event.auto, false);
				assert.equal(event.completionModel.incomplete.size, 1);
				assert.equal(event.completionModel.items.length, 1);

				return assertEvent(model.onDidSuggest, () => {
					// while we cancel incrementally enriching the set of
					// completions we still filter against those that we have
					// until now
					editor.trigger('keyboard', Handler.Type, { text: ';' });
				}, event => {
					assert.equal(event.auto, false);
					assert.equal(event.completionModel.incomplete.size, 1);
					assert.equal(event.completionModel.items.length, 1);

				});
			});
		});
	});

	test('Trigger character is provided in suggest context', function () {
		let triggerCharacter = '';
		disposables.push(CompletionProviderRegistry.register({ scheme: 'test' }, {
			triggerCharacters: ['.'],
			provideCompletionItems(doc, pos, context): CompletionList {
				assert.equal(context.triggerKind, CompletionTriggerKind.TriggerCharacter);
				triggerCharacter = context.triggerCharacter;
				return {
					incomplete: false,
					suggestions: [
						{
							label: 'foo.bar',
							kind: CompletionItemKind.Property,
							insertText: 'foo.bar',
							range: Range.fromPositions(pos.with(undefined, 1), pos)
						}
					]
				};
			}
		}));

		model.setValue('');

		return withOracle((model, editor) => {

			return assertEvent(model.onDidSuggest, () => {
				editor.setPosition({ lineNumber: 1, column: 1 });
				editor.trigger('keyboard', Handler.Type, { text: 'foo.' });
			}, event => {
				assert.equal(triggerCharacter, '.');
			});
		});
	});

	test('Mac press and hold accent character insertion does not update suggestions, #35269', function () {
		disposables.push(CompletionProviderRegistry.register({ scheme: 'test' }, {
			provideCompletionItems(doc, pos): CompletionList {
				return {
					incomplete: true,
					suggestions: [{
						label: 'abc',
						kind: CompletionItemKind.Property,
						insertText: 'abc',
						range: Range.fromPositions(pos.with(undefined, 1), pos)
					}, {
						label: 'äbc',
						kind: CompletionItemKind.Property,
						insertText: 'äbc',
						range: Range.fromPositions(pos.with(undefined, 1), pos)
					}]
				};
			}
		}));

		model.setValue('');
		return withOracle((model, editor) => {

			return assertEvent(model.onDidSuggest, () => {
				editor.setPosition({ lineNumber: 1, column: 1 });
				editor.trigger('keyboard', Handler.Type, { text: 'a' });
			}, event => {
				assert.equal(event.completionModel.items.length, 1);
				assert.equal(event.completionModel.items[0].suggestion.label, 'abc');

				return assertEvent(model.onDidSuggest, () => {
					editor.executeEdits('test', [EditOperation.replace(new Range(1, 1, 1, 2), 'ä')]);

				}, event => {
					// suggest model changed to äbc
					assert.equal(event.completionModel.items.length, 1);
					assert.equal(event.completionModel.items[0].suggestion.label, 'äbc');

				});
			});
		});
	});

	test('Backspace should not always cancel code completion, #36491', function () {
		disposables.push(CompletionProviderRegistry.register({ scheme: 'test' }, alwaysSomethingSupport));

		return withOracle(async (model, editor) => {
			await assertEvent(model.onDidSuggest, () => {
				editor.setPosition({ lineNumber: 1, column: 4 });
				editor.trigger('keyboard', Handler.Type, { text: 'd' });

			}, event => {
				assert.equal(event.auto, true);
				assert.equal(event.completionModel.items.length, 1);
				const [first] = event.completionModel.items;

				assert.equal(first.support, alwaysSomethingSupport);
			});

			await assertEvent(model.onDidSuggest, () => {
				CoreEditingCommands.DeleteLeft.runEditorCommand(null, editor, null);

			}, event => {
				assert.equal(event.auto, true);
				assert.equal(event.completionModel.items.length, 1);
				const [first] = event.completionModel.items;

				assert.equal(first.support, alwaysSomethingSupport);
			});
		});
	});

	test('Text changes for completion CodeAction are affected by the completion #39893', function () {
		disposables.push(CompletionProviderRegistry.register({ scheme: 'test' }, {
			provideCompletionItems(doc, pos): CompletionList {
				return {
					incomplete: true,
					suggestions: [{
						label: 'bar',
						kind: CompletionItemKind.Property,
						insertText: 'bar',
						range: Range.fromPositions(pos.delta(0, -2), pos),
						additionalTextEdits: [{
							text: ', bar',
							range: { startLineNumber: 1, endLineNumber: 1, startColumn: 17, endColumn: 17 }
						}]
					}]
				};
			}
		}));

		model.setValue('ba; import { foo } from "./b"');

		return withOracle(async (sugget, editor) => {
			class TestCtrl extends SuggestController {
				_onDidSelectItem(item: ISelectedSuggestion) {
					super._onDidSelectItem(item, false, true);
				}
			}
			const ctrl = <TestCtrl>editor.registerAndInstantiateContribution(TestCtrl);
			editor.registerAndInstantiateContribution(SnippetController2);

			await assertEvent(sugget.onDidSuggest, () => {
				editor.setPosition({ lineNumber: 1, column: 3 });
				sugget.trigger({ auto: false });
			}, event => {

				assert.equal(event.completionModel.items.length, 1);
				const [first] = event.completionModel.items;
				assert.equal(first.suggestion.label, 'bar');

				ctrl._onDidSelectItem({ item: first, index: 0, model: event.completionModel });
			});

			assert.equal(
				model.getValue(),
				'bar; import { foo, bar } from "./b"'
			);
		});
	});

	test('Completion unexpectedly triggers on second keypress of an edit group in a snippet #43523', function () {

		disposables.push(CompletionProviderRegistry.register({ scheme: 'test' }, alwaysSomethingSupport));

		return withOracle((model, editor) => {
			return assertEvent(model.onDidSuggest, () => {
				editor.setValue('d');
				editor.setSelection(new Selection(1, 1, 1, 2));
				editor.trigger('keyboard', Handler.Type, { text: 'e' });

			}, event => {
				assert.equal(event.auto, true);
				assert.equal(event.completionModel.items.length, 1);
				const [first] = event.completionModel.items;

				assert.equal(first.support, alwaysSomethingSupport);
			});
		});
	});


	test('Fails to render completion details #47988', function () {

		let disposeA = 0;
		let disposeB = 0;

		disposables.push(CompletionProviderRegistry.register({ scheme: 'test' }, {
			provideCompletionItems(doc, pos) {
				return {
					incomplete: true,
					suggestions: [{ kind: CompletionItemKind.Folder, label: 'CompleteNot', insertText: 'Incomplete', sortText: 'a', overwriteBefore: pos.column - 1 }],
					dispose() { disposeA += 1; }
				};
			}
		}));
		disposables.push(CompletionProviderRegistry.register({ scheme: 'test' }, {
			provideCompletionItems(doc, pos) {
				return {
					incomplete: false,
					suggestions: [{ kind: CompletionItemKind.Folder, label: 'Complete', insertText: 'Complete', sortText: 'z', overwriteBefore: pos.column - 1 }],
					dispose() { disposeB += 1; }
				};
			},
			resolveCompletionItem(doc, pos, item) {
				return item;
			},
		}));

		return withOracle(async (model, editor) => {

			await assertEvent(model.onDidSuggest, () => {
				editor.setValue('');
				editor.setSelection(new Selection(1, 1, 1, 1));
				editor.trigger('keyboard', Handler.Type, { text: 'c' });

			}, event => {
				assert.equal(event.auto, true);
				assert.equal(event.completionModel.items.length, 2);
				assert.equal(disposeA, 0);
				assert.equal(disposeB, 0);
			});

			await assertEvent(model.onDidSuggest, () => {
				editor.trigger('keyboard', Handler.Type, { text: 'o' });
			}, event => {
				assert.equal(event.auto, true);
				assert.equal(event.completionModel.items.length, 2);
				assert.equal(disposeA, 1);
				assert.equal(disposeB, 0);
			});
		});
	});
});
