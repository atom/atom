/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!./media/search.contribution';
import { Registry } from 'vs/platform/registry/common/platform';
import { registerSingleton } from 'vs/platform/instantiation/common/extensions';
import { ViewletRegistry, Extensions as ViewletExtensions, ViewletDescriptor } from 'vs/workbench/browser/viewlet';
import { IConfigurationRegistry, Extensions as ConfigurationExtensions, ConfigurationScope } from 'vs/platform/configuration/common/configurationRegistry';
import * as nls from 'vs/nls';
import { Action } from 'vs/base/common/actions';
import * as objects from 'vs/base/common/objects';
import * as platform from 'vs/base/common/platform';
import { ExplorerFolderContext, ExplorerRootContext } from 'vs/workbench/parts/files/common/files';
import { SyncActionDescriptor, MenuRegistry, MenuId, ICommandAction } from 'vs/platform/actions/common/actions';
import { IWorkbenchActionRegistry, Extensions as ActionExtensions } from 'vs/workbench/common/actions';
import { QuickOpenHandlerDescriptor, IQuickOpenRegistry, Extensions as QuickOpenExtensions } from 'vs/workbench/browser/quickopen';
import { KeybindingsRegistry, KeybindingWeight } from 'vs/platform/keybinding/common/keybindingsRegistry';
import { IInstantiationService } from 'vs/platform/instantiation/common/instantiation';
import { IQuickOpenService } from 'vs/platform/quickOpen/common/quickOpen';
import { ICodeEditorService } from 'vs/editor/browser/services/codeEditorService';
import { getSelectionSearchString } from 'vs/editor/contrib/find/findController';
import { IViewletService } from 'vs/workbench/services/viewlet/browser/viewlet';
import { KeyMod, KeyCode } from 'vs/base/common/keyCodes';
import { ITree } from 'vs/base/parts/tree/browser/tree';
import * as Constants from 'vs/workbench/parts/search/common/constants';
import { registerContributions as replaceContributions } from 'vs/workbench/parts/search/browser/replaceContributions';
import { registerContributions as searchWidgetContributions } from 'vs/workbench/parts/search/browser/searchWidget';
import { ContextKeyExpr } from 'vs/platform/contextkey/common/contextkey';
import { ToggleCaseSensitiveKeybinding, ToggleRegexKeybinding, ToggleWholeWordKeybinding } from 'vs/editor/contrib/find/findModel';
import { ISearchWorkbenchService, SearchWorkbenchService } from 'vs/workbench/parts/search/common/searchModel';
import { CommandsRegistry } from 'vs/platform/commands/common/commands';
import { SearchView } from 'vs/workbench/parts/search/browser/searchView';
import { defaultQuickOpenContextKey } from 'vs/workbench/browser/parts/quickopen/quickopen';
import { OpenSymbolHandler } from 'vs/workbench/parts/search/browser/openSymbolHandler';
import { OpenAnythingHandler } from 'vs/workbench/parts/search/browser/openAnythingHandler';
import { registerLanguageCommand } from 'vs/editor/browser/editorExtensions';
import { getWorkspaceSymbols } from 'vs/workbench/parts/search/common/search';
import { illegalArgument } from 'vs/base/common/errors';
import { WorkbenchListFocusContextKey, IListService } from 'vs/platform/list/browser/listService';
import { URI } from 'vs/base/common/uri';
import { relative } from 'path';
import { dirname } from 'vs/base/common/resources';
import { ResourceContextKey } from 'vs/workbench/common/resources';
import { IFileService } from 'vs/platform/files/common/files';
import { distinct } from 'vs/base/common/arrays';
import { getMultiSelectedResources } from 'vs/workbench/parts/files/browser/files';
import { Schemas } from 'vs/base/common/network';
import { PanelRegistry, Extensions as PanelExtensions, PanelDescriptor } from 'vs/workbench/browser/panel';
import { IPanelService } from 'vs/workbench/services/panel/common/panelService';
import { openSearchView, getSearchView, ReplaceAllInFolderAction, ReplaceAllAction, CloseReplaceAction, FocusNextSearchResultAction, FocusPreviousSearchResultAction, ReplaceInFilesAction, FindInFilesAction, toggleCaseSensitiveCommand, toggleRegexCommand, CollapseDeepestExpandedLevelAction, toggleWholeWordCommand, RemoveAction, ReplaceAction, ClearSearchResultsAction, copyPathCommand, copyMatchCommand, copyAllCommand, clearHistoryCommand, FocusNextInputAction, FocusPreviousInputAction, RefreshAction, focusSearchListCommand, OpenSearchViewletAction } from 'vs/workbench/parts/search/browser/searchActions';
import { VIEW_ID, ISearchConfigurationProperties } from 'vs/platform/search/common/search';
import { IWorkbenchContributionsRegistry, Extensions as WorkbenchExtensions } from 'vs/workbench/common/contributions';
import { LifecyclePhase } from 'vs/platform/lifecycle/common/lifecycle';
import { SearchViewLocationUpdater } from 'vs/workbench/parts/search/browser/searchViewLocationUpdater';
import { IConfigurationService } from 'vs/platform/configuration/common/configuration';
import { IEditorService } from 'vs/workbench/services/editor/common/editorService';

