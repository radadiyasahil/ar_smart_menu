using ARSmartMenu.Domain.Enums;

namespace ARSmartMenu.Application.CaptureGuides;

/// <summary>
/// Reusable capture guide definitions for photographer portal overlays.
/// </summary>
public static class CaptureGuideCatalog
{
    public record CaptureGuideItem(
        CaptureGuideType Type,
        string Title,
        string Instruction,
        string Category);

    public static IReadOnlyList<CaptureGuideItem> GetGuidesForCategory(BusinessCategory category) =>
        category switch
        {
            BusinessCategory.Restaurant or BusinessCategory.Cafe or BusinessCategory.Bakery => FoodGuides,
            BusinessCategory.Clothing => ClothingGuides,
            BusinessCategory.Furniture => FurnitureGuides,
            _ => FoodGuides
        };

    public static readonly IReadOnlyList<CaptureGuideItem> FoodGuides =
    [
        new(CaptureGuideType.FoodFront, "Front Angle", "Capture straight-on front view at eye level", "Food"),
        new(CaptureGuideType.Food45Front, "45° Front", "Capture at 45° angle from front-left", "Food"),
        new(CaptureGuideType.FoodTop, "Top View", "Capture directly from above", "Food"),
        new(CaptureGuideType.FoodLeft, "Left Side", "Capture left profile", "Food"),
        new(CaptureGuideType.FoodRight, "Right Side", "Capture right profile", "Food"),
        new(CaptureGuideType.Food45Back, "45° Back", "Capture at 45° angle from back-right", "Food"),
        new(CaptureGuideType.Food360Orbit, "360° Orbit Video", "Slow orbit video around the dish", "Food"),
    ];

    public static readonly IReadOnlyList<CaptureGuideItem> ClothingGuides =
    [
        new(CaptureGuideType.ClothingMannequin, "Mannequin Shot", "Full garment on mannequin", "Clothing"),
        new(CaptureGuideType.ClothingFront, "Front", "Flat lay or mannequin front", "Clothing"),
        new(CaptureGuideType.ClothingBack, "Back", "Back view of garment", "Clothing"),
        new(CaptureGuideType.ClothingDetail, "Detail Closeup", "Stitching, buttons, logos", "Clothing"),
        new(CaptureGuideType.ClothingFabric, "Fabric Texture", "Close-up fabric weave", "Clothing"),
    ];

    public static readonly IReadOnlyList<CaptureGuideItem> FurnitureGuides =
    [
        new(CaptureGuideType.FurnitureAllSides, "All Sides", "Capture front, back, left, right", "Furniture"),
        new(CaptureGuideType.FurnitureScaleRef, "Scale Reference", "Include reference object for scale", "Furniture"),
        new(CaptureGuideType.FurnitureTexture, "Texture Closeup", "Material and finish details", "Furniture"),
        new(CaptureGuideType.FurnitureRoomPlacement, "Room Placement", "In-context room setting shot", "Furniture"),
    ];
}
