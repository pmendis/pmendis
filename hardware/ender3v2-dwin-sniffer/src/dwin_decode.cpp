#include "dwin_decode.h"

#include <stdarg.h>
#include <stdio.h>
#include <string.h>

namespace dwin {

// ---------------------------------------------------------------------------
// Text
// ---------------------------------------------------------------------------
void Text::add(const char* fmt, ...) {
  if (cap == 0 || len + 1 >= cap) return;
  va_list ap;
  va_start(ap, fmt);
  int n = vsnprintf(buf + len, cap - len, fmt, ap);
  va_end(ap);
  if (n < 0) return;
  size_t room = cap - len - 1;
  len += ((size_t)n < room) ? (size_t)n : room;
}

void Text::hex(const uint8_t* p, size_t n) {
  static const char kDigits[] = "0123456789ABCDEF";
  for (size_t i = 0; i < n; ++i) {
    if (len + 4 >= cap) {          // room for "XX " + NUL
      add("...");
      return;
    }
    if (i) buf[len++] = ' ';
    buf[len++] = kDigits[p[i] >> 4];
    buf[len++] = kDigits[p[i] & 0x0F];
    buf[len] = '\0';
  }
}

void Text::quoted(const uint8_t* p, size_t n) {
  add("\"");
  for (size_t i = 0; i < n; ++i) {
    uint8_t c = p[i];
    if (c == '"' || c == '\\') add("\\%c", c);
    else if (c >= 0x20 && c <= 0x7E) add("%c", c);
    else add("\\x%02X", c);
  }
  add("\"");
}

// ---------------------------------------------------------------------------
// Framer
// ---------------------------------------------------------------------------
void Framer::reset() {
  len_ = 0;
}

void Framer::addJunk(uint8_t b) {
  ++junkTotal;
  if (junkLen_ < kJunkKeep) junk_[junkLen_++] = b;
  else ++junkDropped_;
}

bool Framer::feed(uint8_t b) {
  if (len_ == 0) {
    if (b == kHead) buf_[len_++] = b;
    else addJunk(b);
    return false;
  }

  if (len_ >= kMaxFrame) {
    // No tail found: throw the frame away and start over on this byte.
    memcpy(overflowStart_, buf_, sizeof overflowStart_);
    overflowPending_ = true;
    ++overflows;
    len_ = 0;
    if (b == kHead) buf_[len_++] = b;
    else addJunk(b);
    return false;
  }

  buf_[len_++] = b;

  // Shortest frame: AA cmd CC 33 C3 3C
  if (len_ >= 6 && buf_[len_ - 4] == kTail[0] && buf_[len_ - 3] == kTail[1] &&
      buf_[len_ - 2] == kTail[2] && buf_[len_ - 1] == kTail[3]) {
    frameLen_ = len_ - 5;
    memcpy(frame_, buf_ + 1, frameLen_);
    len_ = 0;
    return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Decoder
// ---------------------------------------------------------------------------
namespace {

inline uint16_t W(const uint8_t* p) { return (uint16_t)((p[0] << 8) | p[1]); }

const char* fontName(uint8_t size) {
  static const char* const kFonts[] = {"6x12",  "8x16",  "10x20", "12x24", "14x28",
                                       "16x32", "20x40", "24x48", "28x56", "32x64"};
  return size < sizeof kFonts / sizeof kFonts[0] ? kFonts[size] : "?";
}

const char* rectMode(uint8_t m) {
  switch (m) {
    case 0: return "outline";
    case 1: return "filled";
    case 2: return "xor";
    default: return "mode?";
  }
}

const char* moveDir(uint8_t d) {
  switch (d) {
    case 0: return "left";
    case 1: return "right";
    case 2: return "up";
    case 3: return "down";
    default: return "dir?";
  }
}

// AA 14: number. Payload layout:
//   flags, fg(W), bg(W), intDigits, fracDigits, x(W), y(W), value(4 or 8 bytes, big-endian)
void describeNumber(const uint8_t* p, size_t pl, Text& o) {
  const uint8_t flags = p[0];
  const uint8_t iNum = p[5];
  const uint8_t fNum = p[6];
  const uint8_t* v = p + 11;
  const size_t vl = pl - 11;

  o.add("NUMBER    x=%u y=%u font=%s fg=%04X bg=%04X digits=%u.%u flags=%02X",
        W(p + 7), W(p + 9), fontName(flags & 0x0F), W(p + 1), W(p + 3), iNum, fNum, flags);

  if (vl == 0 || vl > 8) {
    o.add(" value=? bytes=");
    o.hex(v, vl);
    return;
  }

  uint64_t u = 0;
  for (size_t i = 0; i < vl; ++i) u = (u << 8) | v[i];
  int64_t s;
  if (vl < 8 && (v[0] & 0x80)) s = (int64_t)(u | (~0ull << (vl * 8)));  // sign-extend
  else s = (int64_t)u;

  o.add(" raw=%lld", (long long)s);
  if (fNum > 0 && fNum <= 9) {
    uint64_t div = 1;
    for (uint8_t i = 0; i < fNum; ++i) div *= 10;
    uint64_t a = s < 0 ? (uint64_t)(-(s + 1)) + 1 : (uint64_t)s;
    o.add(" value=%s%llu.%0*llu", s < 0 ? "-" : "", (unsigned long long)(a / div), (int)fNum,
          (unsigned long long)(a % div));
  }
  o.add(" vbytes=%u", (unsigned)vl);
}

}  // namespace

const char* cmdName(uint8_t cmd) {
  switch (cmd) {
    case 0x00: return "HANDSHAKE";
    case 0x01: return "CLEAR";
    case 0x02: return "POINT";
    case 0x03: return "LINE";
    case 0x05: return "RECT";
    case 0x09: return "AREAMOVE";
    case 0x11: return "STRING";
    case 0x14: return "NUMBER";
    case 0x21: return "QR";
    case 0x22: return "JPG_SHOW";
    case 0x23: return "ICON";
    case 0x25: return "JPG_CACHE";
    case 0x27: return "AREACOPY";
    case 0x28: return "ANIMATION";
    case 0x30: return "BACKLIGHT";
    case 0x34: return "SETDIR";
    case 0x3D: return "UPDATE";
    default: return nullptr;
  }
}

void describe(const uint8_t* f, size_t n, Text& o) {
  if (n == 0) {
    o.add("EMPTY");
    return;
  }
  const uint8_t cmd = f[0];
  const uint8_t* p = f + 1;
  const size_t pl = n - 1;
  bool ok = true;

  switch (cmd) {
    case 0x00:
      if (pl == 0) o.add("HANDSHAKE (board asks: are you there?)");
      else if (pl == 2 && p[0] == 'O' && p[1] == 'K') o.add("HANDSHAKE_OK (screen replies)");
      else ok = false;
      break;

    case 0x01:
      if (pl == 2) o.add("CLEAR     color=%04X", W(p));
      else ok = false;
      break;

    case 0x02:
      if (pl == 8)
        o.add("POINT     x=%u y=%u size=%ux%u color=%04X", W(p + 4), W(p + 6), p[2], p[3], W(p));
      else ok = false;
      break;

    case 0x03:
      if (pl == 10)
        o.add("LINE      (%u,%u)-(%u,%u) color=%04X", W(p + 2), W(p + 4), W(p + 6), W(p + 8), W(p));
      else ok = false;
      break;

    case 0x05:
      if (pl == 11)
        o.add("RECT      (%u,%u)-(%u,%u) %s color=%04X", W(p + 3), W(p + 5), W(p + 7), W(p + 9),
              rectMode(p[0]), W(p + 1));
      else ok = false;
      break;

    case 0x09:
      if (pl == 13)
        o.add("AREAMOVE  (%u,%u)-(%u,%u) %s dist=%u mode=%u fill=%04X", W(p + 5), W(p + 7),
              W(p + 9), W(p + 11), moveDir(p[0] & 0x7F), W(p + 1), p[0] >> 7, W(p + 3));
      else ok = false;
      break;

    case 0x11:
      if (pl >= 9) {
        o.add("STRING    x=%u y=%u font=%s fg=%04X bg=%04X flags=%02X%s%s text=", W(p + 5),
              W(p + 7), fontName(p[0] & 0x0F), W(p + 1), W(p + 3), p[0],
              (p[0] & 0x80) ? "(widthadj)" : "", (p[0] & 0x40) ? "(showbg)" : "");
        o.quoted(p + 9, pl - 9);
      } else ok = false;
      break;

    case 0x14:
      if (pl >= 11) describeNumber(p, pl, o);
      else ok = false;
      break;

    case 0x21:
      if (pl >= 5) {
        o.add("QR        x=%u y=%u size=%u text=", W(p), W(p + 2), p[4]);
        o.quoted(p + 5, pl - 5);
      } else ok = false;
      break;

    case 0x22:
      if (pl == 2) o.add("JPG_SHOW  id=%u (arg=%02X)", p[1], p[0]);
      else ok = false;
      break;

    case 0x23:
      if (pl == 6)
        o.add("ICON      x=%u y=%u lib=%u icon=%u flags=%02X", W(p), W(p + 2), p[4] & 0x1F, p[5],
              p[4] & 0xE0);
      else ok = false;
      break;

    case 0x25:
      if (pl == 2) o.add("JPG_CACHE buffer=%u id=%u", p[0], p[1]);
      else ok = false;
      break;

    case 0x27:
      if (pl == 13) {
        const uint16_t x1 = W(p + 1), y1 = W(p + 3), x2 = W(p + 5), y2 = W(p + 7);
        o.add("AREACOPY  x=%u y=%u from cache=%u (%u,%u)-(%u,%u) size=%ux%u", W(p + 9), W(p + 11),
              p[0] & 0x7F, x1, y1, x2, y2, (unsigned)(x2 >= x1 ? x2 - x1 : 0),
              (unsigned)(y2 >= y1 ? y2 - y1 : 0));
      } else ok = false;
      break;

    case 0x30:
      if (pl == 1) o.add("BACKLIGHT level=%u", p[0]);
      else ok = false;
      break;

    case 0x34:
      if (pl == 3) o.add("SETDIR    dir=%u (%02X %02X)", p[2], p[0], p[1]);
      else ok = false;
      break;

    case 0x3D:
      if (pl == 0) o.add("UPDATE    ---- frame shown ----");
      else ok = false;
      break;

    default:
      ok = false;
      break;
  }

  if (!ok) {
    const char* name = cmdName(cmd);
    if (name)
      o.add("%-9s len=%u (layout not decoded) data=", name, (unsigned)pl);
    else
      o.add("CMD_%02X    len=%u (unknown command) data=", cmd, (unsigned)pl);
    o.hex(p, pl);
  }
}

bool positionKey(const uint8_t* f, size_t n, uint64_t& key) {
  if (n == 0) return false;
  const uint8_t cmd = f[0];
  const uint8_t* p = f + 1;
  const size_t pl = n - 1;
  uint16_t x, y;
  switch (cmd) {
    case 0x02: if (pl != 8) return false;  x = W(p + 4); y = W(p + 6); break;
    case 0x03: if (pl != 10) return false; x = W(p + 2); y = W(p + 4); break;
    case 0x05: if (pl != 11) return false; x = W(p + 3); y = W(p + 5); break;
    case 0x11: if (pl < 9) return false;   x = W(p + 5); y = W(p + 7); break;
    case 0x14: if (pl < 11) return false;  x = W(p + 7); y = W(p + 9); break;
    case 0x23: if (pl != 6) return false;  x = W(p);     y = W(p + 2); break;
    case 0x27: if (pl != 13) return false; x = W(p + 9); y = W(p + 11); break;
    default: return false;
  }
  key = ((uint64_t)cmd << 32) | ((uint64_t)x << 16) | y;
  return true;
}

uint32_t fnv1a(const uint8_t* p, size_t n) {
  uint32_t h = 2166136261u;
  for (size_t i = 0; i < n; ++i) {
    h ^= p[i];
    h *= 16777619u;
  }
  return h;
}

}  // namespace dwin
