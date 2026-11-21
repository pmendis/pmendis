// Ender 3 V2 display-port sniffer.
//
// Listens (never transmits) to:
//   - mainboard TX -> stock screen : DWIN drawing commands       ("B>D")
//   - stock screen TX -> mainboard : handshake reply              ("D>B")
//   - rotary knob A/B and push button                             ("ENC", "BTN", "EDGE")
//   - buzzer line                                                 ("BEEP")
// and prints one timestamped line per event over USB.
//
// Type "h" + Enter in the serial monitor for commands.

#include <Arduino.h>
#include <stdarg.h>
#include <string.h>

#include "driver/uart.h"
#include "esp_timer.h"
#include "soc/gpio_reg.h"

#include "config.h"
#include "dwin_decode.h"

static_assert((EDGE_RING & (EDGE_RING - 1)) == 0, "EDGE_RING must be a power of two");

namespace {

const char* const kVersion = "1.0";

// ===========================================================================
// Output
// ===========================================================================
bool g_paused = false;
bool g_showDecoded = true;
bool g_showHex = false;
bool g_showEdges = false;
bool g_dedupe = false;
uint32_t g_markNo = 0;

char g_line[1400];

inline uint64_t nowUs() { return (uint64_t)esp_timer_get_time(); }

void put(const char* s, size_t n, bool force) {
  if (g_paused && !force) return;
  Serial.write(reinterpret_cast<const uint8_t*>(s), n);
  Serial.write('\n');
}

// "    12345.678 TAG  " : milliseconds since boot, then a 4-wide tag.
dwin::Text startLine(uint64_t us, const char* tag) {
  int n = snprintf(g_line, sizeof g_line, "%9llu.%03llu %-4s ", (unsigned long long)(us / 1000),
                   (unsigned long long)(us % 1000), tag);
  if (n < 0) n = 0;
  return dwin::Text{g_line, sizeof g_line, (size_t)n};
}

void endLine(const dwin::Text& t, bool force = false) { put(t.buf, t.len, force); }

void logLine(bool force, const char* tag, const char* fmt, ...) __attribute__((format(printf, 3, 4)));
void logLine(bool force, const char* tag, const char* fmt, ...) {
  dwin::Text t = startLine(nowUs(), tag);
  va_list ap;
  va_start(ap, fmt);
  if (t.len + 1 < t.cap) {
    int n = vsnprintf(t.buf + t.len, t.cap - t.len, fmt, ap);
    if (n > 0) {
      size_t room = t.cap - t.len - 1;
      t.len += ((size_t)n < room) ? (size_t)n : room;
    }
  }
  va_end(ap);
  endLine(t, force);
}

// Milliseconds with one decimal, for durations.
struct Ms {
  char s[24];
  explicit Ms(uint64_t us) {
    snprintf(s, sizeof s, "%llu.%01llums", (unsigned long long)(us / 1000),
             (unsigned long long)((us % 1000) / 100));
  }
};

inline int IRAM_ATTR fastRead(int pin) {
  return pin < 32 ? (int)((REG_READ(GPIO_IN_REG) >> pin) & 1)
                  : (int)((REG_READ(GPIO_IN1_REG) >> (pin - 32)) & 1);
}

// ===========================================================================
// Sniffed UART channels
// ===========================================================================

// Remembers the last frame drawn at each (cmd, x, y) so unchanged redraws can
// be hidden when dedupe is on.
struct DedupeTable {
  static const size_t N = 512;
  uint64_t key[N];
  uint32_t hash[N];
  bool used[N];
  size_t count;

  void clear() {
    memset(used, 0, sizeof used);
    count = 0;
  }

