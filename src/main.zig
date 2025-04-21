const std = @import("std");
const rl = @import("raylib");
const shards = @import("shards.zig");
const builtin = @import("builtin");

const screenWidth: u16 = 1000;
const screenHeight: u16 = 1000;

const ProjectileRadius = 10.0;
const ObstacleRadius = 20.0;
const PlayerRadius = 20.0;
const TargetRadius = 20.0;

const Projectile = struct { position: rl.Vector2, t: f32, isDead: bool };
const Obstacle = struct { position: rl.Vector2, angle: f32 };
const Player = struct { position: rl.Vector2, angle: f32 };

const COLOR_1 = rl.Color{
    // #F2EFE7
    .r = 242,
    .g = 239,
    .b = 231,
    .a = 255,
};
const COLOR_2 = rl.Color{
    // #9ACBD0
    .r = 154,
    .g = 203,
    .b = 208,
    .a = 255,
};
const COLOR_3 = rl.Color{
    // #48A6A7
    .r = 72,
    .g = 166,
    .b = 167,
    .a = 255,
};
const COLOR_4 = rl.Color{
    // #006A71
    .r = 0,
    .g = 106,
    .b = 113,
    .a = 255,
};

const TOTAL_CIRCLE_COUNT = 10;
const ANGLE_STEP = 360 / TOTAL_CIRCLE_COUNT;
const DEG2RAD: f32 = 0.0174533;

const RADIUS: f32 = 250;

const center = rl.Vector2{ .x = screenWidth / 2, .y = screenHeight / 2 };

