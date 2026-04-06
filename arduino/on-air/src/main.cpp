#include <Arduino.h>
#include <ArduinoBLE.h>
#include "light.h"
#include "pairing.h"
#include "device_state.h"

#define SERVICE_UUID  "19B10000-E8F2-537E-4F6C-D104768A1214"
#define CHAR_UUID     "19B10001-E8F2-537E-4F6C-D104768A1214"
#define DEVICE_NAME   "on-air-light"

BLEService        onAirService(SERVICE_UUID);
BLEByteCharacteristic micStateChar(CHAR_UUID, BLERead | BLEWrite | BLEWriteWithoutResponse);

// ── BLE event handlers ────────────────────────────────────────────────────────

void onConnected(BLEDevice central) {
    String mac = central.address();
    Serial.print("[ble] Connected: ");
    Serial.println(mac);

    if (pairingIsActive()) {
        if (pairingAddDevice(mac)) {
            Serial.println("[ble] Device added to allowlist");
        }
        // Stay in pairing mode so additional devices can be added in this window
    } else if (!pairingIsAllowed(mac)) {
        Serial.println("[ble] Unknown device — rejecting");
        central.disconnect();
    }
}

void onDisconnected(BLEDevice central) {
    String mac = central.address();
    Serial.print("[ble] Disconnected: ");
    Serial.println(mac);
    deviceStateRemove(mac);
}

void onCharWritten(BLEDevice central, BLECharacteristic /*characteristic*/) {
    String mac = central.address();

    if (!pairingIsAllowed(mac)) {
        central.disconnect();
        return;
    }

    bool active = (micStateChar.value() != 0);
    deviceStateSet(mac, active);

    Serial.print("[ble] ");
    Serial.print(mac);
    Serial.print(" mic: ");
    Serial.println(active ? "ON" : "OFF");
}

// ── setup / loop ──────────────────────────────────────────────────────────────

void setup() {
    Serial.begin(115200);

    lightInit();
    deviceStateInit();

    // Show a dot during the 3-second double-reset detection window
    lightSetState(LightState::STARTUP);
    pairingInit(); // blocks for 3s on normal boot

    if (!BLE.begin()) {
        Serial.println("[ble] Init failed — halting");
        lightSetState(LightState::OFF);
        while (true);
    }

    BLE.setLocalName(DEVICE_NAME);
    BLE.setDeviceName(DEVICE_NAME);
    BLE.setAdvertisedService(onAirService);
    onAirService.addCharacteristic(micStateChar);
    BLE.addService(onAirService);
    micStateChar.writeValue(0);

    BLE.setEventHandler(BLEConnected,    onConnected);
    BLE.setEventHandler(BLEDisconnected, onDisconnected);
    micStateChar.setEventHandler(BLEWritten, onCharWritten);

    BLE.advertise();

    if (pairingIsActive()) {
        lightSetState(LightState::PAIRING);
        Serial.println("[main] Advertising — pairing mode");
    } else {
        lightSetState(LightState::OFF);
        Serial.println("[main] Advertising — ready");
    }
}

void loop() {
    BLE.poll();
    pairingUpdate();
    deviceStateUpdate();
    lightUpdate();

    // When pairing mode expires, update light to reflect current mic state
    static bool wasPairing = false;
    bool isPairing = pairingIsActive();
    if (wasPairing && !isPairing) {
        lightSetState(deviceStateAnyActive() ? LightState::ON_AIR : LightState::OFF);
    }
    wasPairing = isPairing;

    // Drive light from mic state
    static bool wasOnAir = false;
    bool isOnAir = deviceStateAnyActive();
    if (isOnAir != wasOnAir) {
        wasOnAir = isOnAir;
        if (!isPairing) {
            lightSetState(isOnAir ? LightState::ON_AIR : LightState::OFF);
            Serial.println(isOnAir ? "[main] ON AIR" : "[main] OFF AIR");
        }
    }
}
