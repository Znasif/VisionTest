// ColorDiscrimination.cs (renamed to avoid conflict with UnityEngine.Color)
using AEPsych;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Newtonsoft.Json.Linq;
using UnityEngine.InputSystem;

public class ColorDiscrimination : Experiment
{
    [HideInInspector] public string experimentName = "Color Discrimination 3AFC";

    [Header("Response Keys (New Input System)")]
    private Key ResponseNewKey0 = Key.UpArrow;
    private Key ResponseNewKey1 = Key.LeftArrow;
    private Key ResponseNewKey2 = Key.RightArrow;

    //[Header("3AFC Response Buttons (Right Controller)")]
    //public OVRInput.Button ResponseButton1 = OVRInput.Button.One;   // A button
    //public OVRInput.Button ResponseButton2 = OVRInput.Button.Two;   // B button
    //public OVRInput.Button ResponseButton0 = OVRInput.Button.PrimaryIndexTrigger;

    public float stimulusDuration = 0.2f;  // 200ms as per paper
    public float fixationDuration = 0.5f;

    // References to your 3 stimulus objects (circles/quads)
    public Renderer[] stimulusRenderers = new Renderer[3];
    public GameObject fixationCross;

    // Color transformation matrices from Appendix 1
    // These convert from model space (w1, w2) to linear RGB
    private float[,] M_W_TO_RGB = new float[,] {
        {0.292f, -0.292f, 0.5f},
        {0.158f, -0.158f, 0.5f},
        {-0.45f, 0.45f, 0.5f}
    };

    private int comparisonIndex;
    private TrialConfig currentConfig;

    public override void ShowStimuli(TrialConfig config)
    {
        // Guard: skip if config isn't ready yet
        if (config == null || config.Count() == 0 || !config.ContainsKey("x0_dim1"))
        {
            Debug.Log("Config not ready yet, skipping ShowStimuli");
            return;
        }

        Debug.Log($"ShowStimuli called. Config is null: {config == null}");
        if (config != null)
        {
            Debug.Log($"Config count: {config.Count()}");
            foreach (var kvp in config)
            {
                Debug.Log($"Key: '{kvp.Key}', Value type: {kvp.Value?.GetType()}, Value: {kvp.Value}");
            }
        }

        StartCoroutine(RunTrialSequence(config));
    }

    IEnumerator RunTrialSequence(TrialConfig config)
    {
        // Extract parameters from AEPsych - cast from object to List<float>
        float x0_dim1 = GetFloatFromConfig(config, "x0_dim1");
        float x0_dim2 = GetFloatFromConfig(config, "x0_dim2");
        float delta_dim1 = GetFloatFromConfig(config, "delta_dim1");
        float delta_dim2 = GetFloatFromConfig(config, "delta_dim2");

        // Calculate comparison position (clamp to gamut)
        float x1_dim1 = Mathf.Clamp(x0_dim1 + delta_dim1, -1f, 1f);
        float x1_dim2 = Mathf.Clamp(x0_dim2 + delta_dim2, -1f, 1f);

        // Convert model space to RGB
        UnityEngine.Color refColor = ModelSpaceToRGB(x0_dim1, x0_dim2);
        UnityEngine.Color compColor = ModelSpaceToRGB(x1_dim1, x1_dim2);

        AEPsychClient.Log($"Reference: ({x0_dim1:F3}, {x0_dim2:F3}) -> RGB({refColor.r:F3}, {refColor.g:F3}, {refColor.b:F3})");
        AEPsychClient.Log($"Comparison: ({x1_dim1:F3}, {x1_dim2:F3}) -> RGB({compColor.r:F3}, {compColor.g:F3}, {compColor.b:F3})");

        // Randomize comparison position (0, 1, or 2)
        comparisonIndex = Random.Range(0, 3);

        // 1. Show fixation
        
        if (fixationCross != null)
            fixationCross.SetActive(true);
        HideAllStimuli();
        yield return new WaitForSeconds(fixationDuration);
        fixationCross.GetComponent<MeshRenderer>().material.SetColor("_BaseColor", UnityEngine.Color.black);
        // 2. Show stimuli
        if (fixationCross != null)
            fixationCross.SetActive(false);

        for (int i = 0; i < 3; i++)
        {
            if (stimulusRenderers[i] != null)
            {
                UnityEngine.Color c = (i == comparisonIndex) ? compColor : refColor;
                Debug.Log($"Setting stimulus {i} to color: {c}");
                stimulusRenderers[i].material.SetColor("_BaseColor", c);
                Debug.Log($"Material color is now: {stimulusRenderers[i].material.GetColor("_BaseColor")}");
                stimulusRenderers[i].gameObject.SetActive(true);
            }
        }

        yield return new WaitForSeconds(stimulusDuration);

        // 3. Hide stimuli, wait for response
        //HideAllStimuli();
        SetText("Which was different? Press 1, 2, or 3");

        // This signals that stimulus presentation is complete
        // and the experiment should wait for response
        EndShowStimuli();
    }

