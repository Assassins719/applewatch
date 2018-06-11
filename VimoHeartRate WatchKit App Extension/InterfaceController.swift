//
//  InterfaceController.swift
//  VimoHeartRate WatchKit App Extension
//
//  Created by Ethan Fan on 6/25/15.
//  Copyright © 2015 Vimo Lab. All rights reserved.
//

import Foundation
import HealthKit
import WatchKit
import UIKit
import CoreLocation
import UserNotifications


class InterfaceController: WKInterfaceController, HKWorkoutSessionDelegate {
    
    @IBOutlet private weak var label: WKInterfaceLabel!
    @IBOutlet private weak var deviceLabel : WKInterfaceLabel!
    @IBOutlet private weak var heart: WKInterfaceImage!
    @IBOutlet private weak var startStopButton : WKInterfaceButton!
    
    @IBOutlet var btnInterval: WKInterfaceButton!
    @IBOutlet var btnClear: WKInterfaceButton!
    @IBOutlet var labelStart: WKInterfaceLabel!
    
    @IBOutlet var groupTime: WKInterfaceGroup!
    @IBOutlet var labelTime: WKInterfaceLabel!
    @IBOutlet var labelSet: WKInterfaceLabel!
    
    var seconds = 30;
    var nSet = 1;
    var nTimes = [30,45,60,90,120,150,180,300,600];
    let nTimeCount = 9;
    var nTimeIndex = 0;
    
    var timer = Timer()
    var isTimerRunning = -1;
    
    let healthStore = HKHealthStore()
    
    //State of the app - is the workout activated
    var workoutActive = false
    
