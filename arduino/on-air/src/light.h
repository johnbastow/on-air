#pragma once

enum class LightState {
    STARTUP,    // 3-second double-reset detection window
    PAIRING,    // pairing mode — alternating blink
    ON_AIR,     // all LEDs on
    OFF         // all LEDs off
};

void lightInit();
void lightSetState(LightState state);
void lightUpdate(); // call every loop() iteration to drive animations
