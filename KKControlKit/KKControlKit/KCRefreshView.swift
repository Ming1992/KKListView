//
//  KCRefreshView.swift
//  Swift_Demo
//
//  Created by liaozhenming on 2020/5/12.
//  Copyright © 2020 kangcun2019. All rights reserved.
//

import UIKit

let KCRefreshKeyPathContentOffset = "contentOffset"
let KCRefreshKeyPathContentSize = "contentSize"
let KCRefreshKeyPathPanState = "state"

let KCRefreshLastUpdatedTimeKey = "KCRefreshLastUpdatedTimeKey"
let KCRefreshHeaderHeight: CGFloat = 54.0
let KCRefreshFooterHeight: CGFloat = 44.0

typealias KCRefreshRefreshingBlock = (()->())

//  刷新的状态码
enum KCRefreshState : Int {
    case normal = 1         //  闲置状态
    case pulling = 2        //  松开就可以进行刷新状态
    case refreshing = 3     //  正在刷新中
    case willRefresh = 4    //  即将刷新
    case noMoreData = 5     //  没有更多的数据
}


class KCRefreshBaseView: UIView {
    
    fileprivate var scrollViewOriginalInsets: UIEdgeInsets = .zero
    fileprivate weak var scrollView: UIScrollView?
    fileprivate var pan: UIPanGestureRecognizer?
    
    fileprivate var refreshingBlock: KCRefreshRefreshingBlock?
    
    public var isRefreshing: Bool{
        get{
            return self.state == .refreshing || self.state == .willRefresh
        }
    }
    public var state: KCRefreshState = .normal{
        didSet{
            OperationQueue.main.addOperation {
                self.setNeedsLayout()
            }
        }
    }
    
    //  MARK: methods
    init(frame:CGRect = .zero, refreshingBlock:@escaping KCRefreshRefreshingBlock) {
        super.init(frame: frame)
        self.refreshingBlock = refreshingBlock
        self.prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.prepare()
        self.state = .normal
    }
    
    override func layoutSubviews() {
        self.placeSubviews()
        super.layoutSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        if self.state == .willRefresh {
            self.state = .refreshing
        }
    }
    
    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        
        if newSuperview != nil && !(newSuperview?.isKind(of: UIScrollView.self))! {
            return
        }
        self.removeObservers()
        
        if newSuperview != nil {
            self.scrollView = (newSuperview as! UIScrollView)
            
            //  设置当前组件的位置和大小
            let width = self.scrollView?.bounds.width
            let offsetX = self.scrollView?.frame.minX
            self.frame = CGRect.init(x: offsetX!, y: self.frame.minY, width: width!, height: self.frame.height)
            
            self.scrollView!.alwaysBounceVertical = true
            self.scrollViewOriginalInsets = self.scrollView!.kc_contentInset
            self.addObservers()
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if self.isUserInteractionEnabled == false {
            return
        }
        if keyPath == KCRefreshKeyPathContentSize {
            self.scrollViewContentSizeDidChange(change: change!)
        }
        if self.isHidden {
            return
        }
        if keyPath == KCRefreshKeyPathContentOffset {
            self.scrollViewContentOffsetDidChange(change: change!)
        }else if keyPath == KCRefreshKeyPathPanState {
            self.scrollViewPanStateDidChange(change: change!)
        }
    }
    //  MARK:   交给子类去访问 methods
    fileprivate func executeRefreshingCallback(){
        OperationQueue.main.addOperation {
            if self.refreshingBlock != nil {
                self.refreshingBlock!()
            }
        }
    }
    fileprivate func prepare(){
        autoresizingMask = .flexibleWidth
        backgroundColor = .clear
    }
    fileprivate func placeSubviews(){}
    fileprivate func scrollViewContentSizeDidChange(change:[NSKeyValueChangeKey : Any]){}
    fileprivate func scrollViewContentOffsetDidChange(change:[NSKeyValueChangeKey : Any]){}
    fileprivate func scrollViewPanStateDidChange(change:[NSKeyValueChangeKey : Any]){}
    
