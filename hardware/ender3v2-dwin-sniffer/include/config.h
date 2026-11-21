#pragma once
// Include after <Arduino.h> (it defines CONFIG_IDF_TARGET_*).

// ---------------------------------------------------------------------------
// Pins. All of them are INPUTS: the sniffer never drives a printer line.
// Check every line with a meter first: it must be 0-3.3 V, never 5 V.
// ---------------------------------------------------------------------------
#if defined(CONFIG_IDF_TARGET_ESP32S3)
  #define TARGET_NAME             "ESP32-S3"
  #define PIN_SNIFF_BOARD_TX      16   // mainboard TX -> screen  (drawing commands)
  #define PIN_SNIFF_DISPLAY_TX    17   // screen TX -> mainboard  (handshake reply)
  #define PIN_ENC_A               38   // knob A
  #define PIN_ENC_B               39   // knob B
  #define PIN_ENC_BTN             40   // knob push button (active low)
  #define PIN_BEEP                41   // buzzer drive from the mainboard
#elif defined(CONFIG_IDF_TARGET_ESP32)
  #define TARGET_NAME             "ESP32"
  #define PIN_SNIFF_BOARD_TX      16
  #define PIN_SNIFF_DISPLAY_TX    17
  #define PIN_ENC_A               32
  #define PIN_ENC_B               33
  #define PIN_ENC_BTN             25
  #define PIN_BEEP                26
#else
  #error "Unsupported target: add a pin block for it in config.h"
#endif

// Set to 0 if you only tap the mainboard TX line.
#define ENABLE_DISPLAY_TX_SNIFF   1

// ---------------------------------------------------------------------------
// Serial settings
// ---------------------------------------------------------------------------
#define DWIN_BAUD           115200   // mainboard <-> DWIN screen
#define HOST_BAUD           921600   // log output (ignored on the S3 native USB port)
#define UART_RX_BUF         8192     // per sniffed line; Marlin sends bursts with no pacing
#define UART_EVENT_QUEUE    32

// ---------------------------------------------------------------------------
// Knob / buzzer decoding
// ---------------------------------------------------------------------------
#define EDGE_RING           1024     // must be a power of two
#define ENC_SETTLE_US       40000    // end a knob step after this much quiet time
#define BTN_DEBOUNCE_US     5000
#define BEEP_END_US         30000    // a beep ends after this much quiet time
