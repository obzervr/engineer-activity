using System;
namespace NYCTaxiTrips.Models
{
    public class TaxiTrip
    {
        public int id {get; set;}
        public string vendor_id { get; set;}
        public DateTime pickup_datetime {get; set;}
        public DateTime dropoff_datetime {get; set;}
        public  int passenger_count {get; set;}
        public decimal trip_distance {get; set;}
        public double pickup_longitude {get; set;}
        public double pickup_latitude {get; set;}
        public int? rate_code {get; set;}
        public double dropoff_longitude {get; set;}
        public double dropoff_latitude {get; set;}
        public string payment_type {get; set;}
        public decimal fare_amount {get; set;}
        public decimal extra {get; set;}
        public decimal mta_tax {get; set;}
        public decimal tip_amount {get; set;}
        public decimal tolls_amount {get; set;}
        public decimal imp_surcharge {get; set;}
        public decimal total_amount {get; set;}

    }
}