    //  MARK:   公开方法 methods
    public func beginRefreshing(){
        if self.window != nil{
            self.state = .refreshing
        }
        else {
            if self.state != .refreshing {
                self.state = .willRefresh
                self.setNeedsDisplay()
            }
        }
    }
    public func endRefreshing(more:Bool = true){
        OperationQueue.main.addOperation {
            if self.scrollView is UITableView {
                (self.scrollView as! UITableView).reloadData()
            }
            else if self.scrollView is UICollectionView {
                
                CATransaction.setDisableActions(true)
                (self.scrollView as! UICollectionView).reloadData()
                CATransaction.commit()
            }
            self.state = more ? .normal : .noMoreData
        }
    }

    //  MARK:   私有方法 methods
    private func addObservers(){
        //  增加监控事件
        self.scrollView?.addObserver(self, forKeyPath: KCRefreshKeyPathContentOffset, options: [.old,.new], context: nil)
        self.scrollView?.addObserver(self, forKeyPath: KCRefreshKeyPathContentSize, options: [.new,.old], context: nil)
        self.pan = self.scrollView?.panGestureRecognizer
        self.pan?.addObserver(self, forKeyPath: KCRefreshKeyPathPanState, options: [.new,.old], context: nil)
    }
    private func removeObservers(){
        //  移除监控事件
        self.scrollView?.removeObserver(self, forKeyPath: KCRefreshKeyPathContentSize)
        self.scrollView?.removeObserver(self, forKeyPath: KCRefreshKeyPathContentOffset)
        self.pan?.removeObserver(self, forKeyPath: KCRefreshKeyPathPanState)
        self.pan = nil
    }
}

//  MARK: KCRefresh-Header class
class KCRefreshHeaderBaseView: KCRefreshBaseView {
    public var ignoredScrollViewContentInsetTop: CGFloat = 0.0
    private var insetTDelta: CGFloat = 0.0
    
    public var lastUpdatedTime: String{
        get{
            let tmpDate = UserDefaults.standard.object(forKey: KCRefreshLastUpdatedTimeKey)
            let timeDate = tmpDate is Date ? tmpDate as! Date : Date.init()
            let dateFormatter = DateFormatter.init()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return dateFormatter.string(from: timeDate)
        }
    }
    
    override var state: KCRefreshState{
        didSet{
            if state == oldValue {
                return
            }
            if state == .normal{
                if oldValue != .refreshing { return }
                self.headerEndingAction()
            }else if state == .refreshing {
                self.headerRefreshingAction()
            }
        }
    }
    
    override func prepare() {
        super.prepare()
        self.frame = CGRect.init(x: self.frame.minX, y: self.frame.minY, width: self.frame.width, height: KCRefreshHeaderHeight)
        self.backgroundColor = .clear
    }
    override func placeSubviews() {
        super.placeSubviews()
        let pointY = (self.frame.height + self.ignoredScrollViewContentInsetTop)
        self.frame = CGRect.init(x: self.frame.minX, y: -pointY, width: self.frame.width, height: self.frame.height)
    }
    
    override func scrollViewContentOffsetDidChange(change: [NSKeyValueChangeKey : Any]) {
        super.scrollViewContentOffsetDidChange(change: change)
        if self.state == .refreshing {
            self.resetInset()
            return
        }
        //  此处使用extension来获取contentInset，是为了适配iOS11.0以后的safeInset
        self.scrollViewOriginalInsets = self.scrollView!.kc_contentInset
        let offsetY = self.scrollView!.contentOffset.y
        let happenOffsetY = -self.scrollViewOriginalInsets.top
        if offsetY > happenOffsetY { return }
        
        let normal2pullingOffsetY = happenOffsetY - self.bounds.height
        if self.scrollView!.isDragging {
            if self.state == .normal && offsetY < normal2pullingOffsetY {
                self.state = .pulling
            }else if self.state == .pulling && offsetY >= normal2pullingOffsetY {
                self.state = .normal
            }
        }else if self.state == .pulling {
            self.beginRefreshing()
        }
    }
    
