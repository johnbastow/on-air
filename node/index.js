const noble = require('@abandonware/noble');

const serviceGuid = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';
const onAirDataGuid = 'c1ad54c6-1234-4567-890a-abcdef012345';

const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

var bleIsOn = false;
var isScanning = false;
var isConnected = false;

// Check for BLE state change.
noble.on('stateChange', (state) => {
  if (state === 'poweredOn') {
    console.log('BLE powered on.  Available for scanning.')
    bleIsOn = true;
  } 
  else {
    console.log('BLE is powered Off.');
    bleIsOn = false;
    noble.stopScanning();
    console.log('Stopped scanning due to state:', state);
  }
});

const scanForOnAir = async () => {
    try {
        if (isScanning || isConnected) return;

        isScanning = true;
        if (!bleIsOn) {
            console.log('BLE is powered off.  Cannot scan.');
            return;
        }

        noble.startScanningAsync([serviceGuid], false);
        await sleep(1000);
        noble.stopScanning();
    }
    finally {
        isScanning = false;
    }
}

// var dataToWrite = Buffer.from([0x01]); 

const onOnAirFound = async (peripheral) => {
    try {
        if (isConnected) return;

        isConnected = true;
        noble.stopScanning();
 
        console.log(`Found device: ${peripheral.advertisement.localName}`);
        console.log(`Device UUID: ${peripheral.uuid}`);
        console.log(`Local name: ${peripheral.advertisement.localName}`);

        console.log ('Connecting...');
        await peripheral.connectAsync();
        console.log('Connected.');
        const { characteristics } = await peripheral.discoverSomeServicesAndCharacteristicsAsync(
            [serviceGuid],
            [onAirDataGuid]
        );
      
        if (characteristics.length > 0) {
            let buffer = Buffer.alloc(8);
            let epochDate = BigInt(Date.now());
            buffer.writeBigInt64LE(epochDate, 0);
            console.log(epochDate);
            console.log('Found characteristic. Writing data...');
            await characteristics[0].writeAsync(buffer, false); // Write with response
            console.log('Data successfully written to characteristic.');
        } 
        else {
            console.log('Characteristic not found.');
        }
        await sleep(1000);
        await peripheral.disconnectAsync();
        console.log('Disconected.');
    }
    finally {
        isConnected = false;    
    }
}

setInterval(scanForOnAir, 5000);

noble.on('discover', onOnAirFound);

// // Create a buffer with a specific size (e.g., 4 bytes for an integer)
// const buffer = Buffer.alloc(4);

// // Write an integer into the buffer (e.g., 42)
// const integer = 42;

// // Use writeInt32LE or writeInt32BE for a 32-bit integer
// buffer.writeInt32LE(integer, 0); // Little-endian
// // buffer.writeInt32BE(integer, 0); // Big-endian (if needed)

// // Log the buffer and its contents
// console.log(buffer); // Output: <Buffer 2a 00 00 00>
// console.log(buffer.toString('hex')); // Output: '2a000000'

// // Read the integer back from the buffer
// const readInteger = buffer.readInt32LE(0); // Little-endian
// console.log(readInteger); // Output: 42


// Check for discovered peripherals.
// noble.on('discover', (peripheral) => {
//   console.log(`Found device: ${peripheral.advertisement.localName}`);
//   console.log(`Device UUID: ${peripheral.uuid}`);
  
//   // Connect to a device with a specific name or UUID (replace with your target)
//   const targetName = 'ArduinoPeripheral'; // Change to the device you want to connect to
//   if (peripheral.advertisement.localName === targetName) {
//     console.log('Connecting to target device:', targetName);
    
//     peripheral.connect((error) => {
//       if (error) {
//         console.log('Connection error:', error);
//         return;
//       }
//       console.log('Connected to:', targetName);

//       // Discover services and characteristics
//       peripheral.discoverAllServicesAndCharacteristics(async (error, services, characteristics) => {
//         if (error) {
//           console.log('Service/Characteristic discovery error:', error);
//           return;
//         }

//         console.log('Services and characteristics discovered:');
//         characteristics.forEach((char) => {
//           console.log(`Characteristic UUID: ${char.uuid}`);
//         });

//         await sleep(10000)

//         // Disconnect from the device
//         peripheral.disconnect((error) => {
//           if (error) {
//             console.log('Disconnection error:', error);
//             return;
//           }
//           console.log('Disconnected from device.');
//         });
//       });
//     });
//   }
// });
