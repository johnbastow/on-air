#pragma once
#include <Arduino.h>

// Maximum number of paired devices stored in EEPROM
static const uint8_t MAX_PAIRED_DEVICES = 8;

// Duration pairing mode stays open after being triggered
static const unsigned long PAIRING_TIMEOUT_MS = 60000;

// Call from setup() — handles double-reset detection and first-boot logic.
// Blocks for 3 seconds on normal boot (the double-reset detection window);
// the caller should set the STARTUP light state before calling this.
void pairingInit();

bool pairingIsActive();
void pairingUpdate(); // call every loop() — handles timeout

// Add a device MAC to the allowlist. Returns false if allowlist is full.
bool pairingAddDevice(const String& mac);

// Returns true if the MAC is in the allowlist.
bool pairingIsAllowed(const String& mac);

uint8_t pairingDeviceCount();

// Remove a specific MAC from the allowlist. Returns false if not found.
bool pairingRemoveDevice(const String& mac);

// Remove all paired devices.
void pairingClearAll();

// Fill buf with: [count][mac0 6 bytes][mac1 6 bytes]...
// buf must be at least 1 + MAX_PAIRED_DEVICES * 6 = 49 bytes.
// Sets *outLen to the number of bytes written.
void pairingGetDeviceList(uint8_t* buf, uint8_t* outLen);
