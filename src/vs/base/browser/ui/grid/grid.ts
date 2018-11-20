/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!./gridview';
import { Orientation } from 'vs/base/browser/ui/sash/sash';
import { IDisposable, dispose } from 'vs/base/common/lifecycle';
import { tail2 as tail, equals } from 'vs/base/common/arrays';
import { orthogonal, IView, GridView, Sizing as GridViewSizing, Box, IGridViewStyles } from './gridview';
import { Event } from 'vs/base/common/event';

export { Orientation } from './gridview';

export const enum Direction {
	Up,
	Down,
	Left,
	Right
}

function oppositeDirection(direction: Direction): Direction {
	switch (direction) {
		case Direction.Up: return Direction.Down;
		case Direction.Down: return Direction.Up;
		case Direction.Left: return Direction.Right;
		case Direction.Right: return Direction.Left;
	}
}

export interface GridLeafNode<T extends IView> {
	readonly view: T;
	readonly box: Box;
}

export interface GridBranchNode<T extends IView> {
	readonly children: GridNode<T>[];
	readonly box: Box;
}

export type GridNode<T extends IView> = GridLeafNode<T> | GridBranchNode<T>;

export function isGridBranchNode<T extends IView>(node: GridNode<T>): node is GridBranchNode<T> {
	return !!(node as any).children;
}

function getGridNode<T extends IView>(node: GridNode<T>, location: number[]): GridNode<T> {
	if (location.length === 0) {
		return node;
	}

	if (!isGridBranchNode(node)) {
		throw new Error('Invalid location');
	}

	const [index, ...rest] = location;
	return getGridNode(node.children[index], rest);
}

interface Range {
	readonly start: number;
	readonly end: number;
}

function intersects(one: Range, other: Range): boolean {
	return !(one.start >= other.end || other.start >= one.end);
}

interface Boundary {
	readonly offset: number;
	readonly range: Range;
}

function getBoxBoundary(box: Box, direction: Direction): Boundary {
	const orientation = getDirectionOrientation(direction);
	const offset = direction === Direction.Up ? box.top :
		direction === Direction.Right ? box.left + box.width :
			direction === Direction.Down ? box.top + box.height :
				box.left;

	const range = {
		start: orientation === Orientation.HORIZONTAL ? box.top : box.left,
		end: orientation === Orientation.HORIZONTAL ? box.top + box.height : box.left + box.width
	};

	return { offset, range };
}

function findAdjacentBoxLeafNodes<T extends IView>(boxNode: GridNode<T>, direction: Direction, boundary: Boundary): GridLeafNode<T>[] {
	const result: GridLeafNode<T>[] = [];

	function _(boxNode: GridNode<T>, direction: Direction, boundary: Boundary): void {
		if (isGridBranchNode(boxNode)) {
			for (const child of boxNode.children) {
				_(child, direction, boundary);
			}
		} else {
			const { offset, range } = getBoxBoundary(boxNode.box, direction);

			if (offset === boundary.offset && intersects(range, boundary.range)) {
				result.push(boxNode);
			}
		}
	}

	_(boxNode, direction, boundary);
	return result;
}

function getLocationOrientation(rootOrientation: Orientation, location: number[]): Orientation {
	return location.length % 2 === 0 ? orthogonal(rootOrientation) : rootOrientation;
}

function getDirectionOrientation(direction: Direction): Orientation {
	return direction === Direction.Up || direction === Direction.Down ? Orientation.VERTICAL : Orientation.HORIZONTAL;
}

function getSize(dimensions: { width: number; height: number; }, orientation: Orientation) {
	return orientation === Orientation.HORIZONTAL ? dimensions.width : dimensions.height;
}

export function getRelativeLocation(rootOrientation: Orientation, location: number[], direction: Direction): number[] {
	const orientation = getLocationOrientation(rootOrientation, location);
	const directionOrientation = getDirectionOrientation(direction);

	if (orientation === directionOrientation) {
		let [rest, index] = tail(location);

		if (direction === Direction.Right || direction === Direction.Down) {
			index += 1;
		}

		return [...rest, index];
	} else {
		const index = (direction === Direction.Right || direction === Direction.Down) ? 1 : 0;
		return [...location, index];
	}
}