    private func resetInset(){
        if #available(iOS 11.0, *) {}
        else {
            if self.window == nil { return }
        }
        let offsetY = -(self.scrollView!.contentOffset.y)
        let insetTop = self.scrollViewOriginalInsets.top
        var insetT = max(offsetY, insetTop)
        let tmpHeight = self.bounds.height + self.scrollViewOriginalInsets.top
        insetT = min(insetT, tmpHeight)
        self.insetTDelta = self.scrollViewOriginalInsets.top - insetT
    }
    private func headerEndingAction(){
        UserDefaults.standard.setValue(Date(), forKeyPath: KCRefreshLastUpdatedTimeKey)
        UserDefaults.standard.synchronize()
        
        UIView.animate(withDuration: 0.4) {
            self.scrollView?.kc_contentInsetTop += self.insetTDelta
        } completion: { (finished) in
            
        }
    }
    private func headerRefreshingAction(){
        OperationQueue.main.addOperation {
            UIView.animate(withDuration: 0.25) {
                let top = self.scrollViewOriginalInsets.top + self.bounds.height
                self.scrollView?.kc_contentInsetTop = top
                var offset = self.scrollView!.contentOffset
                offset.y = -top
                self.scrollView?.setContentOffset(offset, animated: false)
            } completion: { (finished) in
                self.executeRefreshingCallback()
            }
        }
    }
}

class KCRefreshNormalHeaderView: KCRefreshHeaderBaseView {
    private var arrow_item: UIImageView = UIImageView.init()
    public var loadingView: UIActivityIndicatorView!
    public var lab_time: UILabel = UILabel.init()
    public var lab_title: UILabel = UILabel.init()
    
    override func prepare() {
        super.prepare()
        
        if #available(iOS 13.0, *) {
            self.loadingView = UIActivityIndicatorView.init(style: .medium)
        }
        else {
            self.loadingView = UIActivityIndicatorView.init(style: .gray)
        }
        
        self.lab_title.frame = CGRect.init(x: 0, y: 0, width: self.bounds.width, height: 20)
        self.lab_title.backgroundColor = .clear
        self.lab_title.textColor = .darkGray
        self.lab_title.textAlignment = .center
        self.lab_title.font = UIFont.systemFont(ofSize: 13)
        self.lab_title.autoresizingMask = [.flexibleWidth]
        self.lab_title.text = "正在加载中..."
        addSubview(self.lab_title)
        
        self.lab_time.frame = CGRect.init(x: 0, y: 0, width: self.bounds.width, height: 20)
        self.lab_time.backgroundColor = .clear
        self.lab_time.textColor = .lightGray
        self.lab_time.textAlignment = .center
        self.lab_time.font = UIFont.systemFont(ofSize: 13)
        self.lab_time.autoresizingMask = [.flexibleWidth]
        self.lab_time.text = self.lastUpdatedTime
        addSubview(self.lab_time)
        
        addSubview(self.loadingView)
    }
    
    override func placeSubviews() {
        super.placeSubviews()
        
        let centerX = self.bounds.width * 0.5
        let centerY = self.bounds.height * 0.5
        
        self.loadingView.center = CGPoint.init(x: centerX - 35, y: centerY - 5)
        self.lab_title.center = CGPoint.init(x: centerX + 20, y: centerY - 5)
        self.lab_time.center = CGPoint.init(x: centerX, y: centerY + 15)
    }
    
    override var state: KCRefreshState{
        didSet{
            if self.state == .normal {
                self.lab_time.text = self.lastUpdatedTime
            }
            else {
                self.loadingView.startAnimating()
            }
        }
    }
}

//  MARK: KCRefresh-Footer class
class KCRefreshFooterBaseView: KCRefreshBaseView {
    public var ignoredScrollViewContentInsetBottom: CGFloat = 0.0
    
    override func prepare() {
        super.prepare()
        self.frame = CGRect.init(x: self.frame.minX, y: self.frame.minY, width: self.frame.width, height: KCRefreshFooterHeight)
        self.backgroundColor = .clear
    }
    
    override func placeSubviews() {
        super.placeSubviews()
        
        let contentHeight = self.scrollView!.contentSize.height + self.scrollView!.kc_contentInsetBottom + self.scrollView!.kc_contentInsetTop
        let boundsHeight = self.scrollView!.bounds.height
        self.isHidden = contentHeight >= boundsHeight ? false : true
    }
}

class KCRefreshFooterView: KCRefreshFooterBaseView {
    private var titleLabel: UILabel = UILabel.init()
    public var loadingActivity: UIActivityIndicatorView!
    public var updateTipLabel: UILabel = UILabel.init()
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let centerX = self.bounds.width * 0.5
        let centerY = self.bounds.height * 0.5
        
