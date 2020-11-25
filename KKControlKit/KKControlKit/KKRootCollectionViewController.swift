//
//  KKRootCollectionViewController.swift
//  KKControlKit
//
//  Created by liaozhenming on 2020/11/25.
//

import UIKit

private let reuseIdentifier = "Cell"

class KCBaseCollectionViewCell: UICollectionViewCell {
    public var cellItem: KCListViewCellItem?{
        didSet{
            self.kc_updateUI()
            
            if cellItem!.autoCellHeight {
                let tmpHeight = self.contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
                print("自定适应之后的高度:\(tmpHeight)")
            }
        }
    }
    public func kc_updateUI(){}
}

class KCRootCollecetionViewCell: KCBaseCollectionViewCell {
    @IBOutlet weak var img_item: UIImageView!
    @IBOutlet weak var lab_title: UILabel!
    
    override func kc_updateUI() {
        self.lab_title.text = self.cellItem?.content
        self.img_item.image = self.cellItem?.image
    }
}


class KKRootCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {

    private var arr_cellItems: [KCListViewCellItem] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "UICollectionView"
        
//        let layout = self.collectionView.collectionViewLayout as! UICollectionViewFlowLayout
//        layout.estimatedItemSize = CGSize.init(width: UIScreen.main.bounds.width, height: 10)
        
        self.collectionView.kc_registerHeaderRefreshEvent {
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.arr_cellItems.removeAll()
                self.private_loadingTableViewData()
                self.collectionView.kc_endRefresh()
            }
        } andFooterRefreshEvent: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.private_loadingTableViewData()
                self.collectionView.kc_endRefresh()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.collectionView.headerRefreshView?.beginRefreshing()
    }

    private func private_loadingTableViewData(){
        for index in 0..<20 {
            self.arr_cellItems.append(KCTestDataManager.kc_getCellItem(index: index))
        }
    }
    
    // MARK: UICollectionViewDataSource
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of items
        return self.arr_cellItems.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! KCRootCollecetionViewCell
        cell.cellItem = self.arr_cellItems[indexPath.row]
        return cell
    }
    
    // MARK: UICollectionViewDelegate
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
//        return CGSize.init(width: UIScreen.main.bounds.width - 20, height: 10)
//    }
    
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
//        return UIEdgeInsets.init(top: 0, left: 10, bottom: 0, right: 10)
//    }
}
