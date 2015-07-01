//
//  ViewController.swift
//  Example
//
//  Created by Alexander Schuch on 12/07/14.
//  Copyright (c) 2014 Alexander Schuch. All rights reserved.
//

import UIKit
import AwesomeCache

class ViewController: UIViewController {
    
    @IBOutlet var textView: UITextView!
    
    let cache: Cache<NSString>?
    
    required init(coder aDecoder: NSCoder) {
        do {
            cache = try Cache<NSString>(name: "AwesomeCache")
        } catch {
            cache = nil
            print("unable to instantiate Cache with error: \(error)")
        }
        
        super.init(coder: aDecoder)
    }
                            
	override func viewDidLoad() {
		super.viewDidLoad()
		textView.text = (cache?["myText"] as? String) ?? ""
	}
    
    @IBAction func reloadData(sender: AnyObject?) {
        textView.text = (cache?["myText"] as? String) ?? ""
    }
    
    @IBAction func saveInCache(sender: AnyObject?) {
        cache?["myText"] = textView.text
    }
}

