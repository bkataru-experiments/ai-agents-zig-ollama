const std = @import("std");
const http = std.http;
const json = std.json;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Agent = @import("agent.zig").Agent;
const AgentConfig = @import("agent.zig").AgentConfig;

// Multi-agent orchestrator
pub const AgentOrchestrator = struct {
    agents: ArrayList(Agent),
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .agents = ArrayList(Agent).empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.agents.items) |*agent| {
            agent.deinit();
        }
        self.agents.deinit(self.allocator);
    }

    pub fn addAgent(self: *Self, config: AgentConfig, ollama_url: []const u8) !void {
        const agent = Agent.init(self.allocator, config, ollama_url);
        try self.agents.append(self.allocator, agent);
    }

    pub fn getAgent(self: *Self, name: []const u8) ?*Agent {
        for (self.agents.items) |*agent| {
            if (std.mem.eql(u8, agent.config.name, name)) {
                return agent;
            }
        }
        return null;
    }

    pub fn collaborate(self: *Self, task: []const u8) !void {
        std.debug.print("🤖 Starting collaborative task: {s}\n", .{task});

        // Example collaboration workflow
        if (self.getAgent("researcher")) |researcher| {
            const research_result = try researcher.think(task);
            defer self.allocator.free(research_result);

            std.debug.print("📚 Research: {s}\n", .{research_result});

            if (self.getAgent("analyzer")) |analyzer| {
                const analysis_prompt = try std.fmt.allocPrint(self.allocator, "Analyze this research: {s}", .{research_result});
                defer self.allocator.free(analysis_prompt);

                const analysis = try analyzer.think(analysis_prompt);
                defer self.allocator.free(analysis);

                std.debug.print("🔍 Analysis: {s}\n", .{analysis});

                if (self.getAgent("planner")) |planner| {
                    const plan_prompt = try std.fmt.allocPrint(self.allocator, "Create a plan based on this analysis: {s}", .{analysis});
                    defer self.allocator.free(plan_prompt);

                    const plan = try planner.think(plan_prompt);
                    defer self.allocator.free(plan);

                    std.debug.print("📋 Plan: {s}\n", .{plan});
                }
            }
        }
    }
};
