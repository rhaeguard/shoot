const std = @import("std");
const rl = @import("raylib");

const DEG2RAD: f32 = 0.0174533;

pub var prng = std.Random.DefaultPrng.init(13);

pub const Shard = struct {
    fade: bool,
    color: rl.Color,
    life: f32,
    radius: f32,
    pos: rl.Vector2,
    velocity: rl.Vector2,
    polyPoints: std.ArrayList(rl.Vector2),
    angles: std.ArrayList(f32),

    pub fn init(
        pos: rl.Vector2,
        angle: f32,
        speed: f32,
        life: f32,
        radius: f32,
        color: rl.Color,
        fade: bool,
    ) anyerror!Shard {
        const rad = angle * DEG2RAD;
        const vx = @cos(rad) * speed;
        const vy = -@sin(rad) * speed;

        const allocator = std.heap.page_allocator;
        const polygonPoints = std.ArrayList(rl.Vector2).init(allocator);
        var angles = std.ArrayList(f32).init(allocator);

        const random = prng.random();

        try getAngles(&angles, random);

        return Shard{
            .pos = pos,
            .life = life,
            .velocity = rl.Vector2{
                .x = vx,
                .y = vy,
            },
            .color = color,
            .radius = radius,
            .angles = angles,
            .fade = fade,
            .polyPoints = polygonPoints,
        };
    }

    pub fn deinit(self: *Shard) void {
        self.angles.deinit();
        self.polyPoints.deinit();
    }

    pub fn update(p: *Shard) anyerror!void {
        p.life -= 0.0167 * 2;

        if (p.life <= 0) {
            return;
        }

        p.pos = p.pos.add(p.velocity);

        var i: u16 = 0;
        while (i < p.angles.items.len) : (i += 1) {
            p.angles.items[i] += 10;
        }

        const eRadius = rl.Vector2{
            .x = p.radius * 1.5,
            .y = p.radius,
        };

        p.polyPoints.clearRetainingCapacity();
        try getPolygon(&p.polyPoints, p.pos, p.angles, eRadius);
    }

    pub fn draw(p: *Shard) void {
        if (p.life <= 0) {
            return;
        }

        const alpha = (255.0 * p.life / 2.0) / 255.0;
        const size = p.polyPoints.items.len;
        const p0 = p.polyPoints.items[0];
        var i: u16 = 0;
        while (i < size - 1) : (i += 1) {
            const p1 = p.polyPoints.items[i % size];
            const p2 = p.polyPoints.items[i + 1];
            rl.drawTriangle(p2, p1, p0, p.color.alpha(alpha));
        }
    }
};

fn getPoint(angle: f32, eRadius: rl.Vector2) rl.Vector2 {
    const theta = angle * DEG2RAD;

    const x = eRadius.x * @cos(theta);
    const y = eRadius.y * @sin(theta);

    return rl.Vector2{ .x = x, .y = y };
}

fn getAngles(angles: *std.ArrayList(f32), rand: std.Random) anyerror!void {
    const n = rand.intRangeLessThan(u8, 0, 4) + 3;

    var i: u8 = 0;
    while (i <= n) : (i += 1) {
        const angle = rand.float(f32) * 355.23;
        try angles.append(angle);
    }

    std.mem.sort(f32, angles.items, {}, comptime std.sort.asc(f32));
}

fn getPolygon(polygonPoints: *std.ArrayList(rl.Vector2), center: rl.Vector2, angles: std.ArrayList(f32), eRadius: rl.Vector2) anyerror!void {
    std.mem.sort(f32, angles.items, {}, comptime std.sort.asc(f32));

    for (angles.items) |angle| {
        var pt = getPoint(angle, eRadius);
        pt = pt.add(center);
        try polygonPoints.append(pt);
    }
}
