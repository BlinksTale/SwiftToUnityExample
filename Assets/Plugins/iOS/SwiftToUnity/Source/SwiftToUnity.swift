import Foundation
import UIKit
import GroupActivities
import SwiftUI
import Combine
import CloudKit

@objc public class SwiftToUnity: NSObject
{
    @objc public static let shared = SwiftToUnity()

    @available(iOS 15.0, *)
    @objc public static let manager = SharePlayManager()
    
    @objc public func UnityOnStart(text: String)
    {
        UnitySendMessage("Cube", "OnMessageReceived", "Hello: \(text)");
    }
  
    @objc public func PrintText(text: String)
    {
        UnitySendMessage("Cube", "OnMessageReceived", "Message: \(text)!");
    }
  
    @objc public func UnityOnEnd(text: String)
    {
        UnitySendMessage("Cube", "OnMessageReceived", "Goodbye: \(text)");
    }
  
}

// FIXME: We can probably have Bundle, SharePlayManager, and GroupMessageActivity in different files - but this is quicker to start with before looking into linking issues or anything.

// Message types that we can send via GroupActivity
enum GroupTextMessageType: Codable {
  case join(id: UUID?, name: String)
  case sendText(text: String)
  case leave(id: UUID?, name: String)
}

// Actual activity in action - mostly holds metadata
@available(iOS 15.0, *)
struct GroupMessageActivity: GroupActivity {
  var metadata: GroupActivityMetadata {
    var metadata = GroupActivityMetadata()
    metadata.type = .generic
    metadata.title = "Unity Game"
    metadata.previewImage = Bundle.main.icon?.cgImage ?? // try for icon,
      UIImage(systemName: "gamecontroller.fill")?.cgImage //  fallback bubble
    
    return metadata
  }
}

// Convert our icon into the activity image this way.
// Credit for this code:
// by Rufat Mirza, Jan 23, 2021
// https://stackoverflow.com/a/65862395
extension Bundle {
  
  @objc public var icon: UIImage? {
    
    if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
       let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
       let files = primary["CFBundleIconFiles"] as? [String],
       let icon = files.last
    {
      return UIImage(named: icon)
    }
    
    return nil
  }
}

@available(iOS 15.0, *)
@objc public class SharePlayManager : NSObject {
    
  @objc public var lastGroupText: String = "waiting..."
  @objc public var currentPlayersList: [String: String] = [:]
   
  @objc public var setupAlready: Bool = false
  var tasks = Set<Task<Void, Never>>()
  var subscriptions = Set<AnyCancellable>()
  var groupSession:GroupSession<GroupMessageActivity>?
  var groupSessionMessenger:GroupSessionMessenger?
  var groupActivity: GroupMessageActivity = {
    let activity = GroupMessageActivity()
    return activity
  }()
  
  @objc public var localPlayerNumber = Int.random(in: 0..<1024)
  @objc public var localPlayerName: String {
    get {
      return "Player \(localPlayerNumber)"
    }
  }
  
  @objc public func SharePlayManager() {
    print ("Hello, shareplay world")
  }
  
  // Helper method to configure a Group Session:
  // (lots of initial setup for an activity)
  func configure(localGroupSession:GroupSession<GroupMessageActivity>) {
    
    // grab the group session's messenger and store it locally, along with session itself
    let messenger = GroupSessionMessenger(session: localGroupSession)
    groupSessionMessenger = messenger
    groupSession = localGroupSession
    
    addToPlayersList(id: groupSession?.localParticipant.id, name: localPlayerName)
    
    // clear past listeners listening for self's join calls (self joining others):
    subscriptions.removeAll()
    
    setupMessageSending(messenger: messenger)
    setupMessageReceiving(messenger: messenger)
    
    groupSession?.join()
    
  }
  
  // Run Configure for our groupSession
  @objc public func setupGroupActivity() {
    let task = Task.detached { [self] in
      //guard let self = self else { return } // disabled since we aren't in a class implementation, though another null check might help here instead (EDIT: this was an old comment/decision, but haven't figured out fix now that we are in a class yet since re-enabling doesn't "just work" either)
      
      for await session in GroupMessageActivity.sessions() {
        // once a session is found, configure it in here
        await self.configure(localGroupSession: session)
      }
      
    }
    tasks.insert(task)
  }
  
  // Start of activity:
  @objc public func startGroupActivity() {
    Task.init {
      setupGroupActivity()
      
      switch await groupActivity.prepareForActivation() {
      case .activationPreferred:
        try await groupActivity.activate() // configures session and invites other users on call to join
      case .activationDisabled:
        print("activation disabled")
      case .cancelled:
        print("activation cancelled")
      default:
        print("uknonwn case")
      }
    }
  }
  
