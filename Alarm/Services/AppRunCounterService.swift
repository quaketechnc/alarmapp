//
//  AppRunCounterService.swift
//  Alarm
//
//  Created by Oleksii on 24.04.2026.
//


import SwiftUI

class AppRunCounterService {
    private static let runIncrementerSetting = "numberOfRuns"  // UserDefaults dictionary key where we store number of runs
    private static let onboardedRunIncrementerSetting = "numberOfRunsAfterOnboarding"
    
    static func incrementAppRuns(_ firstTimeCompletion: (() -> Void)? = nil) -> Int {                   // counter for number of runs for the app. You can call this from App.init() or AppDelegate
        let runs = UserDefaults.standard.integer(forKey: runIncrementerSetting) + 1
        UserDefaults.standard.set(runs, forKey: runIncrementerSetting)
        
        if runs == 1 {
            firstTimeCompletion?()
        }
        return runs
    }
    
    static func incrementOnboardingRunsAppRuns(_ firstTimeCompletion: (() -> Void)? = nil) -> Int {
        let OnboardingFinished = UserDefaults.standard.bool(forKey: "OnboardingFinished")
        
        var onboardedRuns = UserDefaults.standard.integer(forKey: onboardedRunIncrementerSetting)
        
        if OnboardingFinished {
            onboardedRuns += 1
            UserDefaults.standard.set(onboardedRuns, forKey: onboardedRunIncrementerSetting)
        }
        
        if onboardedRuns == 1 {
            firstTimeCompletion?()
        }
        
        return onboardedRuns
    }
    
    static func isFirstLaunch() -> Bool {
        let usD = UserDefaults()
        let savedRuns = usD.value(forKey: runIncrementerSetting)
        return savedRuns == nil
    }
    
    static func isFirstAfterOnboardingLaunch() -> Bool {
        let usD = UserDefaults()
        let savedRuns = usD.value(forKey: onboardedRunIncrementerSetting)
        return savedRuns == nil
    }
}
