/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as nls from 'vs/nls';
import * as nativeKeymap from 'native-keymap';
import { release } from 'os';
import * as dom from 'vs/base/browser/dom';
import { StandardKeyboardEvent } from 'vs/base/browser/keyboardEvent';
import { onUnexpectedError } from 'vs/base/common/errors';
import { Emitter, Event } from 'vs/base/common/event';
import { IJSONSchema } from 'vs/base/common/jsonSchema';
import { Keybinding, ResolvedKeybinding } from 'vs/base/common/keyCodes';
import { KeybindingParser } from 'vs/base/common/keybindingParser';
import { OS, OperatingSystem } from 'vs/base/common/platform';
import { ConfigWatcher } from 'vs/base/node/config';
import { ICommandService } from 'vs/platform/commands/common/commands';
import { IConfigurationService } from 'vs/platform/configuration/common/configuration';
import { Extensions as ConfigExtensions, IConfigurationNode, IConfigurationRegistry } from 'vs/platform/configuration/common/configurationRegistry';
import { ContextKeyExpr, IContextKeyService } from 'vs/platform/contextkey/common/contextkey';
import { IEnvironmentService } from 'vs/platform/environment/common/environment';
import { Extensions, IJSONContributionRegistry } from 'vs/platform/jsonschemas/common/jsonContributionRegistry';
import { AbstractKeybindingService } from 'vs/platform/keybinding/common/abstractKeybindingService';
import { IKeybindingEvent, IKeyboardEvent, IUserFriendlyKeybinding, KeybindingSource } from 'vs/platform/keybinding/common/keybinding';
import { KeybindingResolver } from 'vs/platform/keybinding/common/keybindingResolver';
import { IKeybindingItem, IKeybindingRule2, KeybindingRuleSource, KeybindingWeight, KeybindingsRegistry } from 'vs/platform/keybinding/common/keybindingsRegistry';
import { ResolvedKeybindingItem } from 'vs/platform/keybinding/common/resolvedKeybindingItem';
import { INotificationService } from 'vs/platform/notification/common/notification';
import { Registry } from 'vs/platform/registry/common/platform';
import { IStatusbarService } from 'vs/platform/statusbar/common/statusbar';
import { ITelemetryService } from 'vs/platform/telemetry/common/telemetry';
import { keybindingsTelemetry } from 'vs/platform/telemetry/common/telemetryUtils';
import { ExtensionMessageCollector, ExtensionsRegistry } from 'vs/workbench/services/extensions/common/extensionsRegistry';
import { IUserKeybindingItem, KeybindingIO, OutputBuilder } from 'vs/workbench/services/keybinding/common/keybindingIO';
import { CachedKeyboardMapper, IKeyboardMapper } from 'vs/workbench/services/keybinding/common/keyboardMapper';
import { MacLinuxFallbackKeyboardMapper } from 'vs/workbench/services/keybinding/common/macLinuxFallbackKeyboardMapper';
import { IMacLinuxKeyboardMapping, MacLinuxKeyboardMapper, macLinuxKeyboardMappingEquals } from 'vs/workbench/services/keybinding/common/macLinuxKeyboardMapper';
import { IWindowsKeyboardMapping, WindowsKeyboardMapper, windowsKeyboardMappingEquals } from 'vs/workbench/services/keybinding/common/windowsKeyboardMapper';

export class KeyboardMapperFactory {
	public static readonly INSTANCE = new KeyboardMapperFactory();

	private _layoutInfo: nativeKeymap.IKeyboardLayoutInfo | null;
	private _rawMapping: nativeKeymap.IKeyboardMapping | null;
	private _keyboardMapper: IKeyboardMapper | null;
	private _initialized: boolean;

	private readonly _onDidChangeKeyboardMapper: Emitter<void> = new Emitter<void>();
	public readonly onDidChangeKeyboardMapper: Event<void> = this._onDidChangeKeyboardMapper.event;

