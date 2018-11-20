/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as nls from 'vs/nls';
import { Emitter, Event } from 'vs/base/common/event';
import { LanguageId, LanguageIdentifier } from 'vs/editor/common/modes';
import { LanguageConfigurationRegistry } from 'vs/editor/common/modes/languageConfigurationRegistry';
import { ILanguageExtensionPoint } from 'vs/editor/common/services/modeService';
import { Registry } from 'vs/platform/registry/common/platform';

// Define extension point ids
export const Extensions = {
	ModesRegistry: 'editor.modesRegistry'
};

export class EditorModesRegistry {

	private _languages: ILanguageExtensionPoint[];

	private readonly _onDidAddLanguages: Emitter<ILanguageExtensionPoint[]> = new Emitter<ILanguageExtensionPoint[]>();
	public readonly onDidAddLanguages: Event<ILanguageExtensionPoint[]> = this._onDidAddLanguages.event;

	constructor() {
		this._languages = [];
	}

	// --- languages

	public registerLanguage(def: ILanguageExtensionPoint): void {
		this._languages.push(def);
		this._onDidAddLanguages.fire([def]);
	}
	public registerLanguages(def: ILanguageExtensionPoint[]): void {
		this._languages = this._languages.concat(def);
		this._onDidAddLanguages.fire(def);
	}
	public getLanguages(): ILanguageExtensionPoint[] {
		return this._languages.slice(0);
	}
}

export const ModesRegistry = new EditorModesRegistry();
Registry.add(Extensions.ModesRegistry, ModesRegistry);

export const PLAINTEXT_MODE_ID = 'plaintext';
export const PLAINTEXT_LANGUAGE_IDENTIFIER = new LanguageIdentifier(PLAINTEXT_MODE_ID, LanguageId.PlainText);

ModesRegistry.registerLanguage({
	id: PLAINTEXT_MODE_ID,
	extensions: ['.txt', '.gitignore'],
	aliases: [nls.localize('plainText.alias', "Plain Text"), 'text'],
	mimetypes: ['text/plain']
});
LanguageConfigurationRegistry.register(PLAINTEXT_LANGUAGE_IDENTIFIER, {
	brackets: [
		['(', ')'],
		['[', ']'],
		['{', '}'],
	]
});
