//
//  ViewController.swift
//  fulin-ios
//
//  Created by Fumiya-Kubota on 2016/07/06.
//  Copyright © 2016年 sasau. All rights reserved.
//

import UIKit
import SVProgressHUD
import UIKit

enum Colors: Int {
    case HighlightMazenta = 0xe4007f
}

extension UIColor {
    convenience init(color: Colors, alpha: CGFloat = 1.0) {
        let red = CGFloat((color.rawValue & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((color.rawValue & 0xFF00) >> 8) / 255.0
        let blue = CGFloat((color.rawValue & 0xFF)) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

struct LintingWorning {
    let line: Int
    let column: Int
    let message: String
}


class LintingWorningCell: UITableViewCell {
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var textView: UITextView!
    
    
    class func height(lintingWorning: LintingWorning, width: CGFloat) -> CGFloat {
        let textContainer = NSTextContainer.init()
        textContainer.lineFragmentPadding = 0
        let layoutManager = NSLayoutManager.init()
        layoutManager.addTextContainer(textContainer)
        let containerSize = CGSizeMake(width - 8 * 2, 2000)
        textContainer.size = containerSize;
        
        let textStorage = NSTextStorage.init(attributedString: NSAttributedString.init(string: lintingWorning.message, attributes: [
            NSFontAttributeName: UIFont.systemFontOfSize(18)
        ]))
        textStorage.addLayoutManager(layoutManager)
        layoutManager .glyphRangeForTextContainer(textContainer)
        let size = layoutManager .usedRectForTextContainer(textContainer).size
        textStorage.removeLayoutManager(layoutManager)
        return 32 + size.height + 8
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        textView.textContainerInset = UIEdgeInsetsZero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.heightTracksTextView = false
        textView.textContainer.widthTracksTextView = false
    }
    
    func update(lintingWorning: LintingWorning) {
        label.text = "\(lintingWorning.line)行目, \(lintingWorning.column)カラム"
        textView.attributedText = NSAttributedString.init(string: lintingWorning.message, attributes: [
            NSFontAttributeName: UIFont.systemFontOfSize(17)
        ])
    }
}

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var worningsViewHeight: NSLayoutConstraint!
    @IBOutlet weak var worningsViewBottomSpace: NSLayoutConstraint!
    @IBOutlet weak var worningsTableView: UITableView!

    var wornings: [LintingWorning] = []
    
    @IBOutlet weak var textView: UITextView!

    @IBOutlet var keyboardView: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        worningsTableView.delegate = self
        worningsTableView.dataSource = self
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.keyboardWillShow(_:)), name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.keyboardWillHidden(_:)), name: UIKeyboardWillHideNotification, object: nil)
        