registerSingleton(ISearchWorkbenchService, SearchWorkbenchService, true);
replaceContributions();
searchWidgetContributions();

const category = nls.localize('search', "Search");

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: 'workbench.action.search.toggleQueryDetails',
	weight: KeybindingWeight.WorkbenchContrib,
	when: Constants.SearchViewVisibleKey,
	primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.KEY_J,
	handler: accessor => {
		const searchView = getSearchView(accessor.get(IViewletService), accessor.get(IPanelService));
		if (searchView) {
			searchView.toggleQueryDetails();
		}
	}
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: Constants.FocusSearchFromResults,
	weight: KeybindingWeight.WorkbenchContrib,
	when: ContextKeyExpr.and(Constants.SearchViewVisibleKey, Constants.FirstMatchFocusKey),
	primary: KeyMod.CtrlCmd | KeyCode.UpArrow,
	handler: (accessor, args: any) => {
		const searchView = getSearchView(accessor.get(IViewletService), accessor.get(IPanelService));
		searchView.focusPreviousInputBox();
	}
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: Constants.OpenMatchToSide,
	weight: KeybindingWeight.WorkbenchContrib,
	when: ContextKeyExpr.and(Constants.SearchViewVisibleKey, Constants.FileMatchOrMatchFocusKey),
	primary: KeyMod.CtrlCmd | KeyCode.Enter,
	mac: {
		primary: KeyMod.WinCtrl | KeyCode.Enter
	},
	handler: (accessor, args: any) => {
		const searchView = getSearchView(accessor.get(IViewletService), accessor.get(IPanelService));
		const tree: ITree = searchView.getControl();
		searchView.open(tree.getFocus(), false, true, true);
	}
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: Constants.CancelActionId,
	weight: KeybindingWeight.WorkbenchContrib,
	when: ContextKeyExpr.and(Constants.SearchViewVisibleKey, WorkbenchListFocusContextKey),
	primary: KeyCode.Escape,
	handler: (accessor, args: any) => {
		const searchView = getSearchView(accessor.get(IViewletService), accessor.get(IPanelService));
		searchView.cancelSearch();
	}
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: Constants.RemoveActionId,
	weight: KeybindingWeight.WorkbenchContrib,
	when: ContextKeyExpr.and(Constants.SearchViewVisibleKey, Constants.FileMatchOrMatchFocusKey),
	primary: KeyCode.Delete,
	mac: {
		primary: KeyMod.CtrlCmd | KeyCode.Backspace,
	},
	handler: (accessor, args: any) => {
		const searchView = getSearchView(accessor.get(IViewletService), accessor.get(IPanelService));
		const tree: ITree = searchView.getControl();
		accessor.get(IInstantiationService).createInstance(RemoveAction, tree, tree.getFocus(), searchView).run();
	}
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: Constants.ReplaceActionId,
	weight: KeybindingWeight.WorkbenchContrib,
	when: ContextKeyExpr.and(Constants.SearchViewVisibleKey, Constants.ReplaceActiveKey, Constants.MatchFocusKey),
	primary: KeyMod.Shift | KeyMod.CtrlCmd | KeyCode.KEY_1,
	handler: (accessor, args: any) => {
		const searchView = getSearchView(accessor.get(IViewletService), accessor.get(IPanelService));
		const tree: ITree = searchView.getControl();
		accessor.get(IInstantiationService).createInstance(ReplaceAction, tree, tree.getFocus(), searchView).run();
	}
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: Constants.ReplaceAllInFileActionId,
	weight: KeybindingWeight.WorkbenchContrib,
	when: ContextKeyExpr.and(Constants.SearchViewVisibleKey, Constants.ReplaceActiveKey, Constants.FileFocusKey),
	primary: KeyMod.Shift | KeyMod.CtrlCmd | KeyCode.KEY_1,
	secondary: [KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.Enter],
	handler: (accessor, args: any) => {
		const searchView = getSearchView(accessor.get(IViewletService), accessor.get(IPanelService));
		const tree: ITree = searchView.getControl();
		accessor.get(IInstantiationService).createInstance(ReplaceAllAction, tree, tree.getFocus(), searchView).run();
	}
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: Constants.ReplaceAllInFolderActionId,
	weight: KeybindingWeight.WorkbenchContrib,
	when: ContextKeyExpr.and(Constants.SearchViewVisibleKey, Constants.ReplaceActiveKey, Constants.FolderFocusKey),
	primary: KeyMod.Shift | KeyMod.CtrlCmd | KeyCode.KEY_1,
	secondary: [KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.Enter],
	handler: (accessor, args: any) => {
		const searchView = getSearchView(accessor.get(IViewletService), accessor.get(IPanelService));
		const tree: ITree = searchView.getControl();
		accessor.get(IInstantiationService).createInstance(ReplaceAllInFolderAction, tree, tree.getFocus()).run();
	}
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: Constants.CloseReplaceWidgetActionId,
	weight: KeybindingWeight.WorkbenchContrib,
	when: ContextKeyExpr.and(Constants.SearchViewVisibleKey, Constants.ReplaceInputBoxFocusedKey),
	primary: KeyCode.Escape,
	handler: (accessor, args: any) => {
		accessor.get(IInstantiationService).createInstance(CloseReplaceAction, Constants.CloseReplaceWidgetActionId, '').run();
	}
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: FocusNextInputAction.ID,
	weight: KeybindingWeight.WorkbenchContrib,
	when: ContextKeyExpr.and(Constants.SearchViewVisibleKey, Constants.InputBoxFocusedKey),
	primary: KeyMod.CtrlCmd | KeyCode.DownArrow,
	handler: (accessor, args: any) => {
		accessor.get(IInstantiationService).createInstance(FocusNextInputAction, FocusNextInputAction.ID, '').run();
	}
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: FocusPreviousInputAction.ID,
	weight: KeybindingWeight.WorkbenchContrib,
	when: ContextKeyExpr.and(Constants.SearchViewVisibleKey, Constants.InputBoxFocusedKey, Constants.SearchInputBoxFocusedKey.toNegated()),
	primary: KeyMod.CtrlCmd | KeyCode.UpArrow,
	handler: (accessor, args: any) => {
		accessor.get(IInstantiationService).createInstance(FocusPreviousInputAction, FocusPreviousInputAction.ID, '').run();
	}
});