const GameContext = struct {
    obstacles: std.ArrayList(Obstacle),
    projectiles: std.ArrayList(Projectile),
    allShards: std.ArrayList(shards.Shard),
    player: Player,
    score: u16 = 0,
    life: u8 = 3,

    pub fn init(allocator: std.mem.Allocator) anyerror!GameContext {
        var obstacles = std.ArrayList(Obstacle).init(allocator);
        const projectiles = std.ArrayList(Projectile).init(allocator);
        const allShards = std.ArrayList(shards.Shard).init(allocator);

        const object = Player{ .position = rl.Vector2{
            .x = screenWidth / 2,
            .y = screenHeight / 2 - 350,
        }, .angle = 90.0 };

        var i: u16 = 0;
        while (i < TOTAL_CIRCLE_COUNT) : (i += 1) {
            const deg = @as(f32, @floatFromInt(i * ANGLE_STEP));
            const rad = deg * DEG2RAD;

            const v = rl.Vector2{
                .x = RADIUS * @cos(rad) + screenWidth / 2,
                .y = RADIUS * @sin(rad) + screenHeight / 2,
            };

            try obstacles.append(Obstacle{ .position = v, .angle = deg });
        }

        return GameContext{ .obstacles = obstacles, .projectiles = projectiles, .player = object, .allShards = allShards };
    }

    pub fn deinit(self: *GameContext) void {
        self.obstacles.deinit();
        self.projectiles.deinit();
        self.allShards.deinit();
    }

    pub fn update(
        context: *GameContext,
    ) anyerror!void {
        { // shooting logic
            if (rl.isMouseButtonReleased(rl.MouseButton.left)) {
                try context.projectiles.append(Projectile{
                    .position = rl.Vector2.init(context.player.position.x, context.player.position.y),
                    .t = 0,
                    .isDead = false,
                });
            }
        }

        { // update the obstacles moving
            var k: u16 = 0;

            while (k < TOTAL_CIRCLE_COUNT) {
                context.obstacles.items[k].angle += 1;

                const rad = context.obstacles.items[k].angle * DEG2RAD;

                context.obstacles.items[k].position.x = RADIUS * @cos(rad) + screenWidth / 2;
                context.obstacles.items[k].position.y = RADIUS * @sin(rad) + screenHeight / 2;

                k += 1;
            }
        }

        { // move the object based on the mouse position
            const mp = rl.getMousePosition().subtract(center).normalize();
            const rad = -mp.angle(rl.Vector2{ .x = 1, .y = 0 });

            context.player.position.x = 350 * @cos(rad) + screenWidth / 2;
            context.player.position.y = 350 * @sin(rad) + screenHeight / 2;
        }

        { // move the projectiles
            var k: u16 = 0;
            while (k < context.projectiles.items.len) : (k += 1) {
                if (!context.projectiles.items[k].isDead) {
                    context.projectiles.items[k].t += 0.05;
                }
            }

            k = 0;
            while (k < context.projectiles.items.len) : (k += 1) {
                if (!context.projectiles.items[k].isDead) {
                    const v = context.projectiles.items[k].position.lerp(center, context.projectiles.items[k].t);

                    var o: u32 = 0;
                    while (o < context.obstacles.items.len) : (o += 1) {
                        const obs = context.obstacles.items[o];
                        if (rl.checkCollisionCircles(v, PlayerRadius, obs.position, ObstacleRadius)) {
                            context.projectiles.items[k].isDead = true;

                            var f: f32 = 0.0;
                            while (f < 100) : (f += 0.5) {
                                const random = shards.prng.random();
                                const speed = random.float(f32) * (@as(f32, @floatFromInt(screenWidth)) * 0.016);
                                const radius = (@as(f32, @floatFromInt(screenWidth)) / 128) * random.float(f32);
                                const shard = try shards.Shard.init(v, f * 3.6, speed, 2, radius, COLOR_4, true);
                                try context.allShards.append(shard);
                            }
                        }
                    }

                    if (rl.checkCollisionCircles(v, PlayerRadius, center, TargetRadius)) {
                        context.projectiles.items[k].isDead = true;

                        var f: f32 = 0.0;
                        while (f < 100) : (f += 0.5) {
                            const random = shards.prng.random();
                            const speed = random.float(f32) * (@as(f32, @floatFromInt(screenWidth)) * 0.016);
                            const radius = (@as(f32, @floatFromInt(screenWidth)) / 128) * random.float(f32);
                            const shard = try shards.Shard.init(center, f * 3.6, speed, 2, radius, COLOR_1, true);
                            try context.allShards.append(shard);
                        }
                    }
                }
            }
        }

        {
            var i: u32 = 0;
            var size = context.allShards.items.len;
            while (i < size) {
                try context.allShards.items[i].update();
                if (context.allShards.items[i].life <= 0) {
                    _ = context.allShards.swapRemove(i);
                } else {
                    i += 1;
                }

                size = context.allShards.items.len;
            }
        }
    }

    pub fn draw(
        context: GameContext,
    ) anyerror!void {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(COLOR_2);

        var j: u16 = 0;
        while (j < TOTAL_CIRCLE_COUNT) {
            const c = context.obstacles.items[j];
            rl.drawCircleV(c.position, ObstacleRadius, COLOR_4);
            j += 1;
        }

        rl.drawCircleV(center, TargetRadius, COLOR_1);

        rl.drawCircleLinesV(center, 350, COLOR_1);

        rl.drawCircleV(context.player.position, PlayerRadius, COLOR_1);

        {
            var k: u16 = 0;
            while (k < context.projectiles.items.len) : (k += 1) {
                if (!context.projectiles.items[k].isDead) {
                    const p = context.projectiles.items[k].position.lerp(center, context.projectiles.items[k].t);
                    rl.drawCircleV(p, ProjectileRadius, COLOR_4);
                }
            }
        }

        {
            rl.drawText("Score: 0", 0, 0, 50, COLOR_4);
            rl.drawText("000", screenWidth - 200, 0, 50, COLOR_4);
        }

        {
            var i: u32 = 0;
            while (i < context.allShards.items.len) : (i += 1) {
                context.allShards.items[i].draw();
            }
        }
    }
};

pub fn main() anyerror!void {
    rl.setConfigFlags(rl.ConfigFlags{ .vsync_hint = true, .msaa_4x_hint = true });
    rl.initWindow(screenWidth, screenHeight, "shoot!");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    const allocator = std.heap.page_allocator;

    var context = try GameContext.init(allocator);
    defer context.deinit();

    while (!rl.windowShouldClose()) {
        try context.update();
        try context.draw();
    }
}
