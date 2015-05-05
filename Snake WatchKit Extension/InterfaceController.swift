//
//  InterfaceController.swift
//  Snake WatchKit Extension
//
//  Created by David Cairns on 11/20/14.
//  Copyright (c) 2014 David Cairns. All rights reserved.
//

import WatchKit
import Foundation

func DCCGPointIsNearPoint(p1:CGPoint, p2:CGPoint) -> Bool {
	let xDiff = p1.x - p2.x
	let yDiff = p1.y - p2.y
	return xDiff * xDiff + yDiff * yDiff < 1.0
}

enum Direction : Int {
	case Up = 0
	case Right
	case Down
	case Left
	
	func xDiff() -> Int {
		switch(self) {
		case .Up:
			return 0
		case .Right:
			return 1
		case .Down:
			return 0
		case .Left:
			return -1
		}
	}
	func yDiff() -> Int {
		switch(self) {
		case .Up:
			return 1
		case .Right:
			return 0
		case .Down:
			return -1
		case .Left:
			return 0
		}
	}
	
	func nextValueClockwise() -> Direction {
		switch(self) {
		case .Up:
			return .Right
		case .Right:
			return .Down
		case .Down:
			return .Left
		case .Left:
			return .Up
		}
	}
	func nextValueCounterClockwise() -> Direction {
		switch(self) {
		case .Up:
			return .Left
		case .Right:
			return .Up
		case .Down:
			return .Right
		case .Left:
			return .Down
		}
	}
	
	func isHorizontal() -> Bool {
		switch(self) {
		case .Up:
			return false
		case .Right:
			return true
		case .Down:
			return false
		case .Left:
			return true
		}
	}
	func isVertical() -> Bool {
		switch(self) {
		case .Up:
			return true
		case .Right:
			return false
		case .Down:
			return true
		case .Left:
			return false
		}
	}
}

struct DiscretePoint : Equatable, Printable {
	let x: Int, y: Int
	
	init(_ x: Int, _ y: Int) {
		self.x = x
		self.y = y
	}
	
	static var Zero: DiscretePoint {
		get {
			return DiscretePoint(0, 0)
		}
	}
	var cgPoint: CGPoint! {
		get {
			return CGPointMake(CGFloat(self.x), CGFloat(self.y))
		}
	}
	var description: String {
		get {
			return "[\(self.x), \(self.y)]"
		}
	}
}
func ==(lhs: DiscretePoint, rhs: DiscretePoint) -> Bool {
	return lhs.x == rhs.x && lhs.y == rhs.y
}

struct DiscreteSize {
	let width: Int, height: Int
	
	static var Zero: DiscreteSize {
		get {
			return DiscreteSize(width: 0, height: 0)
		}
	}
	var cgSize: CGSize! {
		get {
			return CGSizeMake(CGFloat(self.width), CGFloat(self.height))
		}
	}
}
struct DiscreteRect {
	let origin: DiscretePoint
	let size: DiscreteSize
	
	func containsPoint(point: DiscretePoint) -> Bool {
		return point.x >= origin.x && point.y >= origin.y && point.x < (origin.x + size.width) && point.y < (origin.y + size.height)
	}
	
	var cgRect: CGRect! {
		get {
			return CGRect(origin: self.origin.cgPoint, size: self.size.cgSize)
		}
	}
}

class SnakeGame {
	let updateInterval = 0.7
	let gameSize = DiscreteSize(width: 16, height: 16)
	let blockSize:Int = 8
	var imageOutputSize: CGSize {
		get {
			return DiscreteSize(width: self.gameSize.width * self.blockSize, height: self.gameSize.height * self.blockSize).cgSize
		}
	}
	
	let USE_IMAGES = false
	var appleImage: UIImage?
	var snakePartsImage: UIImage?
	let aliveGrassColor = UIColor.blackColor().CGColor
	let deadGrassColor = UIColor.yellowColor().CGColor
	let snakeColor = UIColor.greenColor().CGColor
	let appleColor = UIColor.redColor().CGColor
	
	
	var snakeParts = [DiscretePoint(6, 10), DiscretePoint(5, 10), DiscretePoint(4, 10)]
	var direction: Direction = .Right
	var pendingDirection: Direction? = nil
	var isAlive = true
	var remainingTime: NSTimeInterval = 20.0
	var applesEaten = 0
	var apples = [DiscretePoint]()
	var eatenApplePoints = [DiscretePoint]()
	