	private constructor() {
		this._layoutInfo = null;
		this._rawMapping = null;
		this._keyboardMapper = null;
		this._initialized = false;
	}

	public _onKeyboardLayoutChanged(): void {
		if (this._initialized) {
			this._setKeyboardData(nativeKeymap.getCurrentKeyboardLayout(), nativeKeymap.getKeyMap());
		}
	}

	public getKeyboardMapper(dispatchConfig: DispatchConfig): IKeyboardMapper {
		if (!this._initialized) {
			this._setKeyboardData(nativeKeymap.getCurrentKeyboardLayout(), nativeKeymap.getKeyMap());
		}
		if (dispatchConfig === DispatchConfig.KeyCode) {
			// Forcefully set to use keyCode
			return new MacLinuxFallbackKeyboardMapper(OS);
		}
		return this._keyboardMapper!;
	}

	public getCurrentKeyboardLayout(): nativeKeymap.IKeyboardLayoutInfo | null {
		if (!this._initialized) {
			this._setKeyboardData(nativeKeymap.getCurrentKeyboardLayout(), nativeKeymap.getKeyMap());
		}
		return this._layoutInfo;
	}

	private static _isUSStandard(_kbInfo: nativeKeymap.IKeyboardLayoutInfo): boolean {
		if (OS === OperatingSystem.Linux) {
			const kbInfo = <nativeKeymap.ILinuxKeyboardLayoutInfo>_kbInfo;
			return (kbInfo && kbInfo.layout === 'us');
		}

		if (OS === OperatingSystem.Macintosh) {
			const kbInfo = <nativeKeymap.IMacKeyboardLayoutInfo>_kbInfo;
			return (kbInfo && kbInfo.id === 'com.apple.keylayout.US');
		}

		if (OS === OperatingSystem.Windows) {
			const kbInfo = <nativeKeymap.IWindowsKeyboardLayoutInfo>_kbInfo;
			return (kbInfo && kbInfo.name === '00000409');
		}

		return false;
	}

	public getRawKeyboardMapping(): nativeKeymap.IKeyboardMapping | null {
		if (!this._initialized) {
			this._setKeyboardData(nativeKeymap.getCurrentKeyboardLayout(), nativeKeymap.getKeyMap());
		}
		return this._rawMapping;
	}

	private _setKeyboardData(layoutInfo: nativeKeymap.IKeyboardLayoutInfo, rawMapping: nativeKeymap.IKeyboardMapping): void {
		this._layoutInfo = layoutInfo;

		if (this._initialized && KeyboardMapperFactory._equals(this._rawMapping, rawMapping)) {
			// nothing to do...
			return;
		}

		this._initialized = true;
		this._rawMapping = rawMapping;
		this._keyboardMapper = new CachedKeyboardMapper(
			KeyboardMapperFactory._createKeyboardMapper(this._layoutInfo, this._rawMapping)
		);
		this._onDidChangeKeyboardMapper.fire();
	}

	private static _createKeyboardMapper(layoutInfo: nativeKeymap.IKeyboardLayoutInfo, rawMapping: nativeKeymap.IKeyboardMapping): IKeyboardMapper {
		const isUSStandard = KeyboardMapperFactory._isUSStandard(layoutInfo);
		if (OS === OperatingSystem.Windows) {
			return new WindowsKeyboardMapper(isUSStandard, <IWindowsKeyboardMapping>rawMapping);
		}

		if (Object.keys(rawMapping).length === 0) {
			// Looks like reading the mappings failed (most likely Mac + Japanese/Chinese keyboard layouts)
			return new MacLinuxFallbackKeyboardMapper(OS);
		}

		if (OS === OperatingSystem.Macintosh) {
			const kbInfo = <nativeKeymap.IMacKeyboardLayoutInfo>layoutInfo;
			if (kbInfo.id === 'com.apple.keylayout.DVORAK-QWERTYCMD') {
				// Use keyCode based dispatching for DVORAK - QWERTY ⌘
				return new MacLinuxFallbackKeyboardMapper(OS);
			}
		}

		return new MacLinuxKeyboardMapper(isUSStandard, <IMacLinuxKeyboardMapping>rawMapping, OS);
	}

