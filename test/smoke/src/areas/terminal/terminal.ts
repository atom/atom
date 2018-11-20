/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { Code } from '../../vscode/code';
import { QuickOpen } from '../quickopen/quickopen';

const PANEL_SELECTOR = 'div[id="workbench.panel.terminal"]';
const XTERM_SELECTOR = `${PANEL_SELECTOR} .terminal-wrapper`;
const XTERM_TEXTAREA = `${XTERM_SELECTOR} textarea.xterm-helper-textarea`;

export class Terminal {

	constructor(private code: Code, private quickopen: QuickOpen) { }

	async showTerminal(): Promise<void> {
		await this.quickopen.runCommand('View: Toggle Integrated Terminal');
		await this.code.waitForActiveElement(XTERM_TEXTAREA);
		await this.code.waitForTerminalBuffer(XTERM_SELECTOR, lines => lines.some(line => line.length > 0));
	}

	async runCommand(commandText: string): Promise<void> {
		await this.code.writeInTerminal(XTERM_SELECTOR, commandText);
		// hold your horses
		await new Promise(c => setTimeout(c, 500));
		await this.code.dispatchKeybinding('enter');
	}

	async waitForTerminalText(accept: (buffer: string[]) => boolean): Promise<void> {
		await this.code.waitForTerminalBuffer(XTERM_SELECTOR, accept);
	}
}