MenuRegistry.appendMenuItem(MenuId.SearchContext, {
	command: {
		id: Constants.ReplaceActionId,
		title: ReplaceAction.LABEL
	},
	when: ContextKeyExpr.and(Constants.ReplaceActiveKey, Constants.MatchFocusKey),
	group: 'search',
	order: 1
});

MenuRegistry.appendMenuItem(MenuId.SearchContext, {
	command: {
		id: Constants.ReplaceAllInFolderActionId,
		title: ReplaceAllInFolderAction.LABEL
	},
	when: ContextKeyExpr.and(Constants.ReplaceActiveKey, Constants.FolderFocusKey),
	group: 'search',
	order: 1
});

MenuRegistry.appendMenuItem(MenuId.SearchContext, {
	command: {
		id: Constants.ReplaceAllInFileActionId,
		title: ReplaceAllAction.LABEL
	},
	when: ContextKeyExpr.and(Constants.ReplaceActiveKey, Constants.FileFocusKey),
	group: 'search',
	order: 1
});

MenuRegistry.appendMenuItem(MenuId.SearchContext, {
	command: {
		id: Constants.RemoveActionId,
		title: RemoveAction.LABEL
	},
	when: Constants.FileMatchOrMatchFocusKey,
	group: 'search',
	order: 2
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: Constants.CopyMatchCommandId,
	weight: KeybindingWeight.WorkbenchContrib,
	when: Constants.FileMatchOrMatchFocusKey,
	primary: KeyMod.CtrlCmd | KeyCode.KEY_C,
	handler: copyMatchCommand
});

