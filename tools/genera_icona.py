"""Icone di tk-acconti nello stile delle app TK: quadrato navy, portafoglio bianco, bollino azzurro con «€».
Uso: python tools/genera_icona.py (serve Pillow) -> assets/icona.png e assets/icona-adattiva.png,
poi: dart run flutter_launcher_icons"""
import os
from PIL import Image, ImageDraw, ImageFont

QUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT_ICONE = r"C:\dev\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf"
FONT_TESTO = r"C:\Windows\Fonts\arialbd.ttf"
NAVY, NAVY2, AZZURRO = (15, 23, 42), (30, 41, 59), (0, 155, 223)
PORTAFOGLIO = chr(0xF520)  # Icons.account_balance_wallet_rounded
G = 4096


def sfondo(img):
    lato = img.size[0]
    grad = Image.new("RGB", (lato, lato))
    gd = ImageDraw.Draw(grad)
    for i in range(lato):
        t = i / lato
        gd.line([(0, i), (lato, i)], fill=tuple(int(NAVY2[k] + (NAVY[k] - NAVY2[k]) * t) for k in range(3)))
    maschera = Image.new("L", (lato, lato), 0)
    ImageDraw.Draw(maschera).rounded_rectangle([0, 0, lato - 1, lato - 1], radius=int(lato * .24), fill=255)
    img.paste(grad, (0, 0), maschera)


def simbolo(img, x0, y0, s):
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(FONT_ICONE, int(s * .86))
    d.text((x0 + s * .40, y0 + s * .42), PORTAFOGLIO, font=f, fill="white", anchor="mm")
    cx, cy, r = x0 + s * .76, y0 + s * .74, s * .22
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=AZZURRO)
    ft = ImageFont.truetype(FONT_TESTO, int(s * .27))
    d.text((cx, cy + s * .01), "€", font=ft, fill="white", anchor="mm")


img = Image.new("RGBA", (G, G), (0, 0, 0, 0))
sfondo(img)
simbolo(img, G * .14, G * .12, G * .76)
img.resize((1024, 1024), Image.LANCZOS).save(os.path.join(QUI, "assets", "icona.png"))
ad = Image.new("RGBA", (G, G), (0, 0, 0, 0))
simbolo(ad, G * .19, G * .17, G * .62)
ad.resize((1024, 1024), Image.LANCZOS).save(os.path.join(QUI, "assets", "icona-adattiva.png"))
print("icone create")
