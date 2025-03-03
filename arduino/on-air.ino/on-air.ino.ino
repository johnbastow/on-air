#include <ArduinoBLE.h>

// Define the BLE Service and Characteristic
const char serviceGuid[] = "f47ac10b-58cc-4372-a567-0e02b2c3d479";
const char characteristicGuid[] = "c1ad54c6-1234-4567-890a-abcdef012345";
BLEService customService(serviceGuid); // Replace with your desired service UUID
BLETypedCharacteristic<long long> customCharacteristic(characteristicGuid, BLERead | BLEWrite); // Example characteristic

void setup() {
  Serial.begin(9600);

  // Start BLE module
  if (!BLE.begin()) {
    Serial.println("Starting BLE failed!");
    while (1);
  }

  Serial.println("BLE initialized...");

  // Set the device name and advertised service
  BLE.setLocalName("OnAir");
  BLE.setAdvertisedService(customService);

  // Add characteristic to the service
  customService.addCharacteristic(customCharacteristic);

  // Add service
  BLE.addService(customService);

  // Start advertising
  BLE.advertise();
  Serial.println("Advertising as Peripheral...");
}

void loop() {
  // Wait for a BLE central device to connect
  // Serial.println("Scanning for connection...");
  BLEDevice central = BLE.central();

  if (central) {
    Serial.print("Connected to: ");
    Serial.println(central.address());

    while (central.connected()) {
      Serial.print("Connected to: ");
      Serial.println(central.address());
      {
        // Check if the characteristic value has been updated
        // if (customCharacteristic.valueUpdated()) {
        //   long long value = customCharacteristic.written().value(); // Read the updated value
        //   Serial.print("Updated value: ");
        //   Serial.println(value);
        // } 
        // else {
        long long value = customCharacteristic.value(); // Read the updated value
        Serial.print("Not updated value: ");
        Serial.println(value);
        // }
      }
    }

  // byte frame[8][12] = {
  //   {0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0},
  //   {0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0},
  //   {0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0},
  //   {0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0},
  //   {0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0},
  //   {0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0},
  //   {0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0},
  //   {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
  // };

  // // Render the pattern on the LED matrix
  // matrix.renderBitmap(frame, 8, 12

    Serial.println("Disconnected from central.");
  }
}
