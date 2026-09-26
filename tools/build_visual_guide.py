from pathlib import Path

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_ALIGN_VERTICAL, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Inches, Pt, RGBColor


ROOT = Path(r"C:\Proyectos de flutter\game_final")
OUTPUT = ROOT / "docs" / "Guia_Produccion_Visual_Sistema_Caido.docx"

NAVY = "17365D"
PALE_BLUE = "EAF2F8"
PALE_GRAY = "F4F6F7"
BORDER = "D9D9D9"
WHITE = "FFFFFF"
BLACK = "000000"
CYAN = "31C7D8"
ORANGE = "F29B45"
PURPLE = "8D66C4"


def set_cell_shading(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_border(cell, color=BORDER, size="6"):
    tc_pr = cell._tc.get_or_add_tcPr()
    borders = tc_pr.first_child_found_in("w:tcBorders")
    if borders is None:
        borders = OxmlElement("w:tcBorders")
        tc_pr.append(borders)
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        tag = "w:" + edge
        element = borders.find(qn(tag))
        if element is None:
            element = OxmlElement(tag)
            borders.append(element)
        element.set(qn("w:val"), "single")
        element.set(qn("w:sz"), size)
        element.set(qn("w:color"), color)


def set_cell_margins(cell, top=100, start=120, bottom=100, end=120):
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for m, value in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = tc_mar.find(qn(f"w:{m}"))
        if node is None:
            node = OxmlElement(f"w:{m}")
            tc_mar.append(node)
        node.set(qn("w:w"), str(value))
        node.set(qn("w:type"), "dxa")


def set_repeat_table_header(row):
    tr_pr = row._tr.get_or_add_trPr()
    tbl_header = OxmlElement("w:tblHeader")
    tbl_header.set(qn("w:val"), "true")
    tr_pr.append(tbl_header)


def keep_with_next(paragraph):
    paragraph.paragraph_format.keep_with_next = True


def add_heading(doc, text, level=1):
    p = doc.add_paragraph(text, style=f"Heading {level}")
    keep_with_next(p)
    return p


def add_body(doc, text, bold_lead=None):
    p = doc.add_paragraph()
    if bold_lead and text.startswith(bold_lead):
        p.add_run(bold_lead).bold = True
        p.add_run(text[len(bold_lead):])
    else:
        p.add_run(text)
    return p


def add_bullets(doc, items):
    for item in items:
        p = doc.add_paragraph(item, style="List Bullet")
        p.paragraph_format.space_after = Pt(3)


def add_numbered(doc, items):
    for item in items:
        p = doc.add_paragraph(item, style="List Number")
        p.paragraph_format.space_after = Pt(4)


def add_table(doc, headers, rows, widths=None, font_size=9):
    table = doc.add_table(rows=1, cols=len(headers))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    table.style = "Table Grid"
    header = table.rows[0]
    set_repeat_table_header(header)
    for i, text in enumerate(headers):
        cell = header.cells[i]
        set_cell_shading(cell, NAVY)
        set_cell_border(cell)
        set_cell_margins(cell)
        cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        run = p.add_run(text)
        run.bold = True
        run.font.color.rgb = RGBColor(255, 255, 255)
        run.font.size = Pt(font_size)
        if widths:
            cell.width = widths[i]
    for row_index, values in enumerate(rows):
        row = table.add_row()
        for i, value in enumerate(values):
            cell = row.cells[i]
            set_cell_border(cell)
            set_cell_margins(cell)
            if row_index % 2 == 1:
                set_cell_shading(cell, PALE_BLUE)
            cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
            p = cell.paragraphs[0]
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER if i == len(values) - 1 else WD_ALIGN_PARAGRAPH.LEFT
            run = p.add_run(str(value))
            run.font.size = Pt(font_size)
            if i == len(values) - 1:
                run.bold = True
            if widths:
                cell.width = widths[i]
    doc.add_paragraph().paragraph_format.space_after = Pt(0)
    return table


def add_entity(doc, title, appearance, rows, priority, canvas):
    add_heading(doc, title, 2)
    add_body(doc, f"Apariencia. {appearance}", "Apariencia.")
    add_body(doc, f"Formato recomendado. {canvas}", "Formato recomendado.")
    add_table(
        doc,
        ["Sprite o estado", "Qué debe mostrar", "Prioridad"],
        rows,
        [Inches(1.55), Inches(4.25), Inches(0.75)],
    )
    p = doc.add_paragraph()
    r = p.add_run(f"Prioridad general del conjunto: {priority}")
    r.bold = True
    r.font.color.rgb = RGBColor.from_string(NAVY)


doc = Document()
section = doc.sections[0]
section.top_margin = Cm(2.0)
section.bottom_margin = Cm(1.8)
section.left_margin = Cm(2.1)
section.right_margin = Cm(2.1)

styles = doc.styles
normal = styles["Normal"]
normal.font.name = "Aptos"
normal._element.rPr.rFonts.set(qn("w:ascii"), "Aptos")
normal._element.rPr.rFonts.set(qn("w:hAnsi"), "Aptos")
normal.font.size = Pt(10.5)
normal.font.color.rgb = RGBColor.from_string(BLACK)
normal.paragraph_format.space_after = Pt(7)
normal.paragraph_format.line_spacing = 1.08

title_style = styles["Title"]
title_style.font.name = "Aptos Display"
title_style._element.rPr.rFonts.set(qn("w:ascii"), "Aptos Display")
title_style._element.rPr.rFonts.set(qn("w:hAnsi"), "Aptos Display")
title_style.font.size = Pt(25)
title_style.font.bold = True
title_style.font.color.rgb = RGBColor.from_string(BLACK)
title_p_pr = title_style._element.get_or_add_pPr()
title_border = title_p_pr.find(qn("w:pBdr"))
if title_border is not None:
    title_p_pr.remove(title_border)

for name, size in (("Heading 1", 17), ("Heading 2", 13), ("Heading 3", 11)):
    style = styles[name]
    style.font.name = "Aptos Display"
    style._element.rPr.rFonts.set(qn("w:ascii"), "Aptos Display")
    style._element.rPr.rFonts.set(qn("w:hAnsi"), "Aptos Display")
    style.font.size = Pt(size)
    style.font.bold = True
    style.font.color.rgb = RGBColor.from_string(BLACK)
    style.paragraph_format.space_before = Pt(12 if name == "Heading 1" else 8)
    style.paragraph_format.space_after = Pt(5)
    style.paragraph_format.keep_with_next = True

for name in ("List Bullet", "List Number"):
    styles[name].font.name = "Aptos"
    styles[name].font.size = Pt(10)

footer = section.footer
fp = footer.paragraphs[0]
fp.alignment = WD_ALIGN_PARAGRAPH.CENTER
fr = fp.add_run("Sistema Caído  |  Guía de producción visual  |  Versión 1.0")
fr.font.name = "Aptos"
fr.font.size = Pt(8)
fr.font.color.rgb = RGBColor(90, 100, 108)

# Cover
p = doc.add_paragraph(style="Title")
p.alignment = WD_ALIGN_PARAGRAPH.LEFT
p.add_run("Guía de producción visual de Sistema Caído")
p_pr = p._p.get_or_add_pPr()
p_border = p_pr.find(qn("w:pBdr"))
if p_border is not None:
    p_pr.remove(p_border)
sub = doc.add_paragraph()
sub.add_run("Descripción artística  sprites necesarios  prioridades y orden de entrega").bold = True
sub.runs[0].font.size = Pt(14)
sub.runs[0].font.color.rgb = RGBColor.from_string(NAVY)
doc.add_paragraph("Documento de trabajo para producir los recursos que reemplazarán los placeholders geométricos del prototipo Flutter y Flame.")
doc.add_paragraph("Versión 1.0  |  24 de septiembre de 2026")

add_heading(doc, "Objetivo", 1)
add_body(doc, "Esta guía define cómo debe verse cada elemento del vertical slice, qué sprites o estados necesita y en qué orden deben producirse. La prioridad principal es sustituir los elementos que el jugador observa continuamente sin modificar colliders, hitboxes ni reglas ya implementadas.")
add_body(doc, "La primera entrega visual debe concentrarse en M-0, Energy, los controles, los tres enemigos activos y VOLT. Los jefes y sectores posteriores quedan documentados como dirección futura, pero no deben retrasar el reemplazo de los placeholders del recorrido P01 a P10.")

add_heading(doc, "Resumen de prioridad", 1)
add_table(
    doc,
    ["Nivel", "Significado", "Ejemplos", "Orden"],
    [
        ("P0", "Imprescindible para que el vertical slice tenga identidad y pueda probarse visualmente.", "M-0, tiles de Energy, HUD, Patrol, Watcher, Drone, VOLT.", "Primero"),
        ("P1", "Necesario para legibilidad, feedback y presentación completa del prototipo.", "VFX, puertas, checkpoint, interruptores, controles táctiles.", "Después de P0"),
        ("P2", "Mejora variedad y acabado; puede esperar sin bloquear la jugabilidad.", "Decoración, fondos, variantes dañadas, Shield Unit y Charge Bot.", "Tercero"),
        ("P3", "Contenido de la campaña futura fuera del vertical slice actual.", "ARCHIVE completo, PROXY, SENTINEL, CORE y otras zonas.", "Más adelante"),
    ],
    [Inches(0.55), Inches(2.45), Inches(2.85), Inches(0.85)],
)

add_heading(doc, "Orden recomendado de producción", 1)
add_numbered(doc, [
    "Definir la paleta, la cuadrícula y una imagen de referencia frontal y lateral de M-0.",
    "Crear M-0 con idle, carrera, ascenso, caída, salto, ataque, dash y daño.",
    "Crear el tileset básico de Energy y los elementos interactivos que aparecen en P01 a P10.",
    "Crear Patrol Unit, Watcher y Drone con sus ataques y estados de daño.",
    "Crear VOLT, sus telegraphs, ataques, fase vulnerable y derrota.",
    "Crear HUD, iconos de módulos y controles táctiles.",
    "Añadir VFX, decoración, fondos y variaciones de ambiente.",
    "Preparar contenido futuro solo después de revisar el vertical slice en un teléfono.",
])

doc.add_page_break()
add_heading(doc, "Dirección visual común", 1)
add_body(doc, "El mundo debe sentirse como una instalación industrial autónoma que lleva años funcionando sin supervisión. Las máquinas continúan obedeciendo órdenes antiguas, pero muestran desgaste, reparaciones incompletas, energía inestable y señalización técnica.")
add_bullets(doc, [
    "Pixel art con siluetas legibles en una pantalla móvil y contraste alto entre personaje, enemigos, peligros y fondo.",
    "Tiles de 32 por 32 píxeles. M-0 en lienzos de 48 por 64 píxeles. Enemigos normales entre 48 y 64 píxeles. VOLT puede ocupar entre 192 y 256 píxeles.",
    "Paleta base fría para NEXUS: azul petróleo, cian, gris acero y negro azulado. Naranja para enemigos, rojo para daño, amarillo para advertencias y violeta para secretos.",
    "La iluminación debe concentrarse en núcleos, sensores, electricidad, permisos y terminales. El fondo nunca debe competir con plataformas o peligros.",
    "Las animaciones pueden usar pocos frames, pero cada anticipación de ataque debe ser clara antes del daño.",
    "No incorporar sombras que cambien la posición aparente del collider. Los sprites pueden sobresalir del collider mediante offsets visuales.",
])

add_heading(doc, "Especificación de archivos", 2)
add_table(
    doc,
    ["Tipo", "Formato de entrega", "Regla"],
    [
        ("Sprites", "PNG transparente y archivo editable", "Sin suavizado, sin fondo y con pivote consistente."),
        ("Spritesheets", "Filas por estado o archivos por animación", "Todos los frames deben conservar el mismo lienzo."),
        ("Tiles", "PNG en cuadrícula de 32 por 32", "Incluir esquinas, bordes y un ejemplo ensamblado."),
        ("Fondos", "PNG por capas", "Separar fondo lejano, medio y primer plano sin colisión."),
        ("UI", "PNG transparente o SVG", "Debe seguir siendo legible con opacidad reducida."),
        ("Nombres", "categoria_elemento_estado_numero.png", "Ejemplo player_run_01.png."),
    ],
    [Inches(1.25), Inches(2.55), Inches(2.9)],
)

doc.add_page_break()
add_heading(doc, "Personaje jugable", 1)
add_entity(
    doc,
    "M 0",
    "Una unidad de mantenimiento pequeña, compacta y reparada varias veces. Debe tener una cabeza o sensor principal muy reconocible, un núcleo cian y extremidades mecánicas simples. Su silueta necesita comunicar agilidad sin parecer un soldado. El cuerpo debe permitir que el jugador identifique de inmediato hacia dónde mira y qué habilidad está ejecutando.",
    [
        ("Referencia", "Frente, perfil derecho, espalda, paleta y piezas separadas.", "P0"),
        ("Idle", "Respiración mecánica, parpadeo del sensor o pulso del núcleo. 4 a 6 frames.", "P0"),
        ("Carrera", "Pasos rápidos, inclinación leve y centro de masa estable. 6 a 8 frames.", "P0"),
        ("Ascenso", "Cuerpo extendido después del impulso. 1 a 2 frames.", "P0"),
        ("Caída", "Extremidades abiertas para leer la dirección vertical. 1 a 2 frames.", "P0"),
        ("Aterrizaje", "Compresión breve sin modificar el collider. 2 a 3 frames.", "P1"),
        ("Ataque", "Anticipación, golpe activo y recuperación. 4 a 6 frames.", "P0"),
        ("Dash", "Cuerpo comprimido horizontalmente con núcleo brillante. 2 a 4 frames.", "P0"),
        ("Wall slide", "Una mano o herramienta contra la pared y chispas separadas. 2 a 4 frames.", "P0"),
        ("Wall jump", "Impulso claramente orientado lejos de la pared. 2 a 3 frames.", "P0"),
        ("Doble salto", "Giro o extensión distinta del primer salto. 3 a 5 frames.", "P0"),
        ("Golpe descendente", "Herramienta dirigida hacia abajo, caída rígida e impacto. 4 a 6 frames.", "P0"),
        ("Daño", "Flash, torsión en sentido contrario al impacto. 2 a 3 frames.", "P0"),
        ("Muerte", "Apagado, piezas sueltas o colapso; sin violencia orgánica. 5 a 8 frames.", "P0"),
        ("Respawn", "Reconstrucción o reactivación del núcleo. 4 a 6 frames.", "P1"),
        ("Checkpoint", "Conexión del núcleo con la columna de guardado. 3 a 5 frames.", "P1"),
        ("Instalar módulo", "Pulso del núcleo y breve apertura de una compuerta corporal. 4 a 6 frames.", "P1"),
    ],
    "P0",
    "48 por 64 píxeles por frame, orientación derecha y pivote constante en el centro de los pies.",
)

add_heading(doc, "Enemigos del vertical slice", 1)
add_entity(
    doc,
    "Patrol Unit",
    "Robot industrial terrestre de silueta baja y pesada. Debe parecer un equipo de inspección convertido en obstáculo, con sensor naranja, patas o ruedas protegidas y un frente fácilmente reconocible.",
    [
        ("Idle", "Sensor buscando actividad. 2 a 4 frames.", "P0"),
        ("Patrulla", "Movimiento lateral mecánico. 4 a 6 frames.", "P0"),
        ("Giro", "Reorientación del sensor antes de cambiar de dirección. 2 frames.", "P1"),
        ("Ataque o contacto", "Extensión frontal o descarga corta. 3 a 5 frames.", "P0"),
        ("Daño", "Retroceso y parpadeo del núcleo. 2 frames.", "P0"),
        ("Destrucción", "Colapso y chispas. 4 a 6 frames.", "P0"),
    ],
    "P0",
    "48 por 48 o 64 por 48 píxeles por frame.",
)
add_entity(
    doc,
    "Watcher",
    "Torre o sensor fijo con un ojo luminoso. Su forma debe mostrar que detecta, apunta y dispara antes de que aparezca el proyectil. El sensor pasa de apagado a amarillo y finalmente a rojo durante la anticipación.",
    [
        ("Idle", "Sensor cerrado o en barrido lento. 2 a 4 frames.", "P0"),
        ("Detectar", "El ojo se abre y fija al jugador. 2 a 3 frames.", "P0"),
        ("Apuntar", "Haz fino o retícula independiente. 3 a 5 frames.", "P0"),
        ("Disparo", "Retroceso mecánico y destello. 3 a 4 frames.", "P0"),
        ("Cooldown", "Humo leve o sensor enfriándose. 2 a 4 frames.", "P1"),
        ("Proyectil", "Orbe o pulso eléctrico con 2 a 4 frames y efecto de impacto.", "P0"),
        ("Daño y destrucción", "Flash, grietas del lente y apagado. 5 a 7 frames en total.", "P0"),
    ],
    "P0",
    "48 por 64 píxeles para la torre; proyectil en lienzo de 24 por 24.",
)
add_entity(
    doc,
    "Drone",
    "Unidad aérea de mantenimiento con cuerpo compacto, dos propulsores y un sensor naranja. Debe ser legible sobre fondos oscuros y comunicar claramente cuándo persigue y cuándo se retira.",
    [
        ("Hover", "Flotación estable con propulsores pulsantes. 4 a 6 frames.", "P0"),
        ("Detectar", "Sensor brillante y cambio de inclinación. 2 a 3 frames.", "P0"),
        ("Perseguir", "Cuerpo inclinado en la dirección de movimiento. 3 a 5 frames.", "P0"),
        ("Retirarse", "Inclinación opuesta y propulsión fuerte. 3 a 5 frames.", "P1"),
        ("Daño", "Pérdida momentánea de estabilidad. 2 frames.", "P0"),
        ("Destrucción", "Separación de propulsores, chispa y caída. 5 a 7 frames.", "P0"),
    ],
    "P0",
    "64 por 48 píxeles por frame.",
)

add_heading(doc, "Enemigos futuros", 2)
add_table(
    doc,
    ["Entidad", "Apariencia y sprites", "Prioridad"],
    [
        ("Shield Unit", "Unidad de seguridad alta con escudo frontal luminoso. Idle, avanzar, bloquear, atacar, stagger trasero, daño y destrucción.", "P2"),
        ("Charge Bot", "Robot de carga con motor sobredimensionado y señal de advertencia. Idle, warning, carga, choque, stun, daño y destrucción.", "P2"),
    ],
    [Inches(1.35), Inches(4.75), Inches(0.7)],
)

doc.add_page_break()
add_heading(doc, "Jefe principal", 1)
add_entity(
    doc,
    "VOLT",
    "Supervisor de Energy. Debe dominar la arena como una máquina industrial enorme construida alrededor de un núcleo amarillo inestable. Su cuerpo combina transformador, brazos pesados, aisladores y cables. La primera fase se ve controlada; la segunda muestra grietas, energía expuesta y movimientos más agresivos.",
    [
        ("Referencia", "Frente, perfil, partes móviles, núcleo, cables, paleta y escala junto a M-0.", "P0"),
        ("Idle fase 1", "Peso, vibración y pulsos de energía. 4 a 6 frames.", "P0"),
        ("Introducción", "Activación del núcleo y cierre de la arena. 6 a 10 frames.", "P1"),
        ("Slam anticipación", "Brazos elevados y zona de impacto advertida. 4 a 6 frames.", "P0"),
        ("Ground Slam", "Golpe, compresión y onda expansiva separada. 5 a 8 frames.", "P0"),
        ("Grid telegraph", "Núcleo cargándose y segmentos del suelo marcados en amarillo.", "P0"),
        ("Grid Surge", "Electricidad activa por sectores, en loops de 3 a 5 frames.", "P0"),
        ("Cable telegraph", "Cable tensándose y trayectoria claramente marcada.", "P0"),
        ("Cable Sweep", "Cable o brazo que atraviesa la arena. 5 a 8 frames.", "P0"),
        ("Overload", "Núcleo abierto, humo, electricidad irregular y pose vulnerable. 4 a 6 frames.", "P0"),
        ("Daño vulnerable", "Flash del núcleo y sacudida corporal. 2 a 3 frames.", "P0"),
        ("Fase 2", "Rotura de placas, energía expuesta y nueva intensidad. 5 a 8 frames.", "P0"),
        ("Derrota", "Apagado escalonado, caída de piezas y descarga final. 10 a 14 frames.", "P0"),
        ("Retrato HUD", "Silueta o sensor de VOLT para acompañar la barra de vida.", "P1"),
    ],
    "P0",
    "Lienzo aproximado de 192 por 192 o 256 por 192 píxeles. Cables, ondas y electricidad deben ir en sprites separados.",
)

add_heading(doc, "Jefes posteriores", 1)
add_table(
    doc,
    ["Jefe", "Descripción visual y necesidades", "Prioridad"],
    [
        ("ARCHIVE", "Araña mecánica de almacenamiento con patas magnéticas, lector central y desplazamiento por techo. Requiere locomoción, láser de escaneo, bloques de datos, daño y destrucción.", "P3"),
        ("PROXY", "Nodo de red móvil con cuerpo central y copias de señal. Requiere señuelos, proyectiles reenviados, nodos activos, daño y derrota.", "P3"),
        ("SENTINEL", "Supervisor de Security con escudo, sensores y silueta militar. Requiere bloqueo, persecución, embestida, fase expuesta y derrota.", "P3"),
        ("CORE", "Núcleo central fragmentado que combina lenguajes visuales de todas las zonas. Requiere múltiples configuraciones de fase y final narrativo.", "P3"),
    ],
    [Inches(1.15), Inches(5.0), Inches(0.65)],
)

doc.add_page_break()
add_heading(doc, "Escenario Energy", 1)
add_body(doc, "Energy debe parecer una planta de distribución eléctrica que sigue funcionando con mantenimiento insuficiente. Las superficies transitables usan grises claros y bordes definidos; el fondo usa azul petróleo y valores más oscuros. La electricidad peligrosa utiliza rojo y amarillo, mientras los elementos seguros o activados utilizan cian y verde.")

add_heading(doc, "Tiles y plataformas", 2)
add_table(
    doc,
    ["Recurso", "Variantes necesarias", "Prioridad"],
    [
        ("Suelo industrial", "Centro, borde superior, esquinas, extremos, unión con pared y tres variantes de desgaste.", "P0"),
        ("Pared y techo", "Centro, esquinas internas y externas, remates y variaciones dañadas.", "P0"),
        ("Plataforma unidireccional", "Centro, extremos, soporte inferior y señal visual de atravesable.", "P0"),
        ("Plataforma móvil", "Base, riel, luz activa y loop de energía o motor.", "P0"),
        ("Suelo rompible", "Intacto, agrietado, ruptura y fragmentos separados.", "P0"),
        ("Pared secreta", "Patrón discontinuo sutil y versión abierta.", "P1"),
        ("Tiles dañados", "Grietas, placas faltantes, óxido, marcas de calor y cables expuestos.", "P2"),
    ],
    [Inches(1.65), Inches(4.45), Inches(0.7)],
)

add_heading(doc, "Elementos interactivos", 2)
add_table(
    doc,
    ["Elemento", "Aspecto y estados", "Prioridad"],
    [
        ("Checkpoint", "Columna cian con base industrial. Apagado, activación, activo y pulso de guardado.", "P0"),
        ("Puerta", "Marco azul oscuro y panel de requisito. Cerrada, denegada, abriendo, abierta y puerta de combate.", "P0"),
        ("Interruptor", "Palanca o panel accesible. Apagado, activándose y verde activo.", "P0"),
        ("Terminal", "Pantalla, teclado industrial, apagada, encendida y mostrando mensaje.", "P1"),
        ("Cápsula de módulo", "Contenedor mecánico con núcleo visible. Cerrada, abriendo y vacía.", "P1"),
        ("Permiso", "Tarjeta, símbolo o pulso de autorización que pueda mostrarse en HUD y puerta.", "P1"),
        ("Registro secreto", "Fragmento violeta, animación flotante y efecto de recolección.", "P1"),
        ("Fragmento de vida", "Pieza cian distinta de los módulos de movimiento.", "P2"),
        ("Recarga de dash", "Punto de energía compacto con estado disponible y descargado.", "P2"),
    ],
    [Inches(1.55), Inches(4.55), Inches(0.7)],
)

add_heading(doc, "Decoración y fondos", 2)
add_table(
    doc,
    ["Grupo", "Recursos", "Prioridad"],
    [
        ("Infraestructura", "Tuberías, curvas, uniones, válvulas, conductos, rejillas, vigas y soportes.", "P2"),
        ("Electricidad", "Generadores, transformadores, aisladores, bobinas, cables y cajas de distribución.", "P1"),
        ("Señalización", "Advertencia, alto voltaje, números de sector, flechas y permisos.", "P1"),
        ("Desgaste", "Chatarra, tornillos, placas, manchas, grietas, marcas de calor y piezas sueltas.", "P2"),
        ("Fondos", "Sala industrial lejana, maquinaria media y primer plano opcional; cada capa separada.", "P1"),
    ],
    [Inches(1.45), Inches(4.65), Inches(0.7)],
)

add_heading(doc, "Interfaz", 1)
add_body(doc, "La interfaz debe parecer parte del sistema NEXUS: tipografía técnica, marcos sencillos, información directa y alto contraste. La forma nunca debe reducir la legibilidad en una pantalla pequeña.")
add_table(
    doc,
    ["Recurso", "Descripción y estados", "Prioridad"],
    [
        ("Logotipo", "Versión horizontal, compacta y monocromática de Sistema Caído.", "P1"),
        ("Vida", "Celda llena, dañada y vacía; debe leerse sobre cualquier fondo.", "P0"),
        ("Módulo Dash", "Icono de impulso con disponible, usado y recargando.", "P0"),
        ("Wall jump", "Icono de pared y rebote.", "P0"),
        ("Golpe descendente", "Icono de flecha o herramienta hacia abajo.", "P0"),
        ("Doble salto", "Icono de doble impulso o dos anillos.", "P0"),
        ("Barra de jefe", "Marco, relleno, nombre VOLT y retrato o símbolo.", "P0"),
        ("Mensajes", "Panel para permisos, terminales, checkpoint y módulos.", "P1"),
        ("Menús", "Botón normal, enfocado, presionado y desactivado; paneles de inicio, pausa y opciones.", "P1"),
        ("Controles táctiles", "Izquierda, derecha, abajo, salto, ataque, dash y pausa. Normal y presionado.", "P0"),
        ("Alto contraste", "Alternativa para peligros, hitboxes de debug y controles táctiles.", "P1"),
        ("Icono Android", "Símbolo de M-0 o su núcleo, legible a tamaños pequeños.", "P2"),
    ],
    [Inches(1.55), Inches(4.55), Inches(0.7)],
)

add_heading(doc, "Efectos visuales", 1)
add_table(
    doc,
    ["Efecto", "Descripción", "Prioridad"],
    [
        ("Salto y aterrizaje", "Polvo o partículas mecánicas breves sin ocultar los pies.", "P1"),
        ("Doble salto", "Anillo cian que aparece debajo de M-0.", "P1"),
        ("Dash", "Estela, afterimages y destello inicial.", "P0"),
        ("Ataque", "Arco de corte separado del cuerpo.", "P0"),
        ("Impacto", "Hit spark, flash y fragmentos pequeños.", "P0"),
        ("Daño", "Flash blanco y partículas orientadas desde la fuente.", "P0"),
        ("Golpe descendente", "Estela vertical, impacto y fragmentos de suelo.", "P0"),
        ("Checkpoint", "Columna de luz, pulso y partículas ascendentes.", "P1"),
        ("Módulo", "Anillo de instalación y pulso del núcleo.", "P1"),
        ("Electricidad", "Arcos, chispas, segmentos de suelo y residuo breve.", "P0"),
        ("Puerta", "Luz de requisito, desbloqueo y movimiento del panel.", "P1"),
        ("Secreto", "Pulso violeta y efecto de recolección.", "P1"),
        ("Muerte de enemigos", "Chispas, piezas y humo corto.", "P1"),
        ("Transición de sala", "Barrido, oscurecimiento o interferencia breve.", "P2"),
    ],
    [Inches(1.65), Inches(4.45), Inches(0.7)],
)

add_heading(doc, "Contenido futuro por zona", 1)
add_table(
    doc,
    ["Zona", "Identidad visual", "Recursos principales", "Prioridad"],
    [
        ("Storage Archive", "Vertical, frío y ordenado, con datos almacenados físicamente.", "Estanterías, bloques móviles, escáneres, conductos y rutas ocultas.", "P3"),
        ("Network", "Señales, pulsos y conexiones cambiantes.", "Nodos, antenas, teletransportes, proyectiles y suelo rompible.", "P3"),
        ("Security", "Defensa, vigilancia y control de acceso.", "Cámaras, sensores, barreras, alarmas, escudos y puertas reforzadas.", "P3"),
        ("Core", "Centro de coordinación con piezas visuales de todas las zonas.", "Núcleo, conductos principales, plataformas cambiantes y arena final.", "P3"),
    ],
    [Inches(1.2), Inches(2.0), Inches(2.9), Inches(0.7)],
)

add_heading(doc, "Audio que conviene producir junto con los sprites", 1)
add_body(doc, "Aunque el audio no forma parte del paquete gráfico, conviene nombrarlo y organizarlo con los mismos estados para que pueda conectarse a los eventos ya implementados.")
add_bullets(doc, [
    "M-0: pasos, salto, aterrizaje, dash, ataque, impacto, daño, muerte y respawn.",
    "Entorno: electricidad, plataforma móvil, puerta, interruptor, terminal, checkpoint y módulo.",
    "Enemigos: movimiento, alerta, disparo, impacto y destrucción de cada tipo.",
    "VOLT: activación, slam, Grid Surge, Cable Sweep, overload, daño, fase 2 y derrota.",
    "Música y ambiente: Energy, combate normal, arena de VOLT y menú.",
])

add_heading(doc, "Recursos que pueden seguir generándose por código", 1)
add_body(doc, "No es necesario dibujar todo. Los siguientes elementos pueden permanecer procedurales mientras se ajusta la jugabilidad:")
add_bullets(doc, [
    "Hitboxes, hurtboxes, colliders, normales de contacto y rangos de detección del modo debug.",
    "Rectángulos de selección, gráficas de FPS y texto técnico de depuración.",
    "Flash de daño, shake de cámara y variaciones de opacidad.",
    "Telegraphs geométricos simples cuando deban adaptarse dinámicamente al tamaño de la arena.",
    "Partículas menores de prueba que todavía no tengan una dirección artística definitiva.",
])

doc.add_page_break()
add_heading(doc, "Lista de entrega inicial", 1)
add_body(doc, "El siguiente paquete permite comenzar la integración sin esperar a que todo el arte esté terminado.")
add_table(
    doc,
    ["Entrega", "Contenido mínimo", "Prioridad"],
    [
        ("01 Referencias", "Paleta, M-0, Patrol, Watcher, Drone, VOLT y una sala Energy ensamblada.", "P0"),
        ("02 M-0 básico", "Idle, carrera, ascenso, caída, ataque, dash, daño y muerte.", "P0"),
        ("03 Energy básico", "Suelo, pared, unidireccional, plataforma móvil, puerta, checkpoint e interruptor.", "P0"),
        ("04 Enemigos", "Patrol, Watcher, Drone, proyectil y efectos de destrucción.", "P0"),
        ("05 VOLT", "Cuerpo, tres ataques, overload, fase 2 y derrota.", "P0"),
        ("06 UI", "Vida, cuatro módulos, barra de jefe y controles táctiles.", "P0"),
        ("07 Feedback", "Ataque, impacto, daño, dash, electricidad y golpe descendente.", "P1"),
        ("08 Acabado", "Fondos, decoración, variantes dañadas, logo e icono Android.", "P2"),
    ],
    [Inches(1.45), Inches(4.65), Inches(0.7)],
)

add_heading(doc, "Control de calidad antes de enviar un recurso", 1)
add_bullets(doc, [
    "El fondo es transparente y no contiene píxeles semitransparentes accidentales.",
    "Todos los frames usan el mismo tamaño de lienzo y el mismo punto de apoyo.",
    "La silueta se entiende a escala de teléfono y no depende de detalles de un solo píxel.",
    "La animación puede reflejarse horizontalmente sin que textos, números o piezas asimétricas queden incorrectos.",
    "El nombre del archivo identifica categoría, entidad, estado y número de frame.",
    "Se adjunta el archivo editable, la paleta y una previsualización animada cuando corresponda.",
    "El recurso no incluye contenido de otra franquicia ni imita directamente una propiedad reconocible.",
])

add_heading(doc, "Conclusión", 1)
add_body(doc, "La producción debe comenzar por la identidad de M-0 y Energy, porque ambos aparecen durante toda la prueba y determinan la escala de los demás recursos. Patrol, Watcher, Drone y VOLT forman el segundo bloque crítico. Cuando estos elementos funcionen dentro del juego, la interfaz, los efectos y la decoración podrán ajustarse con una referencia visual real y sin rehacer sprites por cambios de escala.")

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
doc.save(OUTPUT)
print(OUTPUT)
