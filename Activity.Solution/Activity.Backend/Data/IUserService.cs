using NYCTaxiTrips.Models;
using System.Collections.Generic;

namespace NYCTaxiTrips.Data{
    public interface IUserService
    {
        AuthenticateResponse Authenticate(AuthenticateRequest model);
        User GetById(int id);
    }
}
