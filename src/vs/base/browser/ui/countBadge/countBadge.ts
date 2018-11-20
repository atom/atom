/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!./countBadge';
import { $, append } from 'vs/base/browser/dom';
import { format } from 'vs/base/common/strings';
import { Color } from 'vs/base/common/color';
import { mixin } from 'vs/base/common/objects';

export interface ICountBadgeOptions extends ICountBadgetyles {
	count?: number;
	countFormat?: string;
	titleFormat?: string;
}

export interface ICountBadgetyles {
	badgeBackground?: Color;
	badgeForeground?: Color;
	badgeBorder?: Color;
}

const defaultOpts = {
	badgeBackground: Color.fromHex('#4D4D4D'),
	badgeForeground: Color.fromHex('#FFFFFF')
};

export class CountBadge {

	private element: HTMLElement;
	private count: number;
	private countFormat: string;
	private titleFormat: string;

	private badgeBackground: Color | undefined;
	private badgeForeground: Color | undefined;
	private badgeBorder: Color | undefined;

	private options: ICountBadgeOptions;

	constructor(container: HTMLElement, options?: ICountBadgeOptions) {
		this.options = options || Object.create(null);
		mixin(this.options, defaultOpts, false);

		this.badgeBackground = this.options.badgeBackground;
		this.badgeForeground = this.options.badgeForeground;
		this.badgeBorder = this.options.badgeBorder;

		this.element = append(container, $('.monaco-count-badge'));
		this.countFormat = this.options.countFormat || '{0}';
		this.titleFormat = this.options.titleFormat || '';
		this.setCount(this.options.count || 0);
	}

	setCount(count: number) {
		this.count = count;
		this.render();
	}

	setCountFormat(countFormat: string) {
		this.countFormat = countFormat;
		this.render();
	}

	setTitleFormat(titleFormat: string) {
		this.titleFormat = titleFormat;
		this.render();
	}

	private render() {
		this.element.textContent = format(this.countFormat, this.count);
		this.element.title = format(this.titleFormat, this.count);

		this.applyStyles();
	}

	style(styles: ICountBadgetyles): void {
		this.badgeBackground = styles.badgeBackground;
		this.badgeForeground = styles.badgeForeground;
		this.badgeBorder = styles.badgeBorder;

		this.applyStyles();
	}

	private applyStyles(): void {
		if (this.element) {
			const background = this.badgeBackground ? this.badgeBackground.toString() : null;
			const foreground = this.badgeForeground ? this.badgeForeground.toString() : null;
			const border = this.badgeBorder ? this.badgeBorder.toString() : null;

			this.element.style.backgroundColor = background;
			this.element.style.color = foreground;

			this.element.style.borderWidth = border ? '1px' : null;
			this.element.style.borderStyle = border ? 'solid' : null;
			this.element.style.borderColor = border;
		}
	}
}