MenuRegistry.appendMenuItem(MenuId.SearchContext, {
	command: {
		id: Constants.CopyMatchCommandId,
		title: nls.localize('copyMatchLabel', "Copy")
	},
	when: Constants.FileMatchOrMatchFocusKey,
	group: 'search_2',
	order: 1
});

KeybindingsRegistry.registerCommandAndKeybindingRule({
	id: Constants.CopyPathCommandId,
	weight: KeybindingWeight.WorkbenchContrib,
	when: Constants.FileMatchOrFolderMatchFocusKey,
	primary: KeyMod.CtrlCmd | KeyMod.Alt | KeyCode.KEY_C,
	win: {
		primary: KeyMod.Shift | KeyMod.Alt | KeyCode.KEY_C
	},
	handler: copyPathCommand
});

MenuRegistry.appendMenuItem(MenuId.SearchContext, {
	command: {
		id: Constants.CopyPathCommandId,
		title: nls.localize('copyPathLabel', "Copy Path")
	},
	when: Constants.FileMatchOrFolderMatchFocusKey,
	group: 'search_2',
	order: 2
});

MenuRegistry.appendMenuItem(MenuId.SearchContext, {
	command: {
		id: Constants.CopyAllCommandId,
		title: nls.localize('copyAllLabel', "Copy All")
	},
	when: Constants.HasSearchResults,
	group: 'search_2',
	order: 3
});

CommandsRegistry.registerCommand({
	id: Constants.CopyAllCommandId,
	handler: copyAllCommand
});

CommandsRegistry.registerCommand({
	id: Constants.ClearSearchHistoryCommandId,
	handler: clearHistoryCommand
});

const clearSearchHistoryLabel = nls.localize('clearSearchHistoryLabel', "Clear Search History");
const ClearSearchHistoryCommand: ICommandAction = {
	id: Constants.ClearSearchHistoryCommandId,
	title: clearSearchHistoryLabel,
	category
};
MenuRegistry.addCommand(ClearSearchHistoryCommand);

CommandsRegistry.registerCommand({
	id: Constants.ToggleSearchViewPositionCommandId,
	handler: (accessor) => {
		const configurationService = accessor.get(IConfigurationService);
		const currentValue = configurationService.getValue<ISearchConfigurationProperties>('search').location;
		const toggleValue = currentValue === 'sidebar' ? 'panel' : 'sidebar';

		configurationService.updateValue('search.location', toggleValue);
	}
});

const toggleSearchViewPositionLabel = nls.localize('toggleSearchViewPositionLabel', "Toggle Search View Position");
const ToggleSearchViewPositionCommand: ICommandAction = {
	id: Constants.ToggleSearchViewPositionCommandId,
	title: toggleSearchViewPositionLabel,
	category
};
MenuRegistry.addCommand(ToggleSearchViewPositionCommand);
MenuRegistry.appendMenuItem(MenuId.SearchContext, {
	command: ToggleSearchViewPositionCommand,
	when: Constants.SearchViewVisibleKey,
	group: 'search_9',
	order: 1
});

CommandsRegistry.registerCommand({
	id: Constants.FocusSearchListCommandID,
	handler: focusSearchListCommand
});

const focusSearchListCommandLabel = nls.localize('focusSearchListCommandLabel', "Focus List");
const FocusSearchListCommand: ICommandAction = {
	id: Constants.FocusSearchListCommandID,
	title: focusSearchListCommandLabel,
	category
};
MenuRegistry.addCommand(FocusSearchListCommand);

