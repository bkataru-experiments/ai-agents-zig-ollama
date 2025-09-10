/// Utility functions for advanced features
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const json = std.json;

const agent = @import("agent.zig");
const Message = agent.Message;

pub fn summarizeConversation(allocator: Allocator, messages: []Message) ![]u8 {
    var summary = ArrayList(u8).empty;
    defer summary.deinit(allocator);

    try summary.appendSlice(allocator, "Conversation Summary:\n");
    for (messages) |msg| {
        try summary.print(allocator, "- {s}: {s}\n", .{ msg.role, msg.content[0..@min(100, msg.content.len)] });
    }

    return summary.toOwnedSlice(allocator);
}

pub fn saveConversation(allocator: Allocator, messages: []Message, filename: []const u8) !void {
    const json_string = try json.Stringify.valueAlloc(allocator, messages, .{ .whitespace = .indent_2 });
    defer allocator.free(json_string);

    try std.fs.cwd().writeFile(filename, json_string);
}

pub fn loadConversation(allocator: Allocator, filename: []const u8) ![]Message {
    const contents = try std.fs.cwd().readFileAlloc(allocator, filename, 1024 * 1024);
    defer allocator.free(contents);

    const parsed = try json.parseFromSlice([]Message, allocator, contents, .{});
    return parsed.value;
}