        self.loadingActivity.center = CGPoint.init(x: centerX - 35, y: centerY)
        self.titleLabel.center = CGPoint.init(x: centerX + 20, y: centerY)
    }
    
    override func prepare() {
        super.prepare()
        
        if #available(iOS 13.0, *) {
            self.loadingActivity = UIActivityIndicatorView.init(style: .medium)
        }
        else {
            self.loadingActivity = UIActivityIndicatorView.init(style: .gray)
        }
        
        self.titleLabel.frame = CGRect.init(x: 0, y: 0, width: self.bounds.width, height: 20)
        self.titleLabel.backgroundColor = .clear
        self.titleLabel.textColor = .darkGray
        self.titleLabel.textAlignment = .center
        self.titleLabel.font = UIFont.systemFont(ofSize: 13)
        self.titleLabel.text = "推荐更多中..."
        self.titleLabel.autoresizingMask = [.flexibleWidth]
        addSubview(self.titleLabel)
       
        self.loadingActivity.center = CGPoint.init(x: self.bounds.width/2 - 35, y: self.bounds.height/2 - 5)
        self.loadingActivity.hidesWhenStopped = false
        addSubview(self.loadingActivity)
       
        self.updateTipLabel.frame = CGRect.init(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
        self.updateTipLabel.backgroundColor = .clear
        self.updateTipLabel.textColor = .lightGray
        self.updateTipLabel.font = UIFont.systemFont(ofSize: 13)
        self.updateTipLabel.textAlignment = .center
        self.updateTipLabel.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        self.updateTipLabel.text = "已全部加载完毕"
        self.updateTipLabel.isHidden = true
        addSubview(self.updateTipLabel)
    }
    
    override var state: KCRefreshState{
        didSet{
            self.updateTipLabel.isHidden = state == .noMoreData ? false : true
            self.titleLabel.isHidden = state == .noMoreData ? true : false
            self.loadingActivity.isHidden = state == .noMoreData ? true : false
            
            if state == .refreshing {
                self.loadingActivity.startAnimating()
            }
            else {
                self.loadingActivity.stopAnimating()
            }
        }
    }
}

class KCRefreshBackFooterView: KCRefreshFooterView {
    fileprivate var lastRefreshCount: Int = 0
    fileprivate var lastBottomDelta: CGFloat = 0.0
    
    private func heightForContentBreakView()->CGFloat {
        let tmpHeight = self.scrollView!.frame.height - self.scrollViewOriginalInsets.bottom - self.scrollViewOriginalInsets.top
        return self.scrollView!.contentSize.height - tmpHeight
    }
    private func happenOffsetY()->CGFloat{
        let deltaH = self.heightForContentBreakView()
        if deltaH > 0 {
            return deltaH - self.scrollViewOriginalInsets.top
        }
        else {
            return 0 - self.scrollViewOriginalInsets.top
        }
    }
    
    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        self.scrollViewContentSizeDidChange(change: [:])
    }
    
    override func scrollViewContentSizeDidChange(change: [NSKeyValueChangeKey : Any]) {
        super.scrollViewContentSizeDidChange(change: change)
        
        let contentHeight = self.scrollView!.contentSize.height + self.ignoredScrollViewContentInsetBottom
        let scrollHeight = self.scrollView!.frame.height - self.scrollViewOriginalInsets.top - self.scrollViewOriginalInsets.bottom + self.ignoredScrollViewContentInsetBottom
        let pointY = max(contentHeight, scrollHeight)
        // 设置位置和尺寸
        self.frame = CGRect.init(x: self.frame.minX, y: pointY, width: self.frame.width, height: self.frame.height)
        
        self.placeSubviews()
    }
    
    override func scrollViewContentOffsetDidChange(change: [NSKeyValueChangeKey : Any]) {
        super.scrollViewContentOffsetDidChange(change: change)
        if self.state == .refreshing { return }
        
        self.scrollViewOriginalInsets = self.scrollView!.kc_contentInset
        // 当前的contentOffset
        let currentOffsetY = self.scrollView!.contentOffset.y
        // 尾部控件刚好出现的offsetY
        let happenOffsetY = self.happenOffsetY()
        //  如果是向下滚动到看不见尾部控件，直接返回
        if currentOffsetY <= happenOffsetY { return }
        
        if self.scrollView!.isDragging {
            let normal2pullingOffsetY = happenOffsetY + self.bounds.height
            if self.state == .normal && currentOffsetY > normal2pullingOffsetY {
                self.state = .pulling
            } else if self.state == .pulling && currentOffsetY <= normal2pullingOffsetY {
                self.state = .normal
            }
        }else if self.state == .pulling {
            self.beginRefreshing()
        }
    }
    
    override var state: KCRefreshState{
        didSet{
            if state == .noMoreData || state == .normal {
                if oldValue == .refreshing {
                    UIView.animate(withDuration: 0.4) {
                        self.scrollView?.kc_contentInsetBottom -= self.lastBottomDelta
                    } completion: { (finished) in
                        
                    }
                }
                let deltaH = self.heightForContentBreakView()
                if oldValue == .refreshing && deltaH > 0 && self.scrollView!.kc_totalDataCount != self.lastRefreshCount{
                    self.scrollView?.contentOffset = self.scrollView!.contentOffset
                }
            }else if state == .refreshing {
                
                self.lastRefreshCount = self.scrollView!.kc_totalDataCount
                
                UIView.animate(withDuration: 0.25) {
                    var bottom = self.bounds.height + self.scrollViewOriginalInsets.bottom
                    let deltaH = self.heightForContentBreakView()
                    if deltaH < 0 {
                        bottom -= deltaH
                    }
                    self.lastBottomDelta = bottom - self.scrollView!.kc_contentInsetBottom
                    self.scrollView!.kc_contentInsetBottom = bottom
                    
                    var tmpOffset = self.scrollView!.contentOffset
                    tmpOffset.y = self.happenOffsetY() + self.bounds.height
                    self.scrollView?.contentOffset = tmpOffset
                } completion: { (finished) in
                    self.executeRefreshingCallback()
                }
            }
        }
    }
}