const FIND_IN_FOLDER_ID = 'filesExplorer.findInFolder';
CommandsRegistry.registerCommand({
	id: FIND_IN_FOLDER_ID,
	handler: (accessor, resource?: URI) => {
		const listService = accessor.get(IListService);
		const viewletService = accessor.get(IViewletService);
		const panelService = accessor.get(IPanelService);
		const fileService = accessor.get(IFileService);
		const resources = getMultiSelectedResources(resource, listService, accessor.get(IEditorService));

		return openSearchView(viewletService, panelService, true).then(searchView => {
			if (resources && resources.length) {
				return fileService.resolveFiles(resources.map(resource => ({ resource }))).then(results => {
					const folders: URI[] = [];

					results.forEach(result => {
						if (result.success) {
							folders.push(result.stat.isDirectory ? result.stat.resource : dirname(result.stat.resource));
						}
					});

					searchView.searchInFolders(distinct(folders, folder => folder.toString()), (from, to) => relative(from, to));
				});
			}

			return void 0;
		});
	}
});

CommandsRegistry.registerCommand({
	id: ClearSearchResultsAction.ID,
	handler: (accessor, args: any) => {
		accessor.get(IInstantiationService).createInstance(ClearSearchResultsAction, ClearSearchResultsAction.ID, '').run();
	}
});

CommandsRegistry.registerCommand({
	id: RefreshAction.ID,
	handler: (accessor, args: any) => {
		accessor.get(IInstantiationService).createInstance(RefreshAction, RefreshAction.ID, '').run();
	}
});

const FIND_IN_WORKSPACE_ID = 'filesExplorer.findInWorkspace';
CommandsRegistry.registerCommand({
	id: FIND_IN_WORKSPACE_ID,
	handler: (accessor) => {
		return openSearchView(accessor.get(IViewletService), accessor.get(IPanelService), true).then(searchView => {
			searchView.searchInFolders(null, (from, to) => relative(from, to));
		});
	}
});

MenuRegistry.appendMenuItem(MenuId.ExplorerContext, {
	group: '4_search',
	order: 10,
	command: {
		id: FIND_IN_FOLDER_ID,
		title: nls.localize('findInFolder', "Find in Folder...")
	},
	when: ContextKeyExpr.and(ExplorerFolderContext, ResourceContextKey.Scheme.isEqualTo(Schemas.file)) // todo@remote
});

MenuRegistry.appendMenuItem(MenuId.ExplorerContext, {
	group: '4_search',
	order: 10,
	command: {
		id: FIND_IN_WORKSPACE_ID,
		title: nls.localize('findInWorkspace', "Find in Workspace...")
	},
	when: ContextKeyExpr.and(ExplorerRootContext, ExplorerFolderContext.toNegated())
});


class ShowAllSymbolsAction extends Action {
	static readonly ID = 'workbench.action.showAllSymbols';
	static readonly LABEL = nls.localize('showTriggerActions', "Go to Symbol in Workspace...");
	static readonly ALL_SYMBOLS_PREFIX = '#';

	constructor(
		actionId: string, actionLabel: string,
		@IQuickOpenService private quickOpenService: IQuickOpenService,
		@ICodeEditorService private editorService: ICodeEditorService) {
		super(actionId, actionLabel);
		this.enabled = !!this.quickOpenService;
	}

	public run(context?: any): Promise<void> {

		let prefix = ShowAllSymbolsAction.ALL_SYMBOLS_PREFIX;
		let inputSelection: { start: number; end: number; } = void 0;
		let editor = this.editorService.getFocusedCodeEditor();
		const word = editor && getSelectionSearchString(editor);
		if (word) {
			prefix = prefix + word;
			inputSelection = { start: 1, end: word.length + 1 };
		}

		this.quickOpenService.show(prefix, { inputSelection });

		return Promise.resolve(null);
	}
}

// Register View in Viewlet and Panel area
Registry.as<ViewletRegistry>(ViewletExtensions.Viewlets).registerViewlet(new ViewletDescriptor(
	SearchView,
	VIEW_ID,
	nls.localize('name', "Search"),
	'search',
	1
));

