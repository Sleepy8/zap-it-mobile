import UIKit
import Flutter
import Firebase
import FirebaseMessaging
import UserNotifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Initialize Firebase
    FirebaseApp.configure()
    
    // Configure Firebase Messaging for iOS 18.6
    Messaging.messaging().delegate = self
    
    // Request notification permissions for iOS 18.6
    UNUserNotificationCenter.current().delegate = self
    
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    UNUserNotificationCenter.current().requestAuthorization(
      options: authOptions,
      completionHandler: { _, _ in }
    )
    
    application.registerForRemoteNotifications()
    
    // Configure notification categories for iOS 18.6
    configureNotificationCategories()
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Configure notification categories for iOS 18.6
  private func configureNotificationCategories() {
    // ZAP notifications category
    let zapAction = UNNotificationAction(
      identifier: "VIEW_ZAP",
      title: "Visualizza ZAP",
      options: [.foreground]
    )
    
    let zapCategory = UNNotificationCategory(
      identifier: "zap_it_zaps",
      actions: [zapAction],
      intentIdentifiers: [],
      options: [.customDismissAction]
    )
    
    // Message notifications category
    let messageAction = UNNotificationAction(
      identifier: "REPLY_MESSAGE",
      title: "Rispondi",
      options: [.foreground]
    )
    
    let messageCategory = UNNotificationCategory(
      identifier: "zap_it_messages",
      actions: [messageAction],
      intentIdentifiers: [],
      options: [.customDismissAction]
    )
    
    // Friend request notifications category
    let acceptAction = UNNotificationAction(
      identifier: "ACCEPT_FRIEND_REQUEST",
      title: "Accetta",
      options: [.foreground]
    )
    
    let declineAction = UNNotificationAction(
      identifier: "DECLINE_FRIEND_REQUEST",
      title: "Rifiuta",
      options: [.destructive]
    )
    
    let friendRequestCategory = UNNotificationCategory(
      identifier: "zap_it_friend_requests",
      actions: [acceptAction, declineAction],
      intentIdentifiers: [],
      options: [.customDismissAction]
    )
    
    // Register categories
    UNUserNotificationCenter.current().setNotificationCategories([
      zapCategory,
      messageCategory,
      friendRequestCategory
    ])
  }
}

// MARK: - MessagingDelegate for iOS 18.6
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("Firebase registration token: \(String(describing: fcmToken))")
    
    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
  }
}

// MARK: - UNUserNotificationCenterDelegate for iOS 18.6
extension AppDelegate: UNUserNotificationCenterDelegate {
  // Handle notification when app is in foreground
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    
    // Handle different notification types for iOS 18.6
    if let type = userInfo["type"] as? String {
      switch type {
      case "new_zap":
        // Show ZAP notification with haptic feedback
        completionHandler([.alert, .badge, .sound])
        
        // Trigger haptic feedback for ZAP
        DispatchQueue.main.async {
          let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
          impactFeedback.prepare()
          impactFeedback.impactOccurred()
          
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
            mediumImpact.impactOccurred()
          }
        }
        
      case "new_message":
        // Show message notification
        completionHandler([.alert, .badge, .sound])
        
      case "friend_request":
        // Show friend request notification
        completionHandler([.alert, .badge, .sound])
        
      default:
        completionHandler([.alert, .badge, .sound])
      }
    } else {
      completionHandler([.alert, .badge, .sound])
    }
  }
  
  // Handle notification tap
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    
    // Handle notification actions for iOS 18.6
    switch response.actionIdentifier {
    case "VIEW_ZAP":
      // Handle ZAP view action
      handleZapNotification(userInfo)
      
    case "REPLY_MESSAGE":
      // Handle message reply action
      handleMessageReply(userInfo)
      
    case "ACCEPT_FRIEND_REQUEST":
      // Handle friend request accept
      handleFriendRequestAccept(userInfo)
      
    case "DECLINE_FRIEND_REQUEST":
      // Handle friend request decline
      handleFriendRequestDecline(userInfo)
      
    default:
      // Handle default notification tap
      handleDefaultNotification(userInfo)
    }
    
    completionHandler()
  }
  
  // Handle ZAP notification
  private func handleZapNotification(_ userInfo: [AnyHashable: Any]) {
    // Navigate to ZAP screen or trigger ZAP haptic feedback
    if let zapId = userInfo["zapId"] as? String {
      // Send notification to Flutter
      NotificationCenter.default.post(
        name: Notification.Name("HandleZapNotification"),
        object: nil,
        userInfo: ["zapId": zapId]
      )
    }
  }
  
  // Handle message reply
  private func handleMessageReply(_ userInfo: [AnyHashable: Any]) {
    if let conversationId = userInfo["conversationId"] as? String {
      // Navigate to chat screen
      NotificationCenter.default.post(
        name: Notification.Name("HandleMessageReply"),
        object: nil,
        userInfo: ["conversationId": conversationId]
      )
    }
  }
  
  // Handle friend request accept
  private func handleFriendRequestAccept(_ userInfo: [AnyHashable: Any]) {
    if let senderId = userInfo["senderId"] as? String {
      // Accept friend request
      NotificationCenter.default.post(
        name: Notification.Name("HandleFriendRequestAccept"),
        object: nil,
        userInfo: ["senderId": senderId]
      )
    }
  }
  
  // Handle friend request decline
  private func handleFriendRequestDecline(_ userInfo: [AnyHashable: Any]) {
    if let senderId = userInfo["senderId"] as? String {
      // Decline friend request
      NotificationCenter.default.post(
        name: Notification.Name("HandleFriendRequestDecline"),
        object: nil,
        userInfo: ["senderId": senderId]
      )
    }
  }
  
  // Handle default notification
  private func handleDefaultNotification(_ userInfo: [AnyHashable: Any]) {
    // Send notification to Flutter for default handling
    NotificationCenter.default.post(
      name: Notification.Name("HandleDefaultNotification"),
      object: nil,
      userInfo: userInfo
    )
  }
}
