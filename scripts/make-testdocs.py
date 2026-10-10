#!/usr/bin/env python3
"""Erzeugt synthetische Testdokumente (fiktive Inhalte) für die Funktionsprüfung.

Läuft im Paperless-Image (dort sind PIL und zxing vorhanden), siehe
scripts/test-functions.sh. Ausgabe in den übergebenen Ordner:

  scan_asn.pdf        Bild-PDF ohne Text (OCR nötig), leicht schief, ASN-Barcode ASN00042
  scan_getrennt.pdf   3 Seiten, Seite 2 ist ein Trennblatt (PATCHT) -> 2 Dokumente
  Testordner/scan_tag.pdf  Unterordner -> Tag "Testordner"
  brief.docx          Word-Dokument (über Tika)
  mail.eml            E-Mail (über Tika/Gotenberg)
"""
import sys
import zipfile
from pathlib import Path

import zxingcpp
from PIL import Image, ImageDraw, ImageFont

FONT = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
A4 = (1654, 2339)  # 200 dpi


def page(lines, barcode=None, angle=0.0):
    img = Image.new("L", A4, 255)
    draw = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT, 42)
    y = 250
    for line in lines:
        draw.text((180, y), line, fill=0, font=font)
        y += 80
    if barcode:
        code = zxingcpp.create_barcode(barcode, zxingcpp.BarcodeFormat.Code128)
        img.paste(Image.fromarray(zxingcpp.write_barcode_to_image(code, scale=4)).resize((600, 150)),
                  (A4[0] - 800, 80))
    if angle:
        img = img.rotate(angle, expand=False, fillcolor=255)
    return img


def save_pdf(path, pages):
    path.parent.mkdir(parents=True, exist_ok=True)
    pages[0].save(path, "PDF", resolution=200, save_all=True, append_images=pages[1:])


def docx(path, paragraphs):
    body = "".join(f"<w:p><w:r><w:t>{p}</w:t></w:r></w:p>" for p in paragraphs)
    files = {
        "[Content_Types].xml": '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>',
        "_rels/.rels": '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>',
        "word/document.xml": f'<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>{body}</w:body></w:document>',
    }
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        for name, content in files.items():
            z.writestr(name, content)


def main(out: Path):
    out.mkdir(parents=True, exist_ok=True)
    save_pdf(out / "scan_asn.pdf", [page([
        "Beispiel Versicherung AG (fiktiv)",
        "Musterstrasse 1, 12345 Musterstadt",
        "",
        "Versicherungsschein Nr. VS-2026-0815",
        "Datum: 15.03.2026",
        "",
        "Sehr geehrte Damen und Herren,",
        "hiermit bestaetigen wir den Versicherungsschutz",
        "fuer Ihre Betriebshaftpflicht. Testdokument Kontrollwort: ZITRONENFALTER",
    ], barcode="ASN00042", angle=1.5)])

    save_pdf(out / "scan_getrennt.pdf", [
        page(["Erstes Dokument (fiktiv)", "Kontrollwort: ERSTDOKUMENT"]),
        page(["Trennblatt"], barcode="PATCHT"),
        page(["Zweites Dokument (fiktiv)", "Kontrollwort: ZWEITDOKUMENT"]),
    ])

    save_pdf(out / "Testordner" / "scan_tag.pdf", [page([
        "Dokument im Unterordner (fiktiv)", "Kontrollwort: UNTERORDNER"])])

    docx(out / "brief.docx", [
        "Muster Handwerk GmbH (fiktiv)",
        "Angebot Nr. A-4711 vom 01.04.2026",
        "Testdokument Kontrollwort: WORDDOKUMENT",
    ])

    (out / "mail.eml").write_text(
        "From: Max Muster <max@example.com>\n"
        "To: Buero <buero@example.org>\n"
        "Subject: Testmail fuer Paperless\n"
        "Date: Thu, 02 Apr 2026 10:00:00 +0200\n"
        "MIME-Version: 1.0\n"
        "Content-Type: text/plain; charset=utf-8\n\n"
        "Hallo,\n\ndies ist eine fiktive Testmail. Kontrollwort: MAILDOKUMENT\n\nGruss\nMax\n"
    )
    print(f"Testdokumente erzeugt in {out}")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