Registry.as<PanelRegistry>(PanelExtensions.Panels).registerPanel(new PanelDescriptor(
	SearchView,
	VIEW_ID,
	nls.localize('name', "Search"),
	'search',
	10
));

// Register view location updater
Registry.as<IWorkbenchContributionsRegistry>(WorkbenchExtensions.Workbench).registerWorkbenchContribution(SearchViewLocationUpdater, LifecyclePhase.Restoring);

// Actions
const registry = Registry.as<IWorkbenchActionRegistry>(ActionExtensions.WorkbenchActions);

// Show Search and Find in Files are redundant, but we can't break keybindings by removing one. So it's the same action, same keybinding, registered to different IDs.
// Show Search 'when' is redundant but if the two conflict with exactly the same keybinding and 'when' clause, then they can show up as "unbound" - #51780
registry.registerWorkbenchAction(new SyncActionDescriptor(OpenSearchViewletAction, VIEW_ID, OpenSearchViewletAction.LABEL, { primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.KEY_F }, Constants.SearchViewVisibleKey.toNegated()), 'View: Show Search', nls.localize('view', "View"));
registry.registerWorkbenchAction(new SyncActionDescriptor(FindInFilesAction, Constants.FindInFilesActionId, nls.localize('findInFiles', "Find in Files"), { primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.KEY_F }), 'Find in Files', category);
MenuRegistry.appendMenuItem(MenuId.MenubarEditMenu, {
	group: '4_find_global',
	command: {
		id: Constants.FindInFilesActionId,
		title: nls.localize({ key: 'miFindInFiles', comment: ['&& denotes a mnemonic'] }, "Find &&in Files")
	},
	order: 1
});

registry.registerWorkbenchAction(new SyncActionDescriptor(FocusNextSearchResultAction, FocusNextSearchResultAction.ID, FocusNextSearchResultAction.LABEL, { primary: KeyCode.F4 }, ContextKeyExpr.and(Constants.HasSearchResults)), 'Focus Next Search Result', category);
registry.registerWorkbenchAction(new SyncActionDescriptor(FocusPreviousSearchResultAction, FocusPreviousSearchResultAction.ID, FocusPreviousSearchResultAction.LABEL, { primary: KeyMod.Shift | KeyCode.F4 }, ContextKeyExpr.and(Constants.HasSearchResults)), 'Focus Previous Search Result', category);

registry.registerWorkbenchAction(new SyncActionDescriptor(ReplaceInFilesAction, ReplaceInFilesAction.ID, ReplaceInFilesAction.LABEL, { primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.KEY_H }), 'Replace in Files', category);
MenuRegistry.appendMenuItem(MenuId.MenubarEditMenu, {
	group: '4_find_global',
	command: {
		id: ReplaceInFilesAction.ID,
		title: nls.localize({ key: 'miReplaceInFiles', comment: ['&& denotes a mnemonic'] }, "Replace &&in Files")
	},
	order: 2
});

KeybindingsRegistry.registerCommandAndKeybindingRule(objects.assign({
	id: Constants.ToggleCaseSensitiveCommandId,
	weight: KeybindingWeight.WorkbenchContrib,
	when: ContextKeyExpr.and(Constants.SearchViewVisibleKey, Constants.SearchViewFocusedKey, Constants.FileMatchOrFolderMatchFocusKey.toNegated()),
	handler: toggleCaseSensitiveCommand
}, ToggleCaseSensitiveKeybinding));

KeybindingsRegistry.registerCommandAndKeybindingRule(objects.assign({
	id: Constants.ToggleWholeWordCommandId,
	weight: KeybindingWeight.WorkbenchContrib,
	when: ContextKeyExpr.and(Constants.SearchViewVisibleKey, Constants.SearchViewFocusedKey),
	handler: toggleWholeWordCommand
}, ToggleWholeWordKeybinding));

KeybindingsRegistry.registerCommandAndKeybindingRule(objects.assign({
	id: Constants.ToggleRegexCommandId,
	weight: KeybindingWeight.WorkbenchContrib,
	when: ContextKeyExpr.and(Constants.SearchViewVisibleKey, Constants.SearchViewFocusedKey),
	handler: toggleRegexCommand
}, ToggleRegexKeybinding));

