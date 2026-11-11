using ARSmartMenu.Domain.Enums;

namespace ARSmartMenu.Domain.Entities;

public class Product : BaseEntity
{
    public Guid BusinessId { get; set; }
    public Business Business { get; set; } = null!;

    public required string Name { get; set; }
    public string? Description { get; set; }
    public int? PricePaise { get; set; }
    public ProductCategory? Category { get; set; }
    public VegStatus VegStatus { get; set; } = VegStatus.NotApplicable;
    public bool IsSpicy { get; set; }
    public bool IsBestseller { get; set; }
    public bool IsNew { get; set; }
    public ProductStatus Status { get; set; } = ProductStatus.Draft;
    public string? RejectionReason { get; set; }
    public bool SoldOutToday { get; set; }
    public DateOnly? SoldOutDate { get; set; }
    public int DisplayOrder { get; set; }

    public ICollection<ProductPhoto> Photos { get; set; } = [];
    public Model3d? Model3d { get; set; }
    public ICollection<QrCode> QrCodes { get; set; } = [];
}
