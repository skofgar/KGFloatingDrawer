//
//  KGDrawerViewController.swift
//  KGDrawerViewController
//
//  Created by Kyle Goddard on 2015-02-10.
//  Copyright (c) 2015 Kyle Goddard. All rights reserved.
//

import UIKit

public enum KGDrawerSide: CGFloat {
    case none  = 0
    case left  = 1
    case right = -1
}

open class KGDrawerViewController: UIViewController {
    
    public var swipeToOpenSpeedMinimalThreshold:CGFloat      = 460
    public var swipeToOpenDistanceFromWindowEdge:CGFloat     = 70
    public var swipeListenerIfNoDrawerAction: ((UIPanGestureRecognizer) -> ())? = nil
    public var swipeSupportedDrawerSides: [KGDrawerSide] = [.left, .right]
    let defaultDuration:TimeInterval = 0.3
    private var openDrawerOnSwipe = false
    private var previousPoint:CGPoint?
    private var draggedPointEnd:CGPoint?
    
    // MARK: Initialization
    
    override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func loadView() {
        view = drawerView
    }
    
    
    fileprivate var _drawerView: KGDrawerView?
    var drawerView: KGDrawerView {
        get {
            if let retVal = _drawerView {
                return retVal
            }
            let rect = UIScreen.main.bounds
            let retVal = KGDrawerView(frame: rect)
            _drawerView = retVal
            return retVal
        }
    }
    
    // TODO: Add ability to supply custom animator.
    
    fileprivate var _animator: KGDrawerSpringAnimator?
    public var animator: KGDrawerSpringAnimator {
        get {
            if let retVal = _animator {
                return retVal
            }
            let retVal = KGDrawerSpringAnimator()
            _animator = retVal
            return retVal
        }
    }
    
    // MARK: Interaction
    
    public func openDrawer(side: KGDrawerSide, animated:Bool, complete: @escaping (_ finished: Bool) -> Void) {
        if currentlyOpenedSide != side {
            if let sideView = drawerView.viewContainerForDrawerSide(drawerSide: side) {
                let centerView = drawerView.centerViewContainer
                if currentlyOpenedSide != .none {
                    closeDrawer(side: side, animated: animated) { finished in
                        self.animator.openDrawer(side: side, drawerView: sideView, centerView: centerView, animated: animated, complete: complete)
                    }
                } else {
                    self.animator.openDrawer(side: side, drawerView: sideView, centerView: centerView, animated: animated, complete: complete)
                }
                
                addDrawerGestures()
                drawerView.willOpenDrawer(viewController: self)
            }
        }
        
        currentlyOpenedSide = side
    }
    
    public func animateDrawer(side: KGDrawerSide, animated:Bool, animationCompletion: CGFloat, complete: @escaping (_ finished: Bool) -> Void) {
        if let sideView = drawerView.viewContainerForDrawerSide(drawerSide: side) {
            let centerView = drawerView.centerViewContainer
            
            self.animator.drawerAnimation(side: side, drawerView: sideView, centerView: centerView, animated: animated, animationCompletion: animationCompletion, complete: complete)
            
            addDrawerGestures()
            drawerView.willOpenDrawer(viewController: self)
            
        }
        
        currentlyOpenedSide = side
    }
    
    public func closeDrawer(side: KGDrawerSide, animated: Bool, complete: @escaping (_ finished: Bool) -> Void) {
        if (currentlyOpenedSide == side && currentlyOpenedSide != .none) {
            if let sideView = drawerView.viewContainerForDrawerSide(drawerSide: side) {
                let centerView = drawerView.centerViewContainer
                animator.dismissDrawer(side: side, drawerView: sideView, centerView: centerView, animated: animated, complete: complete)
                currentlyOpenedSide = .none
                restoreGestures()
                drawerView.willCloseDrawer(viewController: self)
            }
        }
    }
    
    public func toggleDrawer(side: KGDrawerSide, animated: Bool, complete: @escaping (_ finished: Bool) -> Void) {
        if side != .none {
            if side == currentlyOpenedSide {
                closeDrawer(side: side, animated: animated, complete: complete)
            } else {
                openDrawer(side: side, animated: animated, complete: complete)
            }
        }
    }
    
    // MARK: Gestures
    
    func addDrawerPanGestures() {
        drawerView.centerViewContainer.addGestureRecognizer(toggleDrawerPanGestureRecognizer)
    }
    
