namespace NYCTaxiTrips.Models
{
    public class TaxiTripGroup
    {
        public int id{get; set;}
        public int trips {get; set;}
        public decimal average_passenger_count {get; set;}
        public decimal average_distance {get; set;}
        public double centre_pickup_longitude {get; set;}
        public double centre_pickup_latitude {get; set;}
        public double centre_dropoff_longitude {get; set;}
        public double centre_dropoff_latitude {get; set;}
        public decimal average_total_amount {get; set;}
    }
}