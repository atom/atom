/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import { TerminalConfigHelper } from 'vs/workbench/parts/terminal/electron-browser/terminalConfigHelper';
import { EDITOR_FONT_DEFAULTS } from 'vs/editor/common/config/editorOptions';
import { isFedora, isUbuntu } from 'vs/workbench/parts/terminal/node/terminal';
import { TestConfigurationService } from 'vs/platform/configuration/test/common/testConfigurationService';

suite('Workbench - TerminalConfigHelper', () => {
	let fixture: HTMLElement;

	setup(() => {
		fixture = document.body;
	});

	test('TerminalConfigHelper - getFont fontFamily', function () {
		const configurationService = new TestConfigurationService();
		configurationService.setUserConfiguration('editor', { fontFamily: 'foo' });
		configurationService.setUserConfiguration('terminal', { integrated: { fontFamily: 'bar' } });

		let configHelper = new TerminalConfigHelper(configurationService, null, null, null);
		configHelper.panelContainer = fixture;
		assert.equal(configHelper.getFont().fontFamily, 'bar', 'terminal.integrated.fontFamily should be selected over editor.fontFamily');

		configurationService.setUserConfiguration('terminal', { integrated: { fontFamily: null } });

		// Recreate config helper as onDidChangeConfiguration isn't implemented in TestConfigurationService
		configHelper = new TerminalConfigHelper(configurationService, null, null, null);
		configHelper.panelContainer = fixture;
		if (isFedora) {
			assert.equal(configHelper.getFont().fontFamily, '\'DejaVu Sans Mono\', monospace', 'Fedora should have its font overridden when terminal.integrated.fontFamily not set');
		} else if (isUbuntu) {
			assert.equal(configHelper.getFont().fontFamily, '\'Ubuntu Mono\', monospace', 'Ubuntu should have its font overridden when terminal.integrated.fontFamily not set');
		} else {
			assert.equal(configHelper.getFont().fontFamily, 'foo', 'editor.fontFamily should be the fallback when terminal.integrated.fontFamily not set');
		}
	});

	test('TerminalConfigHelper - getFont fontSize', function () {
		const configurationService = new TestConfigurationService();

		configurationService.setUserConfiguration('editor', {
			fontFamily: 'foo',
			fontSize: 9
		});
		configurationService.setUserConfiguration('terminal', {
			integrated: {
				fontFamily: 'bar',
				fontSize: 10
			}
		});
		let configHelper = new TerminalConfigHelper(configurationService, null, null, null);
		configHelper.panelContainer = fixture;
		assert.equal(configHelper.getFont().fontSize, 10, 'terminal.integrated.fontSize should be selected over editor.fontSize');

		configurationService.setUserConfiguration('editor', {
			fontFamily: 'foo'
		});
		configurationService.setUserConfiguration('terminal', {
			integrated: {
				fontFamily: null,
				fontSize: 0
			}
		});
		configHelper = new TerminalConfigHelper(configurationService, null, null, null);
		configHelper.panelContainer = fixture;
		if (isUbuntu) {
			assert.equal(configHelper.getFont().fontSize, 8, 'The minimum terminal font size (with adjustment) should be used when terminal.integrated.fontSize less than it');
		} else {
			assert.equal(configHelper.getFont().fontSize, 6, 'The minimum terminal font size should be used when terminal.integrated.fontSize less than it');
		}
		configurationService.setUserConfiguration('editor', {
			fontFamily: 'foo'
		});
		configurationService.setUserConfiguration('terminal', {
			integrated: {
				fontFamily: 0,
				fontSize: 1500
			}
		});
		configHelper = new TerminalConfigHelper(configurationService, null, null, null);
		configHelper.panelContainer = fixture;
		assert.equal(configHelper.getFont().fontSize, 25, 'The maximum terminal font size should be used when terminal.integrated.fontSize more than it');

		configurationService.setUserConfiguration('editor', {
			fontFamily: 'foo'
		});
		configurationService.setUserConfiguration('terminal', {
			integrated: {
				fontFamily: 0,
				fontSize: null
			}
		});
		configHelper = new TerminalConfigHelper(configurationService, null, null, null);
		configHelper.panelContainer = fixture;
		if (isUbuntu) {
			assert.equal(configHelper.getFont().fontSize, EDITOR_FONT_DEFAULTS.fontSize + 2, 'The default editor font size (with adjustment) should be used when terminal.integrated.fontSize is not set');
		} else {
			assert.equal(configHelper.getFont().fontSize, EDITOR_FONT_DEFAULTS.fontSize, 'The default editor font size should be used when terminal.integrated.fontSize is not set');
		}
	});

	test('TerminalConfigHelper - getFont lineHeight', function () {
		const configurationService = new TestConfigurationService();

		configurationService.setUserConfiguration('editor', {
			fontFamily: 'foo',
			lineHeight: 1
		});
		configurationService.setUserConfiguration('terminal', {
			integrated: {
				fontFamily: 0,
				lineHeight: 2
			}
		});
		let configHelper = new TerminalConfigHelper(configurationService, null, null, null);
		configHelper.panelContainer = fixture;
		assert.equal(configHelper.getFont().lineHeight, 2, 'terminal.integrated.lineHeight should be selected over editor.lineHeight');

		configurationService.setUserConfiguration('editor', {
			fontFamily: 'foo',
			lineHeight: 1
		});
		configurationService.setUserConfiguration('terminal', {
			integrated: {
				fontFamily: 0,
				lineHeight: 0
			}
		});
		configHelper = new TerminalConfigHelper(configurationService, null, null, null);
		configHelper.panelContainer = fixture;
		assert.equal(configHelper.getFont().lineHeight, 1, 'editor.lineHeight should be 1 when terminal.integrated.lineHeight not set');
	});

	test('TerminalConfigHelper - isMonospace monospace', function () {
		const configurationService = new TestConfigurationService();
		configurationService.setUserConfiguration('terminal', {
			integrated: {
				fontFamily: 'monospace'
			}
		});

		let configHelper = new TerminalConfigHelper(configurationService, null, null, null);
		configHelper.panelContainer = fixture;
		assert.equal(configHelper.configFontIsMonospace(), true, 'monospace is monospaced');
	});

	test('TerminalConfigHelper - isMonospace sans-serif', function () {
		const configurationService = new TestConfigurationService();
		configurationService.setUserConfiguration('terminal', {
			integrated: {
				fontFamily: 'sans-serif'
			}
		});
		let configHelper = new TerminalConfigHelper(configurationService, null, null, null);
		configHelper.panelContainer = fixture;
		assert.equal(configHelper.configFontIsMonospace(), false, 'sans-serif is not monospaced');
	});

	test('TerminalConfigHelper - isMonospace serif', function () {
		const configurationService = new TestConfigurationService();
		configurationService.setUserConfiguration('terminal', {
			integrated: {
				fontFamily: 'serif'
			}
		});
		let configHelper = new TerminalConfigHelper(configurationService, null, null, null);
		configHelper.panelContainer = fixture;
		assert.equal(configHelper.configFontIsMonospace(), false, 'serif is not monospaced');
	});

	test('TerminalConfigHelper - isMonospace monospace falls back to editor.fontFamily', function () {
		const configurationService = new TestConfigurationService();
		configurationService.setUserConfiguration('editor', {
			fontFamily: 'monospace'
		});
		configurationService.setUserConfiguration('terminal', {
			integrated: {
				fontFamily: null
			}
		});

		let configHelper = new TerminalConfigHelper(configurationService, null, null, null);
		configHelper.panelContainer = fixture;
		assert.equal(configHelper.configFontIsMonospace(), true, 'monospace is monospaced');
	});

	test('TerminalConfigHelper - isMonospace sans-serif falls back to editor.fontFamily', function () {
		const configurationService = new TestConfigurationService();
		configurationService.setUserConfiguration('editor', {
			fontFamily: 'sans-serif'
		});
		configurationService.setUserConfiguration('terminal', {
			integrated: {
				fontFamily: null
			}
		});

		let configHelper = new TerminalConfigHelper(configurationService, null, null, null);
		configHelper.panelContainer = fixture;
		assert.equal(configHelper.configFontIsMonospace(), false, 'sans-serif is not monospaced');
	});

	test('TerminalConfigHelper - isMonospace serif falls back to editor.fontFamily', function () {
		const configurationService = new TestConfigurationService();
		configurationService.setUserConfiguration('editor', {
			fontFamily: 'serif'
		});
		configurationService.setUserConfiguration('terminal', {
			integrated: {
				fontFamily: null
			}
		});

		let configHelper = new TerminalConfigHelper(configurationService, null, null, null);
		configHelper.panelContainer = fixture;
		assert.equal(configHelper.configFontIsMonospace(), false, 'serif is not monospaced');
	});
});