    // Helper to extract float from TrialConfig
    float GetFloatFromConfig(TrialConfig config, string key)
    {
        if (!config.ContainsKey(key))
        {
            Debug.LogError($"Key '{key}' not found in config");
            return 0f;
        }

        object val = config[key];

        // Handle JArray (from Newtonsoft.Json)
        if (val is JArray jArray)
        {
            return jArray[0].Value<float>();
        }

        // Fallback for other types
        if (val is List<float> floatList)
            return floatList[0];
        if (val is List<double> doubleList)
            return (float)doubleList[0];
        if (val is double d)
            return (float)d;
        if (val is float f)
            return f;

        Debug.LogError($"Could not convert '{key}' of type {val.GetType()} to float");
        return 0f;
    }

    UnityEngine.Color ModelSpaceToRGB(float w1, float w2)
    {
        // Apply transformation: RGB = M_W_TO_RGB * [w1, w2, 1]^T
        float r = M_W_TO_RGB[0, 0] * w1 + M_W_TO_RGB[0, 1] * w2 + M_W_TO_RGB[0, 2];
        float g = M_W_TO_RGB[1, 0] * w1 + M_W_TO_RGB[1, 1] * w2 + M_W_TO_RGB[1, 2];
        float b = M_W_TO_RGB[2, 0] * w1 + M_W_TO_RGB[2, 1] * w2 + M_W_TO_RGB[2, 2];

        return new UnityEngine.Color(
            Mathf.Clamp01(r),
            Mathf.Clamp01(g),
            Mathf.Clamp01(b)
        );
    }

    void HideAllStimuli()
    {
        foreach (var r in stimulusRenderers)
        {
            if (r != null)
                r.gameObject.SetActive(false);
        }
    }



    // Override the default WaitForResponse to handle 3 keys instead of 2
    public override IEnumerator WaitForResponse()
    {
        yield return new WaitForSeconds(0.1f);
        Debug.Log("Entered Wait for Response");
        //Wait until one of the 3 keys is pressed
        while (true)
        {
            //Check keyboard
            if (Keyboard.current[ResponseNewKey0].wasPressedThisFrame)
            {
                HandleResponse(0);
                yield break;
            }
            else if (Keyboard.current[ResponseNewKey1].wasPressedThisFrame)
            {
                HandleResponse(1);
                yield break;
            }
            else if (Keyboard.current[ResponseNewKey2].wasPressedThisFrame)
            {
                HandleResponse(2);
                yield break;
            }
            if (OVRInput.GetDown(OVRInput.Button.One, OVRInput.Controller.RTouch))  // A button
            {
                HandleResponse(2);
                yield break;
            }
            else if (OVRInput.GetDown(OVRInput.Button.Two, OVRInput.Controller.RTouch))  // B button
            {
                HandleResponse(1);
                yield break;
            }
            else if (OVRInput.GetDown(OVRInput.Button.PrimaryIndexTrigger, OVRInput.Controller.RTouch))  // Trigger
            {
                HandleResponse(0);
                yield break;
            }
            yield return null;
    }
}

    void HandleResponse(int selectedIndex)
    {
        Debug.Log("Entered Handle Response");
        // Binary outcome: 1 if correct (selected the comparison), 0 if incorrect
        float outcome = (selectedIndex == comparisonIndex) ? 1f : 0f;

        string result = outcome > 0.5f ? "CORRECT" : "INCORRECT";
        UnityEngine.Color c = outcome > 0.5f ? UnityEngine.Color.green : UnityEngine.Color.red;
        fixationCross.GetComponent<Renderer>().material.SetColor("_BaseColor", c);
        AEPsychClient.Log($"Response: {selectedIndex + 1}, Comparison was at: {comparisonIndex + 1}, Result: {result}");

        // Report to server
        ReportResultToServer(outcome);
    }

    // Optional: Override OnConnectToServer for custom messaging
    public override void OnConnectToServer()
    {
        SetText("Connected to server. Select any stimulus to begin.");
        //StartCoroutine(WaitForAnySelection());
        BeginExperiment();
    }

    // Optional: Override ExperimentComplete for custom end behavior
    public override void ExperimentComplete()
    {
        base.ExperimentComplete();
        SetText("Experiment Complete! Thank you for participating.");
    }

    public override string GetName()
    {
        return experimentName;
    }

    private void Start()
    {
        Debug.Log("=== ColorDiscrimination Start() called ===");
        Debug.Log($"=== ColorDiscrimination {client.server_address}: {client.server_port} ===");
        SetText("=== Connecting to server... ===");
    }
}