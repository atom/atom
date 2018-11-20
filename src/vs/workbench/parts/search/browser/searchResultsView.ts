/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as DOM from 'vs/base/browser/dom';
import { ActionBar } from 'vs/base/browser/ui/actionbar/actionbar';
import { CountBadge } from 'vs/base/browser/ui/countBadge/countBadge';
import { IAction } from 'vs/base/common/actions';
import { Disposable, dispose, IDisposable } from 'vs/base/common/lifecycle';
import * as paths from 'vs/base/common/paths';
import * as resources from 'vs/base/common/resources';
import { ContextMenuEvent, IAccessibilityProvider, IDataSource, IFilter, IRenderer, ISorter, ITree } from 'vs/base/parts/tree/browser/tree';
import * as nls from 'vs/nls';
import { fillInContextMenuActions } from 'vs/platform/actions/browser/menuItemActionItem';
import { IMenu, IMenuService, MenuId } from 'vs/platform/actions/common/actions';
import { IConfigurationService } from 'vs/platform/configuration/common/configuration';
import { IContextMenuService } from 'vs/platform/contextview/browser/contextView';
import { FileKind } from 'vs/platform/files/common/files';
import { IInstantiationService } from 'vs/platform/instantiation/common/instantiation';
import { ILabelService } from 'vs/platform/label/common/label';
import { WorkbenchTree, WorkbenchTreeController } from 'vs/platform/list/browser/listService';
import { ISearchConfigurationProperties } from 'vs/platform/search/common/search';
import { attachBadgeStyler } from 'vs/platform/theme/common/styler';
import { IThemeService } from 'vs/platform/theme/common/themeService';
import { IWorkspaceContextService, WorkbenchState } from 'vs/platform/workspace/common/workspace';
import { FileLabel } from 'vs/workbench/browser/labels';
import { RemoveAction, ReplaceAction, ReplaceAllAction, ReplaceAllInFolderAction } from 'vs/workbench/parts/search/browser/searchActions';
import { SearchView } from 'vs/workbench/parts/search/browser/searchView';
import { FileMatch, FileMatchOrMatch, FolderMatch, Match, RenderableMatch, searchMatchComparer, SearchModel, SearchResult } from 'vs/workbench/parts/search/common/searchModel';

export class SearchDataSource implements IDataSource {

	private static readonly AUTOEXPAND_CHILD_LIMIT = 10;

	private includeFolderMatch: boolean;
	private listener: IDisposable;

	constructor(
		@IWorkspaceContextService private contextService: IWorkspaceContextService,
		@IConfigurationService private configurationService: IConfigurationService,
	) {
		this.updateIncludeFolderMatch();
		this.listener = this.contextService.onDidChangeWorkbenchState(() => this.updateIncludeFolderMatch());
	}

	private updateIncludeFolderMatch(): void {
		this.includeFolderMatch = (this.contextService.getWorkbenchState() === WorkbenchState.WORKSPACE);
	}

	public getId(tree: ITree, element: any): string {
		if (element instanceof FolderMatch) {
			return element.id();
		}

		if (element instanceof FileMatch) {
			return element.id();
		}

		if (element instanceof Match) {
			return element.id();
		}

		return 'root';
	}

	private _getChildren(element: any): any[] {
		if (element instanceof FileMatch) {
			return element.matches();
		} else if (element instanceof FolderMatch) {
			return element.matches();
		} else if (element instanceof SearchResult) {
			const folderMatches = element.folderMatches();
			return folderMatches.length > 2 ? // "Other files" + workspace folder = 2
				folderMatches.filter(fm => !fm.isEmpty()) :
				element.matches();
		}

		return [];
	}

	public getChildren(tree: ITree, element: any): Thenable<any[]> {
		return Promise.resolve(this._getChildren(element));
	}

	public hasChildren(tree: ITree, element: any): boolean {
		return element instanceof FileMatch || element instanceof FolderMatch || element instanceof SearchResult;
	}

	public getParent(tree: ITree, element: any): Thenable<any> {
		let value: any = null;

		if (element instanceof Match) {
			value = element.parent();
		} else if (element instanceof FileMatch) {
			value = this.includeFolderMatch ? element.parent() : element.parent().parent();
		} else if (element instanceof FolderMatch) {
			value = element.parent();
		}

		return Promise.resolve(value);
	}