        textView.inputAccessoryView = keyboardView
    }

    @IBAction func pasteButtonPushed(sender: AnyObject) {
        let pasteboard = UIPasteboard.generalPasteboard()
        let text = pasteboard.valueForPasteboardType("public.text") as? String
    
        if textView.text.characters.count != 0 {
            let alert = UIAlertController.init(title: "お知らせ", message: "今書いてあるものは消えちゃうよ！", preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction.init(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil))
            alert.addAction(UIAlertAction.init(title: "OK", style: UIAlertActionStyle.Default, handler: { _ in
                self.textView.text = text
                self.wornings = []
                self.update()
            }))
            self.presentViewController(alert, animated: true, completion: nil)
        } else {
            textView.text = text
            self.wornings = []
            self.update()
        }
    }

    @IBAction func closeButtonPushed(sender: AnyObject) {
        textView.resignFirstResponder()
    }

    @IBAction func copyButtonPushed(sender: AnyObject) {
        let pasteboard = UIPasteboard.generalPasteboard()
        pasteboard.setValue(textView.text, forPasteboardType: "public.text")
        let alert = UIAlertController.init(title: "お知らせ", message: "クリップボードにコピーしたよ！", preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction.init(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
    }

    @IBAction func clearButtonPushed(sender: AnyObject) {
        textView.resignFirstResponder()
        textView.contentOffset = CGPoint.init(x: 0, y: 0)
        textView.text = ""
        wornings = []
        update()
    }

    @IBAction func checkButtonPushed(sender: AnyObject) {
        guard let text = textView.text else {
            return
        }
        if text.characters.count == 0 {
            return
        }
        let request = NSMutableURLRequest.init(URL: NSURL.init(string: "http://160.16.211.54/")!)
        request.HTTPMethod = "POST"
        request.HTTPBody = text.dataUsingEncoding(NSUTF8StringEncoding)
        let session = NSURLSession.init(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        textView.resignFirstResponder()
        SVProgressHUD.setDefaultStyle(.Light)
        SVProgressHUD.setDefaultMaskType(.Black)
        SVProgressHUD.show()
        let task = session.dataTaskWithRequest(request) { (data, response, error) in
            guard let data_ = data else {
                return
            }
            let array: [AnyObject] = try! NSJSONSerialization.JSONObjectWithData(data_, options: NSJSONReadingOptions.MutableContainers) as! [AnyObject]
            
            var wornings: [LintingWorning] = []
            for dict in array {
                guard let line = dict["line"] as? Int else {
                    continue
                }
                guard let column = dict["column"] as? Int else {
                    continue
                }
                guard let message = dict["message"] as? String else {
                    continue
                }
                wornings.append(LintingWorning.init(line: line, column: column, message: message))
            }
            self.wornings = wornings
            if wornings.count == 0 {
                SVProgressHUD.showSuccessWithStatus("良いんじゃないでしょうか！")
                SVProgressHUD.dismissWithDelay(0.8)
            } else {
                SVProgressHUD.dismiss()
            }

            
            dispatch_sync(dispatch_get_main_queue(), {
                self.update()
            })
        }
        task.resume()
    }
    
    func update() {
        worningsTableView.reloadData()
        if wornings.count == 0 {
            worningsViewBottomSpace.constant = -worningsViewHeight.constant
        } else {
            worningsViewBottomSpace.constant = 0
        }
        UIView.animateWithDuration(0.2) {
            self.view.layoutIfNeeded()
        }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return wornings.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as! LintingWorningCell
        cell.update(wornings[indexPath.row])
        return cell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let lintingWorning = wornings[indexPath.row]
        return LintingWorningCell.height(lintingWorning, width: tableView.frame.width)
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let lintingWorning = wornings[indexPath.row]
        
        var numberOfLines = 1
        
        var index = 0
        for pair in textView.text.characters.enumerate() {
            if numberOfLines == lintingWorning.line {
                index = pair.index + lintingWorning.column - 1
                break
            }
            if pair.element == "\n" {
                numberOfLines += 1
            }
        }
        
        var rect = textView.layoutManager.boundingRectForGlyphRange(NSRange.init(location: index, length: 1), inTextContainer: textView.textContainer)
        rect.origin.y -= textView.frame.height / 2
        rect.origin.x = 0
        textView.setContentOffset(rect.origin, animated: true)
        let attributedText = NSMutableAttributedString.init(string: textView.text, attributes: [NSFontAttributeName: UIFont.systemFontOfSize(15)])
        attributedText.addAttributes([
                NSBackgroundColorAttributeName: UIColor.init(color: .HighlightMazenta)
            ], range: NSRange.init(location: index, length: 1))
        textView.attributedText = attributedText
        
    }

    func keyboardWillShow(sender: NSNotification) {
        let keyboardFrame = (sender.userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue()
        let duration = (sender.userInfo![UIKeyboardAnimationDurationUserInfoKey] as! NSTimeInterval)
        let curve = UIViewAnimationCurve.init(rawValue: sender.userInfo![UIKeyboardAnimationCurveUserInfoKey] as! Int)
        UIView.beginAnimations("keyboardWillShow", context: nil)
        UIView.setAnimationCurve(curve!)
        UIView.setAnimationDuration(duration)
        textView.contentInset.bottom = keyboardFrame.height + 40 - (worningsViewBottomSpace.constant + worningsViewHeight.constant)
        textView.scrollIndicatorInsets.bottom = keyboardFrame.height - (worningsViewBottomSpace.constant + worningsViewHeight.constant)
        UIView.commitAnimations()
    }
    
    func keyboardWillHidden(sender: NSNotification) {
        let duration = (sender.userInfo![UIKeyboardAnimationDurationUserInfoKey] as! NSTimeInterval)
        let curve = UIViewAnimationCurve.init(rawValue: sender.userInfo![UIKeyboardAnimationCurveUserInfoKey] as! Int)
        UIView.beginAnimations("keyboardWillShow", context: nil)
        UIView.setAnimationCurve(curve!)
        UIView.setAnimationDuration(duration)
        textView.contentInset.bottom = 0
        textView.scrollIndicatorInsets.bottom = 0
        UIView.commitAnimations()
    }
}