function indexInParent(element: HTMLElement): number {
	const parentElement = element.parentElement;

	if (!parentElement) {
		throw new Error('Invalid grid element');
	}

	let el = parentElement.firstElementChild;
	let index = 0;

	while (el !== element && el !== parentElement.lastElementChild && el) {
		el = el.nextElementSibling;
		index++;
	}

	return index;
}

/**
 * Find the grid location of a specific DOM element by traversing the parent
 * chain and finding each child index on the way.
 *
 * This will break as soon as DOM structures of the Splitview or Gridview change.
 */
function getGridLocation(element: HTMLElement): number[] {
	const parentElement = element.parentElement;

	if (!parentElement) {
		throw new Error('Invalid grid element');
	}

	if (/\bmonaco-grid-view\b/.test(parentElement.className)) {
		return [];
	}

	const index = indexInParent(parentElement);
	const ancestor = parentElement.parentElement!.parentElement!.parentElement!;
	return [...getGridLocation(ancestor), index];
}

export const enum Sizing {
	Distribute = 'distribute',
	Split = 'split'
}

export interface IGridStyles extends IGridViewStyles { }

export interface IGridOptions {
	styles?: IGridStyles;
}

export class Grid<T extends IView> implements IDisposable {

	protected gridview: GridView;
	private views = new Map<T, HTMLElement>();
	private disposables: IDisposable[] = [];

	get orientation(): Orientation { return this.gridview.orientation; }
	set orientation(orientation: Orientation) { this.gridview.orientation = orientation; }

	get width(): number { return this.gridview.width; }
	get height(): number { return this.gridview.height; }

	get minimumWidth(): number { return this.gridview.minimumWidth; }
	get minimumHeight(): number { return this.gridview.minimumHeight; }
	get maximumWidth(): number { return this.gridview.maximumWidth; }
	get maximumHeight(): number { return this.gridview.maximumHeight; }
	get onDidChange(): Event<{ width: number; height: number; } | undefined> { return this.gridview.onDidChange; }

	get element(): HTMLElement { return this.gridview.element; }

	sashResetSizing: Sizing = Sizing.Distribute;

	constructor(view: T, options: IGridOptions = {}) {
		this.gridview = new GridView(options);
		this.disposables.push(this.gridview);

		this.gridview.onDidSashReset(this.doResetViewSize, this, this.disposables);

		this._addView(view, 0, [0]);
	}

	style(styles: IGridStyles): void {
		this.gridview.style(styles);
	}

	layout(width: number, height: number): void {
		this.gridview.layout(width, height);
	}

	addView(newView: T, size: number | Sizing, referenceView: T, direction: Direction): void {
		if (this.views.has(newView)) {
			throw new Error('Can\'t add same view twice');
		}

		const orientation = getDirectionOrientation(direction);

		if (this.views.size === 1 && this.orientation !== orientation) {
			this.orientation = orientation;
		}

		const referenceLocation = this.getViewLocation(referenceView);
		const location = getRelativeLocation(this.gridview.orientation, referenceLocation, direction);

		let viewSize: number | GridViewSizing;

		if (size === Sizing.Split) {
			const [, index] = tail(referenceLocation);
			viewSize = GridViewSizing.Split(index);
		} else if (size === Sizing.Distribute) {
			viewSize = GridViewSizing.Distribute;
		} else {
			viewSize = size;
		}

		this._addView(newView, viewSize, location);
	}

	protected _addView(newView: T, size: number | GridViewSizing, location): void {
		this.views.set(newView, newView.element);
		this.gridview.addView(newView, size, location);
	}

	removeView(view: T, sizing?: Sizing): void {
		if (this.views.size === 1) {
			throw new Error('Can\'t remove last view');
		}

		const location = this.getViewLocation(view);
		this.gridview.removeView(location, sizing === Sizing.Distribute ? GridViewSizing.Distribute : undefined);
		this.views.delete(view);
	}

	moveView(view: T, sizing: number | Sizing, referenceView: T, direction: Direction): void {
		const sourceLocation = this.getViewLocation(view);
		const [sourceParentLocation, from] = tail(sourceLocation);

		const referenceLocation = this.getViewLocation(referenceView);
		const targetLocation = getRelativeLocation(this.gridview.orientation, referenceLocation, direction);
		const [targetParentLocation, to] = tail(targetLocation);

		if (equals(sourceParentLocation, targetParentLocation)) {
			this.gridview.moveView(sourceParentLocation, from, to);
		} else {
			this.removeView(view, typeof sizing === 'number' ? undefined : sizing);
			this.addView(view, sizing, referenceView, direction);
		}
	}