	public shouldAutoexpand(tree: ITree, element: any): boolean {
		const numChildren = this._getChildren(element).length;
		if (numChildren <= 0) {
			return false;
		}

		const collapseOption = this.configurationService.getValue('search.collapseResults');
		if (collapseOption === 'alwaysCollapse') {
			return false;
		} else if (collapseOption === 'alwaysExpand') {
			return true;
		}

		return numChildren < SearchDataSource.AUTOEXPAND_CHILD_LIMIT || element instanceof FolderMatch;
	}

	public dispose(): void {
		this.listener = dispose(this.listener);
	}
}

export class SearchSorter implements ISorter {
	public compare(tree: ITree, elementA: RenderableMatch, elementB: RenderableMatch): number {
		return searchMatchComparer(elementA, elementB);
	}
}

interface IFolderMatchTemplate {
	label: FileLabel;
	badge: CountBadge;
	actions: ActionBar;
}

interface IFileMatchTemplate {
	el: HTMLElement;
	label: FileLabel;
	badge: CountBadge;
	actions: ActionBar;
}

interface IMatchTemplate {
	parent: HTMLElement;
	before: HTMLElement;
	match: HTMLElement;
	replace: HTMLElement;
	after: HTMLElement;
	lineNumber: HTMLElement;
	actions: ActionBar;
}

export class SearchRenderer extends Disposable implements IRenderer {

	private static readonly FOLDER_MATCH_TEMPLATE_ID = 'folderMatch';
	private static readonly FILE_MATCH_TEMPLATE_ID = 'fileMatch';
	private static readonly MATCH_TEMPLATE_ID = 'match';

	constructor(
		private searchView: SearchView,
		@IInstantiationService private instantiationService: IInstantiationService,
		@IThemeService private themeService: IThemeService,
		@IConfigurationService private configurationService: IConfigurationService,
		@IWorkspaceContextService protected contextService: IWorkspaceContextService
	) {
		super();
	}

	public getHeight(tree: ITree, element: any): number {
		return 22;
	}

	public getTemplateId(tree: ITree, element: any): string {
		if (element instanceof FolderMatch) {
			return SearchRenderer.FOLDER_MATCH_TEMPLATE_ID;
		} else if (element instanceof FileMatch) {
			return SearchRenderer.FILE_MATCH_TEMPLATE_ID;
		} else if (element instanceof Match) {
			return SearchRenderer.MATCH_TEMPLATE_ID;
		}
		return null;
	}

	public renderTemplate(tree: ITree, templateId: string, container: HTMLElement): any {
		if (templateId === SearchRenderer.FOLDER_MATCH_TEMPLATE_ID) {
			return this.renderFolderMatchTemplate(tree, templateId, container);
		}

		if (templateId === SearchRenderer.FILE_MATCH_TEMPLATE_ID) {
			return this.renderFileMatchTemplate(tree, templateId, container);
		}

		if (templateId === SearchRenderer.MATCH_TEMPLATE_ID) {
			return this.renderMatchTemplate(tree, templateId, container);
		}

		return null;
	}

	public renderElement(tree: ITree, element: any, templateId: string, templateData: any): void {
		if (SearchRenderer.FOLDER_MATCH_TEMPLATE_ID === templateId) {
			this.renderFolderMatch(tree, <FolderMatch>element, <IFolderMatchTemplate>templateData);
		} else if (SearchRenderer.FILE_MATCH_TEMPLATE_ID === templateId) {
			this.renderFileMatch(tree, <FileMatch>element, <IFileMatchTemplate>templateData);
		} else if (SearchRenderer.MATCH_TEMPLATE_ID === templateId) {
			this.renderMatch(tree, <Match>element, <IMatchTemplate>templateData);
		}
	}

	private renderFolderMatchTemplate(tree: ITree, templateId: string, container: HTMLElement): IFolderMatchTemplate {
		let folderMatchElement = DOM.append(container, DOM.$('.foldermatch'));
		const label = this.instantiationService.createInstance(FileLabel, folderMatchElement, void 0);
		const badge = new CountBadge(DOM.append(folderMatchElement, DOM.$('.badge')));
		this._register(attachBadgeStyler(badge, this.themeService));
		const actions = new ActionBar(folderMatchElement, { animated: false });
		return { label, badge, actions };
	}

	private renderFileMatchTemplate(tree: ITree, templateId: string, container: HTMLElement): IFileMatchTemplate {
		let fileMatchElement = DOM.append(container, DOM.$('.filematch'));
		const label = this.instantiationService.createInstance(FileLabel, fileMatchElement, void 0);
		const badge = new CountBadge(DOM.append(fileMatchElement, DOM.$('.badge')));
		this._register(attachBadgeStyler(badge, this.themeService));
		const actions = new ActionBar(fileMatchElement, { animated: false });
		return { el: fileMatchElement, label, badge, actions };
	}

