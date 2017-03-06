//
//  CollectionViewDynamicLayout.swift
//  creams
//
//  Created by Rawlings on 24/11/2016.
//  Copyright © 2016 jiangren. All rights reserved.
//

import UIKit

class CollectionViewDynamicLayout: UICollectionViewFlowLayout {

    private static let scrollResistanceRatio: CGFloat = 2500.0
    var latestDelta: CGFloat?
    var visibleIndexPathsSet = NSMutableSet.init()
    var dynamicAnimator: UIDynamicAnimator?

    override init() {
        super.init()
        dynamicAnimator = UIDynamicAnimator.init(collectionViewLayout: self)
        minimumInteritemSpacing = 10
        minimumLineSpacing = 10
        itemSize = CGSize.init(width: 100, height: 44)
        sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepare() {
        super.prepare()

        // Need to overflow our actual visible rect slightly to avoid flickering.
        let visibleRect = CGRect.init(origin: (collectionView?.bounds.origin)!, size: (collectionView?.bounds.size)!)
        let itemsInVisibleRectArray = super.layoutAttributesForElements(in: visibleRect)
        var itemsIndexPathsInVisibleRectSet = Set<IndexPath>.init()

        itemsInVisibleRectArray?.forEach({ (item) in
            itemsIndexPathsInVisibleRectSet.insert(item.indexPath)
        })

        // Step 1: Remove any behaviours that are no longer visible.
        let noLongerVisibleBehaviours = (dynamicAnimator?.behaviors)?.filter({ (behavior) -> Bool in
            let currentlyVisible = itemsIndexPathsInVisibleRectSet.contains(((behavior as! UIAttachmentBehavior).items.first as! UICollectionViewLayoutAttributes).indexPath)
            return !currentlyVisible
        })
        noLongerVisibleBehaviours?.forEach({ (behavior) in
            dynamicAnimator?.removeBehavior(behavior)
            visibleIndexPathsSet.remove(((behavior as! UIAttachmentBehavior).items.first as! UICollectionViewLayoutAttributes).indexPath)
        })

        // Step 2: Add any newly visible behaviours.
        // A "newly visible" item is one that is in the itemsInVisibleRect(Set|Array) but not in the visibleIndexPathsSet
        let newlyVisibleItems = itemsInVisibleRectArray?.filter({ (item) -> Bool in
            let currentlyVisible = self.visibleIndexPathsSet.member((item).indexPath) != nil
            return !currentlyVisible
        })
        let touchLocation = collectionView?.panGestureRecognizer.location(in: collectionView)

        newlyVisibleItems?.forEach({ (item) in
            var center = item.center
            let springBehaviour = UIAttachmentBehavior.init(item: item, attachedToAnchor: center)
            springBehaviour.length = 0.0
            springBehaviour.damping = 0.8
            springBehaviour.frequency = 1.5

            // If our touchLocation is not (0,0), we'll need to adjust our item's center "in flight"
            if (touchLocation?.equalTo(.zero))! {
                let yDistanceFromTouch = fabs(touchLocation!.y - springBehaviour.anchorPoint.y)
                let xDistanceFromTouch = fabs(touchLocation!.x - springBehaviour.anchorPoint.x)
                let scrollResistance = (yDistanceFromTouch + xDistanceFromTouch) / CollectionViewDynamicLayout.scrollResistanceRatio

                if latestDelta! < CGFloat(0) {
                    center.y += max(latestDelta!, latestDelta!*scrollResistance)
                } else {
                    center.y += min(latestDelta!, latestDelta!*scrollResistance)
                }
                item.center = center
            }
            dynamicAnimator?.addBehavior(springBehaviour)
            visibleIndexPathsSet.add(item.indexPath)
        })
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return dynamicAnimator?.items(in: rect) as! [UICollectionViewLayoutAttributes]?
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return dynamicAnimator?.layoutAttributesForCell(at: indexPath)
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {

        let delta = newBounds.origin.y - (collectionView?.bounds.origin.y)!
        latestDelta = delta
        let touchLocation = collectionView!.panGestureRecognizer.location(in: collectionView)

        for springBehaviour in dynamicAnimator!.behaviors as! [UIAttachmentBehavior] {
            let yDistanceFromTouch = fabs(touchLocation.y - springBehaviour.anchorPoint.y)
            let xDistanceFromTouch = fabs(touchLocation.x - springBehaviour.anchorPoint.x)
            let scrollResistance = (yDistanceFromTouch + xDistanceFromTouch) / CollectionViewDynamicLayout.scrollResistanceRatio

            let item = springBehaviour.items.first as! UICollectionViewLayoutAttributes
            var center = item.center
            if delta < CGFloat(0) {
                center.y += max(delta, delta*scrollResistance)
            } else {
                center.y += min(delta, delta*scrollResistance)
            }
            item.center = center
            dynamicAnimator?.updateItem(usingCurrentState: item)
        }
        return false
    }

}
