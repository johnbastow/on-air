#include "light.h"
#include <Arduino_LED_Matrix.h>

static ArduinoLEDMatrix matrix;
static LightState currentState = LightState::OFF;
static unsigned long lastFrameTime = 0;
static uint8_t animFrame = 0;

static const uint32_t FRAME_ON[3]       = { 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF };
static const uint32_t FRAME_OFF[3]      = { 0x00000000, 0x00000000, 0x00000000 };
static const uint32_t FRAME_CHECKER_A[3] = { 0xAAAAAAAA, 0x55555555, 0xAAAAAAAA };
static const uint32_t FRAME_CHECKER_B[3] = { 0x55555555, 0xAAAAAAAA, 0x55555555 };
// Single centre dot — shown during startup window so the user sees activity
static const uint32_t FRAME_DOT[3]      = { 0x00000000, 0x00018000, 0x00000000 };

void lightInit() {
    matrix.begin();
    matrix.loadFrame(FRAME_OFF);
}

void lightSetState(LightState state) {
    currentState = state;
    animFrame = 0;
    lastFrameTime = 0;

    switch (state) {
        case LightState::ON_AIR:  matrix.loadFrame(FRAME_ON);  break;
        case LightState::OFF:     matrix.loadFrame(FRAME_OFF); break;
        case LightState::STARTUP: matrix.loadFrame(FRAME_DOT); break;
        case LightState::PAIRING: matrix.loadFrame(FRAME_CHECKER_A); break;
    }
}

void lightUpdate() {
    if (currentState != LightState::PAIRING) return;

    unsigned long now = millis();
    if (now - lastFrameTime < 400) return;
    lastFrameTime = now;

    animFrame = (animFrame + 1) % 2;
    matrix.loadFrame(animFrame == 0 ? FRAME_CHECKER_A : FRAME_CHECKER_B);
}
