/*******************************************************************************
 * NodeJS script to send sensors data to cayenne IoT dashboard
 * you can have a BMP280/BME280 and SI7021/HTU21D conencted to I2C bus
 * This sample has been written by Charles-Henri Hallard (ch2i.eu)
 *  
 * Requires nodejs to be already installed
 * https://nodejs.org/en/download/package-manager/#debian-and-ubuntu-based-linux-distributions
 *
 * Requires CayenneJS bme280 and si7021 libraries
 * npm install bme280-sensor si7021-sensor cayennejs
 *
 * Don't forget to put your Cayenne credential in this script, all of this 
 * stuff can be done with the script installer install.sh of this folder
 * installer will also make the as daemon to start/stop with the system
 * 
 * sudo node sensors.js
 *
 *******************************************************************************/

const BME280 = require('bme280-sensor');
const Si7021 = require('si7021-sensor');
var Cayenne = require('cayennejs');

const bme280 = new BME280({ i2cBusNo : 1, i2cAddress : 0x76 });
const si7021 = new Si7021({ i2cBusNo : 1, i2cAddress : 0x40 });

// Update every x seconds
const updateInterval = 60;

// Initiate Cayenne MQTT API
const cayenneClient = new Cayenne.MQTT({
  username: "a1ced9e0-b24e-11e6-bb76-1157597ded22",
  password: "0858f39268653283bf68bb08b165c07cd6cb1959",
  clientId: "63bf8990-bd27-11e6-ae5a-dfc2c3108b24"
});

// Read BME280 sensor data, repeat
const readBME280SensorData = () => {
  bme280.readSensorData()
    .then((data) => {
      
      console.log(`BME280 data = ${JSON.stringify(data, null, 2)}`);

			// dashboard widget automatically detects datatype & unit
			cayenneClient.celsiusWrite (0, data.temperature_C.toFixed(1));
			cayenneClient.rawWrite(1, data.humidity.toFixed(0), "rel_hum" , "p" );
			cayenneClient.hectoPascalWrite (2, data.pressure_hPa.toFixed(0));

      setTimeout(readBME280SensorData, updateInterval*1000);
    })
    .catch((err) => {
      console.log(`BME280 read error: ${err}`);
      setTimeout(readBME280SensorData, updateInterval*1000);
    });
};
	
const readSI7021SensorData = () => {
  si7021.readSensorData()
    .then((data) => {

			console.log(`SI7021 data = ${JSON.stringify(data, null, 2)}`);
			
			cayenneClient.celsiusWrite (4, data.temperature_C.toFixed(1));
			cayenneClient.rawWrite(5, data.humidity.toFixed(0), "rel_hum" , "p" );

      setTimeout(readSI7021SensorData, updateInterval*1000);
    })
    .catch((err) => {
      console.log(`Si7021 read error: ${err}`);
      setTimeout(readSI7021SensorData, updateInterval*1000);
    });
};

cayenneClient.connect((err , mqttClient) => {
	console.log('Cayenne connected')

	// Initialize the BME280 sensor
	bme280.init()
		.then(() => {
			console.log('BME280 initialization succeeded');
			readBME280SensorData();
		})
		.catch((err) => console.error(`BME280 initialization failed: ${err} `));
		
	// Initialize the si7021 sensor
	si7021.reset()
		.then(() => {
			console.log('SI7021 initialization succeeded');
			readSI7021SensorData();
		})
		.catch((err) => console.error(`Si7021 reset failed: ${err} `));
})	