	private static _equals(a: nativeKeymap.IKeyboardMapping | null, b: nativeKeymap.IKeyboardMapping | null): boolean {
		if (OS === OperatingSystem.Windows) {
			return windowsKeyboardMappingEquals(<IWindowsKeyboardMapping>a, <IWindowsKeyboardMapping>b);
		}

		return macLinuxKeyboardMappingEquals(<IMacLinuxKeyboardMapping>a, <IMacLinuxKeyboardMapping>b);
	}
}

interface ContributedKeyBinding {
	command: string;
	key: string;
	when?: string;
	mac?: string;
	linux?: string;
	win?: string;
}

function isContributedKeyBindingsArray(thing: ContributedKeyBinding | ContributedKeyBinding[]): thing is ContributedKeyBinding[] {
	return Array.isArray(thing);
}

function isValidContributedKeyBinding(keyBinding: ContributedKeyBinding, rejects: string[]): boolean {
	if (!keyBinding) {
		rejects.push(nls.localize('nonempty', "expected non-empty value."));
		return false;
	}
	if (typeof keyBinding.command !== 'string') {
		rejects.push(nls.localize('requirestring', "property `{0}` is mandatory and must be of type `string`", 'command'));
		return false;
	}
	if (keyBinding.key && typeof keyBinding.key !== 'string') {
		rejects.push(nls.localize('optstring', "property `{0}` can be omitted or must be of type `string`", 'key'));
		return false;
	}
	if (keyBinding.when && typeof keyBinding.when !== 'string') {
		rejects.push(nls.localize('optstring', "property `{0}` can be omitted or must be of type `string`", 'when'));
		return false;
	}
	if (keyBinding.mac && typeof keyBinding.mac !== 'string') {
		rejects.push(nls.localize('optstring', "property `{0}` can be omitted or must be of type `string`", 'mac'));
		return false;
	}
	if (keyBinding.linux && typeof keyBinding.linux !== 'string') {
		rejects.push(nls.localize('optstring', "property `{0}` can be omitted or must be of type `string`", 'linux'));
		return false;
	}
	if (keyBinding.win && typeof keyBinding.win !== 'string') {
		rejects.push(nls.localize('optstring', "property `{0}` can be omitted or must be of type `string`", 'win'));
		return false;
	}
	return true;
}

let keybindingType: IJSONSchema = {
	type: 'object',
	default: { command: '', key: '' },
	properties: {
		command: {
			description: nls.localize('vscode.extension.contributes.keybindings.command', 'Identifier of the command to run when keybinding is triggered.'),
			type: 'string'
		},
		key: {
			description: nls.localize('vscode.extension.contributes.keybindings.key', 'Key or key sequence (separate keys with plus-sign and sequences with space, e.g Ctrl+O and Ctrl+L L for a chord).'),
			type: 'string'
		},
		mac: {
			description: nls.localize('vscode.extension.contributes.keybindings.mac', 'Mac specific key or key sequence.'),
			type: 'string'
		},
		linux: {
			description: nls.localize('vscode.extension.contributes.keybindings.linux', 'Linux specific key or key sequence.'),
			type: 'string'
		},
		win: {
			description: nls.localize('vscode.extension.contributes.keybindings.win', 'Windows specific key or key sequence.'),
			type: 'string'
		},
		when: {
			description: nls.localize('vscode.extension.contributes.keybindings.when', 'Condition when the key is active.'),
			type: 'string'
		}
	}
};

