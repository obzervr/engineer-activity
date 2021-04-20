using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using NYCTaxiTrips.Models;

namespace NYCTaxiTrips.Data
{
    public interface INYCTaxiTripsRepo
    {
        Task<IEnumerable<TaxiTrip>> GetTaxiTrips(double startLng, double startlat, double lngeOffset, double latOffset, TripType tripType, DateTime? startDate = null, DateTime? endDate = null);
        Task<IEnumerable<TaxiTripGroup>> GetTaxiTripGroups(double startLng, double startlat, double lngeOffset, double latOffset, TripType tripType, DateTime? startDate = null, DateTime? endDate = null);
    }

    public enum TripType
    {
        PickUp,
        DropOff
    }

    public enum DateType
    {
        StartDate,
        EndDate
    }
}