registry.registerWorkbenchAction(new SyncActionDescriptor(CollapseDeepestExpandedLevelAction, CollapseDeepestExpandedLevelAction.ID, CollapseDeepestExpandedLevelAction.LABEL), 'Search: Collapse All', category);
registry.registerWorkbenchAction(new SyncActionDescriptor(ShowAllSymbolsAction, ShowAllSymbolsAction.ID, ShowAllSymbolsAction.LABEL, { primary: KeyMod.CtrlCmd | KeyCode.KEY_T }), 'Go to Symbol in Workspace...');

registry.registerWorkbenchAction(new SyncActionDescriptor(RefreshAction, RefreshAction.ID, RefreshAction.LABEL), 'Search: Refresh', category);
registry.registerWorkbenchAction(new SyncActionDescriptor(ClearSearchResultsAction, ClearSearchResultsAction.ID, ClearSearchResultsAction.LABEL), 'Search: Clear', category);


// Register Quick Open Handler
Registry.as<IQuickOpenRegistry>(QuickOpenExtensions.Quickopen).registerDefaultQuickOpenHandler(
	new QuickOpenHandlerDescriptor(
		OpenAnythingHandler,
		OpenAnythingHandler.ID,
		'',
		defaultQuickOpenContextKey,
		nls.localize('openAnythingHandlerDescription', "Go to File")
	)
);

Registry.as<IQuickOpenRegistry>(QuickOpenExtensions.Quickopen).registerQuickOpenHandler(
	new QuickOpenHandlerDescriptor(
		OpenSymbolHandler,
		OpenSymbolHandler.ID,
		ShowAllSymbolsAction.ALL_SYMBOLS_PREFIX,
		'inWorkspaceSymbolsPicker',
		[
			{
				prefix: ShowAllSymbolsAction.ALL_SYMBOLS_PREFIX,
				needsEditor: false,
				description: nls.localize('openSymbolDescriptionNormal', "Go to Symbol in Workspace")
			}
		]
	)
);

