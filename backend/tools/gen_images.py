"""Генерация иллюстраций кроссовок для начального наполнения каталога.

Запуск:  python tools/gen_images.py   (из каталога backend, нужен Pillow)
Результат: static/images/shoe_01.png … shoe_40.png
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

W, H, SS = 800, 600, 3  # размер и коэффициент сглаживания

# (тип силуэта, верх, акцент, подошва) — по порядку моделей в seed.go
SHOES = [
    ("run", "#d7263d", "#ffffff", "#f4f4f4"), ("run", "#1b1b1f", "#ffffff", "#ffffff"),
    ("run", "#1d4ed8", "#f97316", "#f1f5f9"), ("run", "#14b8a6", "#ffffff", "#ffffff"),
    ("run", "#facc15", "#111111", "#111111"), ("run", "#f472b6", "#ffffff", "#ffffff"),
    ("run", "#f97316", "#1e3a8a", "#ffffff"), ("run", "#6b7280", "#22c55e", "#e5e7eb"),
    ("run", "#7c3aed", "#ffffff", "#ffffff"), ("run", "#a3e635", "#111111", "#fafafa"),
    ("high", "#6d28d9", "#f59e0b", "#f5f5f5"), ("high", "#f8fafc", "#38bdf8", "#38bdf8"),
    ("high", "#dc2626", "#111111", "#111111"), ("high", "#2dd4bf", "#ec4899", "#ffffff"),
    ("high", "#fde047", "#1d4ed8", "#1d4ed8"),
    ("cleat", "#f97316", "#111111", "#111111"), ("cleat", "#18181b", "#ffffff", "#dc2626"),
    ("cleat", "#2563eb", "#fde047", "#fde047"), ("cleat", "#fafafa", "#dc2626", "#dc2626"),
    ("turf", "#16a34a", "#ffffff", "#f5f5f5"),
    ("train", "#6b7280", "#f97316", "#1f2937"), ("train", "#111827", "#ef4444", "#ef4444"),
    ("train", "#1e3a8a", "#ffffff", "#ffffff"), ("train", "#6ee7b7", "#ffffff", "#ffffff"),
    ("run", "#f8fafc", "#2563eb", "#2563eb"), ("run", "#f9a8d4", "#ffffff", "#ffffff"),
    ("train", "#171717", "#a3e635", "#a3e635"), ("run", "#ffffff", "#f97316", "#e5e7eb"),
    ("trail", "#111827", "#3b82f6", "#1f2937"), ("trail", "#fb923c", "#7c3aed", "#7c3aed"),
    ("trail", "#65a30d", "#f97316", "#3f3f46"), ("trail", "#facc15", "#111111", "#111111"),
    ("life", "#ffffff", "#ffffff", "#ffffff"), ("life", "#fafafa", "#111111", "#b45309"),
    ("life", "#9ca3af", "#e5e7eb", "#f5f5f5"), ("run", "#d1d5db", "#d6b98c", "#ffffff"),
    ("life", "#fafaf9", "#15803d", "#fef3c7"),
    ("run", "#1d4ed8", "#ffffff", "#ffffff"), ("run", "#ffffff", "#ec4899", "#ffffff"),
    ("run", "#111111", "#f472b6", "#ffffff"),
]


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def shade(c, k):
    return mix(c, (0, 0, 0), k) if k > 0 else mix(c, (255, 255, 255), -k)


def bezier(p0, p1, p2, p3, n=24):
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        pts.append((u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0],
                    u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1]))
    return pts


def path(segments):
    pts = []
    for seg in segments:
        pts.extend(bezier(*seg))
    return [(x * SS, y * SS) for x, y in pts]


def s(pts):
    return [(x * SS, y * SS) for x, y in pts]


def draw_shoe(kind, upper, accent, sole):
    up, ac, so = rgb(upper), rgb(accent), rgb(sole)
    bg_top = mix(up, (255, 255, 255), 0.86)
    bg_bot = mix(up, (255, 255, 255), 0.70)
    if sum(up) > 690:  # белая обувь — нейтральный фон
        bg_top, bg_bot = (236, 240, 245), (214, 221, 230)

    img = Image.new("RGB", (W * SS, H * SS))
    d = ImageDraw.Draw(img)
    for y in range(H * SS):
        d.line([(0, y), (W * SS, y)], fill=mix(bg_top, bg_bot, y / (H * SS)))

    # Мягкая тень под обувью
    shadow = Image.new("L", img.size, 0)
    ImageDraw.Draw(shadow).ellipse(s([(150, 450), (680, 490)]), fill=120)
    shadow = shadow.filter(ImageFilter.GaussianBlur(18 * SS))
    img.paste(Image.new("RGB", img.size, shade(bg_bot, 0.35)), (0, 0), shadow)
    d = ImageDraw.Draw(img)

    sole_h = {"run": 58, "trail": 52, "train": 40, "life": 34, "high": 46, "cleat": 22, "turf": 30}[kind]
    base = 440
    top_sole = base - sole_h
    collar_y = 200 if kind == "high" else 262
    heel_x = 150

    # Верх (upper)
    upper_pts = path([
        ((heel_x + 4, top_sole + 4), (heel_x - 14, top_sole - 60), (heel_x - 6, collar_y + 30), (heel_x + 26, collar_y)),
        ((heel_x + 26, collar_y), (heel_x + 70, collar_y - 6), (250, collar_y + 22), (300, collar_y + 10)),
        ((300, collar_y + 10), (318, collar_y - 30), (345, collar_y - 44), (365, collar_y - 36)),
        ((365, collar_y - 36), (430, 300 if kind == "high" else 290), (520, 318), (600, 340)),
        ((600, 340), (660, 352), (706, 372), (708, top_sole - 6)),
        ((708, top_sole - 6), (708, top_sole + 4), (700, top_sole + 6), (690, top_sole + 6)),
    ]) + s([(heel_x + 4, top_sole + 6)])
    d.polygon(upper_pts, fill=up)

    # Затемнение пятки и носка — объём
    d.polygon(path([
        ((heel_x + 4, top_sole + 4), (heel_x - 14, top_sole - 60), (heel_x - 6, collar_y + 30), (heel_x + 26, collar_y)),
        ((heel_x + 26, collar_y), (heel_x + 50, collar_y + 60), (heel_x + 60, top_sole - 40), (heel_x + 70, top_sole + 4)),
    ]), fill=shade(up, 0.12))
    d.polygon(path([
        ((600, 340), (660, 352), (706, 372), (708, top_sole - 6)),
        ((708, top_sole - 6), (680, top_sole + 2), (640, top_sole + 4), (610, top_sole + 4)),
        ((610, top_sole + 4), (630, 380), (625, 360), (600, 340)),
    ]), fill=shade(up, -0.18) if sum(up) < 600 else shade(up, 0.06))

    # Воротник (внутренняя часть)
    d.polygon(path([
        ((heel_x + 26, collar_y), (heel_x + 70, collar_y - 6), (250, collar_y + 22), (300, collar_y + 10)),
        ((300, collar_y + 10), (260, collar_y + 36), (200, collar_y + 26), (heel_x + 26, collar_y)),
    ]), fill=shade(up, 0.45))

    # Акцентная полоса / «свуш»
    if kind in ("life",) and upper == "#fafafa":
        for i in range(3):  # три полоски
            x0 = 330 + i * 34
            d.polygon(s([(x0, 300), (x0 + 16, 298), (x0 - 40, top_sole), (x0 - 56, top_sole)]), fill=ac)
    else:
        d.polygon(path([
            ((220, top_sole - 18), (330, top_sole - 10), (470, 330), (600, 300)),
            ((600, 300), (500, 350), (360, top_sole + 2), (240, top_sole - 4)),
        ]), fill=ac if ac != up else shade(up, 0.15))

    # Шнуровка
    for i in range(6):
        t = i / 5
        x = 360 + 190 * t
        y = collar_y - 30 + (330 - (collar_y - 30)) * t ** 0.9 - 4
        d.line(s([(x - 14, y - 6), (x + 14, y + 6)]), fill=shade(ac if ac != (255, 255, 255) else up, 0.35), width=5 * SS)
        d.line(s([(x - 14, y + 6), (x + 14, y - 6)]), fill=shade(ac if ac != (255, 255, 255) else up, 0.25), width=5 * SS)

    # Язычок
    d.polygon(path([
        ((318, collar_y - 30), (330, collar_y - 62), (350, collar_y - 70), (372, collar_y - 58)),
        ((372, collar_y - 58), (372, collar_y - 44), (366, collar_y - 36), (365, collar_y - 36)),
        ((365, collar_y - 36), (345, collar_y - 44), (330, collar_y - 36), (318, collar_y - 30)),
    ]), fill=shade(up, 0.2))

    # Логотип-кружок на пятке
    d.ellipse(s([(heel_x + 18, top_sole - 70), (heel_x + 44, top_sole - 44)]), fill=ac if ac != up else shade(up, 0.3))

    # Подошва
    sole_pts = path([
        ((heel_x, top_sole), (heel_x - 12, top_sole + sole_h * 0.5), (heel_x - 2, base), (heel_x + 30, base)),
        ((heel_x + 30, base), (360, base + 4), (560, base + 2), (680, base - 4)),
        ((680, base - 4), (716, base - 8), (722, top_sole + 2), (706, top_sole - 2)),
    ])
    d.polygon(sole_pts + s([(heel_x, top_sole)]), fill=so)
    # Полоска-разделитель подошвы и протектор
    d.line(s([(heel_x - 2, top_sole + 2), (712, top_sole + 2)]), fill=shade(so, 0.25), width=3 * SS)
    outsole = shade(so, 0.55) if kind in ("run", "train", "life") else shade(so, 0.7)
    d.polygon(path([
        ((heel_x + 2, base - 10), (heel_x + 8, base), (heel_x + 20, base + 2), (heel_x + 30, base + 2)),
        ((heel_x + 30, base + 2), (360, base + 6), (560, base + 4), (680, base - 2)),
        ((680, base - 2), (700, base - 6), (712, base - 10), (716, base - 16)),
    ]) + s([(heel_x + 2, base - 10)]), fill=outsole)
    if kind in ("run", "trail"):
        for i in range(7):  # декоративные пазы в пене
            x = 230 + i * 62
            d.line(s([(x, top_sole + 14), (x + 26, top_sole + sole_h - 18)]), fill=shade(so, 0.12), width=4 * SS)

    # Шипы / протектор
    if kind in ("cleat", "turf", "trail"):
        n, h_, w_ = {"cleat": (6, 22, 22), "turf": (14, 8, 12), "trail": (10, 12, 22)}[kind]
        for i in range(n):
            x = heel_x + 30 + i * (520 / (n - 1))
            d.polygon(s([(x - w_ / 2, base), (x + w_ / 2, base), (x + w_ / 3, base + h_), (x - w_ / 3, base + h_)]),
                      fill=shade(so, 0.6))

    # Блик
    hl = Image.new("L", img.size, 0)
    ImageDraw.Draw(hl).ellipse(s([(420, 300), (640, 340)]), fill=70)
    hl = hl.filter(ImageFilter.GaussianBlur(20 * SS))
    img.paste(Image.new("RGB", img.size, (255, 255, 255)), (0, 0), hl)

    return img.resize((W, H), Image.LANCZOS)


def main():
    out = os.path.join(os.path.dirname(__file__), "..", "static", "images")
    os.makedirs(out, exist_ok=True)
    for i, (kind, upper, accent, sole) in enumerate(SHOES, 1):
        draw_shoe(kind, upper, accent, sole).save(os.path.join(out, f"shoe_{i:02d}.png"), optimize=True)
    print(f"Сгенерировано изображений: {len(SHOES)}")


if __name__ == "__main__":
    main()