    // define the activity type and location
    var session : HKWorkoutSession?
    let heartRateUnit = HKUnit(from: "count/min")
    //var anchor = HKQueryAnchor(fromValue: Int(HKAnchoredObjectQueryNoAnchor))
    var currenQuery : HKQuery?
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
    }
    override func didAppear() {
        guard HKHealthStore.isHealthDataAvailable() == true else {
            label.setText("not available")
            return
        }
        
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate) else {
            displayNotAllowed()
            return
        }
        
        let dataTypes = Set(arrayLiteral: quantityType)
        healthStore.requestAuthorization(toShare: nil, read: dataTypes) { (success, error) -> Void in
            if success == false {
                self.displayNotAllowed()
            }
        }
        startWorkout()
    }
    override func willActivate() {
        super.willActivate()
        
//        startWorkout()
    }
    
    
    func displayNotAllowed() {
        label.setText("not allowed")
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        switch toState {
        case .running:
            workoutDidStart(date)
        case .ended:
            workoutDidEnd(date)
        default:
            print("Unexpected state \(toState)")
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        // Do nothing for now
        print("Workout error")
    }
    

    func workoutDidStart(_ date : Date) {
        if let query = createHeartRateStreamingQuery(date) {
            self.currenQuery = query
            healthStore.execute(query)
        } else {
            label.setText("cannot start")
        }
    }
    
    func workoutDidEnd(_ date : Date) {
            healthStore.stop(self.currenQuery!)
            label.setText("---")
            session = nil
    }
    
    // MARK: - Actions
    @IBAction func startBtnTapped() {
        if (self.workoutActive) {
            //finish the current workout
            self.workoutActive = false
            self.startStopButton.setTitle("Start")
            if let workout = self.session {
                healthStore.end(workout)
            }
        } else {
            //start a new workout
            self.workoutActive = true
            self.startStopButton.setTitle("Stop")
            startWorkout()
        }
    }
    
    func startWorkout() {
        
        // If we have already started the workout, then do nothing.
        if (session != nil) {
            return
        }
        // Configure the workout session.
        let workoutConfiguration = HKWorkoutConfiguration()
        workoutConfiguration.activityType = .crossTraining
        workoutConfiguration.locationType = .indoor
        
        do {
            session = try HKWorkoutSession(configuration: workoutConfiguration)
            session?.delegate = self
        } catch {
            fatalError("Unable to create the workout session!")
        }
        
        healthStore.start(self.session!)
    }
    
    func createHeartRateStreamingQuery(_ workoutStartDate: Date) -> HKQuery? {

        
        guard let quantityType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate) else { return nil }
        let datePredicate = HKQuery.predicateForSamples(withStart: workoutStartDate, end: nil, options: .strictEndDate )
        //let devicePredicate = HKQuery.predicateForObjects(from: [HKDevice.local()])
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates:[datePredicate])
        
        
        let heartRateQuery = HKAnchoredObjectQuery(type: quantityType, predicate: predicate, anchor: nil, limit: Int(HKObjectQueryNoLimit)) { (query, sampleObjects, deletedObjects, newAnchor, error) -> Void in
            //guard let newAnchor = newAnchor else {return}
            //self.anchor = newAnchor
//            self.updateHeartRate(sampleObjects)
        }
        
        heartRateQuery.updateHandler = {(query, samples, deleteObjects, newAnchor, error) -> Void in
            //self.anchor = newAnchor!
//            self.updateHeartRate(samples)
        }
        return heartRateQuery
    }
    
    func updateHeartRate(_ samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample] else {return}
        
        DispatchQueue.main.async {
            guard let sample = heartRateSamples.first else{return}
            let value = sample.quantity.doubleValue(for: self.heartRateUnit)
            self.label.setText(String(UInt16(value)))
            
            // retrieve source from sample
            let name = sample.sourceRevision.source.name
            self.updateDeviceName(name)
            self.animateHeart()
        }
    }
    
    func updateDeviceName(_ deviceName: String) {
        deviceLabel.setText(deviceName)
    }
    
    func animateHeart() {
        self.animate(withDuration: 0.5) {
            self.heart.setWidth(52)
            self.heart.setHeight(52)
        }
        
        let when = DispatchTime.now() + Double(Int64(0.5 * double_t(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        
        DispatchQueue.global(qos: .default).async {
            DispatchQueue.main.asyncAfter(deadline: when) {
                self.animate(withDuration: 0.5, animations: {
                    self.heart.setWidth(45)
                    self.heart.setHeight(45)
                })            }
            
            
        }
    }
    
    @IBAction func onInterval() {
        nTimeIndex += 1;
        nTimeIndex = nTimeIndex % nTimeCount;
            labelTime.setText(timeString(time: TimeInterval(nTimes[nTimeIndex])))
        
        isTimerRunning = -1
        timer.invalidate()
        labelStart.setText("Start")
    }
    @IBAction func onClear() {
        labelStart.setText("Start")
        seconds = nTimes[nTimeIndex];
        labelTime.setText(timeString(time: TimeInterval(seconds)))
        nSet = 1;
        labelSet.setText(String(nSet))
        timer.invalidate()
        isTimerRunning = -1;
//        nTimeIndex = 0;
    }
    
    @IBAction func onStart() {
        
        if isTimerRunning == -1 {
            labelStart.setText("Stop")
            isTimerRunning = 1
            seconds = nTimes[nTimeIndex];
            runTimer()
//            startNewWorkout()

        }
        else if(isTimerRunning == 1){
            labelStart.setText("Start")
            isTimerRunning = 0;
            timer.invalidate()
//            if let workout = self.session {
//                healthStore.end(workout)
//            }
        }
        else if(isTimerRunning == 0){
            labelStart.setText("Stop")
            isTimerRunning = 1;
            runTimer()
//            startNewWorkout()

        }
    }
    
    func timeString(time:TimeInterval) -> String {
        if(time == 600){
            return "10 M"
        }else{
            let minutes = Int(time) / 60 % 60
            let seconds = Int(time) % 60
            return String(format:"%01i:%02i", minutes, seconds)
        }
    }
    func stringWithUUID() -> String {
        let uuidObj = CFUUIDCreate(nil)
        let uuidString = CFUUIDCreateString(nil, uuidObj)!
        return uuidString as String
    }
    func updateTimer(){
        if seconds < 1 {
            seconds = nTimes[nTimeIndex];
            //Send alert to indicate time's up.
//            seconds -= 1
            labelTime.setText(timeString(time: TimeInterval(seconds)))
            nSet += 1;
            labelSet.setText(String(nSet))
            
            isTimerRunning = -1
            timer.invalidate()
            labelStart.setText("Start")
            
            let content = UNMutableNotificationContent()
            content.title = "How many days are there in one year"
            content.subtitle = "Do you know?"
            content.body = "Do you really know?"
            content.badge = 1
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            let request = UNNotificationRequest(identifier: "timerDone", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            
            
        } else {
            seconds -= 1
            labelTime.setText(timeString(time: TimeInterval(seconds)))
        }
        if seconds == 0{
            WKInterfaceDevice.current().play(.notification)
        }
    }
    
    func runTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: (#selector(updateTimer)),
                                     userInfo: nil, repeats: true)
    }
    
}