	private renderMatchTemplate(tree: ITree, templateId: string, container: HTMLElement): IMatchTemplate {
		DOM.addClass(container, 'linematch');

		const parent = DOM.append(container, DOM.$('a.plain.match'));
		const before = DOM.append(parent, DOM.$('span'));
		const match = DOM.append(parent, DOM.$('span.findInFileMatch'));
		const replace = DOM.append(parent, DOM.$('span.replaceMatch'));
		const after = DOM.append(parent, DOM.$('span'));
		const lineNumber = DOM.append(container, DOM.$('span.matchLineNum'));
		const actionBarContainer = DOM.append(container, DOM.$('span.actionBarContainer'));
		const actions = new ActionBar(actionBarContainer, { animated: false });

		return {
			parent,
			before,
			match,
			replace,
			after,
			lineNumber,
			actions
		};
	}

	private renderFolderMatch(tree: ITree, folderMatch: FolderMatch, templateData: IFolderMatchTemplate): void {
		if (folderMatch.hasResource()) {
			const workspaceFolder = this.contextService.getWorkspaceFolder(folderMatch.resource());
			if (workspaceFolder && resources.isEqual(workspaceFolder.uri, folderMatch.resource())) {
				templateData.label.setFile(folderMatch.resource(), { fileKind: FileKind.ROOT_FOLDER, hidePath: true });
			} else {
				templateData.label.setFile(folderMatch.resource(), { fileKind: FileKind.FOLDER });
			}
		} else {
			templateData.label.setValue(nls.localize('searchFolderMatch.other.label', "Other files"));
		}
		let count = folderMatch.fileCount();
		templateData.badge.setCount(count);
		templateData.badge.setTitleFormat(count > 1 ? nls.localize('searchFileMatches', "{0} files found", count) : nls.localize('searchFileMatch', "{0} file found", count));

		templateData.actions.clear();

		const input = <SearchResult>tree.getInput();
		const actions: IAction[] = [];
		if (input.searchModel.isReplaceActive() && count > 0) {
			actions.push(this.instantiationService.createInstance(ReplaceAllInFolderAction, tree, folderMatch));
		}

		actions.push(new RemoveAction(tree, folderMatch));
		templateData.actions.push(actions, { icon: true, label: false });
	}

	private renderFileMatch(tree: ITree, fileMatch: FileMatch, templateData: IFileMatchTemplate): void {
		templateData.el.setAttribute('data-resource', fileMatch.resource().toString());
		templateData.label.setFile(fileMatch.resource(), { hideIcon: false });
		let count = fileMatch.count();
		templateData.badge.setCount(count);
		templateData.badge.setTitleFormat(count > 1 ? nls.localize('searchMatches', "{0} matches found", count) : nls.localize('searchMatch', "{0} match found", count));

		let input = <SearchResult>tree.getInput();
		templateData.actions.clear();

		const actions: IAction[] = [];
		if (input.searchModel.isReplaceActive() && count > 0) {
			actions.push(this.instantiationService.createInstance(ReplaceAllAction, tree, fileMatch, this.searchView));
		}
		actions.push(new RemoveAction(tree, fileMatch));
		templateData.actions.push(actions, { icon: true, label: false });
	}

	private renderMatch(tree: ITree, match: Match, templateData: IMatchTemplate): void {
		let preview = match.preview();
		const searchModel: SearchModel = (<SearchResult>tree.getInput()).searchModel;
		const replace = searchModel.isReplaceActive() && !!searchModel.replaceString;

		templateData.before.textContent = preview.before;
		templateData.match.textContent = preview.inside;
		DOM.toggleClass(templateData.match, 'replace', replace);
		templateData.replace.textContent = replace ? match.replaceString : '';
		templateData.after.textContent = preview.after;
		templateData.parent.title = (preview.before + (replace ? match.replaceString : preview.inside) + preview.after).trim().substr(0, 999);

		const numLines = match.range().endLineNumber - match.range().startLineNumber;
		const extraLinesStr = numLines > 0 ? `+${numLines}` : '';

		const showLineNumbers = this.configurationService.getValue<ISearchConfigurationProperties>('search').showLineNumbers;
		const lineNumberStr = showLineNumbers ? `:${match.range().startLineNumber}` : '';
		DOM.toggleClass(templateData.lineNumber, 'show', (numLines > 0) || showLineNumbers);

		templateData.lineNumber.textContent = lineNumberStr + extraLinesStr;
		templateData.lineNumber.setAttribute('title', this.getMatchTitle(match, showLineNumbers));

		templateData.actions.clear();
		if (searchModel.isReplaceActive()) {
			templateData.actions.push([this.instantiationService.createInstance(ReplaceAction, tree, match, this.searchView), new RemoveAction(tree, match)], { icon: true, label: false });
		} else {
			templateData.actions.push([new RemoveAction(tree, match)], { icon: true, label: false });
		}
	}

