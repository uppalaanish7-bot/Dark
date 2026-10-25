"""Build the sealed monumental basalt Hollow Spire with Blender 4.5 / bpy.

Run: python tools/create_hollow_spire.py [--render]
Authored coordinates are Godot metres: Y up, front +Z. Exact bounds are
x[-80,80], y[0,150], z[-40,40]. Ten editable Floor groups hold real geometry.
All materials are opaque stone with packed, eight-metre repeating textures.
The entrance is a 4.4m x 4.5m x 6m vestibule, closed at z=34, open at z=40.
"""

from pathlib import Path
import json
import math
import random
import sys
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

PROJECT = Path(__file__).resolve().parents[1]
ART = PROJECT / "art" / "hollow_spire"
TEXTURES = ART / "textures"
EXPORT = PROJECT / "assets" / "buildings" / "hollow_spire.glb"
RNG = random.Random(41226)
NP_RNG = np.random.default_rng(41226)
MATERIALS = []
STONE, DARK, CUT, RECESS, AMBER = range(5)
TILE_METRES = 8.0


def godot_to_blender(point):
    x, y, z = point
    return (x, -z, y)


def smooth_noise(size, cells):
    """Periodic smooth noise for seam-free repeating stone."""
    grid = NP_RNG.random((cells, cells)).astype(np.float32)
    coord = np.arange(size, dtype=np.float32) * cells / size
    lo = np.floor(coord).astype(int)
    mix = coord - lo
    mix = mix * mix * (3.0 - 2.0 * mix)
    a = grid[lo[:, None] % cells, lo[None, :] % cells]
    b = grid[lo[:, None] % cells, (lo[None, :] + 1) % cells]
    c = grid[(lo[:, None] + 1) % cells, lo[None, :] % cells]
    d = grid[(lo[:, None] + 1) % cells, (lo[None, :] + 1) % cells]
    return ((a * (1 - mix[None, :]) + b * mix[None, :]) * (1 - mix[:, None])
            + (c * (1 - mix[None, :]) + d * mix[None, :]) * mix[:, None])


def bake_image(name, rgb, non_color=False):
    height, width = rgb.shape[:2]
    rgba = np.ones((height, width, 4), dtype=np.float32)
    # Image pixels are scene-linear; the stone palette below is authored in
    # sRGB. Convert once before PNG encoding to avoid pale double-gamma stone.
    color = np.clip(rgb, 0, 1)
    if not non_color:
        color = np.where(color <= .04045, color / 12.92, ((color + .055) / 1.055) ** 2.4)
    rgba[:, :, :3] = color
    image = bpy.data.images.new(name, width, height, alpha=False)
    image.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    image.pixels.foreach_set(rgba.reshape(-1))
    image.filepath_raw = str(TEXTURES / (name + ".png"))
    image.file_format = "PNG"
    image.save()
    image.pack()
    return image