let keybindingsExtPoint = ExtensionsRegistry.registerExtensionPoint<ContributedKeyBinding | ContributedKeyBinding[]>('keybindings', [], {
	description: nls.localize('vscode.extension.contributes.keybindings', "Contributes keybindings."),
	oneOf: [
		keybindingType,
		{
			type: 'array',
			items: keybindingType
		}
	]
});

export const enum DispatchConfig {
	Code,
	KeyCode
}

function getDispatchConfig(configurationService: IConfigurationService): DispatchConfig {
	const keyboard = configurationService.getValue('keyboard');
	const r = (keyboard ? (<any>keyboard).dispatch : null);
	return (r === 'keyCode' ? DispatchConfig.KeyCode : DispatchConfig.Code);
}

export class WorkbenchKeybindingService extends AbstractKeybindingService {

	private _keyboardMapper: IKeyboardMapper;
	private _cachedResolver: KeybindingResolver | null;
	private _firstTimeComputingResolver: boolean;
	private userKeybindings: ConfigWatcher<IUserFriendlyKeybinding[]>;

	constructor(
		windowElement: Window,
		@IContextKeyService contextKeyService: IContextKeyService,
		@ICommandService commandService: ICommandService,
		@ITelemetryService telemetryService: ITelemetryService,
		@INotificationService notificationService: INotificationService,
		@IEnvironmentService environmentService: IEnvironmentService,
		@IStatusbarService statusBarService: IStatusbarService,
		@IConfigurationService configurationService: IConfigurationService
	) {
		super(contextKeyService, commandService, telemetryService, notificationService, statusBarService);

		let dispatchConfig = getDispatchConfig(configurationService);
		configurationService.onDidChangeConfiguration((e) => {
			let newDispatchConfig = getDispatchConfig(configurationService);
			if (dispatchConfig === newDispatchConfig) {
				return;
			}

			dispatchConfig = newDispatchConfig;
			this._keyboardMapper = KeyboardMapperFactory.INSTANCE.getKeyboardMapper(dispatchConfig);
			this.updateResolver({ source: KeybindingSource.Default });
		});

		this._keyboardMapper = KeyboardMapperFactory.INSTANCE.getKeyboardMapper(dispatchConfig);
		KeyboardMapperFactory.INSTANCE.onDidChangeKeyboardMapper(() => {
			this._keyboardMapper = KeyboardMapperFactory.INSTANCE.getKeyboardMapper(dispatchConfig);
			this.updateResolver({ source: KeybindingSource.Default });
		});

		this._cachedResolver = null;
		this._firstTimeComputingResolver = true;

		this.userKeybindings = this._register(new ConfigWatcher(environmentService.appKeybindingsPath, { defaultConfig: [], onError: error => onUnexpectedError(error) }));

		keybindingsExtPoint.setHandler((extensions) => {
			let commandAdded = false;

			for (let extension of extensions) {
				commandAdded = this._handleKeybindingsExtensionPointUser(extension.description.isBuiltin, extension.value, extension.collector) || commandAdded;
			}

			if (commandAdded) {
				this.updateResolver({ source: KeybindingSource.Default });
			}
		});

		this._register(this.userKeybindings.onDidUpdateConfiguration(event => this.updateResolver({
			source: KeybindingSource.User,
			keybindings: event.config
		})));

		this._register(dom.addDisposableListener(windowElement, dom.EventType.KEY_DOWN, (e: KeyboardEvent) => {
			let keyEvent = new StandardKeyboardEvent(e);
			let shouldPreventDefault = this._dispatch(keyEvent, keyEvent.target);
			if (shouldPreventDefault) {
				keyEvent.preventDefault();
			}
		}));

		keybindingsTelemetry(telemetryService, this);
		let data = KeyboardMapperFactory.INSTANCE.getCurrentKeyboardLayout();
		/* __GDPR__
			"keyboardLayout" : {
				"currentKeyboardLayout": { "${inline}": [ "${IKeyboardLayoutInfo}" ] }
			}
		*/
		telemetryService.publicLog('keyboardLayout', {
			currentKeyboardLayout: data
		});
	}

