const std = @import("std");

const agent = @import("agent.zig");
const AgentConfig = agent.AgentConfig;
const agent_orchestrator = @import("agent_orchestrator.zig");
const AgentOrchestrator = agent_orchestrator.AgentOrchestrator;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize orchestrator
    var orchestrator = AgentOrchestrator.init(allocator);
    defer orchestrator.deinit();

    const ollama_url = "http://localhost:11434/api/chat";

    // Create different specialized agents
    try orchestrator.addAgent(AgentConfig{
        .name = "researcher",
        .role = .researcher,
        .model = "gemma3:270m",
        .system_prompt = "You are a research assistant. Gather and synthesize information on topics. Be thorough and cite sources when possible.",
        .temperature = 0.3,
    }, ollama_url);

    try orchestrator.addAgent(AgentConfig{
        .name = "analyzer",
        .role = .analyzer,
        .model = "gemma3:270m",
        .system_prompt = "You are an analytical agent. Break down information, identify patterns, and provide structured analysis.",
        .temperature = 0.5,
    }, ollama_url);

    try orchestrator.addAgent(AgentConfig{
        .name = "planner",
        .role = .planner,
        .model = "gemma3:270m",
        .system_prompt = "You are a planning agent. Create actionable plans and strategies based on analysis and research.",
        .temperature = 0.4,
    }, ollama_url);

    try orchestrator.addAgent(AgentConfig{
        .name = "assistant",
        .role = .assistant,
        .model = "gemma3:270m",
        .system_prompt = "You are a helpful assistant. Provide clear, concise answers and help users accomplish their goals.",
        .temperature = 0.7,
    }, ollama_url);

    // Example single agent interaction
    std.debug.print("=== Single Agent Example ===\n", .{});
    if (orchestrator.getAgent("assistant")) |assistant| {
        const response = try assistant.think("What are the benefits of using Zig for systems programming?");
        defer allocator.free(response);
        std.debug.print("Assistant: {s}\n\n", .{response});
    }

    // Example multi-agent collaboration
    std.debug.print("=== Multi-Agent Collaboration Example ===\n", .{});
    try orchestrator.collaborate("How can we improve software development productivity using AI tools?");

    // Example of agent conversation
    std.debug.print("\n=== Agent Conversation Example ===\n", .{});
    if (orchestrator.getAgent("researcher")) |researcher| {
        const initial = try researcher.think("Tell me about machine learning trends in 2024");
        defer allocator.free(initial);
        const followup = try researcher.think("What are the practical applications?");
        defer allocator.free(followup);

        std.debug.print("Follow-up response: {s}\n", .{followup});
    }
}