  // true = same content as last time at this position (hide it)
  bool unchanged(uint64_t k, uint32_t h) {
    if (count >= N * 3 / 4) clear();
    size_t i = (size_t)((k * 0x9E3779B97F4A7C15ull) >> 55) & (N - 1);
    for (;;) {
      if (!used[i]) {
        used[i] = true;
        key[i] = k;
        hash[i] = h;
        ++count;
        return false;
      }
      if (key[i] == k) {
        if (hash[i] == h) return true;
        hash[i] = h;
        return false;
      }
      i = (i + 1) & (N - 1);
    }
  }
};

struct Channel {
  const char* tag;
  uart_port_t port;
  int rxPin;
  QueueHandle_t events;
  bool enabled;

  dwin::Framer fr;
  DedupeTable dd;
  bool printedSinceUpdate;
  uint64_t lastByteUs;
  uint64_t lastWarnUs;

  // statistics
  uint32_t bytes, frames, suppressed, lost, frameErrors, parityErrors, breaks;
  uint32_t frameErrorsReported;
  size_t maxFill;
  uint32_t cmdCount[256];

  void resetStats() {
    bytes = frames = suppressed = lost = frameErrors = parityErrors = breaks = 0;
    frameErrorsReported = 0;
    maxFill = 0;
    memset(cmdCount, 0, sizeof cmdCount);
    fr.junkTotal = 0;
    fr.overflows = 0;
  }
};

Channel g_boardTx;    // B>D
Channel g_displayTx;  // D>B

bool startUart(Channel& c, const char* tag, uart_port_t port, int rxPin) {
  c.tag = tag;
  c.port = port;
  c.rxPin = rxPin;
  c.enabled = false;
  c.resetStats();
  c.dd.clear();

  uart_config_t cfg;
  memset(&cfg, 0, sizeof cfg);
  cfg.baud_rate = DWIN_BAUD;
  cfg.data_bits = UART_DATA_8_BITS;
  cfg.parity = UART_PARITY_DISABLE;
  cfg.stop_bits = UART_STOP_BITS_1;
  cfg.flow_ctrl = UART_HW_FLOWCTRL_DISABLE;
  cfg.source_clk = UART_SCLK_APB;

  if (uart_driver_install(port, UART_RX_BUF, 0, UART_EVENT_QUEUE, &c.events, 0) != ESP_OK) return false;
  if (uart_param_config(port, &cfg) != ESP_OK) return false;
  // RX only. TX/RTS/CTS stay unrouted, so this pin can never drive the printer.
  if (uart_set_pin(port, UART_PIN_NO_CHANGE, rxPin, UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE) != ESP_OK)
    return false;
  c.enabled = true;
  return true;
}

void flushJunk(Channel& c, uint64_t us) {
  if (c.fr.junkLen() == 0) return;
  dwin::Text t = startLine(us, c.tag);
  t.add("JUNK      %u bytes outside frames: ", (unsigned)(c.fr.junkLen() + c.fr.junkDropped()));
  t.hex(c.fr.junk(), c.fr.junkLen());
  if (c.fr.junkDropped()) t.add(" ... (+%u more)", (unsigned)c.fr.junkDropped());
  endLine(t);
  c.fr.clearJunk();
}

void onFrame(Channel& c, uint64_t us) {
  const uint8_t* f = c.fr.frame();
  const size_t n = c.fr.frameLen();
  const uint8_t cmd = n ? f[0] : 0xFF;

  ++c.frames;
  if (n) ++c.cmdCount[cmd];

  if (g_dedupe) {
    if (cmd == 0x01 || cmd == 0x22) c.dd.clear();  // whole screen redrawn
    if (cmd == 0x3D) {
      if (!c.printedSinceUpdate) {
        ++c.suppressed;
        return;
      }
    } else {
      uint64_t k;
      if (dwin::positionKey(f, n, k) && c.dd.unchanged(k, dwin::fnv1a(f, n))) {
        ++c.suppressed;
        return;
      }
    }
  }

  if (g_showDecoded) {
    dwin::Text t = startLine(us, c.tag);
    dwin::describe(f, n, t);
    endLine(t);
  }
  if (g_showHex) {
    dwin::Text t = startLine(us, c.tag);
    t.add("HEX       AA ");
    t.hex(f, n);
    t.add(" CC 33 C3 3C");
    endLine(t);
  }
  c.printedSinceUpdate = (cmd != 0x3D);
}

void pollChannel(Channel& c) {
  if (!c.enabled) return;

  // Driver events: overflow, framing errors (usually = wrong baud or bad wiring).
  uart_event_t ev;
  while (xQueueReceive(c.events, &ev, 0) == pdTRUE) {
    switch (ev.type) {
      case UART_FIFO_OVF:
      case UART_BUFFER_FULL:
        ++c.lost;
        uart_flush_input(c.port);
        xQueueReset(c.events);
        c.fr.reset();
        logLine(false, "WARN", "%s receive buffer overflowed, data lost (host not reading fast enough?)", c.tag);
        return;
      case UART_FRAME_ERR: ++c.frameErrors; break;
      case UART_PARITY_ERR: ++c.parityErrors; break;
      case UART_BREAK: ++c.breaks; break;
      default: break;
    }
  }

  size_t buffered = 0;
  uart_get_buffered_data_len(c.port, &buffered);
  if (buffered > c.maxFill) c.maxFill = buffered;

  uint8_t tmp[256];
  for (;;) {
    int r = uart_read_bytes(c.port, tmp, sizeof tmp, 0);
    if (r <= 0) break;
    const uint64_t us = nowUs();
    c.lastByteUs = us;
    c.bytes += (uint32_t)r;
    for (int i = 0; i < r; ++i) {
      const bool got = c.fr.feed(tmp[i]);
      if (c.fr.overflowPending()) {
        flushJunk(c, us);
        dwin::Text t = startLine(us, c.tag);
        t.add("OVERFLOW  no frame tail within %u bytes, discarded. Start: ",
              (unsigned)dwin::Framer::kMaxFrame);
        t.hex(c.fr.overflowStart(), 16);
        endLine(t);
        c.fr.clearOverflow();
      }
      if (got) {
        flushJunk(c, us);
        onFrame(c, us);
      }
    }
  }

  const uint64_t now = nowUs();
  if (c.fr.junkLen() && now - c.lastByteUs > 5000) flushJunk(c, now);

  if (c.frameErrors != c.frameErrorsReported && now - c.lastWarnUs > 1000000) {
    logLine(false, "WARN", "%s %u UART framing errors so far: check baud (%u), wiring and GND", c.tag,
         (unsigned)c.frameErrors, (unsigned)DWIN_BAUD);
    c.frameErrorsReported = c.frameErrors;
    c.lastWarnUs = now;
  }
}

// ===========================================================================
// Knob (quadrature + button) and buzzer
// ===========================================================================
struct EdgeEv {
  uint64_t us;
  uint8_t lv;  // bit0 = A, bit1 = B, bit2 = BTN
};

EdgeEv g_edgeRing[EDGE_RING];
volatile uint32_t g_edgeHead = 0, g_edgeTail = 0, g_edgeOverflow = 0, g_edgeTotal = 0;
portMUX_TYPE g_edgeMux = portMUX_INITIALIZER_UNLOCKED;

void IRAM_ATTR edgeIsr() {
  const uint64_t us = (uint64_t)esp_timer_get_time();
  const uint8_t lv = (uint8_t)(fastRead(PIN_ENC_A) | (fastRead(PIN_ENC_B) << 1) |
                               (fastRead(PIN_ENC_BTN) << 2));
  portENTER_CRITICAL_ISR(&g_edgeMux);
  const uint32_t next = (g_edgeHead + 1) & (EDGE_RING - 1);
  if (next == g_edgeTail) {
    ++g_edgeOverflow;
  } else {
    g_edgeRing[g_edgeHead].us = us;
    g_edgeRing[g_edgeHead].lv = lv;
    g_edgeHead = next;
  }
  ++g_edgeTotal;
  portEXIT_CRITICAL_ISR(&g_edgeMux);
}

// Buzzer: count edges only (a tone can be thousands of edges per second).
volatile bool g_beepActive = false;
volatile uint64_t g_beepStartUs = 0, g_beepLastUs = 0;
volatile uint32_t g_beepEdges = 0;
portMUX_TYPE g_beepMux = portMUX_INITIALIZER_UNLOCKED;
int g_beepIdle = 0;
uint32_t g_beepCount = 0;

void IRAM_ATTR beepIsr() {
  const uint64_t us = (uint64_t)esp_timer_get_time();
  portENTER_CRITICAL_ISR(&g_beepMux);
  if (!g_beepActive) {
    g_beepActive = true;
    g_beepStartUs = us;
    g_beepEdges = 0;
  }
  ++g_beepEdges;
  g_beepLastUs = us;
  portEXIT_CRITICAL_ISR(&g_beepMux);
}

// Quadrature transition table, index = (prev << 2) | cur, state = (A << 1) | B.
const int8_t kQuad[16] = {0, +1, -1, 0, -1, 0, 0, +1, +1, 0, 0, -1, 0, -1, +1, 0};

uint8_t g_encPrev = 0;         // last A/B state
uint8_t g_encDetent = 0;       // A/B state at rest (read at boot)
int32_t g_encAcc = 0;          // net transitions in the current step
uint32_t g_encTrans = 0;       // transitions in the current step
uint64_t g_encStartUs = 0, g_encLastUs = 0, g_encPrevStepEndUs = 0;
uint32_t g_encInvalid = 0, g_stepsPlus = 0, g_stepsMinus = 0;
uint64_t g_lastEdgeUs = 0;

int g_btnRaw = 1, g_btnStable = 1;
uint64_t g_btnChangeUs = 0, g_btnDownUs = 0;
uint32_t g_btnPresses = 0;

void flushEncoderStep() {
  if (g_encTrans == 0) return;
  const char* dir = g_encAcc > 0 ? "DIR+" : g_encAcc < 0 ? "DIR-" : "JITTER";
  if (g_encAcc > 0) ++g_stepsPlus;
  else if (g_encAcc < 0) ++g_stepsMinus;

  dwin::Text t = startLine(g_encStartUs, "ENC");
  t.add("%-6s transitions=%u net=%+d dur=%s", dir, (unsigned)g_encTrans, (int)g_encAcc,
        Ms(g_encLastUs - g_encStartUs).s);
  if (g_encPrevStepEndUs) t.add(" gap_since_prev=%s", Ms(g_encStartUs - g_encPrevStepEndUs).s);
  if ((g_encPrev & 3) != g_encDetent) t.add(" (stopped between detents)");
  endLine(t);

  g_encPrevStepEndUs = g_encLastUs;
  g_encAcc = 0;
  g_encTrans = 0;
}

void processEdge(const EdgeEv& ev) {
  const int a = ev.lv & 1, b = (ev.lv >> 1) & 1, btn = (ev.lv >> 2) & 1;

  if (g_showEdges) {
    dwin::Text t = startLine(ev.us, "EDGE");
    t.add("A=%d B=%d BTN=%d", a, b, btn);
    if (g_lastEdgeUs) t.add(" dt=%lluus", (unsigned long long)(ev.us - g_lastEdgeUs));
    endLine(t);
  }
  g_lastEdgeUs = ev.us;

  const uint8_t q = (uint8_t)((a << 1) | b);
  if (q == g_encPrev) return;  // button edge or bounce back to same state

  if ((q ^ g_encPrev) == 3) {
    ++g_encInvalid;  // both lines changed at once: an edge was missed
  } else {
    if (g_encTrans == 0) g_encStartUs = ev.us;
    g_encAcc += kQuad[(g_encPrev << 2) | q];
    ++g_encTrans;
  }
  g_encPrev = q;
  g_encLastUs = ev.us;
  if (q == g_encDetent) flushEncoderStep();
}

void pollKnob() {
  for (;;) {
    EdgeEv ev;
    bool have = false;
    portENTER_CRITICAL(&g_edgeMux);
    if (g_edgeTail != g_edgeHead) {
      ev = g_edgeRing[g_edgeTail];
      g_edgeTail = (g_edgeTail + 1) & (EDGE_RING - 1);
      have = true;
    }
    portEXIT_CRITICAL(&g_edgeMux);
    if (!have) break;
    processEdge(ev);
  }

  const uint64_t now = nowUs();
  if (g_encTrans && now - g_encLastUs > ENC_SETTLE_US) flushEncoderStep();

  // Button, debounced by polling.
  const int lvl = fastRead(PIN_ENC_BTN);
  if (lvl != g_btnRaw) {
    g_btnRaw = lvl;
    g_btnChangeUs = now;
  } else if (lvl != g_btnStable && now - g_btnChangeUs >= BTN_DEBOUNCE_US) {
    g_btnStable = lvl;
    if (lvl == 0) {
      g_btnDownUs = g_btnChangeUs;
      ++g_btnPresses;
      dwin::Text t = startLine(g_btnDownUs, "BTN");
      t.add("DOWN");
      endLine(t);
    } else {
      dwin::Text t = startLine(g_btnChangeUs, "BTN");
      t.add("UP   held=%s", Ms(g_btnChangeUs - g_btnDownUs).s);
      endLine(t);
    }
  }
}

void pollBeep() {
  bool active;
  uint64_t start, last;
  uint32_t edges;
  portENTER_CRITICAL(&g_beepMux);
  active = g_beepActive;
  start = g_beepStartUs;
  last = g_beepLastUs;
  edges = g_beepEdges;
  portEXIT_CRITICAL(&g_beepMux);
  if (!active) return;

  const uint64_t now = nowUs();
  if (now - last < BEEP_END_US || fastRead(PIN_BEEP) != g_beepIdle) return;

  portENTER_CRITICAL(&g_beepMux);
  g_beepActive = false;
  portEXIT_CRITICAL(&g_beepMux);

  ++g_beepCount;
  const uint64_t dur = last - start;
  dwin::Text t = startLine(start, "BEEP");
  t.add("dur=%s edges=%u", Ms(dur).s, (unsigned)edges);
  if (edges >= 4 && dur > 0) t.add(" tone~%lluHz", (unsigned long long)((uint64_t)edges * 500000ull / dur));
  endLine(t);
}

// ===========================================================================
// Commands from the host
// ===========================================================================
void printInfo() {
  logLine(true, "SYS", "Ender 3 V2 DWIN sniffer v%s  target=%s  listen-only (no pin is driven)", kVersion,
       TARGET_NAME);
  logLine(true, "SYS", "B>D (mainboard TX)  rx=GPIO%d %s", PIN_SNIFF_BOARD_TX,
       g_boardTx.enabled ? "ok" : "FAILED TO START");
#if ENABLE_DISPLAY_TX_SNIFF
  logLine(true, "SYS", "D>B (screen TX)     rx=GPIO%d %s", PIN_SNIFF_DISPLAY_TX,
       g_displayTx.enabled ? "ok" : "FAILED TO START");
#else
  logLine(true, "SYS", "D>B (screen TX)     disabled in config.h");
#endif
  logLine(true, "SYS", "UART %u 8N1, rx buffer %u bytes", (unsigned)DWIN_BAUD, (unsigned)UART_RX_BUF);
  logLine(true, "SYS", "knob A=GPIO%d B=GPIO%d BTN=GPIO%d  buzzer=GPIO%d", PIN_ENC_A, PIN_ENC_B, PIN_ENC_BTN,
       PIN_BEEP);
  logLine(true, "SYS", "levels now: A=%d B=%d BTN=%d BEEP=%d  (rest state AB=%d%d, BEEP idle=%d)",
       fastRead(PIN_ENC_A), fastRead(PIN_ENC_B), fastRead(PIN_ENC_BTN), fastRead(PIN_BEEP),
       (g_encDetent >> 1) & 1, g_encDetent & 1, g_beepIdle);
  logLine(true, "SYS", "output: decoded=%s hex=%s edges=%s dedupe=%s paused=%s", g_showDecoded ? "on" : "off",
       g_showHex ? "on" : "off", g_showEdges ? "on" : "off", g_dedupe ? "on" : "off",
       g_paused ? "yes" : "no");
  logLine(true, "SYS", "type h + Enter for commands");
}

void printHelp() {
  static const char* const kHelp[] = {
      "h         this help",
      "i         show pins, line levels and settings",
      "d         decoded frame lines on/off   (default on)",
      "x         raw hex frame lines on/off   (default off)",
      "e         raw knob/button edge lines on/off (default off; use to measure timing)",
      "u         dedupe on/off: hide redraws that did not change (default off;",
      "          keep it OFF for the real capture)",
      "p         pause/resume output",
      "s         statistics",
      "z         reset statistics",
      "m [text]  numbered MARK line, e.g. 'm opening Prepare menu'",
  };
  for (const char* line : kHelp) logLine(true, "SYS", "%s", line);
}

void printChannelStats(const Channel& c) {
  if (!c.enabled) return;
  logLine(true, "STAT",
       "%s bytes=%u frames=%u hidden_by_dedupe=%u junk_bytes=%u overflows=%u lost=%u "
       "framing_err=%u parity_err=%u breaks=%u max_buffer=%u/%u",
       c.tag, (unsigned)c.bytes, (unsigned)c.frames, (unsigned)c.suppressed, (unsigned)c.fr.junkTotal,
       (unsigned)c.fr.overflows, (unsigned)c.lost, (unsigned)c.frameErrors, (unsigned)c.parityErrors,
       (unsigned)c.breaks, (unsigned)c.maxFill, (unsigned)UART_RX_BUF);

  dwin::Text t = startLine(nowUs(), "STAT");
  t.add("%s commands:", c.tag);
  bool any = false;
  for (int i = 0; i < 256; ++i) {
    if (!c.cmdCount[i]) continue;
    const char* name = dwin::cmdName((uint8_t)i);
    if (name) t.add(" %s(%02X)=%u", name, i, (unsigned)c.cmdCount[i]);
    else t.add(" %02X=%u", i, (unsigned)c.cmdCount[i]);
    any = true;
  }
  if (!any) t.add(" none yet");
  endLine(t, true);
}

void printStats() {
  logLine(true, "STAT", "uptime=%s", Ms(nowUs()).s);
  printChannelStats(g_boardTx);
  printChannelStats(g_displayTx);
  uint32_t total, ovf;
  portENTER_CRITICAL(&g_edgeMux);
  total = g_edgeTotal;
  ovf = g_edgeOverflow;
  portEXIT_CRITICAL(&g_edgeMux);
  logLine(true, "STAT", "knob edges=%u edge_buffer_overflows=%u steps DIR+=%u DIR-=%u missed_edges=%u button_presses=%u",
       (unsigned)total, (unsigned)ovf, (unsigned)g_stepsPlus, (unsigned)g_stepsMinus, (unsigned)g_encInvalid,
       (unsigned)g_btnPresses);
  logLine(true, "STAT", "beeps=%u", (unsigned)g_beepCount);
}

void resetStats() {
  g_boardTx.resetStats();
  g_displayTx.resetStats();
  portENTER_CRITICAL(&g_edgeMux);
  g_edgeTotal = 0;
  g_edgeOverflow = 0;
  portEXIT_CRITICAL(&g_edgeMux);
  g_stepsPlus = g_stepsMinus = g_encInvalid = g_btnPresses = g_beepCount = 0;
  logLine(true, "SYS", "statistics reset");
}

void handleCommand(char* line) {
  while (*line == ' ') ++line;
  if (!*line) return;
  const char c = line[0];
  const char* arg = line + 1;
  while (*arg == ' ') ++arg;

  switch (c) {
    case 'h': case 'H': case '?': printHelp(); break;
    case 'i': case 'I': printInfo(); break;
    case 'd': case 'D':
      g_showDecoded = !g_showDecoded;
      logLine(true, "SYS", "decoded frames %s", g_showDecoded ? "on" : "off");
      break;
    case 'x': case 'X':
      g_showHex = !g_showHex;
      logLine(true, "SYS", "hex frames %s", g_showHex ? "on" : "off");
      break;
    case 'e': case 'E':
      g_showEdges = !g_showEdges;
      logLine(true, "SYS", "raw edges %s", g_showEdges ? "on" : "off");
      break;
    case 'u': case 'U':
      g_dedupe = !g_dedupe;
      g_boardTx.dd.clear();
      g_displayTx.dd.clear();
      logLine(true, "SYS", "dedupe %s", g_dedupe ? "on (unchanged redraws hidden)" : "off (everything shown)");
      break;
    case 'p': case 'P':
      g_paused = !g_paused;
      logLine(true, "SYS", "output %s", g_paused ? "paused (statistics still counting)" : "resumed");
      break;
    case 's': case 'S': printStats(); break;
    case 'z': case 'Z': resetStats(); break;
    case 'm': case 'M':
      ++g_markNo;
      logLine(true, "MARK", "#%u %s", (unsigned)g_markNo, arg);
      break;
    default:
      logLine(true, "SYS", "unknown command '%s' (h for help)", line);
      break;
  }
}

char g_cmd[160];
size_t g_cmdLen = 0;

void pollHost() {
  while (Serial.available() > 0) {
    const int ch = Serial.read();
    if (ch < 0) break;
    if (ch == '\n' || ch == '\r') {
      if (g_cmdLen) {
        g_cmd[g_cmdLen] = '\0';
        handleCommand(g_cmd);
        g_cmdLen = 0;
      }
    } else if (g_cmdLen + 1 < sizeof g_cmd) {
      g_cmd[g_cmdLen++] = (char)ch;
    }
  }
}

}  // namespace

