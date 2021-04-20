using Microsoft.AspNetCore.Mvc;
using NYCTaxiTrips.Models;
using NYCTaxiTrips.Data;
using NYCTaxiTrips.Helpers;

namespace NYCTaxiTrips.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class UserController: ControllerBase
    {
        private IUserService _userService;

        public UserController(IUserService userService)
        {
            _userService = userService;
        }

        [HttpPost("authenticate")]
        public IActionResult Authenticate(AuthenticateRequest model)
        {
            var response = _userService.Authenticate(model);

            if(response == null)
                return BadRequest(new {message = "User or password is incorrect"});

            return Ok(response);
        }

        [Authorize]
        [HttpGet("testauth")]
        public IActionResult TestAuthorization(){
            return Ok();
        }
    }
}