	init() {
		if USE_IMAGES {
			self.appleImage = UIImage(named: "apple")
			self.snakePartsImage = UIImage(named: "snake_sprites")
		}
	}
	
	func isValidSnake(snakeParts:[DiscretePoint]) -> Bool {
		for snakePartIdx in 0..<snakeParts.count {
			let snakePart = snakeParts[snakePartIdx]
			// Check for the game boundary intersection.
			if !DiscreteRect(origin: DiscretePoint.Zero, size: self.gameSize).containsPoint(snakePart) {
				return false
			}
			
			// Check for snake self-intersection.
			for otherSnakePart in snakeParts[snakePartIdx + 1 ..< snakeParts.count] {
				if snakePart == otherSnakePart {
					return false
				}
			}
		}
		
		// Everything looks good!
		return true
	}
	
	func isValidApplePoint(applePoint: DiscretePoint) -> Bool {
		for snakePart in self.snakeParts {
			if applePoint == snakePart {
				return false
			}
		}
		return true
	}
	func newApplePoint() -> DiscretePoint {
		// Tail recursion like this is totally reasonable in FP; hopefully Swift actually implements it correctly!
		let applePoint = DiscretePoint(random() % self.gameSize.width, random() % self.gameSize.height)
		return (isValidApplePoint(applePoint) ? applePoint : newApplePoint())
	}
	
	func advanceSnakeParts(snakeParts:[DiscretePoint], eatenApplePoints:[DiscretePoint]) -> ([DiscretePoint], [DiscretePoint]) {
		// Move the first snake-part forward.
		var newSnakeParts = [DiscretePoint]()
		newSnakeParts.append(DiscretePoint(snakeParts[0].x + self.direction.xDiff(), snakeParts[0].y + self.direction.yDiff()))
		
		// Move the rest of the snake parts forward.
		let srcRange:Range = 0...snakeParts.count - 2
		newSnakeParts.extend(snakeParts[srcRange])
		
		// See if the end of the original snake is an eaten apple point!
		var newEatenApplePoints = eatenApplePoints
		for eatenAppleIdx in 0..<eatenApplePoints.count {
			let eatenApple = eatenApplePoints[eatenAppleIdx]
			if snakeParts.last! == eatenApple {
				newEatenApplePoints.removeAtIndex(eatenAppleIdx)
				newSnakeParts.append(eatenApple)
				break
			}
		}
		return (newSnakeParts, newEatenApplePoints)
	}
	func update() {
		// If we're already dead, just bail!
		if !self.isAlive {
			return
		}
		
		// Let the snake change direction!
		if let newDirection = self.pendingDirection {
			self.direction = newDirection
			self.pendingDirection = nil
		}
		
		// Move the snake forward!
		(self.snakeParts, self.eatenApplePoints) = self.advanceSnakeParts(self.snakeParts, eatenApplePoints:self.eatenApplePoints)
		
		// See if we should add an apple.
		if 0 == random() % 20 || 0 == self.apples.count {
			let applePoint = self.newApplePoint()
			self.apples.append(applePoint)
		}
		
		// See if the snake eats an apple!
		for appleIdx in 0..<self.apples.count {
			let apple = self.apples[appleIdx]
			if self.snakeParts[0] == apple {
				self.eatenApplePoints.append(apple)
				self.apples.removeAtIndex(appleIdx)
				
				self.applesEaten++
				self.remainingTime += (8.0 - Double(self.applesEaten / 8))
				
				break
			}
		}
		
		self.remainingTime -= self.updateInterval
		
		// Check for DEATH!
		self.isAlive = isValidSnake(self.snakeParts) && self.remainingTime > 0
	}
	
	func directionFromPoint(point: DiscretePoint, toPoint otherPoint: DiscretePoint) -> Direction {
		let yDiff = otherPoint.y - point.y
		if abs(yDiff) > 0 {
			// There is a change in y!
			if yDiff > 0 {
				return .Up
			}
			else if yDiff < 0 {
				return .Down
			}
		}
		
		let xDiff = otherPoint.x - point.x
		if abs(xDiff) > 0 {
			// There is a change in x!
			if xDiff > 0 {
				return .Right
			}
			else if xDiff < 0 {
				return .Left
			}
		}
		
		// Who knows! Let's return Up, I guess!
		return .Up
	}
	