	swapViews(from: T, to: T): void {
		const fromLocation = this.getViewLocation(from);
		const toLocation = this.getViewLocation(to);
		return this.gridview.swapViews(fromLocation, toLocation);
	}

	resizeView(view: T, size: number): void {
		const location = this.getViewLocation(view);
		return this.gridview.resizeView(location, size);
	}

	getViewSize(view: T): number {
		const location = this.getViewLocation(view);
		const viewSize = this.gridview.getViewSize(location);
		return getLocationOrientation(this.orientation, location) === Orientation.HORIZONTAL ? viewSize.width : viewSize.height;
	}

	// TODO@joao cleanup
	getViewSize2(view: T): { width: number; height: number; } {
		const location = this.getViewLocation(view);
		return this.gridview.getViewSize(location);
	}

	maximizeViewSize(view: T): void {
		const location = this.getViewLocation(view);
		this.gridview.maximizeViewSize(location);
	}

	distributeViewSizes(): void {
		this.gridview.distributeViewSizes();
	}

	getViews(): GridBranchNode<T> {
		return this.gridview.getViews() as GridBranchNode<T>;
	}

	getNeighborViews(view: T, direction: Direction, wrap: boolean = false): T[] {
		const location = this.getViewLocation(view);
		const root = this.getViews();
		const node = getGridNode(root, location);
		let boundary = getBoxBoundary(node.box, direction);

		if (wrap) {
			if (direction === Direction.Up && node.box.top === 0) {
				boundary = { offset: root.box.top + root.box.height, range: boundary.range };
			} else if (direction === Direction.Right && node.box.left + node.box.width === root.box.width) {
				boundary = { offset: 0, range: boundary.range };
			} else if (direction === Direction.Down && node.box.top + node.box.height === root.box.height) {
				boundary = { offset: 0, range: boundary.range };
			} else if (direction === Direction.Left && node.box.left === 0) {
				boundary = { offset: root.box.left + root.box.width, range: boundary.range };
			}
		}

		return findAdjacentBoxLeafNodes(root, oppositeDirection(direction), boundary)
			.map(node => node.view);
	}

	private getViewLocation(view: T): number[] {
		const element = this.views.get(view);

		if (!element) {
			throw new Error('View not found');
		}

		return getGridLocation(element);
	}

	private doResetViewSize(location: number[]): void {
		if (this.sashResetSizing === Sizing.Split) {
			const orientation = getLocationOrientation(this.orientation, location);
			const firstViewSize = getSize(this.gridview.getViewSize(location), orientation);
			const [parentLocation, index] = tail(location);
			const secondViewSize = getSize(this.gridview.getViewSize([...parentLocation, index + 1]), orientation);
			const totalSize = firstViewSize + secondViewSize;
			this.gridview.resizeView(location, Math.floor(totalSize / 2));

		} else {
			const [parentLocation,] = tail(location);
			this.gridview.distributeViewSizes(parentLocation);
		}
	}

	dispose(): void {
		this.disposables = dispose(this.disposables);
	}
}

export interface ISerializableView extends IView {
	toJSON(): object;
}

export interface IViewDeserializer<T extends ISerializableView> {
	fromJSON(json: object | null): T;
}

interface InitialLayoutContext<T extends ISerializableView> {
	width: number;
	height: number;
	root: GridBranchNode<T>;
}

export interface ISerializedLeafNode {
	type: 'leaf';
	data: object | null;
	size: number;
}

export interface ISerializedBranchNode {
	type: 'branch';
	data: ISerializedNode[];
	size: number;
}

export type ISerializedNode = ISerializedLeafNode | ISerializedBranchNode;

export interface ISerializedGrid {
	root: ISerializedNode;
	orientation: Orientation;
	width: number;
	height: number;
}

export class SerializableGrid<T extends ISerializableView> extends Grid<T> {

	private static serializeNode<T extends ISerializableView>(node: GridNode<T>, orientation: Orientation): ISerializedNode {
		const size = orientation === Orientation.VERTICAL ? node.box.width : node.box.height;

		if (!isGridBranchNode(node)) {
			return { type: 'leaf', data: node.view.toJSON(), size };
		}

		return { type: 'branch', data: node.children.map(c => SerializableGrid.serializeNode(c, orthogonal(orientation))), size };
	}

