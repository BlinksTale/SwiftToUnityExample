#if UNITY_IOS && !UNITY_EDITOR
using System.Runtime.InteropServices;
#endif
using UnityEngine;

public class CubeScript : MonoBehaviour
{
    public GameObject cube;
    public Vector3 rotate;
    public GUIStyle msgStyle;

    private Rect[] _rect = new Rect[20]; // array of rects for various positions vertically
    private string _msg;
    private string myMessage = "Type your message here";

    string localPlayerName = "null";
    string playersListString = "empty"; // getPlayersListString()
    string lastGroupText = "..."; // lastGroupText
    string myText = "Type your message here";

#if UNITY_IOS && !UNITY_EDITOR
    [DllImport("__Internal")]
    private static extern void UnityOnStart(string cSharpString);
    [DllImport("__Internal")]
    private static extern void PrintText(string cSharpString);
    [DllImport("__Internal")]
    private static extern void UnityOnEnd(string cSharpString);
    
    [DllImport("__Internal")]
    private static extern void GetLocalPlayerName();
    [DllImport("__Internal")]             
    private static extern void GetPlayersListString();
    [DllImport("__Internal")]             
    private static extern void GetLastGroupText();
    
    [DllImport("__Internal")]
    private static extern void SetupGroupActivity();
    [DllImport("__Internal")]
    private static extern void StartGroupActivity();
    [DllImport("__Internal")]
    private static extern void EndGroupActivity();
    [DllImport("__Internal")]
    private static extern void SubmitText(string cSharpString);
#endif

    private void Start()
    {
        int uiElementHeight = 120;
        float uiScreenWidth = 0.8f;

        for (int i = 0; i < _rect.Length; i++)
        {
            _rect[i] = new Rect(Screen.width*(1f- uiScreenWidth)/2f, uiElementHeight + i * uiElementHeight, Screen.width*uiScreenWidth, uiElementHeight);
        }
        _msg = "";

#if UNITY_IOS && !UNITY_EDITOR
        SetupGroupActivity();
#endif
    }

    private void OnMessageReceived(string msg)
    {
        _msg = msg;

        // Crude approach to discerning message type to update variables:
        string[] s = msg.Split(':');
        if (s.Length > 1) {
            string content = s[1].Trim();
            switch (s[0])
            {
                case "GetLocalPlayerName":
                    localPlayerName = content;
                    break;
                case "GetPlayersListString":
                    playersListString = content;
                    break;
                case "GetLastGroupText":
                    lastGroupText = content;
                    break;
            }
        }
    }

    private void OnGUI()
    {
        // Basic join/leave/sendMessage SharePlay interface with playerName, list
        // of other players (cutoff currently), and lastGroupText (aka message) sent

        int i = 0; // uiElementNumber (increment per use) - quick solution to space UI items out

        GUI.Label(_rect[i++], string.IsNullOrEmpty(_msg) ? "Waiting for message..." : _msg, msgStyle);
        i++; // buffer
        GUI.Label(_rect[i++], "My name:", msgStyle);
        GUI.Label(_rect[i++], localPlayerName, msgStyle);
        if (GUI.Button(_rect[i++], "Start Group Activity")) { StartGroupActivity(); }
        if (GUI.Button(_rect[i++], "End Group Activity"))   { EndGroupActivity();   }
        i++; // buffer
        GUI.Label(_rect[i++], "Current players:" + playersListString, msgStyle);
        i++; // buffer
        GUI.Label(_rect[i++], "Current message:", msgStyle);
        GUI.Label(_rect[i++], lastGroupText, msgStyle);
        i++; // buffer
        myText = GUI.TextField(_rect[i++], myText);
        if (GUI.Button(_rect[i++], "Submit")) { SubmitText(myText); myText = ""; } // empty text field on submitting

    }

#if UNITY_IOS && !UNITY_EDITOR
    // real code on device will call Obj-C and Swift codes here instead
#else
    // These are all fallback functions for editor, until we're on device
    void SetupGroupActivity()
    {
        Debug.Log("Setup Group Activity"); // setupGroupActivity
    }

    void StartGroupActivity()
    {
        Debug.Log("Start Group Activity"); // handleStartGroupActivity
    }

    void EndGroupActivity()
    {
        Debug.Log("End Group Activity"); // handleEndGroupActivity
    }

    void SubmitText(string text)
    {
        Debug.Log("Submit Text: " + text); // submitText(text: myText) 
    }
#endif

    private void Update()
    {
        cube.transform.Rotate(rotate * Time.deltaTime);
    }

    private void FixedUpdate()
    {
#if UNITY_IOS && !UNITY_EDITOR
        // Continuously request latest variables
        // (done this way since we must await UnitySendMessage
        // from Swift, which OnMessageReceived picks up)
        GetLocalPlayerName();
        GetPlayersListString();
        GetLastGroupText();

#endif
    }
}
