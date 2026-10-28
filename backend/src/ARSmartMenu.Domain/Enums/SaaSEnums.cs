namespace ARSmartMenu.Domain.Enums;

public enum KycStatus
{
    Pending = 0,
    Submitted = 1,
    Verified = 2,
    Rejected = 3
}

public enum BusinessType
{
    Restaurant = 0,
    Cafe = 1,
    Bakery = 2,
    Clothing = 3,
    Furniture = 4
}

public enum BusinessStatus
{
    PendingApproval = 0,
    Active = 1,
    Suspended = 2,
    Rejected = 3,
    Deactivated = 4
}

public enum BillingCycle
{
    Monthly = 0,
    Yearly = 1
}

public enum SubscriptionStatus
{
    Active = 0,
    PastDue = 1,
    Cancelled = 2,
    Expired = 3,
    Trialing = 4
}

public enum ProductStatus
{
    Draft = 0,
    Submitted = 1,
    Processing = 2,
    Review = 3,
    Live = 4,
    Paused = 5,
    Rejected = 6
}

public enum VegStatus
{
    Veg = 0,
    NonVeg = 1,
    Vegan = 2,
    NotApplicable = 3
}

public enum ProductCategory
{
    Starter = 0,
    MainCourse = 1,
    Dessert = 2,
    Beverage = 3,
    Bread = 4,
    Combo = 5,
    Tops = 6,
    Bottoms = 7,
    Ethnic = 8,
    Western = 9,
    Accessories = 10,
    Sofa = 11,
    Bed = 12,
    Table = 13,
    Chair = 14,
    Storage = 15,
    Decor = 16,
    Cake = 17,
    Pastry = 18,
    Mithai = 19,
    Snack = 20,
    Other = 99
}

public enum ModelProcessingStatus
{
    Queued = 0,
    Processing = 1,
    Done = 2,
    Failed = 3,
    Approved = 4,
    Rejected = 5
}

public enum QrType
{
    Product = 0,
    Table = 1,
    Menu = 2
}

public enum PhotoAngleType
{
    Front = 0,
    Top = 1,
    Left = 2,
    Right = 3,
    Back = 4,
    Angle45Front = 5,
    Angle45Back = 6,
    Detail = 7,
    Other = 99
}
