using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Cors;
using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;
using NYCTaxiTrips.Models;
using NYCTaxiTrips.Data;
using NYCTaxiTrips.Helpers;

namespace NYCTaxiTrips.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [EnableCors("AllowOrigin")]
    public class TaxiTripsController: ControllerBase
    {
        private INYCTaxiTripsRepo _repository;
        
        public TaxiTripsController(INYCTaxiTripsRepo repository)
        {
            _repository = repository;
        }

        [HttpGet("{startLng}/{lngOffset}/{startLat}/{latOffset}/{tripType}")]
        [EnableCors("AllowOrigin")]
        public async Task<ActionResult<IEnumerable<TaxiTrip>>> GetTaxiTrips(double startLng, double lngOffset, double startLat, double latOffset, string tripType)
        {
            TripType tripTypeEnum;
            if(Enum.TryParse(tripType, out tripTypeEnum))
            {
                var taxitrips = await _repository.GetTaxiTrips(startLng,startLat, lngOffset,latOffset, tripTypeEnum);
                
                return Ok(taxitrips);
            }
            else
            {
                return BadRequest(new {message = "Unknown Trip Type"});
            }
        }

        [HttpGet("groups/{startLng}/{lngOffset}/{startLat}/{latOffset}/{tripType}")]
        [EnableCors("AllowOrigin")]
        public async Task<ActionResult<IEnumerable<TaxiTripGroup>>> GetTaxiTripGroups(double startLng, double lngOffset, double startLat, double latOffset, string tripType)
        {
            TripType tripTypeEnum;
            if(Enum.TryParse(tripType, out tripTypeEnum))
            {
                var taxitripgroups = await _repository.GetTaxiTripGroups(startLng,startLat, lngOffset,latOffset, tripTypeEnum);
                return Ok(taxitripgroups);
            }
            else
            {
                return BadRequest(new {message = "Unknown Trip Type"});
            }
        }

        [Authorize]
        [HttpGet("withdaterange/{startLng}/{lngOffset}/{startLat}/{latOffset}/{tripType}/{startDate}/{endDate}")]
        [EnableCors("AllowOrigin")]
        public async Task<ActionResult<IEnumerable<TaxiTrip>>> GetTaxiTripsWithDateRange(double startLng, double lngOffset, double startLat, double latOffset, string tripType, DateTime? startDate, DateTime? endDate)
        {
            TripType tripTypeEnum;
            if(Enum.TryParse(tripType, out tripTypeEnum))
            {
                var taxitrips = await _repository.GetTaxiTrips(startLng,startLat, lngOffset,latOffset, tripTypeEnum, startDate, endDate);
                return Ok(taxitrips);
            }
            else
            {
                return BadRequest(new {message = "Unknown Trip Type"});
            }
        }


        [Authorize]
        [HttpGet("groups/withdaterange/{startLng}/{lngOffset}/{startLat}/{latOffset}/{tripType}/{startDate}/{endDate}")]
        [EnableCors("AllowOrigin")]
        public async Task<ActionResult<IEnumerable<TaxiTripGroup>>> GetTaxiTripGroupsWithDateRange(double startLng, double lngOffset, double startLat, double latOffset, string tripType, DateTime? startDate, DateTime? endDate)
        {
            TripType tripTypeEnum;
            if(Enum.TryParse(tripType, out tripTypeEnum))
            {
                var taxitripgroups = await _repository.GetTaxiTripGroups(startLng,startLat, lngOffset,latOffset, tripTypeEnum, startDate, endDate);
                return Ok(taxitripgroups);
            }
            else
            {
                return BadRequest(new {message = "Unknown Trip Type"});
            }
        }

        [Authorize]
        [HttpGet("withdate/{startLng}/{lngOffset}/{startLat}/{latOffset}/{tripType}/{dateType}/{startOrEndDate}")]
        [EnableCors("AllowOrigin")]
        public async Task<ActionResult<IEnumerable<TaxiTrip>>> GetTaxiTripsWithDate(double startLng, double lngOffset, double startLat, double latOffset, string tripType, DateTime? startOrEndDate, string dateType)
        {
            TripType tripTypeEnum;
            DateType dateTypeEnum;
            IEnumerable<TaxiTrip> result;
            if(!Enum.TryParse(tripType, out tripTypeEnum))
            {
                return BadRequest(new {message = "Unknown Trip Type"});
            }
            else if(!Enum.TryParse(dateType, out dateTypeEnum))
            {
                return BadRequest(new {message = "Unknown Date Type"});
            }
            else
            {
                if(dateTypeEnum == DateType.StartDate)
                    result = await  _repository.GetTaxiTrips(startLng,startLat, lngOffset,latOffset, tripTypeEnum, startOrEndDate);
                else
                    result = await _repository.GetTaxiTrips(startLng,startLat, lngOffset,latOffset, tripTypeEnum, endDate: startOrEndDate);
            }

            return Ok(result);
        }

        [Authorize]
        [HttpGet("withdate/{startLng}/{lngOffset}/{startLat}/{latOffset}/{tripType}/{dateType}/{startOrEndDate}")]
        [EnableCors("AllowOrigin")]
        public async Task<ActionResult<IEnumerable<TaxiTripGroup>>> GetTaxiTripGroupsWithDate(double startLng, double lngOffset, double startLat, double latOffset, string tripType, DateTime? startOrEndDate, string dateType)
        {
            TripType tripTypeEnum;
            DateType dateTypeEnum;
            IEnumerable<TaxiTripGroup> result;
            if(!Enum.TryParse(tripType, out tripTypeEnum))
            {
                return BadRequest(new {message = "Unknown Trip Type"});
            }
            else if(!Enum.TryParse(dateType, out dateTypeEnum))
            {
                return BadRequest(new {message = "Unknown Date Type"});
            }
            else
            {
                if(dateTypeEnum == DateType.StartDate)
                    result = await  _repository.GetTaxiTripGroups(startLng,startLat, lngOffset,latOffset, tripTypeEnum, startOrEndDate);
                else
                    result = await _repository.GetTaxiTripGroups(startLng,startLat, lngOffset,latOffset, tripTypeEnum, endDate: startOrEndDate);
            }

            return Ok(result);
        }

    }
}