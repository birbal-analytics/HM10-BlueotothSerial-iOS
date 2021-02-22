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
enum SensorOption: Int {
    case none,
         fwss,
         loac
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
    
    @IBOutlet weak var titleTextView: UITextView!
    @IBOutlet weak var firstTextView: UITextView!
    @IBOutlet weak var secondTextView: UITextView!
    @IBOutlet weak var thirdTextView: UITextView!
    @IBOutlet weak var fourthTextView: UITextView!
    @IBOutlet weak var firstTextValueView: UITextView!
    @IBOutlet weak var secondTextValueView: UITextView!
    @IBOutlet weak var thirdTextValueView: UITextView!
    @IBOutlet weak var fourthTextValueView: UITextView!
    @IBOutlet weak var messageField: UITextField!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint! // used to move the textField up when the keyboard is present
    @IBOutlet weak var barButton: UIBarButtonItem!
    @IBOutlet weak var navItem: UINavigationItem!

    var dateFormatter : DateFormatter = DateFormatter()
    var timestamp = ""
    var firstFWSSReceived = false
    var firstLOACReceived = false

//MARK: Functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // init serial
        serial = BluetoothSerial(delegate: self)
        
        // UI
        titleTextView.text = "Select sensor from Settings and Connect to device"
        firstTextView.text = ""
        secondTextView.text = ""
        thirdTextView.text = ""
        fourthTextView.text = ""
        firstTextValueView.text = ""
        secondTextValueView.text = ""
        thirdTextValueView.text = ""
        fourthTextValueView.text = ""
        reloadView()
        
        dateFormatter.dateFormat = "yyyy-MMM-dd HH:mm:ss"
        
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
        let range = NSMakeRange(NSString(string: firstTextValueView.text).length - 1, 1)
        firstTextValueView.scrollRangeToVisible(range)
    }
    
    func secondTextValueViewScrollToBottom() {
        let range = NSMakeRange(NSString(string: secondTextValueView.text).length - 1, 1)
        secondTextValueView.scrollRangeToVisible(range)
    }
    
    func thirdTextValueViewScrollToBottom() {
        let range = NSMakeRange(NSString(string: thirdTextValueView.text).length - 1, 1)
        thirdTextValueView.scrollRangeToVisible(range)
    }
    
    func fourthTextValueViewScrollToBottom() {
        let range = NSMakeRange(NSString(string: fourthTextValueView.text).length - 1, 1)
        fourthTextValueView.scrollRangeToVisible(range)
    }
    

    func processFwssMessage(_ message: String) {
        firstLOACReceived = false
        
        // Set title
        if (!firstFWSSReceived) {
            titleTextView.text = "Waiting for FWSS Data..."
        }
        
        // Set field description column
        firstTextView.text  = "Spa Output level"
        secondTextView.text = "10 day timer"
        thirdTextView.text  = "Saline test data..."
        fourthTextView.text = "4 month timer"
        
        // Set field values column
        let msg = message.replacingOccurrences(of: "0x", with: "")
        let array = msg.components(separatedBy: " ")
        if (array[1] == "29") {
            // TODO: Check size of array.
            firstFWSSReceived = true
            let date = Date()
            timestamp = dateFormatter.string(from: date)
            titleTextView.text = "Last update at \(timestamp)"
            
            // Spa output level
            let value1 = UInt8(array[7], radix: 16)
            var display = "OFF"
            if (value1 == 255) {
                display = "NA"
            } else if  (value1 == 0){
                display = "OFF"
            } else {
                let val = Int(10.0 * Double(value1!) / 255)
                display =  "\(val)/10"
            }
            firstTextValueView.text  = "\(display)"
            
            // 10 day timer
            let value2 = UInt8(array[8], radix: 16)
            secondTextValueView.text = "\(value2!)"
            
            // Saline data
            let value3 = UInt8(array[9], radix: 16)
            let lsbs = value3! & 0x3
            if (lsbs == 0) {
                display = "OK"
            } else if (lsbs == 1) {
                display = "HI"
            } else if (lsbs == 3) {
                display = "LO"
            }
            thirdTextValueView.text = display
            
            // 120 day timer
            let value4 = UInt8(array[10], radix: 16)
            fourthTextValueView.text = "\(value4!)"
        }
    }

    func processLoacMessage(_ message:String) {
        firstFWSSReceived = false
        
        // Set title
        if (!firstLOACReceived) {
            titleTextView.text = "Waiting for LOAC Data..."
        }
        
        // Set field description column
        firstTextView.text  = "pH"
        secondTextView.text = "ORP"
        thirdTextView.text  = "Conductivity"
        fourthTextView.text = "Chlorine"

        let msg = message.replacingOccurrences(of: "0x", with: "")
        let array = msg.components(separatedBy: " ")
        if (array[1] == "37") {
            // TODO: Check size of array.
            firstLOACReceived = true
            let date = Date()
            timestamp = dateFormatter.string(from: date)
            titleTextView.text = "Last update at \(timestamp)"
            
            // Spa output level
            let value = UInt16(array[18]+array[17], radix: 16)
            let display = value!/100
            thirdTextValueView.text  = "\(display)"

            // Set field values column
            firstTextValueView.text  = "NA"
            secondTextValueView.text = "NA"
            fourthTextValueView.text = "NA"
        }
    }
    
    func processDefaultMessage(_ message:String) {
        firstFWSSReceived        = false
        firstLOACReceived        = false
        titleTextView.text       = "Select sensor from Settings and Connect to device"
        firstTextView.text       = ""
        secondTextView.text      = ""
        thirdTextView.text       = ""
        fourthTextView.text      = ""
        firstTextValueView.text  = ""
        secondTextValueView.text = ""
        thirdTextValueView.text  = ""
        fourthTextValueView.text = ""
    }
    
//MARK: BluetoothSerialDelegate
    func serialDidReceiveString(_ message: String) {
        let sensorPref = UserDefaults.standard.integer(forKey: SensorOptionKey)
            
        switch sensorPref {
        case SensorOption.fwss.rawValue:
            processFwssMessage(message)
        case SensorOption.loac.rawValue:
            processLoacMessage(message)
        case SensorOption.none.rawValue:
            processDefaultMessage(message)
        default:
            processDefaultMessage(message)
        }
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
