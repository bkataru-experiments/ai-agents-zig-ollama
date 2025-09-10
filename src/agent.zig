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

pub const Message = struct {
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
    model: []const u8,
    created_at: []const u8,
    message: Message,
    done: bool,
    done_reason: ?[]const u8 = null,
    total_duration: ?u64 = null,
    load_duration: ?u64 = null,
    prompt_eval_count: ?u32 = null,
    prompt_eval_duration: ?u64 = null,
    eval_count: ?u32 = null,
    eval_duration: ?u64 = null,
};

// Agent configuration
pub const AgentConfig = struct {
    name: []const u8,
    role: AgentRole,
    model: []const u8,
    system_prompt: []const u8,
    temperature: f32 = 0.7,
    max_context: u32 = 4096,
};

// Main Agent struct
pub const Agent = struct {
    config: AgentConfig,
    conversation_history: std.ArrayList(Message),
    ollama_url: []const u8,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: AgentConfig, ollama_url: []const u8) Self {
        return Self{
            .config = config,
            .conversation_history = std.ArrayList(Message).empty,
            .ollama_url = ollama_url,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.conversation_history.items) |msg| {
            self.allocator.free(msg.role);
            self.allocator.free(msg.content);
        }
        self.conversation_history.deinit(self.allocator);
    }

    pub fn addMessage(self: *Self, role: []const u8, content: []const u8) !void {
        try self.conversation_history.append(self.allocator, Message{
            .role = try self.allocator.dupe(u8, role),
            .content = try self.allocator.dupe(u8, content),
        });
    }

    // Caller owns returned memory
    pub fn think(self: *Self, input: []const u8) ![]const u8 {
        // Add user input to conversation
        try self.addMessage("user", input);

        // Prepare messages array with system prompt
        var messages = ArrayList(Message).empty;
        defer messages.deinit(self.allocator);

        // Add system message
        try messages.append(self.allocator, Message{
            .role = "system",
            .content = self.config.system_prompt,
        });

        // Add conversation history
        for (self.conversation_history.items) |msg| {
            try messages.append(self.allocator, msg);
        }

        // Create request
        const request = OllamaRequest{
            .model = self.config.model,
            .messages = messages.items,
            .options = .{
                .temperature = self.config.temperature,
                .max_tokens = 2048,
            },
        };

        // Send request to Ollama
        const response = try self.sendToOllama(request);
        errdefer self.allocator.free(response);

        // Add response to conversation history
        try self.addMessage("assistant", response);

        return response;
    }

    // Caller owns returned memory
    fn sendToOllama(self: *Self, request: OllamaRequest) ![]const u8 {
        var client = http.Client{ .allocator = self.allocator };
        defer client.deinit();

        // Serialize request to JSON
        const request_body = try json.Stringify.valueAlloc(self.allocator, request, .{});
        defer self.allocator.free(request_body);

        // Parse URL
        const uri = try std.Uri.parse(self.ollama_url);

        // Create request
        var req = try client.request(.POST, uri, .{});
        defer req.deinit();

        // Set headers
        req.headers.content_type = .{ .override = "application/json" };

        // Send request
        try req.sendBodyComplete(request_body);

        // Read response
        var res = try req.receiveHead(&.{});
        // var it = res.head.iterateHeaders();
        // while (it.next()) |header| {
        //     std.debug.print("response header name = {s}, value = {s}\n", .{ header.name, header.value });
        // }
        var reader = res.reader(&.{});

        var writer_alloc = std.Io.Writer.Allocating.init(self.allocator);
        defer writer_alloc.deinit();
        const writer = &writer_alloc.writer;

        _ = try reader.streamRemaining(writer);
        const response_body = writer_alloc.written();

        // Parse JSON response
        const parsed = json.parseFromSlice(OllamaResponse, self.allocator, response_body, .{}) catch |e| {
            std.debug.print("Failed to parse Ollama JSON. Body:\n{s}\n", .{response_body});
            return e;
        };
        defer parsed.deinit();

        return try self.allocator.dupe(u8, parsed.value.message.content);
    }

    pub fn clearHistory(self: *Self) void {
        for (self.conversation_history.items) |msg| {
            self.allocator.free(msg.role);
            self.allocator.free(msg.content);
        }
        self.conversation_history.clearAndFree(self.allocator);
    }
};

test "Agent struct works fine" {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const ollama_url = "http://localhost:11434/api/chat";

    var agent = Agent.init(allocator, AgentConfig{
        .name = "agent",
        .role = .assistant,
        .model = "gemma3:270m",
        .system_prompt = "You are a helpful assistant. Provide clear, concise answers and help users accomplish their goals.",
        .temperature = 0.7,
    }, ollama_url);
    defer agent.deinit();

    const response = try agent.think("Hi there! What's your name?");
    defer allocator.free(response);

    std.debug.print("Assistant: {s}\n", .{response});
}
