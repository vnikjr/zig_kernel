const std = @import("std");
const Reader = std.io.AnyReader;
const Writer = std.io.AnyWriter;

const UART_BASE: u64 = 0x09000000;
const UART_DATA_REGISTER: *volatile u8 = @ptrFromInt(UART_BASE + 0x00); // Data register (read/write)
const UART_FLAG_REGISTER: *volatile u8 = @ptrFromInt(UART_BASE + 0x18); // Flag register
const UART_FLAG_RXFE: u8 = (1 << 4); // flag register bitmask (00010000)
const UART_INTERRUPT_MASK_REGISTER: *volatile u8 = @ptrFromInt(UART_BASE + 0x38); // Interrupt mask register (optional)
const UART_INTERRUPT_CLEAR_REGISTER: *volatile u8 = @ptrFromInt(UART_BASE + 0x44); // Interrupt clear register (optional)

const UARTContext = struct {};

fn writeFn(_: *const anyopaque, msg: []const u8) anyerror!usize {
    for (msg) |c| {
        UART_DATA_REGISTER.* = c;
    }
    return msg.len;
}

fn readFn(_: *const anyopaque, buffer: []u8) anyerror!usize {
    if (buffer.len == 0) return 0;

    // Wait for 1st byte (blocking)
    buffer[0] = readByteBlocking();
    var count: usize = 1;

    // Read more if possible (non-blocking)
    while (count < buffer.len and uart_has_input()) {
        buffer[count] = readByteBlocking();
        count += 1;
    }
    return count;
}

fn uart_has_input() bool {
    return (UART_FLAG_REGISTER.* & UART_FLAG_RXFE) == 0; // apply the bitmask to the value in the register
}

fn readByteBlocking() u8 {
    while (!uart_has_input()) {}
    return UART_DATA_REGISTER.*;
}
const uart = UARTContext{};
pub const UARTWriter = Writer{ .context = &uart, .writeFn = writeFn };
pub const UARTReader = Reader{ .context = &uart, .readFn = readFn };
