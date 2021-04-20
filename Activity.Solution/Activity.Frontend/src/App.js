import React, {useState} from "react";
import { GoogleMap, withScriptjs, withGoogleMap, Marker, InfoWindow } from "react-google-maps";
import NYCTripsReader from "./NYCTripsReader";

function Map(){

  let map = null; 

  
  const dataFetch = NYCTripsReader;

  const [isGroup, setIsGroup] = useState(true);
  
  const [data, setData] = useState([]);

  const [selectedMark, setSelectedMark] = useState(null);

  const [tripType, setTripType] = useState("PickUp");
  
  const reloadMarkers = map => {

    var sw = {lat: map.getBounds().getSouthWest().lat(),lng: map.getBounds().getSouthWest().lng()};
    var ne = {lat: map.getBounds().getNorthEast().lat(),lng: map.getBounds().getNorthEast().lng()}; 
    setIsGroup(map.getZoom() < 20)
    dataFetch(isGroup, sw, ne, tripType).then(data => setData(data));
  }

  const clearMarkers = () => {
    setSelectedMark(null);
    setData([]);
  }

  return(
    <div>
      <div>
        <label>
            <input type="radio" value="PickUp" checked={tripType === 'PickUp'} onClick={() => {setTripType('PickUp')}} />
            Pick Up
        </label>
        <label>
            <input type="radio" value="DropOff" checked={tripType === 'DropOff'} onClick={() => {setTripType('DropOff')}} />
            Drop Off
        </label>
      </div>
      <GoogleMap 
      ref={m => map = m}
      defaultZoom={Number(process.env.REACT_APP_DEFAULT_ZOOM)} 
      defaultCenter={{lat:Number(process.env.REACT_APP_DEFAULT_LAT), lng:Number(process.env.REACT_APP_DEFAULT_LNG)}} 
      onTilesLoaded={() => reloadMarkers(map)}
      onZoomChanged={clearMarkers}
      onDragEnd={clearMarkers}
    >  
      { isGroup?
        data.map(element =>{
          return(
          <Marker 
            position={{
              lat:element.centre_pickup_latitude,
              lng:element.centre_pickup_longitude
            }}
            onClick={() =>{
              setSelectedMark(element);
            }}
          />);
        }):
        data.map(element =>{
          return(
          <Marker 
            position={{
              lat:element.pickup_latitude,
              lng:element.pickup_longitude
            }}
            onClick={() =>{
              setSelectedMark(element);
            }}
          />);
        })
      }

      {
        isGroup?
        selectedMark && (
          <InfoWindow
          position={{
            lat: selectedMark.centre_pickup_latitude,
            lng: selectedMark.centre_pickup_longitude
          }} 
          onCloseClick={() => {
            setSelectedMark(null);
          }}
          >
            {
              
              <div>
                  <h2>Taxi Trips Group: {selectedMark.id}</h2>
                  <p>Number of Trips: {selectedMark.trips}</p>
                  <p>Average Passenger Count: {selectedMark.average_passenger_count}</p>
                  <p>Average Trip Distance: {selectedMark.average_distance}</p>
                  <p>Average Total Amount: {selectedMark.average_total_amount}</p>
              </div>
            }
          </InfoWindow>
        ):
        selectedMark && (
          <InfoWindow
          position={{
            lat: selectedMark.pickup_latitude,
            lng: selectedMark.pickup_longitude
          }} 
          onCloseClick={() => {
            setSelectedMark(null);
          }}
          >
            {
              <div>
                  <h2>Taxi Trip {selectedMark.id}</h2>
                  <p>assenger Count: {selectedMark.passenger_count}</p>
                  <p>Trip Distance: {selectedMark.trip_distance}</p>
                  <p>Total Amount: {selectedMark.total_amount}</p>
              </div>
            }
          </InfoWindow>
        )}
    </GoogleMap>
    </div>
  );

  
}

const WrappedMap = withScriptjs(withGoogleMap(Map));

export default function App() {
  
  return (
    <div>
      <div style={{width: '100vw', height: '90vh'}}>
        <WrappedMap 
          googleMapURL={`https://maps.googleapis.com/maps/api/js?v=3.exp&libraries=geometry,drawing,places&key=${process.env.REACT_APP_GOOGLE_KEY}`}
          loadingElement={<div style={{height:"100%"}}/>} 
          containerElement={<div style={{height:"100%"}}/>} 
          mapElement={<div style={{height:"100%"}}/>} 
        />
      </div>
    </div>
  );
  
 
}


