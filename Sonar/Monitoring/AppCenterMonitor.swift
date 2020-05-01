//
//  AppCenterMonitoring.swift
//  Sonar
//
//  Created by NHSX.
//  Copyright © 2020 NHSX. All rights reserved.
//

import Foundation
import AppCenter
import AppCenterAnalytics

protocol AppCenterAnalyticsReporting {
    func trackEvent(_ eventName: String, withProperties properties: [String : String]?)
}

struct AppCenterMonitor: AppMonitoring {
    
    private var reporter: AppCenterAnalyticsReporting?
    
    static let shared: AppCenterMonitor = {
        guard !Environment.appCenterKey.isEmpty else {
            return AppCenterMonitor(reporter: nil)
        }
        
        MSAppCenter.start(Environment.appCenterKey, withServices: [MSAnalytics.self])
        return AppCenterMonitor(reporter: AppCenterAnalyticsReporter())
    }()
    
    init(reporter: AppCenterAnalyticsReporting?) {
        self.reporter = reporter
    }
    
    func report(_ event: AppEvent) {
        reporter?.trackEvent(event.nameForAppCenter, withProperties: event.propertiesForAppCenter)
    }
}

private struct AppCenterAnalyticsReporter: AppCenterAnalyticsReporting {
    func trackEvent(_ eventName: String, withProperties properties: [String : String]?) {
        MSAnalytics.trackEvent(eventName, withProperties: properties)
    }
}

private extension AppEvent {
    
    var nameForAppCenter: String {
        switch self {
        case .partialPostcodeProvided: return "Partial postcode provided"
        case .onboardingCompleted: return "Onboarding completed"
        case .registrationSucceeded: return "Registration succeeded"
        case .registrationFailed: return "Registration failed"
        case .collectedContactEvents: return "Collected contact events"
        }
    }
    
}

private extension AppEvent {
    
    var propertiesForAppCenter: [String: String]? {
        switch self {
        case .partialPostcodeProvided,
             .onboardingCompleted,
             .registrationSucceeded:
            return nil
            
        case .registrationFailed(let reason):
            return ["Reason": reason.nameForAppCenter]
            
        case .collectedContactEvents(let yesterday, let all):
            return [
                "Yesterday": "\(yesterday)",
                "All": "\(all)",
            ]
        }
    }
    
}

private extension AppEvent.RegistrationFailureReason {
    
    var nameForAppCenter: String {
        switch self {
        case .waitingForFCMTokenTimedOut: return "No FCM token"
        case .registrationCallFailed: return "Registration call failed"
        case .waitingForActivationNotificationTimedOut: return "Activation notification not received"
        case .activationCallFailed: return "Activation call failed"
        }
    }

}