	public dumpDebugInfo(): string {
		const layoutInfo = JSON.stringify(KeyboardMapperFactory.INSTANCE.getCurrentKeyboardLayout(), null, '\t');
		const mapperInfo = this._keyboardMapper.dumpDebugInfo();
		const rawMapping = JSON.stringify(KeyboardMapperFactory.INSTANCE.getRawKeyboardMapping(), null, '\t');
		return `Layout info:\n${layoutInfo}\n${mapperInfo}\n\nRaw mapping:\n${rawMapping}`;
	}

	private _safeGetConfig(): IUserFriendlyKeybinding[] {
		let rawConfig = this.userKeybindings.getConfig();
		if (Array.isArray(rawConfig)) {
			return rawConfig;
		}
		return [];
	}

	public customKeybindingsCount(): number {
		let userKeybindings = this._safeGetConfig();

		return userKeybindings.length;
	}

	private updateResolver(event: IKeybindingEvent): void {
		this._cachedResolver = null;
		this._onDidUpdateKeybindings.fire(event);
	}

	protected _getResolver(): KeybindingResolver {
		if (!this._cachedResolver) {
			const defaults = this._resolveKeybindingItems(KeybindingsRegistry.getDefaultKeybindings(), true);
			const overrides = this._resolveUserKeybindingItems(this._getExtraKeybindings(this._firstTimeComputingResolver), false);
			this._cachedResolver = new KeybindingResolver(defaults, overrides);
			this._firstTimeComputingResolver = false;
		}
		return this._cachedResolver;
	}

	protected _documentHasFocus(): boolean {
		return document.hasFocus();
	}

	private _resolveKeybindingItems(items: IKeybindingItem[], isDefault: boolean): ResolvedKeybindingItem[] {
		let result: ResolvedKeybindingItem[] = [], resultLen = 0;
		for (let i = 0, len = items.length; i < len; i++) {
			const item = items[i];
			const when = (item.when ? item.when.normalize() : null);
			const keybinding = item.keybinding;
			if (!keybinding) {
				// This might be a removal keybinding item in user settings => accept it
				result[resultLen++] = new ResolvedKeybindingItem(null, item.command, item.commandArgs, when, isDefault);
			} else {
				const resolvedKeybindings = this.resolveKeybinding(keybinding);
				for (let j = 0; j < resolvedKeybindings.length; j++) {
					result[resultLen++] = new ResolvedKeybindingItem(resolvedKeybindings[j], item.command, item.commandArgs, when, isDefault);
				}
			}
		}

		return result;
	}

	private _resolveUserKeybindingItems(items: IUserKeybindingItem[], isDefault: boolean): ResolvedKeybindingItem[] {
		let result: ResolvedKeybindingItem[] = [], resultLen = 0;
		for (let i = 0, len = items.length; i < len; i++) {
			const item = items[i];
			const when = (item.when ? item.when.normalize() : null);
			const firstPart = item.firstPart;
			const chordPart = item.chordPart;
			if (!firstPart) {
				// This might be a removal keybinding item in user settings => accept it
				result[resultLen++] = new ResolvedKeybindingItem(null, item.command, item.commandArgs, when, isDefault);
			} else {
				const resolvedKeybindings = this._keyboardMapper.resolveUserBinding(firstPart, chordPart);
				for (let j = 0; j < resolvedKeybindings.length; j++) {
					result[resultLen++] = new ResolvedKeybindingItem(resolvedKeybindings[j], item.command, item.commandArgs, when, isDefault);
				}
			}
		}

		return result;
	}