def stone_textures():
    """Fractured, pitted basalt: no concrete seams, tie holes or office panes."""
    size = 2048
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    broad, strata, rock, grain = [smooth_noise(size, n) for n in (5, 18, 53, 191)]
    grit = NP_RNG.random((size, size)).astype(np.float32)
    veins = np.exp(-((smooth_noise(size, 11) + .21 * rock - .57) / .020) ** 2)
    cracks = np.exp(-((smooth_noise(size, 23) + .12 * grain - .51) / .010) ** 2)
    pits = np.clip((.18 - grit) * 4.8, 0, 1) * (.4 + .6 * grain)
    runoff = np.zeros((size, size), dtype=np.float32)
    for _ in range(64):
        x0, start = NP_RNG.uniform(0, size, 2)
        width, length = NP_RNG.uniform(3, 20), NP_RNG.uniform(260, 1600)
        dx = np.minimum(abs(xx - x0), size - abs(xx - x0))
        dy = (yy - start) % size
        runoff += np.exp(-(dx / width) ** 2) * np.clip(1 - dy / length, 0, 1) * NP_RNG.uniform(.012, .065)
    shade = (.39 + (broad - .5) * .040 + (strata - .5) * .042 + (rock - .5) * .055
             + (grain - .5) * .030 + (grit - .5) * .018 - runoff * .26
             - cracks * .018 - pits * .026 + veins * .010)
    mineral = np.clip(strata - .58, 0, .4)
    rgb = np.stack((shade * 1.025 + mineral * .05, shade + mineral * .02,
                    shade * .955 - mineral * .025), axis=-1)
    main = bake_image("basalt_weathered_8m", rgb)
    dark = bake_image("basalt_shadow_8m", rgb * .77)
    cut = bake_image("basalt_cut_edges_8m", rgb * 1.12 + .026)
    relief = .52 * rock + .22 * grain + .09 * grit + .075 * veins - .075 * cracks - .095 * pits
    gx = (np.roll(relief, -1, axis=1) - np.roll(relief, 1, axis=1)) * .5
    gy = (np.roll(relief, -1, axis=0) - np.roll(relief, 1, axis=0)) * .5
    normals = np.dstack((-gx * 5.8, -gy * 5.8, np.ones_like(gx)))
    normals /= np.linalg.norm(normals, axis=2, keepdims=True)
    normal = bake_image("basalt_normal_8m", normals * .5 + .5, True)
    rough = bake_image("basalt_roughness_8m", np.repeat((.83 + .14 * rock)[:, :, None], 3, axis=2), True)
    return main, dark, cut, normal, rough


def linear(channel):
    return channel / 12.92 if channel <= .04045 else ((channel + .055) / 1.055) ** 2.4


