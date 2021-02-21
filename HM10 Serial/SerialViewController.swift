//
//  SerialViewController.swift
//  HM10 Serial
//
//  Created by Alex on 10-08-15.
//  Copyright (c) 2015 Balancing Rock. All rights reserved.
//

import UIKit
import CoreBluetooth
import QuartzCore

/// The option to add a \n or \r or \r\n to the end of the send message
enum FWSSOption: Int {
    case none,
         spaOutputLevel,
         tenDayTimerCountValue,
         salineTestData,
         fourMonthTimer,
         currentOperatingVoltage, // Cell output
         generationInProgress,    // Status
         errorCodes,
         cumulativeGenerationCycleCount, // Cycle meter
         firmwareRevision,
         catridgeStatus
}

/// The option to add a \n or \r or \r\n to the end of the send message
enum MessageOption: Int {
    case noLineEnding,
         newline,
         carriageReturn,
         carriageReturnAndNewline
}

/// The option to add a \n to the end of the received message (to make it more readable)
enum ReceivedMessageOption: Int {
    case none,
         newline
}

final class SerialViewController: UIViewController, UITextFieldDelegate, BluetoothSerialDelegate {

//MARK: IBOutlets
    
    @IBOutlet weak var firstTextView: UITextView!
    @IBOutlet weak var secondTextView: UITextView!
    @IBOutlet weak var thirdTextView: UITextView!
    @IBOutlet weak var fourthTextView: UITextView!
    @IBOutlet weak var messageField: UITextField!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint! // used to move the textField up when the keyboard is present
    @IBOutlet weak var barButton: UIBarButtonItem!
    @IBOutlet weak var navItem: UINavigationItem!


//MARK: Functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // init serial
        serial = BluetoothSerial(delegate: self)
        
        // UI
        firstTextView.text = ""
        secondTextView.text = ""
        thirdTextView.text = ""
        fourthTextView.text = ""
        reloadView()
        
