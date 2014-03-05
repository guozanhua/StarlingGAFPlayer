/*
 Feathers
 Copyright 2012-2014 Joshua Tynjala. All Rights Reserved.

 This program is free software. You can redistribute and/or modify it in
 accordance with the terms of the accompanying license agreement.
 */
package com.catalystapps.gaf.data
{
	import com.catalystapps.gaf.display.GAFScale9Texture;

	import feathers.core.IValidating;
	import feathers.core.ValidationQueue;
	import feathers.utils.display.getDisplayObjectDepthFromStage;

	import flash.errors.IllegalOperationError;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;

	import starling.core.Starling;
	import starling.display.DisplayObject;
	import starling.display.Image;
	import starling.display.QuadBatch;
	import starling.display.Sprite;
	import starling.events.Event;
	import starling.textures.TextureSmoothing;
	import starling.utils.MatrixUtil;

	public class GAFScale9Image extends Sprite implements IValidating
	{
		//--------------------------------------------------------------------------
		//
		//  PUBLIC VARIABLES
		//
		//--------------------------------------------------------------------------

		//--------------------------------------------------------------------------
		//
		//  PRIVATE VARIABLES
		//
		//--------------------------------------------------------------------------

		/**
		 * @private
		 */
		private static const HELPER_MATRIX: Matrix = new Matrix();

		/**
		 * @private
		 */
		private static const HELPER_POINT: Point = new Point();

		/**
		 * @private
		 */
		private static var helperImage: Image;

		/**
		 * @private
		 */
		private var _propertiesChanged: Boolean = true;

		/**
		 * @private
		 */
		private var _layoutChanged: Boolean = true;

		/**
		 * @private
		 */
		private var _renderingChanged: Boolean = true;

		/**
		 * @private
		 */
		private var _frame: Rectangle;

		/**
		 * @private
		 */
		private var _textures: GAFScale9Texture;

		/**
		 * @private
		 */
		private var _width: Number = NaN;

		/**
		 * @private
		 */
		private var _height: Number = NaN;

		/**
		 * @private
		 */
		private var _textureScale: Number = 1;

		/**
		 * @private
		 */
		private var _smoothing: String = TextureSmoothing.BILINEAR;

		/**
		 * @private
		 */
		private var _color: uint = 0xffffff;

		/**
		 * @private
		 */
		private var _useSeparateBatch: Boolean = true;

		/**
		 * @private
		 */
		private var _hitArea: Rectangle;

		/**
		 * @private
		 */
		private var _batch: QuadBatch;

		/**
		 * @private
		 */
		private var _isValidating: Boolean = false;

		/**
		 * @private
		 */
		private var _isInvalid: Boolean = false;

		/**
		 * @private
		 */
		private var _validationQueue: ValidationQueue;

		/**
		 * @private
		 */
		private var _depth: int = -1;

		//--------------------------------------------------------------------------
		//
		//  CONSTRUCTOR
		//
		//--------------------------------------------------------------------------

		/**
		 * Scales an image with nine regions to maintain the aspect ratio of the
		 * corners regions. The top and bottom regions stretch horizontally, and the
		 * left and right regions scale vertically. The center region stretches in
		 * both directions to fill the remaining space.
		 */
		public function GAFScale9Image(textures: GAFScale9Texture)
		{
			super();

			this.textures = textures;
			this._textureScale = 1;
			this._hitArea = new Rectangle();
			this.readjustSize();

			this._batch = new QuadBatch();
			this._batch.touchable = false;
			this.addChild(this._batch);

			this.addEventListener(Event.FLATTEN, flattenHandler);
			this.addEventListener(Event.ADDED_TO_STAGE, addedToStageHandler);
		}

		//--------------------------------------------------------------------------
		//
		//  PUBLIC METHODS
		//
		//--------------------------------------------------------------------------

		/**
		 * @copy feathers.core.IValidating#validate()
		 */
		public function validate(): void
		{
			if (!this._validationQueue || !this.stage || !this._isInvalid)
			{
				return;
			}
			if (this._isValidating)
			{
				//we were already validating, and something else told us to
				//validate. that's bad.
				this._validationQueue.addControl(this, true);
				return;
			}
			this._isValidating = true;
			if (this._propertiesChanged || this._layoutChanged || this._renderingChanged)
			{
				this._batch.batchable = !this._useSeparateBatch;
				this._batch.reset();

				if (!helperImage)
				{
					//because Scale9Textures enforces it, we know for sure that
					//this texture will have a size greater than zero, so there
					//won't be an error from Quad.
					helperImage = new Image(this._textures.middleCenter);
				}
				helperImage.smoothing = this._smoothing;
				helperImage.color = this._color;

				const grid: Rectangle = this._textures.scale9Grid;
				var scaledLeftWidth: Number = grid.x * this._textureScale;
				var scaledTopHeight: Number = grid.y * this._textureScale;
				var scaledRightWidth: Number = (this._frame.width - grid.x - grid.width) * this._textureScale;
				var scaledBottomHeight: Number = (this._frame.height - grid.y - grid.height) * this._textureScale;
				const scaledCenterWidth: Number = this._width - scaledLeftWidth - scaledRightWidth;
				const scaledMiddleHeight: Number = this._height - scaledTopHeight - scaledBottomHeight;
				if (scaledCenterWidth < 0)
				{
					var offset: Number = scaledCenterWidth / 2;
					scaledLeftWidth += offset;
					scaledRightWidth += offset;
				}
				if (scaledMiddleHeight < 0)
				{
					offset = scaledMiddleHeight / 2;
					scaledTopHeight += offset;
					scaledBottomHeight += offset;
				}

				if (scaledTopHeight > 0)
				{
					if (scaledLeftWidth > 0)
					{
						helperImage.texture = this._textures.topLeft;
						helperImage.readjustSize();
						helperImage.width = scaledLeftWidth;
						helperImage.height = scaledTopHeight;
						helperImage.x = scaledLeftWidth - helperImage.width;
						helperImage.y = scaledTopHeight - helperImage.height;
						this._batch.addImage(helperImage);
					}

					if (scaledCenterWidth > 0)
					{
						helperImage.texture = this._textures.topCenter;
						helperImage.readjustSize();
						helperImage.width = scaledCenterWidth;
						helperImage.height = scaledTopHeight;
						helperImage.x = scaledLeftWidth;
						helperImage.y = scaledTopHeight - helperImage.height;
						this._batch.addImage(helperImage);
					}

					if (scaledRightWidth > 0)
					{
						helperImage.texture = this._textures.topRight;
						helperImage.readjustSize();
						helperImage.width = scaledRightWidth;
						helperImage.height = scaledTopHeight;
						helperImage.x = this._width - scaledRightWidth;
						helperImage.y = scaledTopHeight - helperImage.height;
						this._batch.addImage(helperImage);
					}
				}

				if (scaledMiddleHeight > 0)
				{
					if (scaledLeftWidth > 0)
					{
						helperImage.texture = this._textures.middleLeft;
						helperImage.readjustSize();
						helperImage.width = scaledLeftWidth;
						helperImage.height = scaledMiddleHeight;
						helperImage.x = scaledLeftWidth - helperImage.width;
						helperImage.y = scaledTopHeight;
						this._batch.addImage(helperImage);
					}

					if (scaledCenterWidth > 0)
					{
						helperImage.texture = this._textures.middleCenter;
						helperImage.readjustSize();
						helperImage.width = scaledCenterWidth;
						helperImage.height = scaledMiddleHeight;
						helperImage.x = scaledLeftWidth;
						helperImage.y = scaledTopHeight;
						this._batch.addImage(helperImage);
					}

					if (scaledRightWidth > 0)
					{
						helperImage.texture = this._textures.middleRight;
						helperImage.readjustSize();
						helperImage.width = scaledRightWidth;
						helperImage.height = scaledMiddleHeight;
						helperImage.x = this._width - scaledRightWidth;
						helperImage.y = scaledTopHeight;
						this._batch.addImage(helperImage);
					}
				}

				if (scaledBottomHeight > 0)
				{
					if (scaledLeftWidth > 0)
					{
						helperImage.texture = this._textures.bottomLeft;
						helperImage.readjustSize();
						helperImage.width = scaledLeftWidth;
						helperImage.height = scaledBottomHeight;
						helperImage.x = scaledLeftWidth - helperImage.width;
						helperImage.y = this._height - scaledBottomHeight;
						this._batch.addImage(helperImage);
					}

					if (scaledCenterWidth > 0)
					{
						helperImage.texture = this._textures.bottomCenter;
						helperImage.readjustSize();
						helperImage.width = scaledCenterWidth;
						helperImage.height = scaledBottomHeight;
						helperImage.x = scaledLeftWidth;
						helperImage.y = this._height - scaledBottomHeight;
						this._batch.addImage(helperImage);
					}

					if (scaledRightWidth > 0)
					{
						helperImage.texture = this._textures.bottomRight;
						helperImage.readjustSize();
						helperImage.width = scaledRightWidth;
						helperImage.height = scaledBottomHeight;
						helperImage.x = this._width - scaledRightWidth;
						helperImage.y = this._height - scaledBottomHeight;
						this._batch.addImage(helperImage);
					}
				}
			}

			this._propertiesChanged = false;
			this._layoutChanged = false;
			this._renderingChanged = false;
			this._isInvalid = false;
			this._isValidating = false;
		}

		/**
		 * Readjusts the dimensions of the image according to its current
		 * textures. Call this method to synchronize image and texture size
		 * after assigning textures with a different size.
		 */
		public function readjustSize(): void
		{
			this.width = this._frame.width * this._textureScale;
			this.height = this._frame.height * this._textureScale;
		}

		//--------------------------------------------------------------------------
		//
		//  PRIVATE METHODS
		//
		//--------------------------------------------------------------------------

		/**
		 * @private
		 */
		protected function invalidate(): void
		{
			if (this._isInvalid)
			{
				return;
			}
			this._isInvalid = true;
			if (!this._validationQueue)
			{
				return;
			}
			this._validationQueue.addControl(this, false);
		}

		//--------------------------------------------------------------------------
		//
		// OVERRIDDEN METHODS
		//
		//--------------------------------------------------------------------------

		/**
		 * @private
		 */
		public override function getBounds(targetSpace: DisplayObject, resultRect: Rectangle = null): Rectangle
		{
			if (!resultRect)
			{
				resultRect = new Rectangle();
			}

			var minX: Number = Number.MAX_VALUE, maxX: Number = -Number.MAX_VALUE;
			var minY: Number = Number.MAX_VALUE, maxY: Number = -Number.MAX_VALUE;

			if (targetSpace == this) // optimization
			{
				minX = this._hitArea.x;
				minY = this._hitArea.y;
				maxX = this._hitArea.x + this._hitArea.width;
				maxY = this._hitArea.y + this._hitArea.height;
			}
			else
			{
				this.getTransformationMatrix(targetSpace, HELPER_MATRIX);

				MatrixUtil.transformCoords(HELPER_MATRIX, this._hitArea.x, this._hitArea.y, HELPER_POINT);
				minX = minX < HELPER_POINT.x ? minX : HELPER_POINT.x;
				maxX = maxX > HELPER_POINT.x ? maxX : HELPER_POINT.x;
				minY = minY < HELPER_POINT.y ? minY : HELPER_POINT.y;
				maxY = maxY > HELPER_POINT.y ? maxY : HELPER_POINT.y;

				MatrixUtil.transformCoords(HELPER_MATRIX, this._hitArea.x, this._hitArea.y + this._hitArea.height,
				                           HELPER_POINT);
				minX = minX < HELPER_POINT.x ? minX : HELPER_POINT.x;
				maxX = maxX > HELPER_POINT.x ? maxX : HELPER_POINT.x;
				minY = minY < HELPER_POINT.y ? minY : HELPER_POINT.y;
				maxY = maxY > HELPER_POINT.y ? maxY : HELPER_POINT.y;

				MatrixUtil.transformCoords(HELPER_MATRIX, this._hitArea.x + this._hitArea.width, this._hitArea.y,
				                           HELPER_POINT);
				minX = minX < HELPER_POINT.x ? minX : HELPER_POINT.x;
				maxX = maxX > HELPER_POINT.x ? maxX : HELPER_POINT.x;
				minY = minY < HELPER_POINT.y ? minY : HELPER_POINT.y;
				maxY = maxY > HELPER_POINT.y ? maxY : HELPER_POINT.y;

				MatrixUtil.transformCoords(HELPER_MATRIX, this._hitArea.x + this._hitArea.width,
				                           this._hitArea.y + this._hitArea.height, HELPER_POINT);
				minX = minX < HELPER_POINT.x ? minX : HELPER_POINT.x;
				maxX = maxX > HELPER_POINT.x ? maxX : HELPER_POINT.x;
				minY = minY < HELPER_POINT.y ? minY : HELPER_POINT.y;
				maxY = maxY > HELPER_POINT.y ? maxY : HELPER_POINT.y;
			}

			resultRect.x = minX;
			resultRect.y = minY;
			resultRect.width = maxX - minX;
			resultRect.height = maxY - minY;

			return resultRect;
		}

		/**
		 * @private
		 */
		override public function hitTest(localPoint: Point, forTouch: Boolean = false): DisplayObject
		{
			if (forTouch && (!this.visible || !this.touchable))
			{
				return null;
			}
			return this._hitArea.containsPoint(localPoint) ? this : null;
		}

		/**
		 * @private
		 */
		override public function flatten(): void
		{
			this.validate();
			super.flatten();
		}

		//--------------------------------------------------------------------------
		//
		//  EVENT HANDLERS
		//
		//--------------------------------------------------------------------------

		/**
		 * @private
		 */
		private function flattenHandler(event: Event): void
		{
			this.validate();
		}

		/**
		 * @private
		 */
		private function addedToStageHandler(event: Event): void
		{
			this._depth = getDisplayObjectDepthFromStage(this);
			this._validationQueue = ValidationQueue.forStarling(Starling.current);
			if (this._isInvalid)
			{
				this._validationQueue.addControl(this, false);
			}
		}

		//--------------------------------------------------------------------------
		//
		//  GETTERS AND SETTERS
		//
		//--------------------------------------------------------------------------

		/**
		 * The textures displayed by this image.
		 *
		 * <p>In the following example, the textures are changed:</p>
		 *
		 * <listing version="3.0">
		 * image.textures = new Scale9Textures( texture, scale9Grid );</listing>
		 */
		public function get textures(): GAFScale9Texture
		{
			return this._textures;
		}

		/**
		 * @private
		 */
		public function set textures(value: GAFScale9Texture): void
		{
			if (!value)
			{
				throw new IllegalOperationError("Scale9Image textures cannot be null.");
			}
			if (this._textures == value)
			{
				return;
			}
			this._textures = value;
			this._frame = this._textures.texture.frame;
			this._layoutChanged = true;
			this._renderingChanged = true;
			this.invalidate();
		}

		/**
		 * @private
		 */
		override public function get width(): Number
		{
			return this._width;
		}

		/**
		 * @private
		 */
		override public function set width(value: Number): void
		{
			if (this._width == value)
			{
				return;
			}
			this._width = this._hitArea.width = value;
			this._layoutChanged = true;
			this.invalidate();
		}

		/**
		 * @private
		 */
		override public function get height(): Number
		{
			return this._height;
		}

		/**
		 * @private
		 */
		override public function set height(value: Number): void
		{
			if (this._height == value)
			{
				return;
			}
			this._height = this._hitArea.height = value;
			this._layoutChanged = true;
			this.invalidate();
		}

		/**
		 * The amount to scale the texture. Useful for DPI changes.
		 *
		 * <p>In the following example, the texture scale is changed:</p>
		 *
		 * <listing version="3.0">
		 * image.textureScale = 2;</listing>
		 *
		 * @default 1
		 */
		public function get textureScale(): Number
		{
			return this._textureScale;
		}

		/**
		 * @private
		 */
		public function set textureScale(value: Number): void
		{
			if (this._textureScale == value)
			{
				return;
			}
			this._textureScale = value;
			this._layoutChanged = true;
			this.invalidate();
		}

		/**
		 * The smoothing value to pass to the images.
		 *
		 * <p>In the following example, the smoothing is changed:</p>
		 *
		 * <listing version="3.0">
		 * image.smoothing = TextureSmoothing.NONE;</listing>
		 *
		 * @default starling.textures.TextureSmoothing.BILINEAR
		 *
		 * @see starling.textures.TextureSmoothing
		 */
		public function get smoothing(): String
		{
			return this._smoothing;
		}

		/**
		 * @private
		 */
		public function set smoothing(value: String): void
		{
			if (this._smoothing == value)
			{
				return;
			}
			this._smoothing = value;
			this._propertiesChanged = true;
			this.invalidate();
		}

		/**
		 * The color value to pass to the images.
		 *
		 * <p>In the following example, the color is changed:</p>
		 *
		 * <listing version="3.0">
		 * image.color = 0xff00ff;</listing>
		 *
		 * @default 0xffffff
		 */
		public function get color(): uint
		{
			return this._color;
		}

		/**
		 * @private
		 */
		public function set color(value: uint): void
		{
			if (this._color == value)
			{
				return;
			}
			this._color = value;
			this._propertiesChanged = true;
			this.invalidate();
		}

		/**
		 * Determines if the regions are batched normally by Starling or if
		 * they're batched separately.
		 *
		 * <p>In the following example, the separate batching is disabled:</p>
		 *
		 * <listing version="3.0">
		 * image.useSeparateBatch = false;</listing>
		 *
		 * @default true
		 */
		public function get useSeparateBatch(): Boolean
		{
			return this._useSeparateBatch;
		}

		/**
		 * @private
		 */
		public function set useSeparateBatch(value: Boolean): void
		{
			if (this._useSeparateBatch == value)
			{
				return;
			}
			this._useSeparateBatch = value;
			this._renderingChanged = true;
			this.invalidate();
		}

		/**
		 * @copy feathers.core.IValidating#depth
		 */
		public function get depth(): int
		{
			return this._depth;
		}

		//--------------------------------------------------------------------------
		//
		//  STATIC METHODS
		//
		//--------------------------------------------------------------------------
	}
}