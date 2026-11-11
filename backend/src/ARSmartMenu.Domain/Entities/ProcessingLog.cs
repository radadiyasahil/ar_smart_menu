namespace ARSmartMenu.Domain.Entities;

public class ProcessingLog : BaseEntity
{
    public Guid ProcessingJobId { get; set; }
    public ProcessingJob ProcessingJob { get; set; } = null!;

    public required string Message { get; set; }
    public string? Details { get; set; }
    public string Level { get; set; } = "Info";
}
