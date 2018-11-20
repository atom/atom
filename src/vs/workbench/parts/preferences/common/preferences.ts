/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { createDecorator } from 'vs/platform/instantiation/common/instantiation';
import { RawContextKey } from 'vs/platform/contextkey/common/contextkey';
import { join } from 'vs/base/common/paths';
import { ISettingsEditorModel, ISearchResult } from 'vs/workbench/services/preferences/common/preferences';
import { IEditor } from 'vs/workbench/common/editor';
import { IKeybindingItemEntry } from 'vs/workbench/services/preferences/common/keybindingsEditorModel';
import { CancellationToken } from 'vs/base/common/cancellation';

export interface IWorkbenchSettingsConfiguration {
	workbench: {
		settings: {
			openDefaultSettings: boolean;
			naturalLanguageSearchEndpoint: string;
			naturalLanguageSearchKey: string;
			naturalLanguageSearchAutoIngestFeedback: boolean;
			useNaturalLanguageSearchPost: boolean;
			enableNaturalLanguageSearch: boolean;
			enableNaturalLanguageSearchFeedback: boolean;
		}
	};
}

export interface IEndpointDetails {
	urlBase: string;
	key?: string;
}

export const IPreferencesSearchService = createDecorator<IPreferencesSearchService>('preferencesSearchService');

export interface IPreferencesSearchService {
	_serviceBrand: any;

	getLocalSearchProvider(filter: string): ISearchProvider;
	getRemoteSearchProvider(filter: string, newExtensionsOnly?: boolean): ISearchProvider;
}

export interface ISearchProvider {
	searchModel(preferencesModel: ISettingsEditorModel, token?: CancellationToken): Promise<ISearchResult>;
}

export interface IKeybindingsEditor extends IEditor {

	activeKeybindingEntry: IKeybindingItemEntry;

	search(filter: string): void;
	focusSearch(): void;
	clearSearchResults(): void;
	focusKeybindings(): void;
	recordSearchKeys(): void;
	toggleSortByPrecedence(): void;
	defineKeybinding(keybindingEntry: IKeybindingItemEntry): Thenable<any>;
	removeKeybinding(keybindingEntry: IKeybindingItemEntry): Thenable<any>;
	resetKeybinding(keybindingEntry: IKeybindingItemEntry): Thenable<any>;
	copyKeybinding(keybindingEntry: IKeybindingItemEntry): void;
	copyKeybindingCommand(keybindingEntry: IKeybindingItemEntry): void;
	showSimilarKeybindings(keybindingEntry: IKeybindingItemEntry): void;
}

export const CONTEXT_SETTINGS_EDITOR = new RawContextKey<boolean>('inSettingsEditor', false);
export const CONTEXT_SETTINGS_JSON_EDITOR = new RawContextKey<boolean>('inSettingsJSONEditor', false);
export const CONTEXT_SETTINGS_SEARCH_FOCUS = new RawContextKey<boolean>('inSettingsSearch', false);
export const CONTEXT_TOC_ROW_FOCUS = new RawContextKey<boolean>('settingsTocRowFocus', false);
export const CONTEXT_KEYBINDINGS_EDITOR = new RawContextKey<boolean>('inKeybindings', false);
export const CONTEXT_KEYBINDINGS_SEARCH_FOCUS = new RawContextKey<boolean>('inKeybindingsSearch', false);
export const CONTEXT_KEYBINDING_FOCUS = new RawContextKey<boolean>('keybindingFocus', false);

export const SETTINGS_EDITOR_COMMAND_SEARCH = 'settings.action.search';
export const SETTINGS_EDITOR_COMMAND_CLEAR_SEARCH_RESULTS = 'settings.action.clearSearchResults';
export const SETTINGS_EDITOR_COMMAND_FOCUS_NEXT_SETTING = 'settings.action.focusNextSetting';
export const SETTINGS_EDITOR_COMMAND_FOCUS_PREVIOUS_SETTING = 'settings.action.focusPreviousSetting';
export const SETTINGS_EDITOR_COMMAND_FOCUS_FILE = 'settings.action.focusSettingsFile';
export const SETTINGS_EDITOR_COMMAND_EDIT_FOCUSED_SETTING = 'settings.action.editFocusedSetting';
export const SETTINGS_EDITOR_COMMAND_FOCUS_SETTINGS_FROM_SEARCH = 'settings.action.focusSettingsFromSearch';
export const SETTINGS_EDITOR_COMMAND_FOCUS_SETTINGS_LIST = 'settings.action.focusSettingsList';
export const SETTINGS_EDITOR_COMMAND_SHOW_CONTEXT_MENU = 'settings.action.showContextMenu';

export const SETTINGS_EDITOR_COMMAND_SWITCH_TO_JSON = 'settings.switchToJSON';
export const SETTINGS_EDITOR_COMMAND_FILTER_MODIFIED = 'settings.filterByModified';
export const SETTINGS_EDITOR_COMMAND_FILTER_ONLINE = 'settings.filterByOnline';

export const KEYBINDINGS_EDITOR_COMMAND_SEARCH = 'keybindings.editor.searchKeybindings';
export const KEYBINDINGS_EDITOR_COMMAND_CLEAR_SEARCH_RESULTS = 'keybindings.editor.clearSearchResults';
export const KEYBINDINGS_EDITOR_COMMAND_RECORD_SEARCH_KEYS = 'keybindings.editor.recordSearchKeys';
export const KEYBINDINGS_EDITOR_COMMAND_SORTBY_PRECEDENCE = 'keybindings.editor.toggleSortByPrecedence';
export const KEYBINDINGS_EDITOR_COMMAND_DEFINE = 'keybindings.editor.defineKeybinding';
export const KEYBINDINGS_EDITOR_COMMAND_REMOVE = 'keybindings.editor.removeKeybinding';
export const KEYBINDINGS_EDITOR_COMMAND_RESET = 'keybindings.editor.resetKeybinding';
export const KEYBINDINGS_EDITOR_COMMAND_COPY = 'keybindings.editor.copyKeybindingEntry';
export const KEYBINDINGS_EDITOR_COMMAND_COPY_COMMAND = 'keybindings.editor.copyCommandKeybindingEntry';
export const KEYBINDINGS_EDITOR_COMMAND_SHOW_SIMILAR = 'keybindings.editor.showConflicts';
export const KEYBINDINGS_EDITOR_COMMAND_FOCUS_KEYBINDINGS = 'keybindings.editor.focusKeybindings';
export const KEYBINDINGS_EDITOR_CLEAR_INPUT = 'keybindings.editor.showDefaultKeybindings';
export const KEYBINDINGS_EDITOR_SHOW_DEFAULT_KEYBINDINGS = 'keybindings.editor.showDefaultKeybindings';
export const KEYBINDINGS_EDITOR_SHOW_USER_KEYBINDINGS = 'keybindings.editor.showUserKeybindings';

export const FOLDER_SETTINGS_PATH = join('.vscode', 'settings.json');
export const DEFAULT_SETTINGS_EDITOR_SETTING = 'workbench.settings.openDefaultSettings';

export const MODIFIED_SETTING_TAG = 'modified';