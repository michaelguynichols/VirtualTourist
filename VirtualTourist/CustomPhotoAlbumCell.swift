//
//  CustomPhotoAlbumCell.swift
//  VirtualTourist
//
//  Created by Michael Nichols on 8/12/15.
//  Copyright (c) 2015 Michael Nichols. All rights reserved.
//

import Foundation
import UIKit

class CustomPhotoAlbumCell: UICollectionViewCell {
    
    @IBOutlet weak var collectionImageView: UIImageView!
    @IBOutlet weak var activity: UIActivityIndicatorView!
    
    var taskToCancelifCellIsReused: NSURLSessionTask? {
        
        didSet {
            if let taskToCancel = oldValue {
                taskToCancel.cancel()
            }
        }
    }
    
}