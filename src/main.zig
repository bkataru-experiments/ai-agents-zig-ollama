const std = @import("std");
const http = std.http;
const json = std.json;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

// Core agent structures
const AgentRole = enum {
    assistant,
    researcher,
    analyzer,
    planner,
};

const Message = struct {
    role: []const u8,
    content: []const u8,
};

const OllamaRequest = struct {
    model: []const u8,
    messages: []Message,
    stream: bool = false,
    options: ?struct {
        temperature: f32 = 0.7,
        top_p: f32 = 0.9,
        max_tokens: u32 = 2048,
    } = null,
};

const OllamaResponse = struct {
    message: Message,
    done: bool,
    total_duration: ?u64 = null,
    load_duration: ?u64 = null,
    prompt_eval_count: ?u32 = null,
    eval_count: ?u32 = null,
};

// Agent configuration
const AgentConfig = struct {
    name: []const u8,
    role: AgentRole,
    model: []const u8,
    system_prompt: []const u8,
    temperature: f32 = 0.7,

}
