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
    
    let cache = try! Cache<NSString>(name: "AwesomeCache")
                            
	override func viewDidLoad() {
		super.viewDidLoad()
		textView.text = (cache["myText"] as? String) ?? ""
	}
    
    @IBAction func reloadData(_ sender: AnyObject?) {
        textView.text = (cache["myText"] as? String) ?? ""
    }
    
    @IBAction func saveInCache(_ sender: AnyObject?) {
        cache["myText"] = textView.text as NSString?
    }
}