	private _getExtraKeybindings(isFirstTime: boolean): IUserKeybindingItem[] {
		let extraUserKeybindings: IUserFriendlyKeybinding[] = this._safeGetConfig();
		if (!isFirstTime) {
			let cnt = extraUserKeybindings.length;

			/* __GDPR__
				"customKeybindingsChanged" : {
					"keyCount" : { "classification": "SystemMetaData", "purpose": "FeatureInsight", "isMeasurement": true }
				}
			*/
			this._telemetryService.publicLog('customKeybindingsChanged', {
				keyCount: cnt
			});
		}

		return extraUserKeybindings.map((k) => KeybindingIO.readUserKeybindingItem(k, OS));
	}

	public resolveKeybinding(kb: Keybinding): ResolvedKeybinding[] {
		return this._keyboardMapper.resolveKeybinding(kb);
	}

	public resolveKeyboardEvent(keyboardEvent: IKeyboardEvent): ResolvedKeybinding {
		return this._keyboardMapper.resolveKeyboardEvent(keyboardEvent);
	}

	public resolveUserBinding(userBinding: string): ResolvedKeybinding[] {
		const [firstPart, chordPart] = KeybindingParser.parseUserBinding(userBinding);
		return this._keyboardMapper.resolveUserBinding(firstPart, chordPart);
	}

	private _handleKeybindingsExtensionPointUser(isBuiltin: boolean, keybindings: ContributedKeyBinding | ContributedKeyBinding[], collector: ExtensionMessageCollector): boolean {
		if (isContributedKeyBindingsArray(keybindings)) {
			let commandAdded = false;
			for (let i = 0, len = keybindings.length; i < len; i++) {
				commandAdded = this._handleKeybinding(isBuiltin, i + 1, keybindings[i], collector) || commandAdded;
			}
			return commandAdded;
		} else {
			return this._handleKeybinding(isBuiltin, 1, keybindings, collector);
		}
	}

	private _handleKeybinding(isBuiltin: boolean, idx: number, keybindings: ContributedKeyBinding, collector: ExtensionMessageCollector): boolean {

		let rejects: string[] = [];
		let commandAdded = false;

		if (isValidContributedKeyBinding(keybindings, rejects)) {
			let rule = this._asCommandRule(isBuiltin, idx++, keybindings);
			if (rule) {
				KeybindingsRegistry.registerKeybindingRule2(rule, KeybindingRuleSource.Extension);
				commandAdded = true;
			}
		}

		if (rejects.length > 0) {
			collector.error(nls.localize(
				'invalid.keybindings',
				"Invalid `contributes.{0}`: {1}",
				keybindingsExtPoint.name,
				rejects.join('\n')
			));
		}

		return commandAdded;
	}

	private _asCommandRule(isBuiltin: boolean, idx: number, binding: ContributedKeyBinding): IKeybindingRule2 | undefined {

		let { command, when, key, mac, linux, win } = binding;

		let weight: number;
		if (isBuiltin) {
			weight = KeybindingWeight.BuiltinExtension + idx;
		} else {
			weight = KeybindingWeight.ExternalExtension + idx;
		}

		let desc: IKeybindingRule2 = {
			id: command,
			when: ContextKeyExpr.deserialize(when),
			weight: weight,
			primary: KeybindingParser.parseKeybinding(key, OS),
			mac: mac ? { primary: KeybindingParser.parseKeybinding(mac, OS) } : null,
			linux: linux ? { primary: KeybindingParser.parseKeybinding(linux, OS) } : null,
			win: win ? { primary: KeybindingParser.parseKeybinding(win, OS) } : null
		};

		if (!desc.primary && !desc.mac && !desc.linux && !desc.win) {
			return undefined;
		}

		return desc;
	}

	public getDefaultKeybindingsContent(): string {
		const resolver = this._getResolver();
		const defaultKeybindings = resolver.getDefaultKeybindings();
		const boundCommands = resolver.getDefaultBoundCommands();
		return (
			WorkbenchKeybindingService._getDefaultKeybindings(defaultKeybindings)
			+ '\n\n'
			+ WorkbenchKeybindingService._getAllCommandsAsComment(boundCommands)
		);
	}