    func addDrawerGestures() {
        centerViewController?.view.isUserInteractionEnabled = false
        drawerView.centerViewContainer.addGestureRecognizer(toggleDrawerTapGestureRecognizer)
        if (!self.openDrawerOnSwipe) {
            addDrawerPanGestures()
        }
    }
    
    func restorePanGestures() {
        drawerView.centerViewContainer.removeGestureRecognizer(toggleDrawerPanGestureRecognizer)
    }
    
    func restoreGestures() {
        drawerView.centerViewContainer.removeGestureRecognizer(toggleDrawerTapGestureRecognizer)
        if (!self.openDrawerOnSwipe) {
            restorePanGestures()
        }
        centerViewController?.view.isUserInteractionEnabled = true
    }
    
    func centerViewContainerTapped(sender: AnyObject) {
        closeDrawer(side: currentlyOpenedSide, animated: true) { (finished) -> Void in
            // Do nothing
        }
    }
    
    public var shouldOpenDrawerOnSwipe: Bool {
        get { return self.openDrawerOnSwipe }
        set(value) {
            if (self.openDrawerOnSwipe != value) {
                if (value) {
                    addDrawerPanGestures()
                } else {
                    restorePanGestures()
                }
                self.openDrawerOnSwipe = value
            }
        }
    }
    
    func shouldOpenDrawerSide(_ recognizer: UIPanGestureRecognizer) -> KGDrawerSide {
        let velocityPoint = recognizer.velocity(in: self.view)
        let drawerSide = (velocityPoint.x > 0.0) ? KGDrawerSide.left : KGDrawerSide.right
        
        if (self.swipeSupportedDrawerSides.contains(drawerSide)) {
            if let window = UIApplication.shared.delegate?.window {
                
                let location = recognizer.location(in: window)
                let width = window!.frame.width
                
                let boundaryDistance = (drawerSide == .left) ? location.x : abs(width-location.x)
                
                return (abs(velocityPoint.x) > swipeToOpenSpeedMinimalThreshold && boundaryDistance < swipeToOpenDistanceFromWindowEdge) ? drawerSide : KGDrawerSide.none
            }
        }
        return KGDrawerSide.none
    }
    
    func updateCenterViewControllerPosition(recognizer: UIPanGestureRecognizer) {
        let point:CGPoint = recognizer.location(ofTouch: 0, in:self.view!)
        if (nil != draggedPointEnd) {
            previousPoint = draggedPointEnd
        }
        draggedPointEnd = recognizer.location(ofTouch: 0, in: self.view!)
        var animationCompletion = computeAnimationCompletion(point: point)
        #if DEBUG
            print("%: \(animationCompletion), x: \(point.y), width: \(recognizer.view!.frame.size.width)")
        #endif
        
        animateDrawer(side: currentlyOpenedSide, animated: true, animationCompletion: animationCompletion) { (finished) -> Void in
            // Do nothing
        }
    }
    
    func centerViewContainerDragged(sender: AnyObject) {
        
        if sender is UIPanGestureRecognizer {
            let recognizer = sender as! UIPanGestureRecognizer
            
            if (.began == recognizer.state || .changed == recognizer.state)
            {
                centerViewController?.view.isUserInteractionEnabled = false
                if (currentlyOpenedSide == .none) {
                    let side = shouldOpenDrawerSide(recognizer)
                    if (side == .none) {
                        if let action = self.swipeListenerIfNoDrawerAction {
                            action(recognizer)
                        }
                    } else {
                        animateDrawer(side: side, animated: true, animationCompletion: 0.1) { (finished) -> Void in
                            // Do nothing
                        }
                    }
                } else {
                    updateCenterViewControllerPosition(recognizer: recognizer)
                }
            } else if (.ended == recognizer.state) {
                if (nil != previousPoint) {
                    finishDrawerInteraction(isSwipeDirectionRight: (previousPoint!.x < draggedPointEnd!.x))
                }
                centerViewController?.view.isUserInteractionEnabled = true
            }
        }
    }
    
    func computeAnimationCompletion(point: CGPoint) -> CGFloat {
        if (currentlyOpenedSide == .left) {
            return fabs(point.x) / self.view!.frame.size.width
        } else if (currentlyOpenedSide == .right) {
            return fabs(self.view!.frame.size.width-point.x) / self.view!.frame.size.width
        } else {
            return 1
        }
    }
    
