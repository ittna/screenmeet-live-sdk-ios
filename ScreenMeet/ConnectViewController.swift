//
//  ConnectViewController.swift
//  DemoiOS
//
//  Created by Ross on 21.11.2022.
//

import UIKit
import ScreenMeetLive

class ConnectViewController: UIViewController {
    @IBOutlet weak var bottomInfoView: UIView!
    @IBOutlet weak var bottomInfoLabel: UILabel!
    
    @IBOutlet weak var connectButton: TransitionButton!
    @IBOutlet weak var roomCodeTextField: UITextField!
    
    @IBOutlet weak var waitingView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        connectButton.setTitleColor(.white, for: .normal)
        connectButton.tintColor = .screenMeetBrandColor
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
        
        roomCodeTextField.becomeFirstResponder()
    }
    
    @IBAction func connectButtonClicked() {
        connectButton.setTitleColor(.white, for: .normal)
        connectButton.tintColor = .screenMeetBrandColor
        roomCodeTextField.resignFirstResponder()
        
        connectButton.startAnimation()
        ScreenMeet.config.collectMetric = true
        
       // ScreenMeet.config.developerLoggingTiers = [.mediasoup, .webrtc, .signalling, .http, .rawSocket]
        ScreenMeet.connect(roomCodeTextField.text!, "iOS") { [weak self] error in
            
            guard error == nil else {
                if let challenge = error!.challenge {
                    self?.showCaptchaScreen(challenge)
                }
                else if error!.code == .knockEntryPermissionRequiredError {
                    // Knock is on, host has to let you in, just show an error and wait for success completion in case we are let in
                    self?.waitingView.isHidden = false
                    self?.showError(error!.message)
                }
                else if error!.code == .knockWaitTimeForEntryExpiredError {
                    self?.connectButton.stopAnimation(animationStyle: .shake)
                    self?.connectButton.setTitleColor(.white, for: .normal)
                    self?.connectButton.isEnabled = true
                    self?.roomCodeTextField.isHidden = false
                    self?.roomCodeTextField.isEnabled = true
                    self?.waitingView.isHidden = true
                    self?.showError(error!.message)
                    
                    self?.connectButton.setTitle("Connect", for: .normal)
                    self?.connectButton.setTitleColor(.white, for: .normal)
                }
                else {
                    self?.connectButton.stopAnimation()
                    self?.connectButton.setTitleColor(.white, for: .normal)
                    self?.connectButton.isEnabled = true
                    self?.roomCodeTextField.isHidden = false
                    self?.roomCodeTextField.isEnabled = true
                    self?.waitingView.isHidden = true
                    self?.showError(error!.message)
                    
                    self?.connectButton.setTitle("Connect", for: .normal)
                    self?.connectButton.setTitleColor(.white, for: .normal)
                }
                return
            }
            
            self?.connectButton.setTitle("Connect", for: .normal)
            self?.connectButton.setTitleColor(.white, for: .normal)
            self?.openCallScreen()
        }
        //ScreenMeet.getConfidentiality().addConfidentialView()
    }
    
    @IBAction func quitWaitingButtonTapped(_ sender: UIButton) {
        ScreenMeet.disconnect()
        
        connectButton.stopAnimation()
        connectButton.setTitleColor(.white, for: .normal)
        connectButton.isEnabled = true
        roomCodeTextField.isHidden = false
        roomCodeTextField.isEnabled = true
        waitingView.isHidden = true
    }
    
    private func openCallScreen() {
        connectButton.stopAnimation(animationStyle: .expand, revertAfterDelay: 1.0, completion: { [weak self] in
            if let callViewController = self?.storyboard?.instantiateViewController(withIdentifier: "CallViewController") as? CallViewController {
                self?.navigationController?.pushViewController(callViewController, animated: true)
            }
            
        })
    }
    
    private func showCaptchaScreen(_ challenge: SMChallenge) {
        if let captchaViewController = storyboard?.instantiateViewController(identifier: "CaptchaViewController") as? CaptchaViewController {
            
            captchaViewController.isModalInPresentation = true
            captchaViewController.svg = challenge.getSvg()
            captchaViewController.verifyCompletion = { captcha in
                challenge.solve(captcha)
            }
            
            present(captchaViewController, animated: true, completion: nil)
        }
    }
    
    private func showError(_ text: String) {
        bottomInfoView.backgroundColor = UIColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 0.8)
        bottomInfoView.isHidden = false
        bottomInfoLabel.text = text
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: { [weak self] in
            self?.bottomInfoView.isHidden = true
        })
    }
    
    @objc private func dismissKeyboard() {
        roomCodeTextField.endEditing(true)
    }
}

extension ConnectViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
