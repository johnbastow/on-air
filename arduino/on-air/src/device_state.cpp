#include "device_state.h"

#define MAX_DEVICES 8

struct DeviceEntry {
    String mac;
    bool active;
    unsigned long lastSeen;
    bool valid;
};

static DeviceEntry devices[MAX_DEVICES];

void deviceStateInit() {
    for (int i = 0; i < MAX_DEVICES; i++) devices[i].valid = false;
}

static int findDevice(const String& mac) {
    for (int i = 0; i < MAX_DEVICES; i++) {
        if (devices[i].valid && devices[i].mac == mac) return i;
    }
    return -1;
}

static int findFreeSlot() {
    for (int i = 0; i < MAX_DEVICES; i++) {
        if (!devices[i].valid) return i;
    }
    return -1;
}

void deviceStateSet(const String& mac, bool active) {
    int idx = findDevice(mac);
    if (idx < 0) idx = findFreeSlot();
    if (idx < 0) return;

    devices[idx] = { mac, active, millis(), true };
}

void deviceStateRemove(const String& mac) {
    int idx = findDevice(mac);
    if (idx < 0) return;
    // Mark inactive but keep the entry — timeout will clean it up.
    // This means an unexpected disconnect doesn't immediately kill the light.
    devices[idx].active = false;
    devices[idx].lastSeen = millis();
}

void deviceStateUpdate() {
    unsigned long now = millis();
    for (int i = 0; i < MAX_DEVICES; i++) {
        if (devices[i].valid && (now - devices[i].lastSeen) > DEVICE_TIMEOUT_MS) {
            Serial.print("[state] Entry expired: ");
            Serial.println(devices[i].mac);
            devices[i].valid = false;
        }
    }
}

bool deviceStateAnyActive() {
    for (int i = 0; i < MAX_DEVICES; i++) {
        if (devices[i].valid && devices[i].active) return true;
    }
    return false;
}
