//
//  FirebaseService.swift
//  CaloriesApp
//
//  Created by Alexey Burmistrov on 11/14/25.
//


import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseAppCheck

class FirebaseService {
    
    private static let FirebaseUserIDKey = "FirebaseUserID"
    static func startup() async {
        let providerFactory = FirebaseAppCheckProvider()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        FirebaseApp.configure()
        
        if AppRunCounterService.isFirstLaunch() {
            await registerUserAnonymously()
        }
    }
    
    #if DEBUG
    static func cleanIDs(){
//        KeychainService().clearFirebaseAndMarketingIDs()
        UserDefaults.standard.removeObject(forKey: FirebaseUserIDKey)
        try! Auth.auth().signOut()
    }
    #endif
}

//MARK: User Section
extension FirebaseService {
    private static func registerUserAnonymously() async {
        if let FBUser = Auth.auth().currentUser {
//            if let oldUserId = KeychainService().getFirebaseID() { // got Old ID
//                UserDefaults.standard.set(oldUserId, forKey: FirebaseUserIDKey)
//            } else {
                UserDefaults.standard.set(FBUser.uid, forKey: FirebaseUserIDKey)
//                KeychainService().saveFirebaseID(FBUser.uid)
//            }
        } else {
            let result = try? await Auth.auth().signInAnonymously()
            UserDefaults.standard.set(result?.user.uid, forKey: FirebaseUserIDKey)
//            if let firebaseUID = result?.user.uid{
//                KeychainService().saveFirebaseID(firebaseUID)
//            }
            
        }
        
    }
    
    static var userID: String { // backendID use for backend interactions currently
        if let savedID = UserDefaults.standard.string(forKey: FirebaseUserIDKey) {
            return savedID
        }
        if let firebaseID = Auth.auth().currentUser?.uid { //if nil somehow try grab from firebase directly
            UserDefaults.standard.set(firebaseID, forKey: FirebaseUserIDKey)
//            KeychainService().saveFirebaseID(firebaseID)
            return firebaseID
        }
        let UUID = UUID().uuidString
        UserDefaults.standard.set(UUID, forKey: FirebaseUserIDKey)
//        KeychainService().saveFirebaseID(UUID)
        return UUID
        
    }
}

//MARK: AppCheck Section
extension FirebaseService {
    static func refreshAppCheckTokenToken() async throws -> AppCheckToken{
        try await AppCheck.appCheck().token(forcingRefresh: true)
    }
}

//MARK: - Networking request don`t work by default with AppCheck for Simulators
//MARK: and you need whitelist every simulator you use
//MARK: Follow Steps to enable networking on Simulator:
//MARK: 1) launch App on EXACT Simulator
//MARK: 2) find in console and copy your localDebugToken() from search "Firebase App Check debug token:"
//MARK: 3) follow to Firebase Console -> App Check -> press three dots icons near your App -> Manage Debug Tokens
//MARK: 4) Press "Add debug token" enter Device Name and add your localDebugToken() to second field
//MARK: 5) repeat for every EXACT Simulator / Version Simulator you need / INSTALATION (!!!!)
//MARK: -
class FirebaseAppCheckProvider: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if targetEnvironment(simulator)
        let provider = AppCheckDebugProvider(app: app)
        print("Firebase App Check debug token: \(provider?.localDebugToken() ?? "" )")
        return provider
        #else
        return DeviceCheckProvider(app: app)
        #endif   
    }
}
