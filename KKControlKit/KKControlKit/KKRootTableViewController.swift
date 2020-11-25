//
//  KKRootTableViewController.swift
//  KKControlKit
//
//  Created by liaozhenming on 2020/11/25.
//

import UIKit

class KCBaseTableViewCell: UITableViewCell {
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

class KKRootTableViewCell: KCBaseTableViewCell {
    @IBOutlet weak var lab_content: UILabel!
    
    override func kc_updateUI() {
        self.lab_content.text = self.cellItem?.content
    }
}


class KKRootTableViewController: UITableViewController {

    private var arr_cellItems: [KCListViewCellItem] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "UITableView"
        self.tableView.tableFooterView = UIView.init()
        
        self.tableView.kc_registerHeaderRefreshEvent {
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.arr_cellItems.removeAll()
                self.private_loadingTableViewData()
                self.tableView.kc_endRefresh()
            }
        } andFooterRefreshEvent: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.private_loadingTableViewData()
                self.tableView.kc_endRefresh()
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.tableView.headerRefreshView?.beginRefreshing()
    }
    
    private func private_loadingTableViewData(){
        for index in 0..<20 {
            self.arr_cellItems.append(KCTestDataManager.kc_getCellItem(index: index))
        }
    }
    

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return self.arr_cellItems.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath) as!KKRootTableViewCell

        // Configure the cell...
        
        let cellItem = self.arr_cellItems[indexPath.row]
        cell.cellItem = cellItem
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        print("...cell.bounds:\(cell.bounds)")
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}