	func rectForGamePoint(gamePoint: DiscretePoint) -> CGRect {
		return DiscreteRect(origin: DiscretePoint(self.blockSize * gamePoint.x, self.blockSize * gamePoint.y), size: DiscreteSize(width: self.blockSize, height: self.blockSize)).cgRect
	}
	
	func imageSourceOriginForMiddleSnakePart(index snakePartIdx: Int) -> CGPoint {
		let snakePart = self.snakeParts[snakePartIdx]
		let leadingSnakePart = self.snakeParts[snakePartIdx - 1]
		let trailingSnakePart = self.snakeParts[snakePartIdx + 1]
		
		var hasUp = false
		var hasDown = false
		var hasRight = false
		var hasLeft = false
		switch self.directionFromPoint(snakePart, toPoint: leadingSnakePart) {
			case .Up:
				hasUp = true
			case .Right:
				hasRight = true
			case .Down:
				hasDown = true
			case .Left:
				hasLeft = true
		}
		switch self.directionFromPoint(snakePart, toPoint: trailingSnakePart) {
			case .Up:
				hasUp = true
			case .Right:
				hasRight = true
			case .Down:
				hasDown = true
			case .Left:
				hasLeft = true
		}
		
		var columnOffset = 0
		var rowOffset = 0
		if hasUp && hasDown {
			// Totally vertical!
			columnOffset = 0
			rowOffset = (random() % 5) + 1
		}
		else if hasLeft && hasRight {
			// Totally horizontal!
			columnOffset = 1
			rowOffset = (random() % 5) + 1
		}
		else if hasDown {
			rowOffset = 1
			columnOffset = (hasRight ? 2 : 3)
		}
		else {
			rowOffset = 2
			columnOffset = (hasRight ? 2 : 3)
		}
		
		return CGPointMake(64.0 * CGFloat(columnOffset), 64.0 * CGFloat(rowOffset))
	}
	func drawSnakeSegment(snakePartRect: CGRect, fromSourceOrigin sourceOrigin: CGPoint, inContext context: CGContextRef) {
		let snakePartImageRect = CGRectMake(sourceOrigin.x, sourceOrigin.y, 64.0, 64.0)
		let snakePartImage = CGImageCreateWithImageInRect(self.snakePartsImage?.CGImage, snakePartImageRect)
		CGContextDrawImage(context, snakePartRect, snakePartImage)
	}
	func drawFlatSnakeSegment(snakePartRect: CGRect, inContext context: CGContextRef) {
		CGContextSaveGState(context)
		CGContextSetFillColorWithColor(context, self.snakeColor)
		CGContextFillRect(context, snakePartRect)
		CGContextRestoreGState(context)
	}
	func renderSnake(inContext context:CGContextRef) {
		// First draw the head.
		if USE_IMAGES {
			drawSnakeSegment(rectForGamePoint(self.snakeParts[0]), fromSourceOrigin: CGPointMake(64.0 * CGFloat(self.direction.rawValue), 0.0), inContext: context)
		}
		else {
			drawFlatSnakeSegment(rectForGamePoint(self.snakeParts[0]), inContext: context)
		}
		
		// Now draw the tail.
		if USE_IMAGES {
			let tailDirection = self.directionFromPoint(self.snakeParts.last!, toPoint: self.snakeParts[self.snakeParts.count - 2])
			drawSnakeSegment(rectForGamePoint(self.snakeParts.last!), fromSourceOrigin: CGPointMake(64.0 * CGFloat(tailDirection.rawValue), 64.0 * 6.0), inContext: context)
		}
		else {
			drawFlatSnakeSegment(rectForGamePoint(self.snakeParts.last!), inContext: context)
		}
		
		// Lastly, draw the middle bits!
		for snakePartIdx in 1 ... self.snakeParts.count - 2 {
			let snakePart = self.snakeParts[snakePartIdx]
			
			if USE_IMAGES {
				let imageSourceOrigin = self.imageSourceOriginForMiddleSnakePart(index: snakePartIdx)
				drawSnakeSegment(rectForGamePoint(snakePart), fromSourceOrigin: imageSourceOrigin, inContext: context)
			}
			else {
				drawFlatSnakeSegment(rectForGamePoint(snakePart), inContext: context)
			}
		}
	}
	
