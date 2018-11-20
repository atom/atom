/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { Emitter, Event } from 'vs/base/common/event';
import { Disposable } from 'vs/base/common/lifecycle';
import { URI } from 'vs/base/common/uri';
import { IMode, LanguageId, LanguageIdentifier } from 'vs/editor/common/modes';
import { FrankensteinMode } from 'vs/editor/common/modes/abstractMode';
import { NULL_LANGUAGE_IDENTIFIER } from 'vs/editor/common/modes/nullMode';
import { LanguagesRegistry } from 'vs/editor/common/services/languagesRegistry';
import { ILanguageSelection, IModeService } from 'vs/editor/common/services/modeService';

class LanguageSelection extends Disposable implements ILanguageSelection {

	public languageIdentifier: LanguageIdentifier;

	private readonly _selector: () => LanguageIdentifier;

	private readonly _onDidChange: Emitter<LanguageIdentifier> = this._register(new Emitter<LanguageIdentifier>());
	public readonly onDidChange: Event<LanguageIdentifier> = this._onDidChange.event;

	constructor(onLanguagesMaybeChanged: Event<void>, selector: () => LanguageIdentifier) {
		super();
		this._selector = selector;
		this.languageIdentifier = this._selector();
		this._register(onLanguagesMaybeChanged(() => this._evaluate()));
	}

	private _evaluate(): void {
		let languageIdentifier = this._selector();
		if (languageIdentifier.id === this.languageIdentifier.id) {
			// no change
			return;
		}
		this.languageIdentifier = languageIdentifier;
		this._onDidChange.fire(this.languageIdentifier);
	}
}

export class ModeServiceImpl implements IModeService {
	public _serviceBrand: any;

	private readonly _instantiatedModes: { [modeId: string]: IMode; };
	private readonly _registry: LanguagesRegistry;

	private readonly _onDidCreateMode: Emitter<IMode> = new Emitter<IMode>();
	public readonly onDidCreateMode: Event<IMode> = this._onDidCreateMode.event;

	protected readonly _onLanguagesMaybeChanged: Emitter<void> = new Emitter<void>();
	private readonly onLanguagesMaybeChanged: Event<void> = this._onLanguagesMaybeChanged.event;

	constructor(warnOnOverwrite = false) {
		this._instantiatedModes = {};

		this._registry = new LanguagesRegistry(true, warnOnOverwrite);
		this._registry.onDidChange(() => this._onLanguagesMaybeChanged.fire());
	}

	protected _onReady(): Promise<boolean> {
		return Promise.resolve(true);
	}

	public isRegisteredMode(mimetypeOrModeId: string): boolean {
		return this._registry.isRegisteredMode(mimetypeOrModeId);
	}

	public getRegisteredModes(): string[] {
		return this._registry.getRegisteredModes();
	}

	public getRegisteredLanguageNames(): string[] {
		return this._registry.getRegisteredLanguageNames();
	}

	public getExtensions(alias: string): string[] {
		return this._registry.getExtensions(alias);
	}

	public getFilenames(alias: string): string[] {
		return this._registry.getFilenames(alias);
	}

	public getMimeForMode(modeId: string): string | null {
		return this._registry.getMimeForMode(modeId);
	}

	public getLanguageName(modeId: string): string | null {
		return this._registry.getLanguageName(modeId);
	}

	public getModeIdForLanguageName(alias: string): string | null {
		return this._registry.getModeIdForLanguageNameLowercase(alias);
	}

	public getModeIdByFilepathOrFirstLine(filepath: string, firstLine?: string): string | null {
		const modeIds = this._registry.getModeIdsFromFilepathOrFirstLine(filepath, firstLine);

		if (modeIds.length > 0) {
			return modeIds[0];
		}

		return null;
	}

	public getModeId(commaSeparatedMimetypesOrCommaSeparatedIds: string): string | null {
		const modeIds = this._registry.extractModeIds(commaSeparatedMimetypesOrCommaSeparatedIds);

		if (modeIds.length > 0) {
			return modeIds[0];
		}

		return null;
	}

	public getLanguageIdentifier(modeId: string | LanguageId): LanguageIdentifier | null {
		return this._registry.getLanguageIdentifier(modeId);
	}

	public getConfigurationFiles(modeId: string): URI[] {
		return this._registry.getConfigurationFiles(modeId);
	}

	// --- instantiation

	public create(commaSeparatedMimetypesOrCommaSeparatedIds: string): ILanguageSelection {
		return new LanguageSelection(this.onLanguagesMaybeChanged, () => {
			const modeId = this.getModeId(commaSeparatedMimetypesOrCommaSeparatedIds);
			return this._createModeAndGetLanguageIdentifier(modeId);
		});
	}

	public createByLanguageName(languageName: string): ILanguageSelection {
		return new LanguageSelection(this.onLanguagesMaybeChanged, () => {
			const modeId = this._getModeIdByLanguageName(languageName);
			return this._createModeAndGetLanguageIdentifier(modeId);
		});
	}

	public createByFilepathOrFirstLine(filepath: string, firstLine?: string): ILanguageSelection {
		return new LanguageSelection(this.onLanguagesMaybeChanged, () => {
			const modeId = this.getModeIdByFilepathOrFirstLine(filepath, firstLine);
			return this._createModeAndGetLanguageIdentifier(modeId);
		});
	}

	private _createModeAndGetLanguageIdentifier(modeId: string | null): LanguageIdentifier {
		// Fall back to plain text if no mode was found
		const languageIdentifier = this.getLanguageIdentifier(modeId || 'plaintext') || NULL_LANGUAGE_IDENTIFIER;
		this._getOrCreateMode(languageIdentifier.language);
		return languageIdentifier;
	}

	public triggerMode(commaSeparatedMimetypesOrCommaSeparatedIds: string): void {
		const modeId = this.getModeId(commaSeparatedMimetypesOrCommaSeparatedIds);
		// Fall back to plain text if no mode was found
		this._getOrCreateMode(modeId || 'plaintext');
	}

	public waitForLanguageRegistration(): Promise<void> {
		return this._onReady().then(() => { });
	}

	private _getModeIdByLanguageName(languageName: string): string | null {
		const modeIds = this._registry.getModeIdsFromLanguageName(languageName);

		if (modeIds.length > 0) {
			return modeIds[0];
		}

		return null;
	}

	private _getOrCreateMode(modeId: string): IMode {
		if (!this._instantiatedModes.hasOwnProperty(modeId)) {
			let languageIdentifier = this.getLanguageIdentifier(modeId) || NULL_LANGUAGE_IDENTIFIER;
			this._instantiatedModes[modeId] = new FrankensteinMode(languageIdentifier);

			this._onDidCreateMode.fire(this._instantiatedModes[modeId]);
		}
		return this._instantiatedModes[modeId];
	}
}
