#include "pairing.h"
#include <EEPROM.h>

// EEPROM layout:
//   [0]      double-reset flag  (0xAA = pending, 0x00 = clear)
//   [1]      num_paired          (0–8)
//   [2..49]  MAC addresses, 6 bytes each (max 8 devices)

#define ADDR_RESET_FLAG  0
#define ADDR_COUNT       1
#define ADDR_MACS        2
#define MAC_LEN          6
#define RESET_FLAG       0xAA
#define RESET_WINDOW_MS  3000

static bool inPairingMode = false;
static unsigned long pairingStartTime = 0;

// Parse "aa:bb:cc:dd:ee:ff" into a 6-byte array
static void macToBytes(const String& mac, uint8_t* out) {
    for (int i = 0; i < 6; i++) {
        out[i] = (uint8_t)strtol(mac.substring(i * 3, i * 3 + 2).c_str(), nullptr, 16);
    }
}

static void enterPairingMode() {
    inPairingMode = true;
    pairingStartTime = millis();
}

void pairingInit() {
    uint8_t flag  = EEPROM.read(ADDR_RESET_FLAG);
    uint8_t count = EEPROM.read(ADDR_COUNT);

    if (flag == RESET_FLAG) {
        // Second reset within the detection window — enter pairing mode
        EEPROM.write(ADDR_RESET_FLAG, 0x00);
        Serial.println("[pairing] Double reset — entering pairing mode");
        enterPairingMode();
    } else if (count == 0 || count == 0xFF) {
        // No paired devices yet — always open pairing on first boot
        EEPROM.write(ADDR_COUNT, 0);
        Serial.println("[pairing] No devices paired — entering pairing mode");
        enterPairingMode();
    } else {
        // Normal boot: set the flag, wait for the detection window, then clear it.
        // If the user resets during this delay, the flag will still be set and
        // the next boot will detect it as a double reset.
        Serial.println("[pairing] Normal boot — double reset within 3s to pair");
        EEPROM.write(ADDR_RESET_FLAG, RESET_FLAG);
        delay(RESET_WINDOW_MS);
        EEPROM.write(ADDR_RESET_FLAG, 0x00);
    }
}

bool pairingIsActive() {
    return inPairingMode;
}

void pairingUpdate() {
    if (!inPairingMode) return;
    if (millis() - pairingStartTime >= PAIRING_TIMEOUT_MS) {
        inPairingMode = false;
        Serial.println("[pairing] Pairing mode timed out");
    }
}

bool pairingIsAllowed(const String& mac) {
    uint8_t count = EEPROM.read(ADDR_COUNT);
    uint8_t incoming[MAC_LEN];
    macToBytes(mac, incoming);

    for (uint8_t i = 0; i < count; i++) {
        int base = ADDR_MACS + i * MAC_LEN;
        bool match = true;
        for (int j = 0; j < MAC_LEN; j++) {
            if (EEPROM.read(base + j) != incoming[j]) { match = false; break; }
        }
        if (match) return true;
    }
    return false;
}

bool pairingAddDevice(const String& mac) {
    if (pairingIsAllowed(mac)) return true; // already paired

    uint8_t count = EEPROM.read(ADDR_COUNT);
    if (count >= MAX_PAIRED_DEVICES) {
        Serial.println("[pairing] Allowlist full");
        return false;
    }

    uint8_t bytes[MAC_LEN];
    macToBytes(mac, bytes);
    int base = ADDR_MACS + count * MAC_LEN;
    for (int i = 0; i < MAC_LEN; i++) EEPROM.write(base + i, bytes[i]);
    EEPROM.write(ADDR_COUNT, count + 1);

    Serial.print("[pairing] Paired: ");
    Serial.println(mac);
    return true;
}

uint8_t pairingDeviceCount() {
    return EEPROM.read(ADDR_COUNT);
}