// Configuration
const configurationRegistry = Registry.as<IConfigurationRegistry>(ConfigurationExtensions.Configuration);
configurationRegistry.registerConfiguration({
	id: 'search',
	order: 13,
	title: nls.localize('searchConfigurationTitle', "Search"),
	type: 'object',
	properties: {
		'search.exclude': {
			type: 'object',
			markdownDescription: nls.localize('exclude', "Configure glob patterns for excluding files and folders in searches. Inherits all glob patterns from the `#files.exclude#` setting. Read more about glob patterns [here](https://code.visualstudio.com/docs/editor/codebasics#_advanced-search-options)."),
			default: { '**/node_modules': true, '**/bower_components': true },
			additionalProperties: {
				anyOf: [
					{
						type: 'boolean',
						description: nls.localize('exclude.boolean', "The glob pattern to match file paths against. Set to true or false to enable or disable the pattern."),
					},
					{
						type: 'object',
						properties: {
							when: {
								type: 'string', // expression ({ "**/*.js": { "when": "$(basename).js" } })
								pattern: '\\w*\\$\\(basename\\)\\w*',
								default: '$(basename).ext',
								description: nls.localize('exclude.when', 'Additional check on the siblings of a matching file. Use $(basename) as variable for the matching file name.')
							}
						}
					}
				]
			},
			scope: ConfigurationScope.RESOURCE
		},
		'search.useRipgrep': {
			type: 'boolean',
			description: nls.localize('useRipgrep', "This setting is deprecated and now falls back on \"search.usePCRE2\"."),
			deprecationMessage: nls.localize('useRipgrepDeprecated', "Deprecated. Consider \"search.usePCRE2\" for advanced regex feature support."),
			default: true
		},
		'search.useLegacySearch': {
			type: 'boolean',
			description: nls.localize('useLegacySearch', "Controls whether to use the deprecated legacy mode for text and file search. It supports some text encodings that are not supported by the standard ripgrep-based search."),
			default: false
		},
		'search.useIgnoreFiles': {
			type: 'boolean',
			markdownDescription: nls.localize('useIgnoreFiles', "Controls whether to use `.gitignore` and `.ignore` files when searching for files."),
			default: true,
			scope: ConfigurationScope.RESOURCE
		},
		'search.useGlobalIgnoreFiles': {
			type: 'boolean',
			markdownDescription: nls.localize('useGlobalIgnoreFiles', "Controls whether to use global `.gitignore` and `.ignore` files when searching for files."),
			default: false,
			scope: ConfigurationScope.RESOURCE
		},
		'search.quickOpen.includeSymbols': {
			type: 'boolean',
			description: nls.localize('search.quickOpen.includeSymbols', "Whether to include results from a global symbol search in the file results for Quick Open."),
			default: false
		},
		'search.quickOpen.includeHistory': {
			type: 'boolean',
			description: nls.localize('search.quickOpen.includeHistory', "Whether to include results from recently opened files in the file results for Quick Open."),
			default: true
		},
		'search.followSymlinks': {
			type: 'boolean',
			description: nls.localize('search.followSymlinks', "Controls whether to follow symlinks while searching."),
			default: true
		},
		'search.smartCase': {
			type: 'boolean',
			description: nls.localize('search.smartCase', "Search case-insensitively if the pattern is all lowercase, otherwise, search case-sensitively."),
			default: false
		},
		'search.globalFindClipboard': {
			type: 'boolean',
			default: false,
			description: nls.localize('search.globalFindClipboard', "Controls whether the search view should read or modify the shared find clipboard on macOS."),
			included: platform.isMacintosh
		},
		'search.location': {
			type: 'string',
			enum: ['sidebar', 'panel'],
			default: 'sidebar',
			description: nls.localize('search.location', "Controls whether the search will be shown as a view in the sidebar or as a panel in the panel area for more horizontal space."),
		},
		'search.collapseResults': {
			type: 'string',
			enum: ['auto', 'alwaysCollapse', 'alwaysExpand'],
			enumDescriptions: [
				'Files with less than 10 results are expanded. Others are collapsed.',
				'',
				''
			],
			default: 'auto',
			description: nls.localize('search.collapseAllResults', "Controls whether the search results will be collapsed or expanded."),
		},
		'search.useReplacePreview': {
			type: 'boolean',
			default: true,
			description: nls.localize('search.useReplacePreview', "Controls whether to open Replace Preview when selecting or replacing a match."),
		},
		'search.showLineNumbers': {
			type: 'boolean',
			default: false,
			description: nls.localize('search.showLineNumbers', "Controls whether to show line numbers for search results."),
		},
		'searchRipgrep.enable': {
			type: 'boolean',
			default: false,
			deprecationMessage: nls.localize('search.searchRipgrepEnableDeprecated', "Deprecated. Use \"search.runInExtensionHost\" instead"),
			description: nls.localize('search.searchRipgrepEnable', "Whether to run search in the extension host")
		},
		'search.runInExtensionHost': {
			type: 'boolean',
			default: false,
			description: nls.localize('search.runInExtensionHost', "Whether to run search in the extension host. Requires a restart to take effect.")
		},
		'search.usePCRE2': {
			type: 'boolean',
			default: false,
			description: nls.localize('search.usePCRE2', "Whether to use the PCRE2 regex engine in text search. This enables using some advanced regex features like lookbehind and backreferences. However, not all PCRE2 features are supported - only features that are also supported by JavaScript.")
		}
	}
});

registerLanguageCommand('_executeWorkspaceSymbolProvider', function (accessor, args: { query: string; }) {
	let { query } = args;
	if (typeof query !== 'string') {
		throw illegalArgument();
	}
	return getWorkspaceSymbols(query);
});

// View menu

MenuRegistry.appendMenuItem(MenuId.MenubarViewMenu, {
	group: '3_views',
	command: {
		id: VIEW_ID,
		title: nls.localize({ key: 'miViewSearch', comment: ['&& denotes a mnemonic'] }, "&&Search")
	},
	order: 2
});

// Go to menu

MenuRegistry.appendMenuItem(MenuId.MenubarGoMenu, {
	group: 'z_go_to',
	command: {
		id: 'workbench.action.showAllSymbols',
		title: nls.localize({ key: 'miGotoSymbolInWorkspace', comment: ['&& denotes a mnemonic'] }, "Go to Symbol in &&Workspace...")
	},
	order: 3
});
