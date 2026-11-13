namespace ARSmartMenu.Application.Common;

/// <summary>High-performance geodesic distance calculation for restaurant geofencing.</summary>
public static class GeoUtils
{
    private const double EarthRadiusMeters = 6371000.0;

    /// <summary>Calculates the great-circle distance between two GPS coordinates in meters using Haversine formula.</summary>
    public static double CalculateDistanceMeters(double lat1, double lon1, double lat2, double lon2)
    {
        var dLat = (lat2 - lat1) * (Math.PI / 180.0);
        var dLon = (lon2 - lon1) * (Math.PI / 180.0);

        var rLat1 = lat1 * (Math.PI / 180.0);
        var rLat2 = lat2 * (Math.PI / 180.0);

        var a = Math.Sin(dLat / 2.0) * Math.Sin(dLat / 2.0) +
                Math.Cos(rLat1) * Math.Cos(rLat2) *
                Math.Sin(dLon / 2.0) * Math.Sin(dLon / 2.0);

        var c = 2.0 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1.0 - a));
        return EarthRadiusMeters * c;
    }
}