	private static deserializeNode<T extends ISerializableView>(json: ISerializedNode, orientation: Orientation, box: Box, deserializer: IViewDeserializer<T>): GridNode<T> {
		if (!json || typeof json !== 'object') {
			throw new Error('Invalid JSON');
		}

		if (json.type === 'branch') {
			if (!Array.isArray(json.data)) {
				throw new Error('Invalid JSON: \'data\' property of branch must be an array.');
			}

			const children: GridNode<T>[] = [];
			let offset = 0;

			for (const child of json.data) {
				if (typeof child.size !== 'number') {
					throw new Error('Invalid JSON: \'size\' property of node must be a number.');
				}

				const childBox: Box = orientation === Orientation.HORIZONTAL
					? { top: box.top, left: box.left + offset, width: child.size, height: box.height }
					: { top: box.top + offset, left: box.left, width: box.width, height: child.size };

				children.push(SerializableGrid.deserializeNode(child, orthogonal(orientation), childBox, deserializer));
				offset += child.size;
			}

			return { children, box };

		} else if (json.type === 'leaf') {
			const view = deserializer.fromJSON(json.data) as T;
			return { view, box };
		}

		throw new Error('Invalid JSON: \'type\' property must be either \'branch\' or \'leaf\'.');
	}

	private static getFirstLeaf<T extends IView>(node: GridNode<T>): GridLeafNode<T> | undefined {
		if (!isGridBranchNode(node)) {
			return node;
		}

		return SerializableGrid.getFirstLeaf(node.children[0]);
	}

	static deserialize<T extends ISerializableView>(json: ISerializedGrid, deserializer: IViewDeserializer<T>, options: IGridOptions = {}): SerializableGrid<T> {
		if (typeof json.orientation !== 'number') {
			throw new Error('Invalid JSON: \'orientation\' property must be a number.');
		} else if (typeof json.width !== 'number') {
			throw new Error('Invalid JSON: \'width\' property must be a number.');
		} else if (typeof json.height !== 'number') {
			throw new Error('Invalid JSON: \'height\' property must be a number.');
		}

		const orientation = json.orientation as Orientation;
		const width = json.width as number;
		const height = json.height as number;
		const box: Box = { top: 0, left: 0, width, height };

		const root = SerializableGrid.deserializeNode(json.root, orientation, box, deserializer) as GridBranchNode<T>;
		const firstLeaf = SerializableGrid.getFirstLeaf(root);

		if (!firstLeaf) {
			throw new Error('Invalid serialized state, first leaf not found');
		}

		const result = new SerializableGrid<T>(firstLeaf.view, options);
		result.orientation = orientation;
		result.restoreViews(firstLeaf.view, orientation, root);
		result.initialLayoutContext = { width, height, root };

		return result;
	}

	/**
	 * Useful information in order to proportionally restore view sizes
	 * upon the very first layout call.
	 */
	private initialLayoutContext: InitialLayoutContext<T> | undefined;

	serialize(): ISerializedGrid {
		return {
			root: SerializableGrid.serializeNode(this.getViews(), this.orientation),
			orientation: this.orientation,
			width: this.width,
			height: this.height
		};
	}

	layout(width: number, height: number): void {
		super.layout(width, height);

		if (this.initialLayoutContext) {
			const widthScale = width / this.initialLayoutContext.width;
			const heightScale = height / this.initialLayoutContext.height;

			this.restoreViewsSize([], this.initialLayoutContext.root, this.orientation, widthScale, heightScale);
			this.initialLayoutContext = undefined;

			this.gridview.trySet2x2();
		}
	}

	/**
	 * Recursively restores views which were just deserialized.
	 */
	private restoreViews(referenceView: T, orientation: Orientation, node: GridNode<T>): void {
		if (!isGridBranchNode(node)) {
			return;
		}

		const direction = orientation === Orientation.VERTICAL ? Direction.Down : Direction.Right;
		const firstLeaves = node.children.map(c => SerializableGrid.getFirstLeaf(c));

		for (let i = 1; i < firstLeaves.length; i++) {
			const size = orientation === Orientation.VERTICAL ? firstLeaves[i]!.box.height : firstLeaves[i]!.box.width;
			this.addView(firstLeaves[i]!.view, size, referenceView, direction);
			referenceView = firstLeaves[i]!.view;
		}

		for (let i = 0; i < node.children.length; i++) {
			this.restoreViews(firstLeaves[i]!.view, orthogonal(orientation), node.children[i]);
		}
	}

