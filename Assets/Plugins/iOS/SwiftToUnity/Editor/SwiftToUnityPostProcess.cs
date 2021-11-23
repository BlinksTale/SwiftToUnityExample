using System.IO;
using UnityEditor;
using UnityEditor.Callbacks;
using UnityEditor.iOS.Xcode;
using UnityEngine;

public class SwiftToUnityPostProcess : ScriptableObject
{
    /// <summary>
    /// Entitlements.plist with GroupActivities capability for Xcode.
    /// </summary>
    public DefaultAsset m_entitlementsFile;

    /// <summary>
    /// Entitlements copying code
    /// by a_p_u_r_o
    /// (gets entitlements into Xcode and hooked up)
    /// https://forum.unity.com/threads/how-to-put-ios-entitlements-file-in-a-unity-project.442277/
    /// </summary>
    /// <param name="buildTarget"></param>
    /// <param name="buildPath"></param>
    /// <param name="project"></param>
    /// <returns></returns>
    public static PBXProject CopyEntitlementsFile(BuildTarget buildTarget, string buildPath, PBXProject project)
    {
        // Must be iOS
        if (buildTarget != BuildTarget.iOS)
        {
            return project;
        }

        // Instantiate this class so we can copy the Entitlements file from it
        // (otherwise, since a static function calls this, we can't really get the file)
        var dummy = ScriptableObject.CreateInstance<SwiftToUnityPostProcess>();
        var file = dummy.m_entitlementsFile;
        ScriptableObject.DestroyImmediate(dummy);
        if (file == null)
        {
            Debug.LogError("Entitlements file must not be null! Populate this script's static public variable with Plugins/iOS/SwiftToUnity/Entitlements.plist, and this only works if this is a scriptableObject for SwiftToUnityPostProcess as a class.");

            return project;
        }

        // Then grab src and dest paths
        var targetGuid = project.GetUnityMainTargetGuid();
        var src = AssetDatabase.GetAssetPath(file);
        var target_name = "Unity-iPhone"; // PBXProject.GetUnityTargetName();
        var file_name = Path.GetFileName(src);
        var dest = buildPath + "/" + target_name + "/" + file_name;

        // and copy, plus assigning hook properties so it's in use:
        if (File.Exists(dest))
        {
            FileUtil.DeleteFileOrDirectory(dest);
        }
        FileUtil.CopyFileOrDirectory(src, dest);
        project.AddFile(target_name + "/" + file_name, file_name);
        project.AddBuildProperty(targetGuid, "CODE_SIGN_ENTITLEMENTS", target_name + "/" + file_name);

        return project;
    }

    [PostProcessBuild]
    public static void OnPostProcessBuild(BuildTarget buildTarget, string buildPath)
    {
        Debug.Log("OnPostProcessBuild: " + buildTarget);

        if (buildTarget == BuildTarget.iOS)
        {
            var projectPath = buildPath + "/Unity-iPhone.xcodeproj/project.pbxproj";

            var project = new PBXProject();
            project.ReadFromFile(projectPath);

            var unityFrameworkGuid = project.GetUnityFrameworkTargetGuid();

            // Modulemap
            project.AddBuildProperty(unityFrameworkGuid, "DEFINES_MODULE", "YES");

            // Group Activities (works!)
            // (once Unity allows this AddCapability function or equivalent though, do this instead. File copy is ugly/higher risk long term)
            //project.AddCapability(PBXCapabilityType.GroupSession) // this doesn't exist yet, might be slightly renamed once real
            project = CopyEntitlementsFile(buildTarget, buildPath, project);

            var moduleFile = buildPath + "/UnityFramework/UnityFramework.modulemap";
            if (!File.Exists(moduleFile))
            {
                FileUtil.CopyFileOrDirectory("Assets/Plugins/iOS/SwiftToUnity/Source/UnityFramework.modulemap", moduleFile);
                project.AddFile(moduleFile, "UnityFramework/UnityFramework.modulemap");
                project.AddBuildProperty(unityFrameworkGuid, "MODULEMAP_FILE", "$(SRCROOT)/UnityFramework/UnityFramework.modulemap");
            }

            // Headers
            string unityInterfaceGuid = project.FindFileGuidByProjectPath("Classes/Unity/UnityInterface.h");
            project.AddPublicHeaderToBuild(unityFrameworkGuid, unityInterfaceGuid);

            string unityForwardDeclsGuid = project.FindFileGuidByProjectPath("Classes/Unity/UnityForwardDecls.h");
            project.AddPublicHeaderToBuild(unityFrameworkGuid, unityForwardDeclsGuid);

            string unityRenderingGuid = project.FindFileGuidByProjectPath("Classes/Unity/UnityRendering.h");
            project.AddPublicHeaderToBuild(unityFrameworkGuid, unityRenderingGuid);

            string unitySharedDeclsGuid = project.FindFileGuidByProjectPath("Classes/Unity/UnitySharedDecls.h");
            project.AddPublicHeaderToBuild(unityFrameworkGuid, unitySharedDeclsGuid);

            // Save project
            project.WriteToFile(projectPath);
        }

        Debug.Log("OnPostProcessBuild: Complete");
    }
}
