//
//  KCListViewModels.swift
//  KKControlKit
//
//  Created by liaozhenming on 2020/11/25.
//

import UIKit

@objcMembers class KCListViewCellItem: NSObject {
    //  UITableViewCell的高度是否自动适应
    public var autoCellHeight: Bool = false
    //  UITableViewCell的高度
    public var cellHeight: CGFloat = 0.0
    
    //  UICollectionViewCell的大小是否自动适应
    public var autoCellSize: Bool = false
    //  UICollectionViewCell的大小
    public var cellSize: CGSize = .zero
    
    
    public var identifier: String = ""
    public var cellIdentifier: String = ""
    
    public var title: String = ""
    public var content: String = ""
    public var image: UIImage?
}