class KCRefreshAutoFooterView: KCRefreshFooterView {
    /** 当底部控件出现多少时就自动刷新(默认为1.0，也就是底部控件完全出现时，才会自动刷新) */
    public var triggerAutomaticallyRefreshPercent: CGFloat = 1.0
    public var autoTriggerTimes: Int = 1{
        didSet{
            self.leftTriggerTimes = autoTriggerTimes
        }
    }
    private var triggerByDrag: Bool = false
    private var leftTriggerTimes: Int = 0
    private var unlimitedTrigger:Bool{
        get{
            return self.leftTriggerTimes == -1
        }
    }
    
    override var isHidden: Bool{
        didSet{
            if !oldValue && isHidden {
                self.state = .normal
                self.scrollView?.kc_contentInsetBottom -= self.bounds.height
            }else if oldValue && !isHidden {
                self.scrollView?.kc_contentInsetBottom += self.bounds.height
                self.frame = CGRect.init(x: self.frame.minX, y: self.scrollView!.contentSize.height, width: self.frame.width, height: self.frame.height)
            }
        }
    }
    
    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        if newSuperview != nil {
            if self.isHidden == false {
                self.scrollView?.kc_contentInsetBottom += self.bounds.height
            }
            self.frame = CGRect.init(x: self.frame.minX, y: self.scrollView!.contentSize.height, width: self.frame.width, height: self.frame.height)
        }
        else {
            if self.isHidden == false {
                self.scrollView?.kc_contentInsetBottom -= self.bounds.height
            }
        }
    }
    
    override func scrollViewContentSizeDidChange(change: [NSKeyValueChangeKey : Any]) {
        super.scrollViewContentSizeDidChange(change: change)
        
        let pointY = self.scrollView!.contentSize.height + self.ignoredScrollViewContentInsetBottom
        self.frame = CGRect.init(x: self.frame.minX, y: pointY, width: self.frame.width, height: self.frame.height)
        
        self.placeSubviews()
    }
    
    override func scrollViewContentOffsetDidChange(change: [NSKeyValueChangeKey : Any]) {
        super.scrollViewContentOffsetDidChange(change: change)
        
        if self.state != .normal || self.frame.minY == 0 {
            return
        }
        
        let insetTop = self.scrollView!.kc_contentInsetTop
        let contentH = self.scrollView!.contentSize.height
        //内容超过一个屏幕
        if insetTop + contentH > self.scrollView!.bounds.height {
            let offsetY = self.scrollView!.contentOffset.y
            if offsetY >= self.scrollView!.contentSize.height - self.scrollView!.bounds.height + self.bounds.height * (1.0 - self.triggerAutomaticallyRefreshPercent) + self.scrollView!.kc_contentInsetBottom {
                let old = change[.oldKey] as! CGPoint
                let new = change[.newKey] as! CGPoint
                if new.y <= old.y { return }
                
                if self.scrollView!.isDragging {
                    self.triggerByDrag = true
                }
                
                self.beginRefreshing()
            }
        }
    }
    
    override func scrollViewPanStateDidChange(change: [NSKeyValueChangeKey : Any]) {
        super.scrollViewPanStateDidChange(change: change)
        
        if self.state != .normal { return }
        
        let panState = self.scrollView!.panGestureRecognizer.state
        switch panState {
        case .ended:
            if self.scrollView!.kc_contentInsetTop + self.scrollView!.contentSize.height <= self.scrollView!.bounds.height {
                if self.scrollView!.contentOffset.y >= -self.scrollView!.kc_contentInsetTop {
                    self.triggerByDrag = true
                    self.beginRefreshing()
                }
            }
            else {
                if self.scrollView!.contentOffset.y >= self.scrollView!.contentSize.height + self.scrollView!.kc_contentInsetBottom - self.scrollView!.bounds.height {
                    self.triggerByDrag = true
                    self.beginRefreshing()
                }
            }
            break
        case .began:
            self.resetTriggerTimes()
            break
        default:
            break
        }
    }
    
    override func beginRefreshing() {
        if self.triggerByDrag && self.leftTriggerTimes <= 0 && !self.unlimitedTrigger {
            return
        }
        super.beginRefreshing()
    }
    
    override var state: KCRefreshState{
        didSet{
            if state == .refreshing {
                self.executeRefreshingCallback()
            }else if(state == .noMoreData || state == .normal){
                if self.triggerByDrag {
                    if !self.unlimitedTrigger {
                        self.leftTriggerTimes -= 1
                    }
                    self.triggerByDrag = false
                }
                
                if oldValue == .refreshing {
                    if self.scrollView!.isPagingEnabled {
                        var offset = self.scrollView!.contentOffset
                        offset.y -= self.scrollView!.kc_contentInsetBottom
                        UIView.animate(withDuration: 0.4) {
                            self.scrollView?.contentOffset = offset
                        } completion: { (finished) in
                            
                        }
                    }
                }
            }
        }
    }
    
    private func resetTriggerTimes(){
        self.leftTriggerTimes = self.autoTriggerTimes
    }
}