	func drawApple(#point: DiscretePoint, inContext context: CGContextRef) {
		let appleRect = self.rectForGamePoint(point)
		
		if USE_IMAGES {
			CGContextDrawImage(context, appleRect, self.appleImage?.CGImage)
		}
		else {
			CGContextSaveGState(context)
			CGContextSetFillColorWithColor(context, self.appleColor)
			CGContextFillRect(context, appleRect)
			CGContextRestoreGState(context)
		}
	}
	func render() -> (UIImage, UIImage) {
		UIGraphicsBeginImageContext(self.imageOutputSize)
		let context = UIGraphicsGetCurrentContext()
		// Flip the y-axis.
		CGContextTranslateCTM(context, 0.0, self.imageOutputSize.height)
		CGContextScaleCTM(context, 1.0, -1.0)
		
		if isAlive {
			// Fill the background!
			CGContextSetFillColorWithColor(context, self.aliveGrassColor)
		}
		else {
			// Fill the background with BLACK!
			CGContextSetFillColorWithColor(context, self.deadGrassColor)
		}
		CGContextFillRect(context, CGRectMake(0.0, 0.0, self.imageOutputSize.width, self.imageOutputSize.height))
		
		// Draw the apples!
		for apple in self.apples {
			drawApple(point: apple, inContext: context)
		}
		
		// Draw the snake!
		self.renderSnake(inContext: context)
		
		let fullImage = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		
		// Split up the image into left- and right-halves.
		let halfWidth = self.imageOutputSize.width / 2.0
		let leftImage = UIImage(CGImage: CGImageCreateWithImageInRect(fullImage.CGImage, CGRectMake(0.0, 0.0, halfWidth, self.imageOutputSize.height)))
		let rightImage = UIImage(CGImage: CGImageCreateWithImageInRect(fullImage.CGImage, CGRectMake(halfWidth, 0.0, halfWidth, self.imageOutputSize.height)))
		return (leftImage!, rightImage!)
	}
	
	func changeDirectionClockwise() {
		self.pendingDirection = self.direction.nextValueClockwise()
	}
	func changeDirectionCounterClockwise() {
		self.pendingDirection = self.direction.nextValueCounterClockwise()
	}
}


class InterfaceController: WKInterfaceController {
	@IBOutlet var scoreLabel: WKInterfaceLabel?
	@IBOutlet var timerLabel: WKInterfaceLabel?
	@IBOutlet var leftImageButton: WKInterfaceButton?
	@IBOutlet var rightImageButton: WKInterfaceButton?
	var timer: NSTimer?
	var game: SnakeGame
	
	override init() {
		self.game = SnakeGame()
	}

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
		
		self.timer = NSTimer.scheduledTimerWithTimeInterval(self.game.updateInterval, target: self, selector: Selector("gameTimerFired"), userInfo: nil, repeats: true)
    }

    override func didDeactivate() {
		self.timer?.invalidate()
		
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
	
	@IBAction func leftButtonTapped(sender:AnyObject) {
		if(self.game.isAlive) {
			self.game.changeDirectionCounterClockwise()
		}
		else {
			// Restart!
			self.game = SnakeGame()
		}
	}
	@IBAction func rightButtonTapped(sender:AnyObject) {
		if(self.game.isAlive) {
			self.game.changeDirectionClockwise()
		}
		else {
			// Restart!
			self.game = SnakeGame()
		}
	}
	
	func gameTimerFired() {
		self.game.update()
		self.scoreLabel?.setText("🍎:\(self.game.applesEaten)")
		self.timerLabel?.setText("🕐:\(Int(self.game.remainingTime))")
		
		// Split up the game image!
		let (leftImage, rightImage) = self.game.render()
		self.leftImageButton?.setBackgroundImage(leftImage)
		self.rightImageButton?.setBackgroundImage(rightImage)
	}
}
