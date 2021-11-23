#import <UnityFramework/UnityFramework-Swift.h>

extern "C"
{
    ///
    /// Swift example functions
    ///

    void UnityOnStart(char* cSharpString)
    {
        [[SwiftToUnity shared]   UnityOnStartWithText:(NSString* _Nonnull)[NSString stringWithUTF8String:cSharpString]];
    }

    void PrintText(char* cSharpString)
    {
        // When converting from Swift to Obj C, use method name + "With" + capitalized first parameter name:
        [[SwiftToUnity shared]   PrintTextWithText:(NSString* _Nonnull)[NSString stringWithUTF8String:cSharpString]];
    }

    void UnityOnEnd(char* cSharpString)
    {
      [[SwiftToUnity shared]   UnityOnEndWithText:(NSString* _Nonnull)[NSString stringWithUTF8String:cSharpString]];
    }

    ///
    /// SharePlay get data functions
    ///

    void GetLocalPlayerName()
    {
      if (@available(iOS 15.0, *)) {
        [[SwiftToUnity manager]   getLocalPlayerName];
      }
    }

    void GetPlayersListString()
    {
      if (@available(iOS 15.0, *)) {
        [[SwiftToUnity manager]   getPlayersListString];
      }
    }

    void GetLastGroupText()
    {
      if (@available(iOS 15.0, *)) {
        [[SwiftToUnity manager]   getLastGroupText];
      }
    }

    ///
    /// SharePlay send action functions
    ///

    void SetupGroupActivity()
    {
      if (@available(iOS 15.0, *)) {
        [[SwiftToUnity manager]   setupGroupActivity];
      }
    }

    void StartGroupActivity()
    {
      if (@available(iOS 15.0, *)) {
        [[SwiftToUnity manager]   startGroupActivity];
      }
    }

    void EndGroupActivity()
    {
      if (@available(iOS 15.0, *)) {
        [[SwiftToUnity manager]   endGroupActivity];
      }
    }

    void SubmitText(char* cSharpString)
    {
      if (@available(iOS 15.0, *)) {
        [[SwiftToUnity manager]   submitTextWithText:(NSString* _Nonnull)[NSString stringWithUTF8String:cSharpString]];
      }
    }

}