	private static _getDefaultKeybindings(defaultKeybindings: ResolvedKeybindingItem[]): string {
		let out = new OutputBuilder();
		out.writeLine('[');

		let lastIndex = defaultKeybindings.length - 1;
		defaultKeybindings.forEach((k, index) => {
			KeybindingIO.writeKeybindingItem(out, k, OS);
			if (index !== lastIndex) {
				out.writeLine(',');
			} else {
				out.writeLine();
			}
		});
		out.writeLine(']');
		return out.toString();
	}

	private static _getAllCommandsAsComment(boundCommands: Map<string, boolean>): string {
		const unboundCommands = KeybindingResolver.getAllUnboundCommands(boundCommands);
		let pretty = unboundCommands.sort().join('\n// - ');
		return '// ' + nls.localize('unboundCommands', "Here are other available commands: ") + '\n// - ' + pretty;
	}

	mightProducePrintableCharacter(event: IKeyboardEvent): boolean {
		if (event.ctrlKey || event.metaKey) {
			// ignore ctrl/cmd-combination but not shift/alt-combinatios
			return false;
		}
		// consult the KeyboardMapperFactory to check the given event for
		// a printable value.
		const mapping = KeyboardMapperFactory.INSTANCE.getRawKeyboardMapping();
		if (!mapping) {
			return false;
		}
		const keyInfo = mapping[event.code];
		if (!keyInfo) {
			return false;
		}
		if (!keyInfo.value || /\s/.test(keyInfo.value)) {
			return false;
		}
		return true;
	}
}

let schemaId = 'vscode://schemas/keybindings';
let schema: IJSONSchema = {
	'id': schemaId,
	'type': 'array',
	'title': nls.localize('keybindings.json.title', "Keybindings configuration"),
	'items': {
		'required': ['key'],
		'type': 'object',
		'defaultSnippets': [{ 'body': { 'key': '$1', 'command': '$2', 'when': '$3' } }],
		'properties': {
			'key': {
				'type': 'string',
				'description': nls.localize('keybindings.json.key', "Key or key sequence (separated by space)"),
			},
			'command': {
				'description': nls.localize('keybindings.json.command', "Name of the command to execute"),
			},
			'when': {
				'type': 'string',
				'description': nls.localize('keybindings.json.when', "Condition when the key is active.")
			},
			'args': {
				'description': nls.localize('keybindings.json.args', "Arguments to pass to the command to execute.")
			}
		}
	}
};

let schemaRegistry = Registry.as<IJSONContributionRegistry>(Extensions.JSONContribution);
schemaRegistry.registerSchema(schemaId, schema);

const configurationRegistry = Registry.as<IConfigurationRegistry>(ConfigExtensions.Configuration);
const keyboardConfiguration: IConfigurationNode = {
	'id': 'keyboard',
	'order': 15,
	'type': 'object',
	'title': nls.localize('keyboardConfigurationTitle', "Keyboard"),
	'overridable': true,
	'properties': {
		'keyboard.dispatch': {
			'type': 'string',
			'enum': ['code', 'keyCode'],
			'default': 'code',
			'markdownDescription': nls.localize('dispatch', "Controls the dispatching logic for key presses to use either `code` (recommended) or `keyCode`."),
			'included': OS === OperatingSystem.Macintosh || OS === OperatingSystem.Linux
		},
		'keyboard.touchbar.enabled': {
			'type': 'boolean',
			'default': true,
			'description': nls.localize('touchbar.enabled', "Enables the macOS touchbar buttons on the keyboard if available."),
			'included': OS === OperatingSystem.Macintosh && parseFloat(release()) >= 16 // Minimum: macOS Sierra (10.12.x = darwin 16.x)
		}
	}
};

configurationRegistry.registerConfiguration(keyboardConfiguration);
