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

class SnakeGame {
	enum Direction {
		case Up
		case Right
		case Down
		case Left
		
		func xDiff() -> CGFloat {
			switch(self) {
				case .Up:
					return 0.0
				case .Right:
					return 1.0
				case .Down:
					return 0.0
				case .Left:
					return -1.0
			}
		}
		func yDiff() -> CGFloat {
			switch(self) {
				case .Up:
					return 1.0
				case .Right:
					return 0.0
				case .Down:
					return -1.0
				case .Left:
					return 0.0
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
	}
	
	let size:CGSize = CGSizeMake(256.0, 256.0)
	let blockSize:CGFloat = 8.0
	var gameSize:CGSize {
		get {
			return CGSizeMake(self.size.width / self.blockSize, self.size.height / self.blockSize)
		}
	}
	
	var snakeParts = [CGPointMake(12, 10), CGPointMake(11, 10), CGPointMake(10, 10)]
	var direction:Direction = .Right
	var isAlive = true
	var apples = [CGPoint]()
	var eatenApplePoints = [CGPoint]()
	
	func isValidSnake(snakeParts:[CGPoint]) -> Bool {
		for snakePartIdx in 0..<snakeParts.count {
			let snakePart = snakeParts[snakePartIdx]
			// Check for the game boundary intersection.
			if !CGRectContainsPoint(CGRectMake(0.0, 0.0, self.gameSize.width, self.gameSize.height), snakePart) {
				return false
			}
			
			// Check for snake self-intersection.
			for otherSnakePart in snakeParts[snakePartIdx + 1 ..< snakeParts.count] {
				if DCCGPointIsNearPoint(snakePart, otherSnakePart) {
					return false
				}
			}
		}
		
		// Everything looks good!
		return true
	}
	
	func isValidApplePoint(applePoint:CGPoint) -> Bool {
		for snakePart in self.snakeParts {
			if DCCGPointIsNearPoint(applePoint, snakePart) {
				return false
			}
		}
		return true
	}
	func newApplePoint() -> CGPoint {
		// Tail recursion like this is totally reasonable in FP; hopefully Swift actually implements it correctly!
		let applePoint = CGPointMake(CGFloat(random() % Int(self.gameSize.width)), CGFloat(random() % Int(self.gameSize.height)))
		return (isValidApplePoint(applePoint) ? applePoint : newApplePoint())
	}
	
	func advanceSnakeParts(snakeParts:[CGPoint], eatenApplePoints:[CGPoint]) -> ([CGPoint], [CGPoint]) {
		// Move the first snake-part forward.
		var newSnakeParts = [CGPoint]()
		newSnakeParts.append(CGPointMake(snakeParts[0].x + self.direction.xDiff(), snakeParts[0].y + self.direction.yDiff()))
		
		// Move the rest of the snake parts forward.
		let srcRange:Range = 0...snakeParts.count - 2
		newSnakeParts.extend(snakeParts[srcRange])
		
		// See if the end of the original snake is an eaten apple point!
		var newEatenApplePoints = eatenApplePoints
		for eatenAppleIdx in 0..<eatenApplePoints.count {
			let eatenApple = eatenApplePoints[eatenAppleIdx]
			if DCCGPointIsNearPoint(snakeParts.last!, eatenApple) {
				newEatenApplePoints.removeAtIndex(eatenAppleIdx)
				newSnakeParts.append(eatenApple)
				break
			}
		}
		return (newSnakeParts, newEatenApplePoints)
	}
	func update() {
		// If we're already dead, just bail!
		if !isAlive {
			return
		}
		
		// Move the snake forward!
		(self.snakeParts, self.eatenApplePoints) = self.advanceSnakeParts(self.snakeParts, eatenApplePoints:self.eatenApplePoints)
		
		// See if we should add an apple.
		if 0 == rand() % 20 || 0 == self.apples.count {
			self.apples.append(self.newApplePoint())
		}
		
		// See if the snake eats an apple!
		for appleIdx in 0..<self.apples.count {
			let apple = self.apples[appleIdx]
			if DCCGPointIsNearPoint(self.snakeParts[0], apple) {
				self.eatenApplePoints.append(apple)
				self.apples.removeAtIndex(appleIdx)
				break
			}
		}
		
		// Check for DEATH!
		self.isAlive = isValidSnake(self.snakeParts)
	}
	func render() -> (UIImage, UIImage)
	{
		UIGraphicsBeginImageContext(self.size)
		let context = UIGraphicsGetCurrentContext()
		// Flip the y-axis.
		CGContextTranslateCTM(context, 0.0, self.size.height)
		CGContextScaleCTM(context, 1.0, -1.0)
		
		if isAlive {
			// Fill the background!
			CGContextSetFillColorWithColor(context, UIColor.greenColor().CGColor)
		}
		else {
			// Fill the background with RED!
			CGContextSetFillColorWithColor(context, UIColor.blackColor().CGColor)
		}
		CGContextFillRect(context, CGRectMake(0.0, 0.0, self.size.width, self.size.height))
		
		// Draw the apples!
		CGContextSetFillColorWithColor(context, UIColor.redColor().CGColor)
		for apple in self.apples {
			CGContextFillRect(context, CGRectMake(self.self.blockSize * apple.x, self.self.blockSize * apple.y, self.self.blockSize, self.self.blockSize))
		}
		
		// Draw the snake!
		CGContextSetFillColorWithColor(context, UIColor.brownColor().CGColor)
		for snakePart in self.snakeParts {
			CGContextFillRect(context, CGRectMake(self.self.blockSize * snakePart.x, self.self.blockSize * snakePart.y, self.self.blockSize, self.self.blockSize))
		}
		
		let fullImage = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		
		// Split up the image into left- and right-halves.
		let halfWidth = self.size.width / 2.0
		let leftImage = UIImage(CGImage: CGImageCreateWithImageInRect(fullImage.CGImage, CGRectMake(0.0, 0.0, halfWidth, self.size.height)))
		let rightImage = UIImage(CGImage: CGImageCreateWithImageInRect(fullImage.CGImage, CGRectMake(halfWidth, 0.0, halfWidth, self.size.height)))
		return (leftImage!, rightImage!)
	}
	
	func changeDirectionClockwise() {
		self.direction = self.direction.nextValueClockwise()
	}
	func changeDirectionCounterClockwise() {
		self.direction = self.direction.nextValueCounterClockwise()
	}
}


class InterfaceController: WKInterfaceController {
	@IBOutlet var leftImageButton:WKInterfaceButton?
	@IBOutlet var rightImageButton:WKInterfaceButton?
	var timer:NSTimer?
	var game:SnakeGame

    override init(context: AnyObject?) {
		self.game = SnakeGame()
		
        // Initialize variables here.
        super.init(context: context)
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
		
		self.timer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: Selector("gameTimerFired"), userInfo: nil, repeats: true)
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
		
		// Split up the game image!
		let (leftImage, rightImage) = self.game.render()
		self.leftImageButton?.setBackgroundImage(leftImage)
		self.rightImageButton?.setBackgroundImage(rightImage)
	}
}
