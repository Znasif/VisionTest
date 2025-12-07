using Oculus.Interaction;
using UnityEngine;

public class StimulusSelectable : MonoBehaviour
{
    public int stimulusIndex;
    public static event System.Action<int> OnStimulusSelected;

    private RayInteractable rayInteractable;

    void Awake()
    {
        rayInteractable = GetComponent<RayInteractable>();
        rayInteractable.WhenSelectingInteractorAdded.Action += HandleSelect;
    }

    void OnDestroy()
    {
        if (rayInteractable != null)
            rayInteractable.WhenSelectingInteractorAdded.Action -= HandleSelect;
    }

    void HandleSelect(RayInteractor interactor)
    {
        OnStimulusSelected?.Invoke(stimulusIndex);
    }
}