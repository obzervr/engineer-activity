using System;
using System.Globalization;
using System.Linq;
using System.Collections.Generic;
using System.Threading.Tasks;
using NYCTaxiTrips.Models;
using Microsoft.Extensions.Options;

namespace NYCTaxiTrips.Data
{
    public class BigQueryNYCTaxiTripsRepo : INYCTaxiTripsRepo
    {
        private readonly IGoogeBigQueryRepo _repository;
        private readonly int _grid;
        private readonly int _limit;

        public BigQueryNYCTaxiTripsRepo(IGoogeBigQueryRepo repository, IOptions<TaxiTripsCServiceSettings> settings)
        {
            _repository = repository;
            _grid = settings.Value.Grid;
            _limit = settings.Value.Limit;
        }

        public async Task<IEnumerable<TaxiTripGroup>> GetTaxiTripGroups(double startLng, double startLat, double lngOffset, double latOffset, TripType tripType, DateTime? startDate = null, DateTime? endDate = null)
        {
            List<ValueTuple<double, double, int>> range = new List<ValueTuple<double, double, int>>();
            
            var divLongitudeOffset = (double)lngOffset / _grid;
            var divLatitudeOffset = (double)latOffset / _grid;

            var strType = tripType == TripType.PickUp ? "pickup" : "dropoff";

            for(int i = 0; i < _grid; i++)
            {
                for(int j = 0; j < _grid; j++)
                {
                    range.Add((startLng + divLongitudeOffset * i, startLat + divLatitudeOffset * j, i * _grid + j));
                }
            }
                
            var groups = string.Join(' ', range.Select(r => $@"WHEN {strType}_longitude > {r.Item1} AND 
                                                                    {strType}_longitude <= {r.Item1 + divLongitudeOffset} AND 
                                                                    {strType}_latitude > {r.Item2} AND 
                                                                    {strType}_latitude <= {r.Item2 + divLatitudeOffset} 
                                                               THEN {r.Item3}"));
            
            

            var startDateCondition = (startDate != null)? $"AND {tripType}_datetime >= '{((DateTime)startDate).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")}'":string.Empty;
            var endDateCondition = (endDate != null)? $"AND {tripType}_datetime < '{((DateTime)endDate).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")}'":string.Empty;
            

            var query = $@" SELECT      CASE {groups} ELSE -1 END loc_range, 
                                        COUNT(*) trips, 
                                        AVG(pickup_latitude) centre_pickup_latitude,
                                        AVG(pickup_longitude) centre_pickup_longitude,
                                        AVG(dropoff_latitude) centre_dropoff_latitude,
                                        AVG(dropoff_longitude) centre_dropoff_longitude,
                                        AVG(passenger_count) average_passenger_count,
                                        AVG(trip_distance) average_distance,
                                        AVG(total_amount) average_total_amount
                            FROM        [FULL_TABLE_NAME]
                            WHERE       {strType}_longitude > {startLng} AND 
                                        {strType}_longitude <= {startLng + lngOffset} AND 
                                        {strType}_latitude > {startLat} AND 
                                        {strType}_latitude <= {startLat + latOffset}  
                                        {startDateCondition}
                                        {endDateCondition}
                            GROUP BY    loc_range 
                            ORDER BY    loc_range";

            var result = await _repository.GetData(query);
            return result.Select(row => new TaxiTripGroup{id = (int)(long)row["loc_range"] + 1,
                                                          trips = (int)(long)row["trips"],
                                                          average_passenger_count = (decimal)(double)row["average_passenger_count"],
                                                          average_distance = (decimal)(double)row["average_distance"],
                                                          centre_pickup_longitude = (double)row["centre_pickup_longitude"],
                                                          centre_pickup_latitude = (double)row["centre_pickup_latitude"],
                                                          centre_dropoff_longitude = (double)row["centre_dropoff_longitude"],
                                                          centre_dropoff_latitude = (double)row["centre_dropoff_latitude"],
                                                          average_total_amount = (decimal)(double)row["average_total_amount"]
                                                        });
        }

        public async Task<IEnumerable<TaxiTrip>> GetTaxiTrips(double startLng, double startLat, double lngOffset, double latOffset, TripType tripType, DateTime? startDate = null, DateTime? endDate = null)
        {
            var strType = tripType == TripType.PickUp ? "pickup" : "dropoff";

            var startDateCondition = (startDate != null)? $"AND {tripType}_datetime >= '{((DateTime)startDate).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")}'":string.Empty;
            var endDateCondition = (endDate != null)? $"AND {tripType}_datetime < '{((DateTime)endDate).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")}'":string.Empty;

            var query = $@"SELECT   row_number() over (order by {strType}_datetime) id,
                                    vendor_id,
                                    pickup_datetime,
                                    dropoff_datetime, 
                                    passenger_count, 
                                    trip_distance,
                                    pickup_longitude, 
                                    pickup_latitude, 
                                    rate_code,
                                    dropoff_longitude,
                                    dropoff_latitude,
                                    payment_type,
                                    fare_amount,
                                    extra,
                                    mta_tax,
                                    tip_amount,
                                    tolls_amount,
                                    imp_surcharge,
                                    total_amount
                            FROM    [FULL_TABLE_NAME]
                            WHERE   {strType}_longitude > {startLng} AND 
                                    {strType}_longitude <= {startLng + lngOffset} AND 
                                    {strType}_latitude > {startLat} AND 
                                    {strType}_latitude <= {startLat + latOffset}
                                    {startDateCondition}
                                    {endDateCondition}
                            ORDER BY {strType}_datetime
                            LIMIT {_limit}";
            
            var result = await _repository.GetData(query);
            return result.Select(row => new TaxiTrip{id = (int)(long) row["id"],
                                                     vendor_id = (string)row["vendor_id"],
                                                     pickup_datetime = DateTime.ParseExact(row["pickup_datetime"].ToString(), "d/M/yyyy h:mm:ss tt",CultureInfo.InvariantCulture),
                                                     dropoff_datetime = DateTime.ParseExact(row["dropoff_datetime"].ToString(), "d/M/yyyy h:mm:ss tt",CultureInfo.InvariantCulture), 
                                                     passenger_count = (int)(long)row["passenger_count"],
                                                     trip_distance = (decimal)(double)row["trip_distance"],
                                                     pickup_longitude = (double)(double)row["pickup_longitude"],
                                                     pickup_latitude = (double)row["pickup_latitude"],
                                                     rate_code = row["rate_code"] != null?(int?)(long)row["rate_code"]:null,
                                                     dropoff_longitude = (double)row["dropoff_longitude"],
                                                     dropoff_latitude = (double)row["dropoff_latitude"],
                                                     payment_type = (string)row["payment_type"],
                                                     fare_amount = (decimal)(double)row["fare_amount"],
                                                     extra = (decimal)(double)row["extra"],
                                                     mta_tax = (decimal)(double)row["mta_tax"],
                                                     tip_amount = (decimal)(double)row["tip_amount"],
                                                     tolls_amount = (decimal)(double)row["tip_amount"],
                                                     imp_surcharge = (decimal)(double)row["imp_surcharge"],
                                                     total_amount = (decimal)(double)row["total_amount"]
                                                    });
        }

    }
}