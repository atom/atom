/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import * as sinon from 'sinon';
import { Emitter } from 'vs/base/common/event';
import { ExtHostTreeViews } from 'vs/workbench/api/node/extHostTreeViews';
import { ExtHostCommands } from 'vs/workbench/api/node/extHostCommands';
import { MainThreadTreeViewsShape, MainContext } from 'vs/workbench/api/node/extHost.protocol';
import { TreeDataProvider, TreeItem } from 'vscode';
import { TestRPCProtocol } from './testRPCProtocol';
import { ExtHostHeapService } from 'vs/workbench/api/node/extHostHeapService';
import { TestInstantiationService } from 'vs/platform/instantiation/test/common/instantiationServiceMock';
import { MainThreadCommands } from 'vs/workbench/api/electron-browser/mainThreadCommands';
import { IInstantiationService } from 'vs/platform/instantiation/common/instantiation';
import { mock } from 'vs/workbench/test/electron-browser/api/mock';
import { TreeItemCollapsibleState, ITreeItem } from 'vs/workbench/common/views';
import { NullLogService } from 'vs/platform/log/common/log';
import { IExtensionDescription } from 'vs/workbench/services/extensions/common/extensions';

suite('ExtHostTreeView', function () {

	class RecordingShape extends mock<MainThreadTreeViewsShape>() {

		onRefresh = new Emitter<{ [treeItemHandle: string]: ITreeItem }>();

		$registerTreeViewDataProvider(treeViewId: string): void {
		}

		$refresh(viewId: string, itemsToRefresh?: { [treeItemHandle: string]: ITreeItem }): Promise<void> {
			return Promise.resolve(null).then(() => this.onRefresh.fire(itemsToRefresh));
		}

		$reveal(): Promise<void> {
			return null;
		}

	}

	let testObject: ExtHostTreeViews;
	let target: RecordingShape;
	let onDidChangeTreeNode: Emitter<{ key: string }>;
	let onDidChangeTreeNodeWithId: Emitter<{ key: string }>;
	let tree, labels, nodes;

	setup(() => {
		tree = {
			'a': {
				'aa': {},
				'ab': {}
			},
			'b': {
				'ba': {},
				'bb': {}
			}
		};

		labels = {};
		nodes = {};

		let rpcProtocol = new TestRPCProtocol();
		// Use IInstantiationService to get typechecking when instantiating
		let inst: IInstantiationService;
		{
			let instantiationService = new TestInstantiationService();
			inst = instantiationService;
		}

		rpcProtocol.set(MainContext.MainThreadCommands, inst.createInstance(MainThreadCommands, rpcProtocol));
		target = new RecordingShape();
		testObject = new ExtHostTreeViews(target, new ExtHostCommands(rpcProtocol, new ExtHostHeapService(), new NullLogService()), new NullLogService());
		onDidChangeTreeNode = new Emitter<{ key: string }>();
		onDidChangeTreeNodeWithId = new Emitter<{ key: string }>();
		testObject.createTreeView('testNodeTreeProvider', { treeDataProvider: aNodeTreeDataProvider() }, { enableProposedApi: true } as IExtensionDescription);
		testObject.createTreeView('testNodeWithIdTreeProvider', { treeDataProvider: aNodeWithIdTreeDataProvider() }, { enableProposedApi: true } as IExtensionDescription);
		testObject.createTreeView('testNodeWithHighlightsTreeProvider', { treeDataProvider: aNodeWithHighlightedLabelTreeDataProvider() }, { enableProposedApi: true } as IExtensionDescription);

		return loadCompleteTree('testNodeTreeProvider');
	});

	test('construct node tree', () => {
		return testObject.$getChildren('testNodeTreeProvider')
			.then(elements => {
				const actuals = elements.map(e => e.handle);
				assert.deepEqual(actuals, ['0/0:a', '0/0:b']);
				return Promise.all([
					testObject.$getChildren('testNodeTreeProvider', '0/0:a')
						.then(children => {
							const actuals = children.map(e => e.handle);
							assert.deepEqual(actuals, ['0/0:a/0:aa', '0/0:a/0:ab']);
							return Promise.all([
								testObject.$getChildren('testNodeTreeProvider', '0/0:a/0:aa').then(children => assert.equal(children.length, 0)),
								testObject.$getChildren('testNodeTreeProvider', '0/0:a/0:ab').then(children => assert.equal(children.length, 0))
							]);
						}),
					testObject.$getChildren('testNodeTreeProvider', '0/0:b')
						.then(children => {
							const actuals = children.map(e => e.handle);
							assert.deepEqual(actuals, ['0/0:b/0:ba', '0/0:b/0:bb']);
							return Promise.all([
								testObject.$getChildren('testNodeTreeProvider', '0/0:b/0:ba').then(children => assert.equal(children.length, 0)),
								testObject.$getChildren('testNodeTreeProvider', '0/0:b/0:bb').then(children => assert.equal(children.length, 0))
							]);
						})
				]);
			});
	});

	test('construct id tree', () => {
		return testObject.$getChildren('testNodeWithIdTreeProvider')
			.then(elements => {
				const actuals = elements.map(e => e.handle);
				assert.deepEqual(actuals, ['1/a', '1/b']);
				return Promise.all([
					testObject.$getChildren('testNodeWithIdTreeProvider', '1/a')
						.then(children => {
							const actuals = children.map(e => e.handle);
							assert.deepEqual(actuals, ['1/aa', '1/ab']);
							return Promise.all([
								testObject.$getChildren('testNodeWithIdTreeProvider', '1/aa').then(children => assert.equal(children.length, 0)),
								testObject.$getChildren('testNodeWithIdTreeProvider', '1/ab').then(children => assert.equal(children.length, 0))
							]);
						}),
					testObject.$getChildren('testNodeWithIdTreeProvider', '1/b')
						.then(children => {
							const actuals = children.map(e => e.handle);
							assert.deepEqual(actuals, ['1/ba', '1/bb']);
							return Promise.all([
								testObject.$getChildren('testNodeWithIdTreeProvider', '1/ba').then(children => assert.equal(children.length, 0)),
								testObject.$getChildren('testNodeWithIdTreeProvider', '1/bb').then(children => assert.equal(children.length, 0))
							]);
						})
				]);
			});
	});

	test('construct highlights tree', () => {
		return testObject.$getChildren('testNodeWithHighlightsTreeProvider')
			.then(elements => {
				assert.deepEqual(removeUnsetKeys(elements), [{
					handle: '1/a',
					label: { label: 'a', highlights: [[0, 2], [3, 5]] },
					collapsibleState: TreeItemCollapsibleState.Collapsed
				}, {
					handle: '1/b',
					label: { label: 'b', highlights: [[0, 2], [3, 5]] },
					collapsibleState: TreeItemCollapsibleState.Collapsed
				}]);
				return Promise.all([
					testObject.$getChildren('testNodeWithHighlightsTreeProvider', '1/a')
						.then(children => {
							assert.deepEqual(removeUnsetKeys(children), [{
								handle: '1/aa',
								parentHandle: '1/a',
								label: { label: 'aa', highlights: [[0, 2], [3, 5]] },
								collapsibleState: TreeItemCollapsibleState.None
							}, {
								handle: '1/ab',
								parentHandle: '1/a',
								label: { label: 'ab', highlights: [[0, 2], [3, 5]] },
								collapsibleState: TreeItemCollapsibleState.None
							}]);
						}),
					testObject.$getChildren('testNodeWithHighlightsTreeProvider', '1/b')
						.then(children => {
							assert.deepEqual(removeUnsetKeys(children), [{
								handle: '1/ba',
								parentHandle: '1/b',
								label: { label: 'ba', highlights: [[0, 2], [3, 5]] },
								collapsibleState: TreeItemCollapsibleState.None
							}, {
								handle: '1/bb',
								parentHandle: '1/b',
								label: { label: 'bb', highlights: [[0, 2], [3, 5]] },
								collapsibleState: TreeItemCollapsibleState.None
							}]);
						})
				]);
			});
	});

	test('error is thrown if id is not unique', (done) => {
		tree['a'] = {
			'aa': {},
		};
		tree['b'] = {
			'aa': {},
			'ba': {}
		};
		target.onRefresh.event(() => {
			testObject.$getChildren('testNodeWithIdTreeProvider')
				.then(elements => {
					const actuals = elements.map(e => e.handle);
					assert.deepEqual(actuals, ['1/a', '1/b']);
					return testObject.$getChildren('testNodeWithIdTreeProvider', '1/a')
						.then(() => testObject.$getChildren('testNodeWithIdTreeProvider', '1/b'))
						.then(() => { assert.fail('Should fail with duplicate id'); done(); }, () => done());
				});
		});
		onDidChangeTreeNode.fire();
	});

	test('refresh root', function (done) {
		target.onRefresh.event(actuals => {
			assert.equal(undefined, actuals);
			done();
		});
		onDidChangeTreeNode.fire();
	});

	test('refresh a parent node', () => {
		return new Promise((c, e) => {
			target.onRefresh.event(actuals => {
				assert.deepEqual(['0/0:b'], Object.keys(actuals));
				assert.deepEqual(removeUnsetKeys(actuals['0/0:b']), {
					handle: '0/0:b',
					label: { label: 'b' },
					collapsibleState: TreeItemCollapsibleState.Collapsed
				});
				c(null);
			});
			onDidChangeTreeNode.fire(getNode('b'));
		});
	});

	test('refresh a leaf node', function (done) {
		target.onRefresh.event(actuals => {
			assert.deepEqual(['0/0:b/0:bb'], Object.keys(actuals));
			assert.deepEqual(removeUnsetKeys(actuals['0/0:b/0:bb']), {
				handle: '0/0:b/0:bb',
				parentHandle: '0/0:b',
				label: { label: 'bb' },
				collapsibleState: TreeItemCollapsibleState.None
			});
			done();
		});
		onDidChangeTreeNode.fire(getNode('bb'));
	});

	test('refresh parent and child node trigger refresh only on parent - scenario 1', function (done) {
		target.onRefresh.event(actuals => {
			assert.deepEqual(['0/0:b', '0/0:a/0:aa'], Object.keys(actuals));
			assert.deepEqual(removeUnsetKeys(actuals['0/0:b']), {
				handle: '0/0:b',
				label: { label: 'b' },
				collapsibleState: TreeItemCollapsibleState.Collapsed
			});
			assert.deepEqual(removeUnsetKeys(actuals['0/0:a/0:aa']), {
				handle: '0/0:a/0:aa',
				parentHandle: '0/0:a',
				label: { label: 'aa' },
				collapsibleState: TreeItemCollapsibleState.None
			});
			done();
		});
		onDidChangeTreeNode.fire(getNode('b'));
		onDidChangeTreeNode.fire(getNode('aa'));
		onDidChangeTreeNode.fire(getNode('bb'));
	});

	test('refresh parent and child node trigger refresh only on parent - scenario 2', function (done) {
		target.onRefresh.event(actuals => {
			assert.deepEqual(['0/0:a/0:aa', '0/0:b'], Object.keys(actuals));
			assert.deepEqual(removeUnsetKeys(actuals['0/0:b']), {
				handle: '0/0:b',
				label: { label: 'b' },
				collapsibleState: TreeItemCollapsibleState.Collapsed
			});
			assert.deepEqual(removeUnsetKeys(actuals['0/0:a/0:aa']), {
				handle: '0/0:a/0:aa',
				parentHandle: '0/0:a',
				label: { label: 'aa' },
				collapsibleState: TreeItemCollapsibleState.None
			});
			done();
		});
		onDidChangeTreeNode.fire(getNode('bb'));
		onDidChangeTreeNode.fire(getNode('aa'));
		onDidChangeTreeNode.fire(getNode('b'));
	});

	test('refresh an element for label change', function (done) {
		labels['a'] = 'aa';
		target.onRefresh.event(actuals => {
			assert.deepEqual(['0/0:a'], Object.keys(actuals));
			assert.deepEqual(removeUnsetKeys(actuals['0/0:a']), {
				handle: '0/0:aa',
				label: { label: 'aa' },
				collapsibleState: TreeItemCollapsibleState.Collapsed
			});
			done();
		});
		onDidChangeTreeNode.fire(getNode('a'));
	});

	test('refresh calls are throttled on roots', function (done) {
		target.onRefresh.event(actuals => {
			assert.equal(undefined, actuals);
			done();
		});
		onDidChangeTreeNode.fire();
		onDidChangeTreeNode.fire();
		onDidChangeTreeNode.fire();
		onDidChangeTreeNode.fire();
	});

	test('refresh calls are throttled on elements', function (done) {
		target.onRefresh.event(actuals => {
			assert.deepEqual(['0/0:a', '0/0:b'], Object.keys(actuals));
			done();
		});

		onDidChangeTreeNode.fire(getNode('a'));
		onDidChangeTreeNode.fire(getNode('b'));
		onDidChangeTreeNode.fire(getNode('b'));
		onDidChangeTreeNode.fire(getNode('a'));
	});

	test('refresh calls are throttled on unknown elements', function (done) {
		target.onRefresh.event(actuals => {
			assert.deepEqual(['0/0:a', '0/0:b'], Object.keys(actuals));
			done();
		});

		onDidChangeTreeNode.fire(getNode('a'));
		onDidChangeTreeNode.fire(getNode('b'));
		onDidChangeTreeNode.fire(getNode('g'));
		onDidChangeTreeNode.fire(getNode('a'));
	});

	test('refresh calls are throttled on unknown elements and root', function (done) {
		target.onRefresh.event(actuals => {
			assert.equal(undefined, actuals);
			done();
		});

		onDidChangeTreeNode.fire(getNode('a'));
		onDidChangeTreeNode.fire(getNode('b'));
		onDidChangeTreeNode.fire(getNode('g'));
		onDidChangeTreeNode.fire();
	});

	test('refresh calls are throttled on elements and root', function (done) {
		target.onRefresh.event(actuals => {
			assert.equal(undefined, actuals);
			done();
		});

		onDidChangeTreeNode.fire(getNode('a'));
		onDidChangeTreeNode.fire(getNode('b'));
		onDidChangeTreeNode.fire();
		onDidChangeTreeNode.fire(getNode('a'));
	});

	test('generate unique handles from labels by escaping them', (done) => {
		tree = {
			'a/0:b': {}
		};

		target.onRefresh.event(() => {
			testObject.$getChildren('testNodeTreeProvider')
				.then(elements => {
					assert.deepEqual(elements.map(e => e.handle), ['0/0:a//0:b']);
					done();
				});
		});
		onDidChangeTreeNode.fire();
	});

	test('tree with duplicate labels', (done) => {

		const dupItems = {
			'adup1': 'c',
			'adup2': 'g',
			'bdup1': 'e',
			'hdup1': 'i',
			'hdup2': 'l',
			'jdup1': 'k'
		};

		labels['c'] = 'a';
		labels['e'] = 'b';
		labels['g'] = 'a';
		labels['i'] = 'h';
		labels['l'] = 'h';
		labels['k'] = 'j';

		tree[dupItems['adup1']] = {};
		tree['d'] = {};

		const bdup1Tree = {};
		bdup1Tree['h'] = {};
		bdup1Tree[dupItems['hdup1']] = {};
		bdup1Tree['j'] = {};
		bdup1Tree[dupItems['jdup1']] = {};
		bdup1Tree[dupItems['hdup2']] = {};

		tree[dupItems['bdup1']] = bdup1Tree;
		tree['f'] = {};
		tree[dupItems['adup2']] = {};

		target.onRefresh.event(() => {
			testObject.$getChildren('testNodeTreeProvider')
				.then(elements => {
					const actuals = elements.map(e => e.handle);
					assert.deepEqual(actuals, ['0/0:a', '0/0:b', '0/1:a', '0/0:d', '0/1:b', '0/0:f', '0/2:a']);
					return testObject.$getChildren('testNodeTreeProvider', '0/1:b')
						.then(elements => {
							const actuals = elements.map(e => e.handle);
							assert.deepEqual(actuals, ['0/1:b/0:h', '0/1:b/1:h', '0/1:b/0:j', '0/1:b/1:j', '0/1:b/2:h']);
							done();
						});
				});
		});

		onDidChangeTreeNode.fire();
	});

	test('getChildren is not returned from cache if refreshed', (done) => {
		tree = {
			'c': {}
		};

		target.onRefresh.event(() => {
			testObject.$getChildren('testNodeTreeProvider')
				.then(elements => {
					assert.deepEqual(elements.map(e => e.handle), ['0/0:c']);
					done();
				});
		});

		onDidChangeTreeNode.fire();
	});

	test('getChildren is returned from cache if not refreshed', () => {
		tree = {
			'c': {}
		};

		return testObject.$getChildren('testNodeTreeProvider')
			.then(elements => {
				assert.deepEqual(elements.map(e => e.handle), ['0/0:a', '0/0:b']);
			});
	});

	test('reveal will throw an error if getParent is not implemented', () => {
		const treeView = testObject.createTreeView('treeDataProvider', { treeDataProvider: aNodeTreeDataProvider() }, { enableProposedApi: true } as IExtensionDescription);
		return treeView.reveal({ key: 'a' })
			.then(() => assert.fail('Reveal should throw an error as getParent is not implemented'), () => null);
	});

	test('reveal will return empty array for root element', () => {
		const revealTarget = sinon.spy(target, '$reveal');
		const treeView = testObject.createTreeView('treeDataProvider', { treeDataProvider: aCompleteNodeTreeDataProvider() }, { enableProposedApi: true } as IExtensionDescription);
		return treeView.reveal({ key: 'a' })
			.then(() => {
				assert.ok(revealTarget.calledOnce);
				assert.deepEqual('treeDataProvider', revealTarget.args[0][0]);
				assert.deepEqual({ handle: '0/0:a', label: { label: 'a' }, collapsibleState: TreeItemCollapsibleState.Collapsed }, removeUnsetKeys(revealTarget.args[0][1]));
				assert.deepEqual([], revealTarget.args[0][2]);
				assert.deepEqual({ select: true, focus: false, expand: false }, revealTarget.args[0][3]);
			});
	});

	test('reveal will return parents array for an element when hierarchy is not loaded', () => {
		const revealTarget = sinon.spy(target, '$reveal');
		const treeView = testObject.createTreeView('treeDataProvider', { treeDataProvider: aCompleteNodeTreeDataProvider() }, { enableProposedApi: true } as IExtensionDescription);
		return treeView.reveal({ key: 'aa' })
			.then(() => {
				assert.ok(revealTarget.calledOnce);
				assert.deepEqual('treeDataProvider', revealTarget.args[0][0]);
				assert.deepEqual({ handle: '0/0:a/0:aa', label: { label: 'aa' }, collapsibleState: TreeItemCollapsibleState.None, parentHandle: '0/0:a' }, removeUnsetKeys(revealTarget.args[0][1]));
				assert.deepEqual([{ handle: '0/0:a', label: { label: 'a' }, collapsibleState: TreeItemCollapsibleState.Collapsed }], (<Array<any>>revealTarget.args[0][2]).map(arg => removeUnsetKeys(arg)));
				assert.deepEqual({ select: true, focus: false, expand: false }, revealTarget.args[0][3]);
			});
	});

	test('reveal will return parents array for an element when hierarchy is loaded', () => {
		const revealTarget = sinon.spy(target, '$reveal');
		const treeView = testObject.createTreeView('treeDataProvider', { treeDataProvider: aCompleteNodeTreeDataProvider() }, { enableProposedApi: true } as IExtensionDescription);
		return testObject.$getChildren('treeDataProvider')
			.then(() => testObject.$getChildren('treeDataProvider', '0/0:a'))
			.then(() => treeView.reveal({ key: 'aa' })
				.then(() => {
					assert.ok(revealTarget.calledOnce);
					assert.deepEqual('treeDataProvider', revealTarget.args[0][0]);
					assert.deepEqual({ handle: '0/0:a/0:aa', label: { label: 'aa' }, collapsibleState: TreeItemCollapsibleState.None, parentHandle: '0/0:a' }, removeUnsetKeys(revealTarget.args[0][1]));
					assert.deepEqual([{ handle: '0/0:a', label: { label: 'a' }, collapsibleState: TreeItemCollapsibleState.Collapsed }], (<Array<any>>revealTarget.args[0][2]).map(arg => removeUnsetKeys(arg)));
					assert.deepEqual({ select: true, focus: false, expand: false }, revealTarget.args[0][3]);
				}));
	});

	test('reveal will return parents array for deeper element with no selection', () => {
		tree = {
			'b': {
				'ba': {
					'bac': {}
				}
			}
		};
		const revealTarget = sinon.spy(target, '$reveal');
		const treeView = testObject.createTreeView('treeDataProvider', { treeDataProvider: aCompleteNodeTreeDataProvider() }, { enableProposedApi: true } as IExtensionDescription);
		return treeView.reveal({ key: 'bac' }, { select: false, focus: false, expand: false })
			.then(() => {
				assert.ok(revealTarget.calledOnce);
				assert.deepEqual('treeDataProvider', revealTarget.args[0][0]);
				assert.deepEqual({ handle: '0/0:b/0:ba/0:bac', label: { label: 'bac' }, collapsibleState: TreeItemCollapsibleState.None, parentHandle: '0/0:b/0:ba' }, removeUnsetKeys(revealTarget.args[0][1]));
				assert.deepEqual([
					{ handle: '0/0:b', label: { label: 'b' }, collapsibleState: TreeItemCollapsibleState.Collapsed },
					{ handle: '0/0:b/0:ba', label: { label: 'ba' }, collapsibleState: TreeItemCollapsibleState.Collapsed, parentHandle: '0/0:b' }
				], (<Array<any>>revealTarget.args[0][2]).map(arg => removeUnsetKeys(arg)));
				assert.deepEqual({ select: false, focus: false, expand: false }, revealTarget.args[0][3]);
			});
	});

	test('reveal after first udpate', () => {
		const revealTarget = sinon.spy(target, '$reveal');
		const treeView = testObject.createTreeView('treeDataProvider', { treeDataProvider: aCompleteNodeTreeDataProvider() }, { enableProposedApi: true } as IExtensionDescription);
		return loadCompleteTree('treeDataProvider')
			.then(() => {
				tree = {
					'a': {
						'aa': {},
						'ac': {}
					},
					'b': {
						'ba': {},
						'bb': {}
					}
				};
				onDidChangeTreeNode.fire(getNode('a'));

				return treeView.reveal({ key: 'ac' })
					.then(() => {
						assert.ok(revealTarget.calledOnce);
						assert.deepEqual('treeDataProvider', revealTarget.args[0][0]);
						assert.deepEqual({ handle: '0/0:a/0:ac', label: { label: 'ac' }, collapsibleState: TreeItemCollapsibleState.None, parentHandle: '0/0:a' }, removeUnsetKeys(revealTarget.args[0][1]));
						assert.deepEqual([{ handle: '0/0:a', label: { label: 'a' }, collapsibleState: TreeItemCollapsibleState.Collapsed }], (<Array<any>>revealTarget.args[0][2]).map(arg => removeUnsetKeys(arg)));
						assert.deepEqual({ select: true, focus: false, expand: false }, revealTarget.args[0][3]);
					});
			});
	});

	test('reveal after second udpate', () => {
		const revealTarget = sinon.spy(target, '$reveal');
		const treeView = testObject.createTreeView('treeDataProvider', { treeDataProvider: aCompleteNodeTreeDataProvider() }, { enableProposedApi: true } as IExtensionDescription);
		return loadCompleteTree('treeDataProvider')
			.then(() => {
				tree = {
					'a': {
						'aa': {},
						'ac': {}
					},
					'b': {
						'ba': {},
						'bb': {}
					}
				};
				onDidChangeTreeNode.fire(getNode('a'));
				tree = {
					'a': {
						'aa': {},
						'ac': {}
					},
					'b': {
						'ba': {},
						'bc': {}
					}
				};
				onDidChangeTreeNode.fire(getNode('b'));

				return treeView.reveal({ key: 'bc' })
					.then(() => {
						assert.ok(revealTarget.calledOnce);
						assert.deepEqual('treeDataProvider', revealTarget.args[0][0]);
						assert.deepEqual({ handle: '0/0:b/0:bc', label: { label: 'bc' }, collapsibleState: TreeItemCollapsibleState.None, parentHandle: '0/0:b' }, removeUnsetKeys(revealTarget.args[0][1]));
						assert.deepEqual([{ handle: '0/0:b', label: { label: 'b' }, collapsibleState: TreeItemCollapsibleState.Collapsed }], (<Array<any>>revealTarget.args[0][2]).map(arg => removeUnsetKeys(arg)));
						assert.deepEqual({ select: true, focus: false, expand: false }, revealTarget.args[0][3]);
					});
			});
	});

	function loadCompleteTree(treeId, element?: string) {
		return testObject.$getChildren(treeId, element)
			.then(elements => elements.map(e => loadCompleteTree(treeId, e.handle)))
			.then(() => null);
	}

	function removeUnsetKeys(obj: any): any {
		if (Array.isArray(obj)) {
			return obj.map(o => removeUnsetKeys(o));
		}

		if (typeof obj === 'object') {
			const result = {};
			for (const key of Object.keys(obj)) {
				if (obj[key] !== void 0) {
					result[key] = removeUnsetKeys(obj[key]);
				}
			}
			return result;
		}
		return obj;
	}

	function aNodeTreeDataProvider(): TreeDataProvider<{ key: string }> {
		return {
			getChildren: (element: { key: string }): { key: string }[] => {
				return getChildren(element ? element.key : undefined).map(key => getNode(key));
			},
			getTreeItem: (element: { key: string }): TreeItem => {
				return getTreeItem(element.key);
			},
			onDidChangeTreeData: onDidChangeTreeNode.event
		};
	}

	function aCompleteNodeTreeDataProvider(): TreeDataProvider<{ key: string }> {
		return {
			getChildren: (element: { key: string }): { key: string }[] => {
				return getChildren(element ? element.key : undefined).map(key => getNode(key));
			},
			getTreeItem: (element: { key: string }): TreeItem => {
				return getTreeItem(element.key);
			},
			getParent: ({ key }: { key: string }): { key: string } => {
				const parentKey = key.substring(0, key.length - 1);
				return parentKey ? new Key(parentKey) : void 0;
			},
			onDidChangeTreeData: onDidChangeTreeNode.event
		};
	}

	function aNodeWithIdTreeDataProvider(): TreeDataProvider<{ key: string }> {
		return {
			getChildren: (element: { key: string }): { key: string }[] => {
				return getChildren(element ? element.key : undefined).map(key => getNode(key));
			},
			getTreeItem: (element: { key: string }): TreeItem => {
				const treeItem = getTreeItem(element.key);
				treeItem.id = element.key;
				return treeItem;
			},
			onDidChangeTreeData: onDidChangeTreeNodeWithId.event
		};
	}

	function aNodeWithHighlightedLabelTreeDataProvider(): TreeDataProvider<{ key: string }> {
		return {
			getChildren: (element: { key: string }): { key: string }[] => {
				return getChildren(element ? element.key : undefined).map(key => getNode(key));
			},
			getTreeItem: (element: { key: string }): TreeItem => {
				const treeItem = getTreeItem(element.key, [[0, 2], [3, 5]]);
				treeItem.id = element.key;
				return treeItem;
			},
			onDidChangeTreeData: onDidChangeTreeNodeWithId.event
		};
	}

	function getTreeElement(element): any {
		let parent = tree;
		for (let i = 0; i < element.length; i++) {
			parent = parent[element.substring(0, i + 1)];
			if (!parent) {
				return null;
			}
		}
		return parent;
	}

	function getChildren(key: string): string[] {
		if (!key) {
			return Object.keys(tree);
		}
		let treeElement = getTreeElement(key);
		if (treeElement) {
			return Object.keys(treeElement);
		}
		return [];
	}

	function getTreeItem(key: string, highlights?: [number, number][]): TreeItem {
		const treeElement = getTreeElement(key);
		return {
			label: <any>{ label: labels[key] || key, highlights },
			collapsibleState: treeElement && Object.keys(treeElement).length ? TreeItemCollapsibleState.Collapsed : TreeItemCollapsibleState.None
		};
	}

	function getNode(key: string): { key: string } {
		if (!nodes[key]) {
			nodes[key] = new Key(key);
		}
		return nodes[key];
	}

	class Key {
		constructor(readonly key: string) { }
	}

});
