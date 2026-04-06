#pragma once
#include <Arduino.h>

// How long to keep a device's last-known state after it disconnects.
// If a device drops unexpectedly while on a call, the light stays on
// until this timeout elapses rather than turning off immediately.
static const unsigned long DEVICE_TIMEOUT_MS = 300000; // 5 minutes

void deviceStateInit();

// Record the mic state for a device. Creates an entry if first seen.
void deviceStateSet(const String& mac, bool active);

// Called on disconnect — marks the device inactive and starts the timeout.
void deviceStateRemove(const String& mac);

// Call every loop() — expires stale entries after DEVICE_TIMEOUT_MS.
void deviceStateUpdate();

// Returns true if any tracked device currently has mic active.
bool deviceStateAnyActive();