// ===========================================================================
void setup() {
  Serial.begin(HOST_BAUD);

  startUart(g_boardTx, "B>D", UART_NUM_1, PIN_SNIFF_BOARD_TX);
#if ENABLE_DISPLAY_TX_SNIFF
  startUart(g_displayTx, "D>B", UART_NUM_2, PIN_SNIFF_DISPLAY_TX);
#else
  g_displayTx.tag = "D>B";
  g_displayTx.enabled = false;
#endif

  // Plain inputs, no internal pull-ups: the printer already defines these levels.
  pinMode(PIN_ENC_A, INPUT);
  pinMode(PIN_ENC_B, INPUT);
  pinMode(PIN_ENC_BTN, INPUT);
  pinMode(PIN_BEEP, INPUT);

  g_encPrev = (uint8_t)((fastRead(PIN_ENC_A) << 1) | fastRead(PIN_ENC_B));
  g_encDetent = g_encPrev;
  g_btnRaw = g_btnStable = fastRead(PIN_ENC_BTN);
  g_beepIdle = fastRead(PIN_BEEP);

  attachInterrupt(digitalPinToInterrupt(PIN_ENC_A), edgeIsr, CHANGE);
  attachInterrupt(digitalPinToInterrupt(PIN_ENC_B), edgeIsr, CHANGE);
  attachInterrupt(digitalPinToInterrupt(PIN_ENC_BTN), edgeIsr, CHANGE);
  attachInterrupt(digitalPinToInterrupt(PIN_BEEP), beepIsr, CHANGE);

  delay(300);
  printInfo();
}

void loop() {
  pollChannel(g_boardTx);
  pollChannel(g_displayTx);
  pollKnob();
  pollBeep();
  pollHost();
}
