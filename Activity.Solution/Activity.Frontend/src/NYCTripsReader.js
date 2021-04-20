
export default function NYCDataReader(isGroup, swPosition, nePosition, positionType)
{   
    var startPosition = swPosition;
          var offset = {
              lat_offset : nePosition.lat - swPosition.lat,
              lng_offset : nePosition.lng - swPosition.lng
          };

          var params = `${startPosition.lng}/${offset.lng_offset}/${startPosition.lat}/${offset.lat_offset}/${positionType}`;

          var url = isGroup? 
                    `${process.env.REACT_APP_API_URL}${process.env.REACT_APP_TRIPGROUPS_API}${params}`: 
                    `${process.env.REACT_APP_API_URL}${process.env.REACT_APP_TRIPS_API}${params}`;

        alert(url);
        console.log(url);

          return fetch(url,
               {
                   method:"get",
                   headers:{
                      'Accept': 'application/json',
                      'crossDomain':'true',
                      'Content-Type': 'application/json',
                      'Pragma': 'no-cache'
                  }
               })
          .then(response => response.json());
}