	/**
	 * Recursively restores view sizes.
	 * This should be called only after the very first layout call.
	 */
	private restoreViewsSize(location: number[], node: GridNode<T>, orientation: Orientation, widthScale: number, heightScale: number): void {
		if (!isGridBranchNode(node)) {
			return;
		}

		const scale = orientation === Orientation.VERTICAL ? heightScale : widthScale;

		for (let i = 0; i < node.children.length; i++) {
			const child = node.children[i];
			const childLocation = [...location, i];

			if (i < node.children.length - 1) {
				const size = orientation === Orientation.VERTICAL ? child.box.height : child.box.width;
				this.gridview.resizeView(childLocation, Math.floor(size * scale));
			}

			this.restoreViewsSize(childLocation, child, orthogonal(orientation), widthScale, heightScale);
		}
	}
}

export type GridNodeDescriptor = { size?: number, groups?: GridNodeDescriptor[] };
export type GridDescriptor = { orientation: Orientation, groups?: GridNodeDescriptor[] };

export function sanitizeGridNodeDescriptor(nodeDescriptor: GridNodeDescriptor): void {
	if (nodeDescriptor.groups && nodeDescriptor.groups.length === 0) {
		nodeDescriptor.groups = undefined;
	}

	if (!nodeDescriptor.groups) {
		return;
	}

	let totalDefinedSize = 0;
	let totalDefinedSizeCount = 0;

	for (const child of nodeDescriptor.groups) {
		sanitizeGridNodeDescriptor(child);

		if (child.size) {
			totalDefinedSize += child.size;
			totalDefinedSizeCount++;
		}
	}

	const totalUndefinedSize = totalDefinedSizeCount > 0 ? totalDefinedSize : 1;
	const totalUndefinedSizeCount = nodeDescriptor.groups.length - totalDefinedSizeCount;
	const eachUndefinedSize = totalUndefinedSize / totalUndefinedSizeCount;

	for (const child of nodeDescriptor.groups) {
		if (!child.size) {
			child.size = eachUndefinedSize;
		}
	}
}

function createSerializedNode(nodeDescriptor: GridNodeDescriptor): ISerializedNode {
	if (nodeDescriptor.groups) {
		return { type: 'branch', data: nodeDescriptor.groups.map(c => createSerializedNode(c)), size: nodeDescriptor.size! };
	} else {
		return { type: 'leaf', data: null, size: nodeDescriptor.size! };
	}
}

function getDimensions(node: ISerializedNode, orientation: Orientation): { width?: number, height?: number } {
	if (node.type === 'branch') {
		const childrenDimensions = node.data.map(c => getDimensions(c, orthogonal(orientation)));

		if (orientation === Orientation.VERTICAL) {
			const width = node.size || (childrenDimensions.length === 0 ? undefined : Math.max(...childrenDimensions.map(d => d.width || 0)));
			const height = childrenDimensions.length === 0 ? undefined : childrenDimensions.reduce((r, d) => r + (d.height || 0), 0);
			return { width, height };
		} else {
			const width = childrenDimensions.length === 0 ? undefined : childrenDimensions.reduce((r, d) => r + (d.width || 0), 0);
			const height = node.size || (childrenDimensions.length === 0 ? undefined : Math.max(...childrenDimensions.map(d => d.height || 0)));
			return { width, height };
		}
	} else {
		const width = orientation === Orientation.VERTICAL ? node.size : undefined;
		const height = orientation === Orientation.VERTICAL ? undefined : node.size;
		return { width, height };
	}
}

export function createSerializedGrid(gridDescriptor: GridDescriptor): ISerializedGrid {
	sanitizeGridNodeDescriptor(gridDescriptor);

	const root = createSerializedNode(gridDescriptor);
	const { width, height } = getDimensions(root, gridDescriptor.orientation);

	return {
		root,
		orientation: gridDescriptor.orientation,
		width: width || 1,
		height: height || 1
	};
}
