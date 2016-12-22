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
    case highlightMazenta = 0xe4007f
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
    
    
    class func height(_ lintingWorning: LintingWorning, width: CGFloat) -> CGFloat {
        let textContainer = NSTextContainer.init()
        textContainer.lineFragmentPadding = 0
        let layoutManager = NSLayoutManager.init()
        layoutManager.addTextContainer(textContainer)
        let containerSize = CGSize(width: width - 8 * 2, height: 2000)
        textContainer.size = containerSize;
        
        let textStorage = NSTextStorage.init(attributedString: NSAttributedString.init(string: lintingWorning.message, attributes: [
            NSFontAttributeName: UIFont.systemFont(ofSize: 17)
        ]))
        textStorage.addLayoutManager(layoutManager)
        layoutManager .glyphRange(for: textContainer)
        let size = layoutManager .usedRect(for: textContainer).size
        textStorage.removeLayoutManager(layoutManager)
        return 32 + size.height + 8
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        textView.textContainerInset = UIEdgeInsets.zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.heightTracksTextView = false
        textView.textContainer.widthTracksTextView = false
    }
    
    func update(_ lintingWorning: LintingWorning) {
        label.text = "\(lintingWorning.line)行目, \(lintingWorning.column)カラム"
        textView.attributedText = NSAttributedString.init(string: lintingWorning.message, attributes: [
            NSFontAttributeName: UIFont.systemFont(ofSize: 17)
        ])
    }
}

class ViewController: UIViewController, UITextViewDelegate, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var worningsViewHeight: NSLayoutConstraint!
    @IBOutlet weak var worningsViewBottomSpace: NSLayoutConstraint!
    @IBOutlet weak var worningsTableView: UITableView!

    var wornings: [LintingWorning] = []
    
    @IBOutlet weak var textView: UITextView!

    @IBOutlet var keyboardView: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textView.delegate = self
        worningsTableView.delegate = self
        worningsTableView.dataSource = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.keyboardWillHidden(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        textView.inputAccessoryView = keyboardView
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        textView.typingAttributes = [NSFontAttributeName: UIFont.systemFont(ofSize: 17)]
        return true
    }

    @IBAction func pasteButtonPushed(_ sender: AnyObject) {
        let pasteboard = UIPasteboard.general
        let text = pasteboard.value(forPasteboardType: "public.text") as? String
    
        if textView.text.characters.count != 0 {
            let alert = UIAlertController.init(title: "お知らせ", message: "今書いてあるものは消えちゃうよ！", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction.init(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
            alert.addAction(UIAlertAction.init(title: "OK", style: UIAlertActionStyle.default, handler: { _ in
                self.textView.text = text
                self.wornings = []
                self.update()
            }))
            self.present(alert, animated: true, completion: nil)
        } else {
            textView.text = text
            self.wornings = []
            self.update()
        }
    }

    @IBAction func closeButtonPushed(_ sender: AnyObject) {
        textView.resignFirstResponder()
    }

    @IBAction func copyButtonPushed(_ sender: AnyObject) {
        let pasteboard = UIPasteboard.general
        pasteboard.setValue(textView.text, forPasteboardType: "public.text")
        let alert = UIAlertController.init(title: "お知らせ", message: "クリップボードにコピーしたよ！", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction.init(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    @IBAction func clearButtonPushed(_ sender: AnyObject) {
        textView.resignFirstResponder()
        textView.contentOffset = CGPoint.init(x: 0, y: -textView.contentInset.top)
        textView.text = ""
        wornings = []
        update()
    }

    @IBAction func checkButtonPushed(_ sender: AnyObject) {
        guard let text = textView.text else {
            return
        }
        if text.characters.count == 0 {
            return
        }
        textView.attributedText = NSMutableAttributedString.init(string: textView.text, attributes: [NSFontAttributeName: UIFont.systemFont(ofSize: 17)])
        var request = URLRequest.init(url: URL.init(string: "https://fu-lin.xyz/check")!)
        request.httpMethod = "POST"
        request.httpBody = text.data(using: String.Encoding.utf8)
        let session = URLSession.init(configuration: URLSessionConfiguration.default)
        textView.resignFirstResponder()
        SVProgressHUD.setDefaultStyle(.light)
        SVProgressHUD.setDefaultMaskType(.black)
        SVProgressHUD.show()
        let task = session.dataTask(with: request) { (data, response, error) in
            guard let data_ = data else {
                return
            }
            let array: [AnyObject] = try! JSONSerialization.jsonObject(with: data_, options: JSONSerialization.ReadingOptions.mutableContainers) as! [AnyObject]
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
                SVProgressHUD.showSuccess(withStatus: "良いんじゃないでしょうか！")
                SVProgressHUD.dismiss(withDelay: 0.8)
            } else {
                SVProgressHUD.dismiss()
            }
            DispatchQueue.main.sync(execute: {
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
        UIView.animate(withDuration: 0.2, animations: {
            self.view.layoutIfNeeded()
        }) 
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return wornings.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! LintingWorningCell
        cell.update(wornings[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let lintingWorning = wornings[indexPath.row]
        return LintingWorningCell.height(lintingWorning, width: tableView.frame.width)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let lintingWorning = wornings[indexPath.row]
        
        var numberOfLines = 1
        
        var index = 0
        for pair in textView.text.characters.enumerated() {
            if numberOfLines == lintingWorning.line {
                index = pair.offset + lintingWorning.column - 1
                break
            }
            if pair.element == "\n" {
                numberOfLines += 1
            }
        }
        
        var rect = textView.layoutManager.boundingRect(forGlyphRange: NSRange.init(location: index, length: 1), in: textView.textContainer)
        rect.origin.y -= textView.frame.height / 2
        rect.origin.x = 0
        textView.setContentOffset(rect.origin, animated: true)
        let attributedText = NSMutableAttributedString.init(string: textView.text, attributes: [NSFontAttributeName: UIFont.systemFont(ofSize: 17)])
        attributedText.addAttributes([
                NSBackgroundColorAttributeName: UIColor.init(color: .highlightMazenta)
            ], range: NSRange.init(location: index, length: 1))
        textView.attributedText = attributedText
        
    }

    func keyboardWillShow(_ sender: Notification) {
        let keyboardFrame = (sender.userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        let duration = (sender.userInfo![UIKeyboardAnimationDurationUserInfoKey] as! TimeInterval)
        let curve = UIViewAnimationCurve.init(rawValue: sender.userInfo![UIKeyboardAnimationCurveUserInfoKey] as! Int)
        UIView.beginAnimations("keyboardWillShow", context: nil)
        UIView.setAnimationCurve(curve!)
        UIView.setAnimationDuration(duration)
        textView.contentInset.bottom = keyboardFrame.height + 40 - (worningsViewBottomSpace.constant + worningsViewHeight.constant)
        textView.scrollIndicatorInsets.bottom = keyboardFrame.height - (worningsViewBottomSpace.constant + worningsViewHeight.constant)
        UIView.commitAnimations()
    }
    
    func keyboardWillHidden(_ sender: Notification) {
        let duration = (sender.userInfo![UIKeyboardAnimationDurationUserInfoKey] as! TimeInterval)
        let curve = UIViewAnimationCurve.init(rawValue: sender.userInfo![UIKeyboardAnimationCurveUserInfoKey] as! Int)
        UIView.beginAnimations("keyboardWillShow", context: nil)
        UIView.setAnimationCurve(curve!)
        UIView.setAnimationDuration(duration)
        textView.contentInset.bottom = 0
        textView.scrollIndicatorInsets.bottom = 0
        UIView.commitAnimations()
    }
}