  // Conclusion of activity:
  @objc public func endGroupActivity() {
    
    resetPlayersList()
    
    // Then terminate session: (try .leave later maybe, to not kick out others or if not last?)
    if let groupSession = groupSession {
      groupSession.end()
    }
  }
  
  // Functions to handle start/end group activities:
  @objc public func handleStartGroupActivity() {
    lastGroupText = "Started Group Activity"
    
    startGroupActivity()
  }
  
  @objc public func handleEndGroupActivity() {
    lastGroupText = "Ended Group Activity"
    
    groupMessengerSend(GroupTextMessageType.leave(id: groupSession?.localParticipant.id, name: localPlayerName))
    endGroupActivity()
  }
  
  @objc public func addToPlayersList(id: UUID?, name: String) {
    if (id != nil) {
      currentPlayersList[getIdString(id: id)] = name
    }
  }
  
  @objc public func removeFromPlayersList(id:UUID?) {
    if (id != nil) {
      currentPlayersList.removeValue(forKey: getIdString(id: id))
    }
  }
  
  @objc public func resetPlayersList() {
    
    // Remove all other players from our active list, since we quit
    currentPlayersList.removeAll()
    
    addToPlayersList(id: groupSession?.localParticipant.id, name: localPlayerName)
  }
  
  // convert UUID to a string (was more advanced before)
  @objc public func getIdString(id: UUID?) -> String {
    let idString = "\(id)"
    return idString
  }
  
  // String for use displaying all current players
  @objc public func getPlayersListString() -> String {
    var result = ""
    currentPlayersList.forEach {
      result = "\(result)\n\($0)"
    }
    UnitySendMessage("Cube", "OnMessageReceived", "GetPlayersListString: \(result)");
    return result
  }
  
  // Send data to all participants using GroupSessionMessenger
  public func setupMessageSending(messenger: GroupSessionMessenger) {
    
    groupSession?.$activeParticipants.sink{ [self] activeParticipants in
      
      messengerSend(messenger: messenger, GroupTextMessageType.join(id: groupSession?.localParticipant.id, name: localPlayerName))
      
    }.store(in: &subscriptions)
    
  }
  
  // Handle messages arriving from GroupSessionMessenger
  public func setupMessageReceiving(messenger: GroupSessionMessenger) {
    
    let task = Task.detached {
      // task to receive message via group session messenger
      for await (message, _) in messenger.messages(of: GroupTextMessageType.self) {
        switch message {
        case .join(let id, let name):
          await self.handleJoinMessage(id: id, name: name)
        case .sendText(let text):
          await self.handleTextMessage(text: text)
        case .leave(let id, let name):
          await self.handleLeaveMessage(id: id, name: name)
        }
      }
      
    }
    
    tasks.insert(task)

  }
  
  // Send Text via a GroupSession Message:
  @objc public func sendTextMessage(text: String) {
    groupMessengerSend(GroupTextMessageType.sendText(text: text))
  }
  
  // For use with existing groupSessionMessenger
  func groupMessengerSend(_ value: GroupTextMessageType) {
    guard let messenger = groupSessionMessenger else {
      return
    }
    messengerSend(messenger: messenger, value)
  }
  
  // Reusable code for messenger sending any message
  func messengerSend( messenger: GroupSessionMessenger, _ value: GroupTextMessageType) {
    
    Task.init {
      do {
        // catch any time self joins a game, and send that:
        try await messenger.send(value)
        // GroupTextMessageType.sendText(text: text)
      } catch {
        print (error)
      }
    };
    
  }
  
  // Assign value to display text
  @objc public func setText(text: String) {
    lastGroupText = text
  }
  
  // Local sendText function, updates remote players too:
  @objc public func submitText(text: String) {
    setText(text: text)
    sendTextMessage(text: text)
  }
  
  // Player Joins Game:
  @objc public func handleJoinMessage(id:UUID?, name: String) {
    lastGroupText = "Hello, " + name + "!"
    
    addToPlayersList(id: id, name: name)
  }

  // Text Received:
  @objc public func handleTextMessage(text: String) {
    setText(text: text)
  }

  // Player Leaves Game:
  @objc public func handleLeaveMessage(id:UUID?, name: String) {
    lastGroupText = "Goodbye, " + name + "!"
    
    removeFromPlayersList(id: id)
  }
  
  @objc public func getLocalPlayerName() {
    UnitySendMessage("Cube", "OnMessageReceived", "GetLocalPlayerName: \(localPlayerName)");
  }
  
  @objc public func getLastGroupText() {
    UnitySendMessage("Cube", "OnMessageReceived", "GetLastGroupText: \(lastGroupText)");
  }

}