	private getMatchTitle(match: Match, showLineNumbers: boolean): string {
		const startLine = match.range().startLineNumber;
		const numLines = match.range().endLineNumber - match.range().startLineNumber;

		const lineNumStr = showLineNumbers ?
			nls.localize('lineNumStr', "From line {0}", startLine, numLines) + ' ' :
			'';

		const numLinesStr = numLines > 0 ?
			'+ ' + nls.localize('numLinesStr', "{0} more lines", numLines) :
			'';

		return lineNumStr + numLinesStr;
	}

	public disposeTemplate(tree: ITree, templateId: string, templateData: any): void {
		if (SearchRenderer.FOLDER_MATCH_TEMPLATE_ID === templateId) {
			const template = <IFolderMatchTemplate>templateData;
			template.label.dispose();
			template.actions.dispose();
		} else if (SearchRenderer.FILE_MATCH_TEMPLATE_ID === templateId) {
			const template = <IFileMatchTemplate>templateData;
			template.label.dispose();
			template.actions.dispose();
		} else if (SearchRenderer.MATCH_TEMPLATE_ID === templateId) {
			const template = <IMatchTemplate>templateData;
			template.actions.dispose();
		}
	}
}

export class SearchAccessibilityProvider implements IAccessibilityProvider {

	constructor(
		@ILabelService private labelService: ILabelService
	) {
	}

	public getAriaLabel(tree: ITree, element: FileMatchOrMatch): string {
		if (element instanceof FolderMatch) {
			return element.hasResource() ?
				nls.localize('folderMatchAriaLabel', "{0} matches in folder root {1}, Search result", element.count(), element.name()) :
				nls.localize('otherFilesAriaLabel', "{0} matches outside of the workspace, Search result", element.count());
		}

		if (element instanceof FileMatch) {
			const path = this.labelService.getUriLabel(element.resource(), { relative: true }) || element.resource().fsPath;

			return nls.localize('fileMatchAriaLabel', "{0} matches in file {1} of folder {2}, Search result", element.count(), element.name(), paths.dirname(path));
		}

		if (element instanceof Match) {
			const match = <Match>element;
			const searchModel: SearchModel = (<SearchResult>tree.getInput()).searchModel;
			const replace = searchModel.isReplaceActive() && !!searchModel.replaceString;
			const matchString = match.getMatchString();
			const range = match.range();
			const matchText = match.text().substr(0, range.endColumn + 150);
			if (replace) {
				return nls.localize('replacePreviewResultAria', "Replace term {0} with {1} at column position {2} in line with text {3}", matchString, match.replaceString, range.startColumn + 1, matchText);
			}

			return nls.localize('searchResultAria', "Found term {0} at column position {1} in line with text {2}", matchString, range.startColumn + 1, matchText);
		}
		return undefined;
	}
}

export class SearchFilter implements IFilter {

	public isVisible(tree: ITree, element: any): boolean {
		return !(element instanceof FileMatch || element instanceof FolderMatch) || element.matches().length > 0;
	}
}

export class SearchTreeController extends WorkbenchTreeController {
	private contextMenu: IMenu;

	constructor(
		@IContextMenuService private contextMenuService: IContextMenuService,
		@IMenuService private menuService: IMenuService,
		@IConfigurationService configurationService: IConfigurationService
	) {
		super({}, configurationService);
	}

	public onContextMenu(tree: WorkbenchTree, element: any, event: ContextMenuEvent): boolean {
		if (!this.contextMenu) {
			this.contextMenu = this.menuService.createMenu(MenuId.SearchContext, tree.contextKeyService);
			this.disposables.push(this.contextMenu);
		}

		tree.setFocus(element, { preventOpenOnFocus: true });

		const anchor = { x: event.posx, y: event.posy };
		this.contextMenuService.showContextMenu({
			getAnchor: () => anchor,

			getActions: () => {
				const actions: IAction[] = [];
				fillInContextMenuActions(this.contextMenu, { shouldForwardArgs: true }, actions, this.contextMenuService);
				return actions;
			},

			getActionsContext: () => element
		});

		return true;
	}
}
