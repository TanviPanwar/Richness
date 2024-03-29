//
//  YYPPickerVC.swift
//  YPPickerVC
//
//  Created by Sacha Durand Saint Omer on 25/10/16.
//  Copyright © 2016 Yummypets. All rights reserved.
//

import Foundation
//import Stevia
import Photos

protocol ImagePickerDelegate: AnyObject {
    func noPhotos()
}

public class YPPickerVC: YPBottomPager, YPBottomPagerDelegate , PostVideoDelegate{
    func navigateToHome() {
        //ProjectManager.shared.refreshHomeDelegate?.refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: {
            self.dismiss(animated: false, completion: nil)

        })
    }
    
    
    let albumsManager = YPAlbumsManager()
    var shouldHideStatusBar = false
    var initialStatusBarHidden = false
    weak var imagePickerDelegate: ImagePickerDelegate?
    
    override public var prefersStatusBarHidden: Bool {
        return (shouldHideStatusBar || initialStatusBarHidden) && YPConfig.hidesStatusBar
    }
    
    /// Private callbacks to YPImagePicker
    public var didClose:(() -> Void)?
    public var didSelectItems: (([YPMediaItem]) -> Void)?
    
    enum Mode {
        case library
        case camera
        case video
    }
    
    private var libraryVC: YPLibraryVC?
    private var cameraVC: YPCameraVC?
    private var videoVC: YPVideoCaptureVC?
    
    var mode = Mode.camera
    
    var capturedImage: UIImage?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(r: 247, g: 247, b: 247)
        ProjectManager.shared.postVideoDelegate = self
        delegate = self
        // Force Library only when using `minNumberOfItems`.
        if YPConfig.library.minNumberOfItems > 1 {
            YPImagePickerConfiguration.shared.screens = [.library]
        }
        
        // Library
        if YPConfig.screens.contains(.library) {
            libraryVC = YPLibraryVC()
            libraryVC?.delegate = self
        }
        
        // Camera
        if YPConfig.screens.contains(.photo) {
            cameraVC = YPCameraVC()
            cameraVC?.didCapturePhoto = { [weak self] img in
                self?.didSelectItems?([YPMediaItem.photo(p: YPMediaPhoto(image: img,
                                                                        fromCamera: true))])
            }
        }
        
        // Video
        if YPConfig.screens.contains(.video) {
            videoVC = YPVideoCaptureVC()
            videoVC?.didCaptureVideo = { [weak self] videoURL in
                self?.didSelectItems?([YPMediaItem
                    .video(v: YPMediaVideo(thumbnail: thumbnailFromVideoPath(videoURL),
                                           videoURL: videoURL,
                                           fromCamera: true))])
            }
        }
        
        // Show screens
        var vcs = [UIViewController]()
        for screen in YPConfig.screens {
            switch screen {
            case .library:
                if let libraryVC = libraryVC {
                    vcs.append(libraryVC)
                }
            case .photo:
                if let cameraVC = cameraVC {
                    vcs.append(cameraVC)
                }
            case .video:
                if let videoVC = videoVC {
                    vcs.append(videoVC)
                }
            }
        }
        controllers = vcs
        
        // Select good mode
        if YPConfig.screens.contains(YPConfig.startOnScreen) {
            switch YPConfig.startOnScreen {
            case .library:
                mode = .library
            case .photo:
                mode = .camera
            case .video:
                mode = .video
            }
        }
        
        // Select good screen
        if let index = YPConfig.screens.index(of: YPConfig.startOnScreen) {
            startOnPage(index)
        }
        
        YPHelper.changeBackButtonIcon(self)
        YPHelper.changeBackButtonTitle(self)
       

    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.main.async {
            self.cameraVC?.v.shotButton.isEnabled = true
        
        }
       
        
        updateMode(with: currentController)
        v.scrollView.isScrollEnabled = false

    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        shouldHideStatusBar = true
        initialStatusBarHidden = true
        UIView.animate(withDuration: 0.3) {
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    internal func pagerScrollViewDidScroll(_ scrollView: UIScrollView) { }
    
    func modeFor(vc: UIViewController) -> Mode {
        switch vc {
        case is YPLibraryVC:
            return .library
        case is YPCameraVC:
            return .camera
        case is YPVideoCaptureVC:
            return .video
        default:
            return .camera
        }
    }
    
    func pagerDidSelectController(_ vc: UIViewController) {
        updateMode(with: vc)
    }
    
    func updateMode(with vc: UIViewController) {
        stopCurrentCamera()
        
        // Set new mode
        mode = modeFor(vc: vc)
        
        // Re-trigger permission check
        if let vc = vc as? YPLibraryVC {
            vc.checkPermission()
        } else if let cameraVC = vc as? YPCameraVC {
            cameraVC.start()
        } else if let videoVC = vc as? YPVideoCaptureVC {
            DispatchQueue.main.async {
            videoVC.v.shotButton.isEnabled = true
            videoVC.start()
            }
            
        }
    
        updateUI()
    }
    
    func stopCurrentCamera() {
        switch mode {
        case .library:
            libraryVC?.pausePlayer()
        case .camera:
            cameraVC?.stopCamera()
        case .video:
            videoVC?.stopCamera()
        }
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        shouldHideStatusBar = false
        stopAll()
    }
    
    @objc
    func navBarTapped() {
        let vc = YPAlbumVC(albumsManager: albumsManager)
        let navVC = UINavigationController(rootViewController: vc)
        
        vc.didSelectAlbum = { [weak self] album in
            self?.libraryVC?.setAlbum(album)
            self?.libraryVC?.title = album.title
            self?.libraryVC?.refreshMediaRequest()
            self?.setTitleViewWithTitle(aTitle: album.title)
            self?.dismiss(animated: true, completion: nil)
        }
        present(navVC, animated: true, completion: nil)
    }
    
    func setTitleViewWithTitle(aTitle: String) {
          let upperLine = UIView()
        let titleView = UIView()
        titleView.frame = CGRect(x: 0, y: 0, width: 200, height: 40)
        
        let label = UILabel()
        label.text = aTitle
        // Use standard font by default.
        label.font = UIFont.boldSystemFont(ofSize: 17)
        
        // Use custom font if set by user.
        if let navBarTitleFont = UINavigationBar.appearance().titleTextAttributes?[.font] as? UIFont {
            // Use custom font if set by user.
            label.font = navBarTitleFont
        }
        // Use custom textColor if set by user.
//        if let navBarTitleColor = UINavigationBar.appearance().titleTextAttributes?[.foregroundColor] as? UIColor {
//            label.textColor = #colorLiteral(red: 0.8164560199, green: 0.7133601308, blue: 0.52625525, alpha: 1)
//
//        }

        label.textColor = #colorLiteral(red: 0.8164560199, green: 0.7133601308, blue: 0.52625525, alpha: 1)

        
        if YPConfig.library.options != nil {
            titleView.sv(
                label
            )
            //|-(>=8)-label.centerHorizontally()-(>=8)-|
            label-(30)-|

            
            align(horizontally: label)
        } else {
            let arrow = UIImageView()
            //arrow.image = YPConfig.icons.arrowDownIcon
            
            let attributes = UINavigationBar.appearance().titleTextAttributes
            if let attributes = attributes, let foregroundColor = attributes[NSAttributedString.Key.foregroundColor] as? UIColor {
                arrow.image = arrow.image?.withRenderingMode(.alwaysTemplate)
                arrow.tintColor = foregroundColor
            }
            
            let button = UIButton()
            button.addTarget(self, action: #selector(navBarTapped), for: .touchUpInside)
            button.setBackgroundColor(UIColor.white.withAlphaComponent(0.5), forState: .highlighted)


            let lowerLine = UIView()
          // upperLine.height(2)
          // upperLine.width(UIScreen.main.bounds.size.width)
            lowerLine.height(2)
            lowerLine.width(UIScreen.main.bounds.size.width)
            upperLine.backgroundColor = #colorLiteral(red: 0.8164560199, green: 0.7133601308, blue: 0.52625525, alpha: 1)
            lowerLine.backgroundColor = #colorLiteral(red: 0.8164560199, green: 0.7133601308, blue: 0.52625525, alpha: 1)

           upperLine.Top == titleView.Bottom //+ 50
            //lowerLine.Bottom == titleView.Top + 2
            upperLine.frame = CGRect(x: 0, y:0, width: UIScreen.main.bounds.size.width, height: 2 )

            //self.view.sv(upperLine)
            
            titleView.sv(
                label,
                arrow,
                button


            )
            button.fillContainer()
            |-(>=8)-label.centerHorizontally()-arrow-(>=8)-|

            align(horizontally: label-arrow)
        }
        self.view.addSubview(upperLine)
        label.firstBaselineAnchor.constraint(equalTo: titleView.bottomAnchor, constant: -14).isActive = true
        
        
        
        titleView.heightAnchor.constraint(equalToConstant: 40).isActive = true
        navigationItem.titleView = titleView
    }
    
    func updateUI() {
        // Update Nav Bar state.
//        navigationItem.leftBarButtonItem = UIBarButtonItem(title: YPConfig.wordings.cancel,
//                                                           style: .plain,
//                                                           target: self,
//                                                           action: #selector(close))
//         navigationItem.leftBarButtonItem?.tintColor = #colorLiteral(red: 0.8164560199, green: 0.7133601308, blue: 0.52625525, alpha: 1)
//        let closeButtonImage = UIImage(named: "icon4")
//        navigationItem.leftBarButtonItem = UIBarButtonItem(image: closeButtonImage, style: .plain, target: self, action: #selector(close))
        
        
        
        
        
     
//        let button: UIButton = UIButton(type: UIButtonType.custom)
//        //set image for button
//        button.setImage(UIImage(named: "icon4"), for: UIControlState.normal)
//        //add function for button
//        button.addTarget(self, action: #selector(close), for: UIControlEvents.touchUpInside)
//        //set frame
//        button.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
//
//        let barButton = UIBarButtonItem(customView: button)
//        //assign button to navigationbar
//        self.navigationItem.leftBarButtonItem = barButton
        
        
        
        
        
        
        
        

        switch mode {
        case .library:
            //setTitleViewWithTitle(aTitle: libraryVC?.title ?? "")
            let button = UIButton(type: UIButtonType.custom)
            button.setImage(UIImage(named: "icon4"), for: .normal)
            button.setTitle("     Gallery", for: .normal)
            button.setTitleColor(#colorLiteral(red: 0.8921323419, green: 0.7623001933, blue: 0.5988301635, alpha: 1), for: .normal)
            button.addTarget(self, action: #selector(close), for: .touchUpInside)
            button.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            button.sizeToFit()
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: button)
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: YPConfig.wordings.next,
                                                                style: .done,
                                                                target: self,
                                                                action: #selector(done))
            navigationItem.rightBarButtonItem?.tintColor = #colorLiteral(red: 0.8164560199, green: 0.7133601308, blue: 0.52625525, alpha: 1) //YPConfig.colors.tintColor
           // navigationItem.rightBarButtonItem = nil
            
            // Disable Next Button until minNumberOfItems is reached.
            let minNumberOfItems = YPConfig.library.minNumberOfItems
            if minNumberOfItems > 1 {
                navigationItem.rightBarButtonItem?.isEnabled = libraryVC!.selection.count >= minNumberOfItems
            }
        case .camera:
            navigationItem.titleView = nil
            //title = cameraVC?.title
            let button = UIButton(type: UIButtonType.custom)
            button.setImage(UIImage(named: "icon4"), for: .normal)
            button.setTitle("     FOTO", for: .normal)
            button.setTitleColor(#colorLiteral(red: 0.8921323419, green: 0.7623001933, blue: 0.5988301635, alpha: 1), for: .normal)
            button.addTarget(self, action: #selector(close), for: .touchUpInside)
            button.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            button.sizeToFit()
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: button)
            navigationItem.rightBarButtonItem = nil
        case .video:
            navigationItem.titleView = nil
           // title = videoVC?.title
            let button = UIButton(type: UIButtonType.custom)
            button.setImage(UIImage(named: "icon4"), for: .normal)
            button.setTitle("     Video", for: .normal)
            button.setTitleColor(#colorLiteral(red: 0.8921323419, green: 0.7623001933, blue: 0.5988301635, alpha: 1), for: .normal)
            button.addTarget(self, action: #selector(close), for: .touchUpInside)
            button.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            button.sizeToFit()
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: button)
            navigationItem.rightBarButtonItem = nil
        }
    }
    
    @objc
    func close() {
        // Cancelling exporting of all videos
        if let libraryVC = libraryVC {
            libraryVC.mediaManager.forseCancelExporting()
        }
        self.didClose?()
    }
    
    // When pressing "Next"
    @objc
    func done() {
        guard let libraryVC = libraryVC else { print("⚠️ YPPickerVC >>> YPLibraryVC deallocated"); return }
        
        if mode == .library {
            libraryVC.doAfterPermissionCheck { [weak self] in
                libraryVC.selectedMedia(photoCallback: { photo in
                    self?.didSelectItems?([YPMediaItem.photo(p: photo)])
                }, videoCallback: { video in
                
                    self?.didSelectItems?([YPMediaItem
                        .video(v: video)])
                }, multipleItemsCallback: { items in
                    self?.didSelectItems?(items)
                })
            }
        }
    }
    
    func stopAll() {
        libraryVC?.v.assetZoomableView.videoView.deallocate()
        videoVC?.stopCamera()
        cameraVC?.stopCamera()
    }
}

extension YPPickerVC: YPLibraryViewDelegate {
    
    public func libraryViewStartedLoading() {
        libraryVC?.isProcessing = true
        DispatchQueue.main.async {
            self.v.scrollView.isScrollEnabled = false
            self.libraryVC?.v.fadeInLoader()
            self.navigationItem.rightBarButtonItem = YPLoaders.defaultLoader
        }
    }
    
    public func libraryViewFinishedLoading() {
        libraryVC?.isProcessing = false
        DispatchQueue.main.async {
            self.v.scrollView.isScrollEnabled = false
            self.libraryVC?.v.hideLoader()
            self.updateUI()
        }
    }
    
    public func libraryViewDidToggleMultipleSelection(enabled: Bool) {
        var offset = v.header.frame.height
        if #available(iOS 11.0, *) {
            offset += v.safeAreaInsets.bottom
        }
        
        v.header.bottomConstraint?.constant = enabled ? offset : 0
        v.layoutIfNeeded()
    }
    
    public func noPhotosForOptions() {
        self.dismiss(animated: true) {
            self.imagePickerDelegate?.noPhotos()
        }
    }
}