    func finishDrawerInteraction(isSwipeDirectionRight: Bool) {
        if ((isSwipeDirectionRight && currentlyOpenedSide == .left) || (!isSwipeDirectionRight && currentlyOpenedSide == .right)) {
            let openSide = currentlyOpenedSide
            currentlyOpenedSide = KGDrawerSide.none
            openDrawer(side: openSide, animated: true) { (finished) -> Void in
            }
        } else {
            closeDrawer(side: currentlyOpenedSide, animated: true) { (finished) -> Void in
            }
        }
    }
    
    // MARK: Helpers
    
    func viewContainer(side: KGDrawerSide) -> UIViewController? {
        switch side {
        case .left:
            return self.leftViewController
        case .right:
            return self.rightViewController
        case .none:
            return nil
        }
    }
    
    func replaceViewController(sourceViewController: UIViewController?, destinationViewController: UIViewController, container: UIView) {
        
        sourceViewController?.willMove(toParentViewController: nil)
        sourceViewController?.view.removeFromSuperview()
        sourceViewController?.removeFromParentViewController()
        
        self.addChildViewController(destinationViewController)
        container.addSubview(destinationViewController.view)
        
        let destinationView = destinationViewController.view
        destinationView?.translatesAutoresizingMaskIntoConstraints = false
        
        container.removeConstraints(container.constraints)
        
        let views: [String:UIView] = ["v1" : destinationView!]
        container.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[v1]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views))
        container.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[v1]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views))
        
        destinationViewController.didMove(toParentViewController: self)
    }
    
    // MARK: Private computed properties
    
    public var currentlyOpenedSide: KGDrawerSide = .none
    
    // MARK: Accessors
    fileprivate var _leftViewController: UIViewController?
    public var leftViewController: UIViewController? {
        get {
            return _leftViewController
        }
        set {
            self.replaceViewController(sourceViewController: self.leftViewController, destinationViewController: newValue!, container: self.drawerView.leftViewContainer)
            _leftViewController = newValue!
        }
    }
    
    fileprivate var _rightViewController: UIViewController?
    public var rightViewController: UIViewController? {
        get {
            return _rightViewController
        }
        set {
            self.replaceViewController(sourceViewController: self.rightViewController, destinationViewController: newValue!, container: self.drawerView.rightViewContainer)
            _rightViewController = newValue
        }
    }
    
    fileprivate var _centerViewController: UIViewController?
    public var centerViewController: UIViewController? {
        get {
            return _centerViewController
        }
        set {
            self.replaceViewController(sourceViewController: self.centerViewController, destinationViewController: newValue!, container: self.drawerView.centerViewContainer)
            _centerViewController = newValue
        }
    }
    
    fileprivate lazy var toggleDrawerTapGestureRecognizer: UITapGestureRecognizer = {
        [unowned self] in
        let gesture = UITapGestureRecognizer(target: self, action: #selector(KGDrawerViewController.centerViewContainerTapped(sender:)))
        return gesture
    }()
    
    fileprivate lazy var toggleDrawerPanGestureRecognizer: UIPanGestureRecognizer = {
        [unowned self] in
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(KGDrawerViewController.centerViewContainerDragged(sender:)))
        gesture.minimumNumberOfTouches = 1
        gesture.maximumNumberOfTouches = 1
        return gesture
    }()
    
    public var leftDrawerWidth: CGFloat {
        get  {
            return drawerView.leftViewContainerWidth
        }
        set {
            drawerView.leftViewContainerWidth = newValue
        }
    }
    
    public var rightDrawerWidth: CGFloat {
        get {
            return drawerView.rightViewContainerWidth
        }
        set {
            drawerView.rightViewContainerWidth = newValue
        }
    }
    
    public var leftDrawerRevealWidth: CGFloat {
        get {
            return drawerView.leftViewContainerWidth
        }
    }
    
    public var rightDrawerRevealWidth: CGFloat {
        get {
            return drawerView.rightViewContainerWidth
        }
    }
    
    public var backgroundImage: UIImage? {
        get {
            return drawerView.backgroundImageView.image
        }
        set {
            drawerView.backgroundImageView.image = newValue
        }
    }
    
    public var backgroundColor: UIColor? {
        get {
            return drawerView.backgroundColor
        }
        set {
            drawerView.backgroundColor = newValue
        }
    }
    
    // MARK: Status Bar
    
    override open var childViewControllerForStatusBarHidden: UIViewController? {
        return centerViewController
    }
    
    override open var childViewControllerForStatusBarStyle: UIViewController? {
        return centerViewController
    }
    
//    // MARK: Memory Management
//    
//    override public func didReceiveMemoryWarning() {
//        super.didReceiveMemoryWarning()
//    }
    
}
