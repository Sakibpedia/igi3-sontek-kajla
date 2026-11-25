import pymupdf, os
from PIL import Image, ImageDraw
PDF = r'G:\GTA\Downloads\Image.pdf'
OUT = r'C:\Users\sakib\AppData\Local\Temp\opencode\pdf_contact.jpg'
doc = pymupdf.open(PDF)
n = min(60, len(doc))
cols, tw, th = 5, 220, 175
rows = (n + cols - 1) // cols
sheet = Image.new('RGB', (cols * tw, rows * (th + 18)), (235, 235, 235))
d = ImageDraw.Draw(sheet)
for i in range(n):
    pix = doc[i].get_pixmap(matrix=pymupdf.Matrix(0.35, 0.35), alpha=False)
    im = Image.frombytes('RGB', (pix.width, pix.height), pix.samples)
    im.thumbnail((tw, th))
    x, y = (i % cols) * tw, (i // cols) * (th + 18)
    sheet.paste(im, (x, y))
    d.text((x + 3, y + th), 'page %d' % (i + 1), fill=(0, 0, 0))
sheet.save(OUT, quality=80)
print('saved', OUT, sheet.size)