        NotificationCenter.default.addObserver(self, selector: #selector(SerialViewController.reloadView), name: NSNotification.Name(rawValue: "reloadStartViewController"), object: nil)
        
        // we want to be notified when the keyboard is shown (so we can move the textField up)
        NotificationCenter.default.addObserver(self, selector: #selector(SerialViewController.keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SerialViewController.keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        // to dismiss the keyboard if the user taps outside the textField while editing
        let tap = UITapGestureRecognizer(target: self, action: #selector(SerialViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func keyboardWillShow(_ notification: Notification) {
        // animate the text field to stay above the keyboard
        var info = (notification as NSNotification).userInfo!
        let value = info[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue
        let keyboardFrame = value.cgRectValue
        
        //TODO: Not animating properly
        UIView.animate(withDuration: 1, delay: 0, options: UIView.AnimationOptions(), animations: { () -> Void in
            self.bottomConstraint.constant = keyboardFrame.size.height
            }, completion: { Bool -> Void in
            self.mainTextViewScrollToBottom()
        })
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
        // bring the text field back down..
        UIView.animate(withDuration: 1, delay: 0, options: UIView.AnimationOptions(), animations: { () -> Void in
            self.bottomConstraint.constant = 0
        }, completion: nil)

    }
    
    @objc func reloadView() {
        // in case we're the visible view again
        serial.delegate = self
        
        if serial.isReady {
            navItem.title = serial.connectedPeripheral!.name
            barButton.title = "Disconnect"
            barButton.tintColor = UIColor.red
            barButton.isEnabled = true
        } else if serial.centralManager.state == .poweredOn {
            navItem.title = "Bluetooth Serial"
            barButton.title = "Connect"
            barButton.tintColor = view.tintColor
            barButton.isEnabled = true
        } else {
            navItem.title = "Bluetooth Serial"
            barButton.title = "Connect"
            barButton.tintColor = view.tintColor
            barButton.isEnabled = false
        }
    }
    
    func mainTextViewScrollToBottom() {
        let range = NSMakeRange(NSString(string: firstTextView.text).length - 1, 1)
        firstTextView.scrollRangeToVisible(range)
    }
    
    func secondTextViewScrollToBottom() {
        let range = NSMakeRange(NSString(string: secondTextView.text).length - 1, 1)
        secondTextView.scrollRangeToVisible(range)
    }
    
    func thirdTextViewScrollToBottom() {
        let range = NSMakeRange(NSString(string: thirdTextView.text).length - 1, 1)
        thirdTextView.scrollRangeToVisible(range)
    }
    
    func fourthTextViewScrollToBottom() {
        let range = NSMakeRange(NSString(string: fourthTextView.text).length - 1, 1)
        fourthTextView.scrollRangeToVisible(range)
    }
    

//MARK: BluetoothSerialDelegate
    
    func serialDidReceiveString(_ message: String) {
        print ("serialDidReceiveString \(message)")
        // add the received text to the textView, optionally with a line break at the end

        
        let msg = message.replacingOccurrences(of: "0x", with: "")
        let array = msg.components(separatedBy: " ")
        let fwssPref = UserDefaults.standard.integer(forKey: FWSSOptionKey)
        if (array[1] == "29") {
            print ("FWSS field with pref \(fwssPref)")
            
            let value1 = UInt8(array[7], radix: 16)
            firstTextView.text = "\(value1!)"
            let value2 = UInt8(array[8], radix: 16)
            secondTextView.text = "\(value2!)"
            let value3 = UInt8(array[9], radix: 16)
            thirdTextView.text = "\(value3!)"
            let value4 = UInt8(array[10], radix: 16)
            fourthTextView.text = "\(value4!)"
            

//            switch fwssPref {
//            case FWSSOption.none.rawValue:
//                msg = message
//            case FWSSOption.spaOutputLevel.rawValue:
//                msg = array[7]
//            case FWSSOption.tenDayTimerCountValue.rawValue:
//                msg = array[8]
//            case FWSSOption.salineTestData.rawValue:
//                msg = array[9]
//            case FWSSOption.fourMonthTimer.rawValue:
//                msg = array[10]
//            case FWSSOption.currentOperatingVoltage.rawValue:
//                msg = array[11]
//            case FWSSOption.generationInProgress.rawValue:
//                msg = array[12]
//            case FWSSOption.errorCodes.rawValue:
//                msg = array[13]
//            case FWSSOption.cumulativeGenerationCycleCount.rawValue:
//                msg = array[16]+array[15]+array[14]
//            case FWSSOption.firmwareRevision.rawValue:
//                msg = array[17]
//            case FWSSOption.catridgeStatus.rawValue:
//                msg = array[18]
//            default:
//                msg = message
//            }
        }
        
//        if (array[1] == "0x01") {
//            firstTextView.text = msg
//        } else if (array[1] == "0x33") {
//            secondTextView.text = msg
//        } else if (array[1] == "0x21") {
//            thirdTextView.text = msg
//        } else if (array[1] == "0x24") {
//            fourthTextView.text = msg
//        }
    }
    
    func serialDidDisconnect(_ peripheral: CBPeripheral, error: NSError?) {
        reloadView()
        dismissKeyboard()
        let hud = MBProgressHUD.showAdded(to: view, animated: true)
        hud?.mode = MBProgressHUDMode.text
        hud?.labelText = "Disconnected"
        hud?.hide(true, afterDelay: 1.0)
    }
    
    func serialDidChangeState() {
        reloadView()
        if serial.centralManager.state != .poweredOn {
            dismissKeyboard()
            let hud = MBProgressHUD.showAdded(to: view, animated: true)
            hud?.mode = MBProgressHUDMode.text
            hud?.labelText = "Bluetooth turned off"
            hud?.hide(true, afterDelay: 1.0)
        }
    }
    
    
//MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if !serial.isReady {
            let alert = UIAlertController(title: "Not connected", message: "What am I supposed to send this to?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertAction.Style.default, handler: { action -> Void in self.dismiss(animated: true, completion: nil) }))
            present(alert, animated: true, completion: nil)
            messageField.resignFirstResponder()
            return true
        }
        
        // send the message to the bluetooth device
        // but fist, add optionally a line break or carriage return (or both) to the message
        let pref = UserDefaults.standard.integer(forKey: MessageOptionKey)
        var msg = messageField.text!
        switch pref {
        case MessageOption.newline.rawValue:
            msg += "\n"
        case MessageOption.carriageReturn.rawValue:
            msg += "\r"
        case MessageOption.carriageReturnAndNewline.rawValue:
            msg += "\r\n"
        default:
            msg += ""
        }
        
        // send the message and clear the textfield
        serial.sendMessageToDevice(msg)
        messageField.text = ""
        return true
    }
    
    @objc func dismissKeyboard() {
        if (messageField != nil) { messageField.resignFirstResponder()
        }
    }
    
    
//MARK: IBActions

    @IBAction func barButtonPressed(_ sender: AnyObject) {
        print ("Bar button pressed")
        if serial.connectedPeripheral == nil {
            performSegue(withIdentifier: "ShowScanner", sender: self)
        } else {
            serial.disconnect()
            reloadView()
        }
    }
}