//  MAKR:   UIScrollView--Extension 类
private struct UIScrollViewRefreshKeys{
    static var headerRefreshViewName = "kc_headerRefreshViewName"
    static var footerRefreshViewName = "kc_footerRefreshViewName"
}

extension UIScrollView {
    
    var headerRefreshView:KCRefreshHeaderBaseView?{
        set{
            objc_setAssociatedObject(self, &UIScrollViewRefreshKeys.headerRefreshViewName, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get{
            return objc_getAssociatedObject(self, &UIScrollViewRefreshKeys.headerRefreshViewName) as? KCRefreshHeaderBaseView
        }
    }
    
    var footerRefreshView:KCRefreshFooterView?{
        set{
            objc_setAssociatedObject(self, &UIScrollViewRefreshKeys.footerRefreshViewName, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get{
            return objc_getAssociatedObject(self, &UIScrollViewRefreshKeys.footerRefreshViewName) as? KCRefreshFooterView
        }
    }
    
    var isRefreshing:Bool{
        get{
            var tmpRefreshing = false
            if self.headerRefreshView != nil {
                tmpRefreshing = tmpRefreshing || self.headerRefreshView!.state == .refreshing
            }
            if self.footerRefreshView != nil {
                tmpRefreshing = tmpRefreshing || self.footerRefreshView!.state == .refreshing
            }
            return tmpRefreshing
        }
    }
    
    //  注册下拉刷新功能
    @discardableResult func kc_registerHeaderRefreshEvent(refreshing:@escaping KCRefreshRefreshingBlock) ->KCRefreshHeaderBaseView{
        self.headerRefreshView = KCRefreshNormalHeaderView.init(frame: CGRect.init(x: 0, y: 0, width: self.bounds.width, height: KCRefreshHeaderHeight), refreshingBlock: refreshing)
        self.insertSubview(self.headerRefreshView!, at: 0)
        return self.headerRefreshView!
    }
    
    //  注册上拉加载更多功能
    @discardableResult func kc_registerFooterRefreshEvent(refreshing:@escaping KCRefreshRefreshingBlock) ->KCRefreshFooterView {
        self.footerRefreshView = KCRefreshBackFooterView.init(frame: CGRect.init(x: 0, y: 0, width: self.bounds.width, height: KCRefreshFooterHeight), refreshingBlock: refreshing)
        self.addSubview(self.footerRefreshView!)
        return self.footerRefreshView!
    }
    
    //  注册上拉自动加载更多功能
    @discardableResult func kc_registerFooterAutoRefreshEvent(refreshing:@escaping KCRefreshRefreshingBlock) ->KCRefreshFooterView {
        self.footerRefreshView = KCRefreshAutoFooterView.init(frame: CGRect.init(x: 0, y: 0, width: self.bounds.width, height: KCRefreshFooterHeight), refreshingBlock: refreshing)
        self.addSubview(self.footerRefreshView!)
        return self.footerRefreshView!
    }
    
    func kc_registerHeaderRefreshEvent(headerRefreshing:@escaping KCRefreshRefreshingBlock, andFooterRefreshEvent footerRefreshing:@escaping KCRefreshRefreshingBlock){
        self.headerRefreshView = KCRefreshNormalHeaderView.init(frame: CGRect.init(x: 0, y: 0, width: self.bounds.width, height: KCRefreshHeaderHeight), refreshingBlock: headerRefreshing)
        self.insertSubview(self.headerRefreshView!, at: 0)
        
        self.footerRefreshView = KCRefreshBackFooterView.init(frame: CGRect.init(x: 0, y: 0, width: self.bounds.width, height: KCRefreshFooterHeight), refreshingBlock: footerRefreshing)
        self.addSubview(self.footerRefreshView!)
    }
    
    
    func kc_endRefresh(moreData:Bool = true){
        //  此方法相当于 先调用了 reloadData方法，再把state的状态修改

        if self.headerRefreshView != nil {
            if self.headerRefreshView!.isRefreshing {
                self.headerRefreshView?.endRefreshing()
            }
        }

        if self.footerRefreshView != nil {
            if self.footerRefreshView!.isRefreshing {
                self.footerRefreshView?.endRefreshing(more: moreData)
            }
        }
    }
    
    //  MARK: extension - fileprivate variable
    fileprivate var kc_contentInset: UIEdgeInsets{
        set{
            self.contentInset = newValue
        }
        get{
            if #available(iOS 11.0, *) {
                return self.adjustedContentInset
            }
            else {
                return self.contentInset
            }
        }
    }
    
    fileprivate var kc_contentInsetTop: CGFloat{
        set{
            var inset = self.contentInset
            inset.top = newValue
            if #available(iOS 11.0, *) {
                inset.top -= (self.adjustedContentInset.top - self.contentInset.top)
            }
            self.contentInset = inset
        }
        get{
            return self.kc_contentInset.top
        }
    }
    
    fileprivate var kc_contentInsetBottom: CGFloat{
        set{
            var inset = self.contentInset
            inset.bottom = newValue
            if #available(iOS 11.0, *) {
                inset.bottom -= (self.adjustedContentInset.bottom - self.contentInset.bottom)
            }
            self.contentInset = inset
        }
        get{
            return self.kc_contentInset.bottom
        }
    }
    
    fileprivate var kc_totalDataCount: NSInteger {
        get{
            var totalCount = 0
            if self is UITableView {
                let tmpTableView = self as! UITableView
                for section in 0..<tmpTableView.numberOfSections {
                    totalCount += tmpTableView.numberOfRows(inSection: section)
                }
            }else if self is UICollectionView {
                let tmpCollectionView = self as! UICollectionView
                for section in 0..<tmpCollectionView.numberOfSections {
                    totalCount += tmpCollectionView.numberOfItems(inSection: section)
                }
            }
            return totalCount
        }
    }
}

