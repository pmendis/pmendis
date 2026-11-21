#pragma once
// DWIN (Ender 3 V2 stock screen) serial frame splitter and decoder.
// Plain C++ with no Arduino dependency, so it can be unit-tested on a PC.
//
// Frame: AA <cmd> <payload...> CC 33 C3 3C, numbers big-endian.

#include <stddef.h>
#include <stdint.h>

namespace dwin {

static const uint8_t kHead = 0xAA;
static const uint8_t kTail[4] = {0xCC, 0x33, 0xC3, 0x3C};

// Bounded text builder (never overflows, truncates instead).
struct Text {
  char* buf;
  size_t cap;
  size_t len;

  void add(const char* fmt, ...) __attribute__((format(printf, 2, 3)));
  void hex(const uint8_t* p, size_t n);      // "AA 11 42"
  void quoted(const uint8_t* p, size_t n);   // "text" with \xNN escapes
};

// Splits a byte stream into frames.
class Framer {
 public:
  static const size_t kMaxFrame = 600;
  static const size_t kJunkKeep = 48;

  // Feed one byte. Returns true when a complete frame is ready; frame() and
  // frameLen() then stay valid until the next feed().
  bool feed(uint8_t b);
  void reset();

  const uint8_t* frame() const { return frame_; }   // <cmd> <payload>, no head/tail
  size_t frameLen() const { return frameLen_; }

  // Bytes received outside any frame (wrong baud, noise, unknown protocol).
  const uint8_t* junk() const { return junk_; }
  size_t junkLen() const { return junkLen_; }
  uint32_t junkDropped() const { return junkDropped_; }  // beyond kJunkKeep
  void clearJunk() { junkLen_ = 0; junkDropped_ = 0; }

  // A frame grew past kMaxFrame without a tail and was thrown away.
  bool overflowPending() const { return overflowPending_; }
  const uint8_t* overflowStart() const { return overflowStart_; }  // first 16 bytes
  void clearOverflow() { overflowPending_ = false; }

  uint32_t junkTotal = 0;
  uint32_t overflows = 0;

 private:
  void addJunk(uint8_t b);

  uint8_t buf_[kMaxFrame];
  size_t len_ = 0;
  uint8_t frame_[kMaxFrame];
  size_t frameLen_ = 0;
  uint8_t junk_[kJunkKeep];
  size_t junkLen_ = 0;
  uint32_t junkDropped_ = 0;
  bool overflowPending_ = false;
  uint8_t overflowStart_[16];
};

// One-line human description of a frame (f = <cmd> <payload>).
void describe(const uint8_t* f, size_t n, Text& out);

// Short name of a command byte, or nullptr if unknown.
const char* cmdName(uint8_t cmd);

// For drawing commands: a key made of (cmd, x, y). Used to hide redraws that
// did not change anything. Returns false for commands without a position.
bool positionKey(const uint8_t* f, size_t n, uint64_t& key);

uint32_t fnv1a(const uint8_t* p, size_t n);

}  // namespace dwin
