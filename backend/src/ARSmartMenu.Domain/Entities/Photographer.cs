using ARSmartMenu.Domain.Enums;

namespace ARSmartMenu.Domain.Entities;

public class Photographer : BaseEntity
{
    public required string Name { get; set; }
    public required string Phone { get; set; }
    public required string CityCoverage { get; set; }
    public PhotographerStatus Status { get; set; } = PhotographerStatus.Available;
    public decimal Rating { get; set; }
    public int CompletedShoots { get; set; }
    public bool IsActive { get; set; } = true;

    public ICollection<ShootBooking> Bookings { get; set; } = [];
}