def material(name, color, images=None, emission=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_backface_culling = True
    mat.diffuse_color = (*map(linear, color), 1)
    mat["opaque_stone"], mat["texture_tile_metres"] = True, TILE_METRES
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    shader = nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = mat.diffuse_color
    shader.inputs["Metallic"].default_value = 0
    shader.inputs["Roughness"].default_value = .91
    shader.inputs["Specular IOR Level"].default_value = .20
    shader.inputs["Alpha"].default_value = 1
    shader.inputs["Transmission Weight"].default_value = 0
    if images:
        tex = nodes.new("ShaderNodeTexImage")
        tex.image, tex.extension = images[0], "REPEAT"
        tex.label = "Packed stone, repeats every 8 metres"
        links.new(tex.outputs["Color"], shader.inputs["Base Color"])
        normal_tex = nodes.new("ShaderNodeTexImage")
        normal_tex.image, normal_tex.extension = images[1], "REPEAT"
        normal = nodes.new("ShaderNodeNormalMap")
        normal.inputs["Strength"].default_value = .28
        links.new(normal_tex.outputs["Color"], normal.inputs["Color"])
        links.new(normal.outputs["Normal"], shader.inputs["Normal"])
        rough = nodes.new("ShaderNodeTexImage")
        rough.image, rough.extension = images[2], "REPEAT"
        links.new(rough.outputs["Color"], shader.inputs["Roughness"])
    if emission:
        shader.inputs["Emission Color"].default_value = (*emission, 1)
        shader.inputs["Emission Strength"].default_value = 1.7
    MATERIALS.append(mat)


def create_materials():
    main, dark, cut, normal, rough = stone_textures()
    material("Weathered basalt masonry", (.30, .31, .33), (main, normal, rough))
    material("Dark cleaved basalt", (.20, .21, .22), (dark, normal, rough))
    material("Worn carved stone edges", (.34, .35, .36), (cut, normal, rough))
    material("Deep stone crevices", (.055, .061, .070))
    material("Amber mineral in carved stone", (.28, .13, .035), emission=(.45, .16, .025))


class Geometry:
    """One mesh per architectural tier, shared stone materials and metre UVs."""
    def __init__(self, name, parent, collection):
        self.name, self.parent, self.collection = name, parent, collection
        self.vertices, self.faces, self.uvs, self.material_ids = [], [], [], []

    def quad(self, points, mat):
        start = len(self.vertices)
        self.vertices.extend(godot_to_blender(p) for p in points)
        self.faces.append(tuple(range(start, start + len(points))))
        a, b, c = [np.array(p) for p in points[:3]]
        normal = np.cross(b - a, c - a)
        axes = ((2, 1), (0, 2), (0, 1))[int(np.argmax(np.abs(normal)))]
        self.uvs.extend((p[axes[0]] / TILE_METRES, p[axes[1]] / TILE_METRES) for p in points)
        self.material_ids.append(mat)

    def box(self, center, size, mat):
        x, y, z = center
        sx, sy, sz = [s / 2 for s in size]
        xl, xr, yl, yr, zl, zr = x - sx, x + sx, y - sy, y + sy, z - sz, z + sz
        self.quad(((xl, yl, zr), (xr, yl, zr), (xr, yr, zr), (xl, yr, zr)), mat)
        self.quad(((xr, yl, zl), (xl, yl, zl), (xl, yr, zl), (xr, yr, zl)), mat)
        self.quad(((xr, yl, zr), (xr, yl, zl), (xr, yr, zl), (xr, yr, zr)), mat)
        self.quad(((xl, yl, zl), (xl, yl, zr), (xl, yr, zr), (xl, yr, zl)), mat)
        self.quad(((xl, yr, zr), (xr, yr, zr), (xr, yr, zl), (xl, yr, zl)), mat)
        self.quad(((xl, yl, zl), (xr, yl, zl), (xr, yl, zr), (xl, yl, zr)), mat)

    def facade_stone(self, direction, fixed, u, y, width, height, depth, mat, bevel=.12):
        """Closed eight-corner prism, giving each block a chipped silhouette."""
        w, h, c = width / 2, height / 2, min(bevel, width * .15, height * .15)
        ring = [(-w + c, -h), (w - c, -h), (w, -h + c), (w, h - c),
                (w - c, h), (-w + c, h), (-w, h - c), (-w, -h + c)]
        def point(px, py, dd):
            if direction == "front": return (u + px, y + py, fixed + dd)
            if direction == "rear": return (u - px, y + py, fixed - dd)
            if direction == "right": return (fixed + dd, y + py, u - px)
            return (fixed - dd, y + py, u + px)
        front = [point(px, py, depth / 2) for px, py in ring]
        back = [point(px, py, -depth / 2) for px, py in ring]
        self.quad(front, mat)
        self.quad(tuple(reversed(back)), mat)
        for index in range(8):
            other = (index + 1) % 8
            self.quad((back[index], back[other], front[other], front[index]), mat)

    def finish(self):
        mesh = bpy.data.meshes.new(self.name + "_Mesh")
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        used = sorted(set(self.material_ids))
        remap = {index: local for local, index in enumerate(used)}
        for index in used: mesh.materials.append(MATERIALS[index])
        for face, mat_id in zip(mesh.polygons, self.material_ids):
            face.material_index = remap[mat_id]
        uv = mesh.uv_layers.new(name="Stone_8m_Repeat_UV")
        uv.data.foreach_set("uv", np.asarray(self.uvs, dtype=np.float32).reshape(-1))
        mesh.validate(verbose=False)
        obj = bpy.data.objects.new(self.name, mesh)
        self.collection.objects.link(obj)
        obj.parent = self.parent
        obj["storey_geometry"] = True
        obj["material_surface_count"] = len(used)
        return obj


def empty(name, parent, collection):
    obj = bpy.data.objects.new(name, None)
    collection.objects.link(obj)
    obj.parent = parent
    obj.empty_display_size = 1
    return obj


def facade_box(geo, direction, fixed, u, y, width, height, depth, mat):
    if direction in ("front", "rear"):
        geo.box((u, y, fixed), (width, height, depth), mat)
    else:
        geo.box((fixed, y, u), (depth, height, width), mat)


def masonry(geo, direction, fixed, u0, u1, low, high, entrance=False):
    """Staggered great stones with low-contrast joints and occasional cleaves."""
    rows = max(1, round((high - low) / 3.0))
    pitch_y = (high - low) / rows
    for row in range(rows):
        y0, y1 = low + row * pitch_y, low + (row + 1) * pitch_y
        start = u0 - (4.05 if row % 2 else 0)
        while start < u1:
            end = min(start + RNG.uniform(6.8, 9.2), u1)
            a, b = max(start, u0), min(end - .07, u1)
            if b - a > .35 and not (entrance and y0 < 7.8 and b > -5.7 and a < 5.7):
                mat = DARK if RNG.random() < .035 else STONE
                geo.facade_stone(direction, fixed, (a + b) / 2, (y0 + y1) / 2,
                                 b - a, y1 - y0 - .065, RNG.uniform(.22, .38), mat,
                                 bevel=RNG.uniform(.08, .20))
            start = end


def solid_tier(geo, half_width, half_depth, low, high, ground=False):
    """Fully closed mass, except the specifically authored short vestibule."""
    height, mid = high - low, (low + high) / 2
    if ground:
        # A solid rear volume reaches z=34. No open ground-floor rear exists.
        geo.box((0, mid, (34 - half_depth) / 2),
                (half_width * 2, height, half_depth + 34), STONE)
        for sign in (-1, 1):
            # Reserve the entire portal-frame width for vestibule() so its
            # inner walls have one surface each, without coplanar overlaps.
            width = half_width - 5.7
            geo.box((sign * (5.7 + width / 2), mid, (34 + half_depth) / 2),
                    (width, height, half_depth - 34), STONE)
        # Box bottom points downward, directly into the room, at y=4.5.
        geo.box((0, (4.5 + high) / 2, (34 + half_depth) / 2),
                (11.4, high - 4.5, half_depth - 34), STONE)
    else:
        geo.box((0, mid, 0), (half_width * 2, height, half_depth * 2), STONE)
    for direction, fixed, extent in (("front", half_depth + .05, half_width),
                                      ("rear", -half_depth - .05, half_width),
                                      ("right", half_width + .05, half_depth),
                                      ("left", -half_width - .05, half_depth)):
        masonry(geo, direction, fixed, -extent, extent, low, high,
                entrance=ground and direction == "front")


def buttresses(geo, low, high, span, depth, include_sides=True):
    """Deep uninterrupted stone piers avoid repetitive bright floor bands."""
    mid, height = (low + high) / 2, high - low
    for sign in (-1, 1):
        for x in (-76.5, -59, -43, -27, -11, 11, 27, 43, 59, 76.5):
            if abs(x) > span: continue
            width = 7 if abs(x) > 70 else (5.6 if abs(x) == 11 else 4.8)
            z = sign * (depth + .40)
            projection = min(3.20, 2 * (40 - abs(z)))
            geo.box((x, mid, z), (width, height, projection), STONE)
            direction = "front" if sign > 0 else "rear"
            outer = sign * (abs(z) + projection / 2 + .009)
            if abs(outer) < 40:
                facade_box(geo, direction, outer, x, mid, width * .28, height, .018, DARK)
            for dx in (-width * .31, width * .31):
                facade_box(geo, direction, sign * min(39.84, abs(z) + projection / 2 - .1),
                           x + dx, mid, width * .15, height, .30, CUT)
    if include_sides:
        for sign in (-1, 1):
            for z in (-27, -10, 10, 27):
                geo.box((sign * 79, mid, z), (2, height, 5.2), STONE)
                geo.box((sign * 79.81, mid, z), (.38, height, .70), DARK)


def carved_recess(geo, direction, fixed, u, bottom, height, width, glow=False):
    """Opaque mineral inset at the bottom of an overhung, carved stone scar."""
    sign = 1 if direction in ("front", "right") else -1
    facade_box(geo, direction, fixed, u, bottom + height / 2, width, height, .06, RECESS)
    for offset in (-width / 2 - .20, width / 2 + .20):
        facade_box(geo, direction, fixed + sign * .14, u + offset,
                   bottom + height / 2, .38, height + .62, .4, DARK)
    facade_box(geo, direction, fixed + sign * .21, u, bottom + height + .28,
               width + .76, .55, .56, STONE)
    if glow:
        facade_box(geo, direction, fixed + sign * .043, u,
                   bottom + height * .44, min(.14, width * .14), height * .54, .025, AMBER)


def relief_prism(geo, direction, fixed, u, outline, depth, mat):
    """Closed architectural relief, with an explicit face separation."""
    outline = list(outline)
    area = sum(a[0] * b[1] - b[0] * a[1]
               for a, b in zip(outline, outline[1:] + outline[:1]))
    if area < 0:
        outline.reverse()
    def point(px, py, dd):
        if direction == "front": return (u + px, py, fixed + dd)
        if direction == "rear": return (u - px, py, fixed - dd)
        if direction == "right": return (fixed + dd, py, u - px)
        return (fixed - dd, py, u + px)
    front = [point(px, py, depth / 2) for px, py in outline]
    back = [point(px, py, -depth / 2) for px, py in outline]
    geo.quad(front, mat)
    geo.quad(tuple(reversed(back)), mat)
    for index in range(len(front)):
        other = (index + 1) % len(front)
        geo.quad((back[index], back[other], front[other], front[index]), mat)


def relief_ring(geo, direction, fixed, u, y, radius, width, depth, mat):
    segments = 32 if radius > 2 else 16
    for i in range(segments):
        a, b = math.tau * i / segments, math.tau * (i + 1) / segments
        outer, inner = radius + width / 2, radius - width / 2
        outline = [(math.cos(t) * r, y + math.sin(t) * r)
                   for t, r in ((a, outer), (b, outer), (b, inner), (a, inner))]
        relief_prism(geo, direction, fixed, u, outline, depth, mat)


def blind_arch(geo, direction, fixed, u, bottom, spring, radius, rise, central=False):
    """Tall, opaque tracery relief carved into the continuous sealed mass."""
    sign = 1 if direction in ("front", "right") else -1
    arc = [(radius * (-1 + 2 * i / 32),
            spring + rise * (1 - abs(-1 + 2 * i / 32)) ** .78) for i in range(33)]
    relief_prism(geo, direction, fixed, u,
                 [(-radius, bottom), (radius, bottom)] + list(reversed(arc)), .09, RECESS)
    frame_fixed = fixed + sign * .24
    for a, b in zip(arc, arc[1:]):
        relief_prism(geo, direction, frame_fixed, u,
                     [(a[0] * 1.12, a[1] + .50), (b[0] * 1.12, b[1] + .50),
                      (b[0], b[1] - .20), (a[0], a[1] - .20)], .50, CUT)
    for side in (-1, 1):
        facade_box(geo, direction, frame_fixed, u + side * (radius + .28),
                   (spring + bottom) / 2, .56, spring - bottom, .50, CUT)
        facade_box(geo, direction, fixed + sign * .12, u + side * radius * .40,
                   (spring + bottom) / 2, .22, spring - bottom, .18, DARK)
    facade_box(geo, direction, frame_fixed, u, bottom - .34, radius * 2 + 1.9, .72, .74, CUT)
    # The upper rosette is real relief over opaque stone, never glass or a hole.
    rosette_y = spring + rise * .25
    rosette_r = radius * .68
    relief_ring(geo, direction, frame_fixed, u, rosette_y, rosette_r, .36, .50, CUT)
    relief_ring(geo, direction, fixed + sign * .33, u, rosette_y, rosette_r * .79, .13, .18, AMBER if central else DARK)
    for i in range(8):
        angle = math.tau * i / 8
        px, py = math.cos(angle) * rosette_r * .47, rosette_y + math.sin(angle) * rosette_r * .47
        relief_ring(geo, direction, fixed + sign * .35, u + px, py, rosette_r * .31, .16, .25, CUT)
    if central:
        relief_prism(geo, direction, fixed + sign * .47, u,
                     [(0, rosette_y + .65), (.42, rosette_y), (0, rosette_y - .65), (-.42, rosette_y)], .18, AMBER)


def facade_composition(geo):
    for direction, fixed in (("front", 38.40), ("rear", -38.40)):
        blind_arch(geo, direction, fixed, 0, 32, 75, 7.0, 17, central=direction == "front")
        for u in (-67, -51, -35, 35, 51, 67):
            blind_arch(geo, direction, fixed, u, 20, 80, 3.6, 9)
    for direction, fixed in (("right", 78.40), ("left", -78.40)):
        for u in (-18.5, 0, 18.5):
            blind_arch(geo, direction, fixed, u, 20, 80, 4.0, 9)


def vestibule(geo):
    # Thick closed side solids provide +X left and -X right inward normals.
    for sign in (-1, 1):
        geo.box((sign * 3.95, 3.75, 37), (3.5, 7.5, 6), CUT)
    # The bottom of this closed box is the y=4.5 vestibule ceiling (-Y normal).
    # The main mass supplies z34..38; this extension supplies z38..40 only.
    geo.box((0, 6, 39), (4.4, 3, 2), STONE)
    # Single visible stone floor, upward winding, exactly on the model base.
    geo.quad(((-2.2, 0, 40), (2.2, 0, 40), (2.2, 0, 34), (-2.2, 0, 34)), CUT)
    # Rear wall is the solid_tier box's z=34 face (+Z normal). Restrained
    # mineral seam gives the eye a stop without resembling a glass opening.
    geo.box((0, 2.6, 34.012), (.09, 1.55, .020), AMBER)


def roof_crown(geo):
    # Every set-back is a closed solid; no open top exposes a hollow interior.
    for sign in (-1, 1):
        for z in (-23, 23):
            geo.box((sign * 24.5, 144, z), (7, 12, 9), STONE)
            geo.box((sign * 24.5, 149.4, z), (7.8, 1.2, 9.8), CUT)
            geo.box((sign * 24.5, 146, z + (4.53 if z > 0 else -4.53)), (1.1, 5.8, .05), DARK)
    geo.box((0, 142.5, 0), (40, 9, 50), STONE)
    geo.box((0, 147.55, 0), (33, 1.1, 44), DARK)
    geo.box((0, 148.6, 0), (27, 1, 38), STONE)
    for x in (-9, 0, 9):
        geo.box((x, 149.55, 0), (3.8, .9, 35), DARK)


def build_tower():
    collection = bpy.data.collections.new("HOLLOW SPIRE — SEALED STONE GAME EXPORT")
    bpy.context.scene.collection.children.link(collection)
    root = empty("HollowSpire", None, collection)
    root["description"] = "Monumental weathered basalt fortress; ten editable architectural tiers"
    root["metres_per_unit"], root["front_direction"] = 1.0, "Godot +Z"
    root["dimensions_m"] = [160.0, 150.0, 80.0]
    root["entrance_clearance"] = "4.4m wide x 4.5m high x 6m deep, x=0, front z=40, solid back z=34"
    root["sealed_exterior"], root["stone_texture_repeat_m"] = True, TILE_METRES
    for i in range(10):
        low, high = i * 15.0, (i + 1) * 15.0
        floor = empty(f"Floor{i + 1:02d}", root, collection)
        floor["storey"], floor["floor_height_m"], floor["elevation_m"] = i + 1, 15.0, low
        geo = Geometry(f"Floor{i + 1:02d}_Stone_Architecture", floor, collection)
        if i < 7:
            solid_tier(geo, 78, 38, low, high, ground=(i == 0))
            buttresses(geo, low, high, 78, 38)
        elif i == 7:
            # Broad, fully roofed 108-metre bastions frame the taller tower.
            solid_tier(geo, 78, 38, low, 108)
            buttresses(geo, low, 108, 78, 38)
            solid_tier(geo, 37.5, 34, 108, high)
            buttresses(geo, 108, high, 30, 34, include_sides=False)
            for sign in (-1, 1):
                for x in (47, 63, 76):
                    for z in (-34, 34):
                        geo.box((sign * x, 109.5, z), (5, 3, 8), STONE)
        elif i == 8:
            solid_tier(geo, 37.5, 34, low, high)
            buttresses(geo, low, high, 30, 34, include_sides=False)
        else:
            solid_tier(geo, 37.5, 34, low, 138)
            buttresses(geo, low, 138, 30, 34, include_sides=False)
            roof_crown(geo)
        if i == 0:
            vestibule(geo)
            facade_composition(geo)
        if i in (7, 8):
            for x in (-19, 0, 19):
                bottom = max(low + 1, 109)
                carved_recess(geo, "front", 34.31, x, bottom, high - bottom - .8, 1.35,
                              glow=(i == 8 and x == 0))
        geo.finish()
    return root


def descendants(root):
    result = [root]
    for child in root.children: result.extend(descendants(child))
    return result


def validate_geometry(root):
    meshes = [obj for obj in descendants(root) if obj.type == "MESH"]
    points = [vertex.co for obj in meshes for vertex in obj.data.vertices]
    lower = [min(p[axis] for p in points) for axis in range(3)]
    upper = [max(p[axis] for p in points) for axis in range(3)]
    assert all(abs(a - b) < 1e-4 for a, b in zip(lower, [-80, -40, 0])), lower
    assert all(abs(a - b) < 1e-4 for a, b in zip(upper, [80, 40, 150])), upper
    triangles = sum(sum(len(face.vertices) - 2 for face in obj.data.polygons) for obj in meshes)
    surfaces = sum(len(obj.data.materials) for obj in meshes)
    assert triangles < 150000 and surfaces < 100, (triangles, surfaces)
    assert len(meshes) == 10
    assert {obj.name for obj in root.children} == {f"Floor{i:02d}" for i in range(1, 11)}
    vertices, polygons = [], []
    for obj in meshes:
        offset = len(vertices)
        vertices.extend(vertex.co[:] for vertex in obj.data.vertices)
        polygons.extend(tuple(index + offset for index in face.vertices) for face in obj.data.polygons)
    tree = BVHTree.FromPolygons(vertices, polygons, all_triangles=False)
    def ray(name, origin, direction, expected, tolerance=.001):
        _, normal, _, distance = tree.ray_cast(Vector(godot_to_blender(origin)),
                                              Vector(godot_to_blender(direction)), 1000)
        if expected is None:
            assert distance is None, (name, distance)
        else:
            assert distance is not None and abs(distance - expected) <= tolerance, (name, distance)
            # Validate winding: an incoming ray must see the stone FRONT face.
            assert normal.dot(Vector(godot_to_blender(direction))) < -.999, (name, normal)
        return {"name": name, "hit_distance_m": distance, "front_facing": normal is not None}
    checks = [ray("vestibule floor", (0, 2, 37), (0, -1, 0), 2),
              ray("vestibule ceiling", (0, 2, 37), (0, 1, 0), 2.5),
              ray("vestibule left wall", (0, 2, 37), (-1, 0, 0), 2.2),
              ray("vestibule right wall", (0, 2, 37), (1, 0, 0), 2.2),
              ray("vestibule solid back wall", (1, 2, 37), (0, 0, -1), 3),
              ray("entrance clear to outdoors", (0, 2, 37), (0, 0, 1), None),
              ray("sealed rear at ground", (0, 2, -45), (0, 0, 1), 7, .3),
              ray("sealed central roof", (0, 160, 0), (0, -1, 0), 10)]
    report = {"meshes": len(meshes), "material_surfaces": surfaces, "triangles": triangles,
              "godot_bounds_min": [-80, 0, -40], "godot_bounds_max": [80, 150, 40],
              "dimensions_width_height_depth_m": [160, 150, 80],
              "vestibule_width_height_depth_m": [4.4, 4.5, 6], "vestibule_front_z": 40,
              "vestibule_back_z": 34, "stone_texture_repeat_m": TILE_METRES,
              "baked_texture_resolution": [2048, 2048], "checks": checks}
    (ART / "hollow_spire_geometry_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("HOLLOW_SPIRE_REPORT=" + json.dumps(report), flush=True)


def compose_beauty_scene():
    collection = bpy.data.collections.new("AUTHORING ONLY — camera and lighting")
    bpy.context.scene.collection.children.link(collection)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x, scene.render.resolution_y = 1600, 1200
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(ART / "hollow_spire_stone_preview.png")
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (.17, .21, .28, 1)
    background.inputs["Strength"].default_value = .6
    scene.view_settings.view_transform, scene.view_settings.exposure = "AgX", .65
    data = bpy.data.cameras.new("Architectural review camera")
    camera = bpy.data.objects.new("Architectural review camera", data)
    collection.objects.link(camera)
    camera.location = godot_to_blender((143, 66, 194))
    target = Vector(godot_to_blender((0, 69, 0)))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.lens, camera.data.clip_end = 31, 1500
    scene.camera = camera
    light_data = bpy.data.lights.new("Broad dusk sun", "SUN")
    light_data.energy, light_data.angle, light_data.color = 2.3, .12, (.78, .84, 1)
    light = bpy.data.objects.new("Broad dusk sun", light_data)
    collection.objects.link(light)
    light.rotation_euler = (math.radians(27), math.radians(-28), math.radians(-22))
    for name, position, power, color, size in (
            ("Front fill", (10, 100, 140), 250000, (.76, .80, .89), 100),
            ("Warm stone rim", (-100, 130, 30), 500000, (.93, .75, .52), 85)):
        light_data = bpy.data.lights.new(name, "AREA")
        light_data.energy, light_data.color, light_data.shape, light_data.size = power, color, "DISK", size
        light = bpy.data.objects.new(name, light_data)
        collection.objects.link(light)
        light.location = godot_to_blender(position)
        light.rotation_euler = (Vector(godot_to_blender((0, 60, 0))) - light.location).to_track_quat("-Z", "Y").to_euler()
    mesh = bpy.data.meshes.new("Review ground mesh")
    mesh.from_pydata([(-600, -600, -.025), (600, -600, -.025), (600, 600, -.025), (-600, 600, -.025)], [], [(0, 1, 2, 3)])
    ground = bpy.data.objects.new("Review ground — excluded from GLB", mesh)
    collection.objects.link(ground)
    ground.data.materials.append(MATERIALS[DARK])
    scene.unit_settings.system, scene.unit_settings.scale_length = "METRIC", 1
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                area.spaces.active.region_3d.view_perspective = "CAMERA"
                area.spaces.active.clip_end = 1500


def main():
    ART.mkdir(parents=True, exist_ok=True)
    TEXTURES.mkdir(parents=True, exist_ok=True)
    EXPORT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    create_materials()
    root = build_tower()
    validate_geometry(root)
    compose_beauty_scene()
    bpy.ops.object.select_all(action="DESELECT")
    for obj in descendants(root): obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.wm.save_as_mainfile(filepath=str(ART / "hollow_spire.blend"))
    bpy.ops.export_scene.gltf(filepath=str(EXPORT), export_format="GLB", use_selection=True,
                             export_yup=True, export_apply=False, export_texcoords=True,
                             export_normals=True, export_tangents=False, export_materials="EXPORT",
                             export_cameras=False, export_lights=False, export_extras=True,
                             export_animations=False, export_image_format="AUTO")
    print(f"HOLLOW_SPIRE_BLEND={ART / 'hollow_spire.blend'}", flush=True)
    print(f"HOLLOW_SPIRE_GLB={EXPORT}", flush=True)
    if "--render" in sys.argv:
        bpy.ops.render.render(write_still=True)
        print(f"HOLLOW_SPIRE_PREVIEW={bpy.context.scene.render.filepath}", flush=True)


if __name__ == "__main__":
    main()
