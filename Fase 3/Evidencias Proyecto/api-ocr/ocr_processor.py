# ocr_processor.py
from paddleocr import PaddleOCR
import numpy as np, base64, tempfile, os, re
from PIL import Image            # <-- añadido
import io                        # <-- añadido

_OCR = PaddleOCR(use_angle_cls=True, lang='es')

_num_re = re.compile(r"[-+]?\d+(?:[\.,]\d+)?")
_MAX_SIDE = 1600  # <-- límite de lado (ajustable). Mantener < 4000 para evitar el warning de PaddleOCR.

def _to_float(s):
    if s is None: return None
    s = str(s).replace(",", ".").replace("%", "").strip()
    try: return float(s)
    except: return None

def _last_two_numbers(line):
    nums = _num_re.findall(line or "")
    vals = [_to_float(n) for n in nums]
    vals = [v for v in vals if v is not None]
    if len(vals) >= 2: return vals[-2], vals[-1]
    if len(vals) == 1: return vals[0], None
    return None, None

def _compute_scale(valor, from_qty, to_qty):
    try:
        if valor is None or from_qty is None or to_qty is None: return None
        return round(float(valor) * float(to_qty) / float(from_qty), 3)
    except:
        return None

def _normalize_lines(lines):
    fixed = []
    for line in lines:
        s = line
        if s.strip() in ("(g)", "(mg)") and fixed:
            fixed[-1] += " " + s.strip(); continue
        s = (s.replace(" mi)", " ml)")
             .replace("(6)", "(g)")
             .replace("monoinsat.", "monoinsaturada")
             .replace("poliinsat.", "poliinsaturada")
             .replace("H. de C. disponibles", "Carbohidratos disponibles")
             .replace("Azúcares Totales", "Azucares Totales")
             .replace("Proteínas", "Proteinas")
             .replace("Grasa Total", "Grasa total")
             .replace("Fósforo", "Fosforo")
             .replace(" 06 ", " 90 "))
        fixed.append(s)
    return fixed

_MAP = [
    ("energia_kcal", ["energía (kcal)", "energia (kcal)", "energia"]),
    ("proteinas_g", ["proteinas (g)", "proteinas"]),
    ("grasa_total_g", ["grasa total (g)", "grasa total"]),
    ("grasa_saturada_g", ["grasa saturada (g)", "grasa saturada"]),
    ("grasa_monoinsaturada_g", ["grasa monoinsaturada (g)", "monoinsaturada (g)", "monoinsaturada"]),
    ("grasa_poliinsaturada_g", ["grasa poliinsaturada (g)", "poliinsaturada (g)", "poliinsaturada"]),
    ("grasa_trans_g", ["grasa trans (g)", " trans (g)"]),
    ("colesterol_mg", ["colesterol (mg)", "colesterol"]),
    ("carbohidratos_disponibles_g", ["carbohidratos disponibles (g)", "carbohidratos disponibles"]),
    ("azucares_totales_g", ["azucares totales (g)", "azúcares totales (g)", "azucares totales"]),
    ("sodio_mg", ["sodio (mg)", "sodio"]),
    ("calcio_mg", ["calcio (mg)", "calcio"]),
    ("fosforo_mg", ["fosforo (mg)", "fósforo (mg)", "fosforo"]),
]

def _match_key(line_lower):
    for key, aliases in _MAP:
        for a in aliases:
            if a in line_lower:
                return key
    return None

# -------------------------
# NUEVO: preprocesado/resize
# -------------------------
def _bytes_from_b64_resized(image_b64: str) -> bytes:
    """
    Decodifica base64, reescala si el lado mayor excede _MAX_SIDE y re-encodea a JPEG (quality=80).
    Retorna bytes JPEG listos para escribir a archivo temporal para PaddleOCR.
    """
    raw = base64.b64decode(image_b64)
    img = Image.open(io.BytesIO(raw)).convert("RGB")
    w, h = img.size
    if max(w, h) > _MAX_SIDE:
        if w >= h:
            nw, nh = _MAX_SIDE, int(h * (_MAX_SIDE / w))
        else:
            nh, nw = _MAX_SIDE, int(w * (_MAX_SIDE / h))
        img = img.resize((nw, nh), Image.LANCZOS)
    out = io.BytesIO()
    img.save(out, format="JPEG", quality=80, optimize=True)
    return out.getvalue()

def _predict_from_b64(image_b64: str):
    try:
        # antes escribías RAW → ahora escribimos bytes reescalados/optim
        jpg_bytes = _bytes_from_b64_resized(image_b64)
        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp:
            tmp.write(jpg_bytes); img_path = tmp.name
        o = _OCR.predict(img_path)[0]
        os.unlink(img_path)
        return o.get('rec_texts', []), o.get('rec_scores', []), o.get('rec_boxes', [])
    except:
        return [], [], []

def _group_lines(texts, scores, boxes, score_min=0.6, tol=15):
    tokens = []
    for t, s, b in zip(texts, scores, boxes):
        try:
            if s and s >= score_min:
                box = np.array(b).reshape(-1, 2)
                x0, y0 = box.min(axis=0)
                x1, y1 = box.max(axis=0)
                cy = (y0 + y1) / 2
                tokens.append((t.strip(), float(x0), float(cy)))
        except: continue
    tokens.sort(key=lambda r: (r[2], r[1]))

    lines, current, last_cy = [], [], None
    for t, x, cy in tokens:
        if last_cy is None or abs(cy - last_cy) <= tol:
            current.append((x, t))
        else:
            lines.append(" ".join([tok for _, tok in sorted(current)]))
            current = [(x, t)]
        last_cy = cy
    if current:
        lines.append(" ".join([tok for _, tok in sorted(current)]))
    return _normalize_lines(lines)

def _detectar_porcion_y_unidad(lines):
    porcion, unidad = None, None
    for l in lines:
        ll = l.lower()
        if "(" in ll and ")" in ll:
            if "ml" in ll: unidad = "ml"
            elif re.search(r"\bg\b", ll): unidad = "g"
            a, b = _last_two_numbers(ll)
            cand = a or b
            if cand: porcion = cand; break
    return porcion, unidad

def _extraer_nutrientes(lines, porcion, unidad, base_qty=100.0):
    """
    Devuelve {clave: {por_base, por_porcion}}
    - por_base: 1ra columna (se asume 'por 100 unidad'); si falta, se back-calcula desde porción.
    - por_porcion: 2da columna; si falta, se calcula desde por_base usando 'porcion'.
    """
    nutrientes = {}
    for l in lines:
        ll = l.lower()
        key = _match_key(ll)
        if not key:
            if "(g)" in ll and ("0,13" in ll or "0.13" in ll):
                v100, vpor = _last_two_numbers(l)
                por_base = v100
                por_porcion = vpor if vpor is not None else _compute_scale(v100, base_qty, porcion)
                nutrientes["grasa_trans_g"] = {
                    "por_base": None if v100 is None else round(v100, 3),
                    "por_porcion": por_porcion
                }
            continue

        v_col1, v_col2 = _last_two_numbers(l)  # col1≈por 100 unidad, col2≈porción
        por_base = v_col1
        por_porcion = v_col2

        if por_porcion is None and por_base is not None and porcion is not None:
            por_porcion = _compute_scale(por_base, base_qty, porcion)
        if por_base is None and por_porcion is not None and porcion is not None:
            por_base = _compute_scale(por_porcion, porcion, base_qty)

        def rnd(x): return None if x is None else round(x, 3)
        nutrientes[key] = {
            "por_base": rnd(por_base),
            "por_porcion": rnd(por_porcion)
        }
    return nutrientes

def procesar_imagen_base64(image_b64: str, nombre: str, marca: str, categoria: str):
    try:
        texts, scores, boxes = _predict_from_b64(image_b64)
        lines = _group_lines(texts, scores, boxes)
        porcion, unidad = _detectar_porcion_y_unidad(lines)

        if unidad is None: unidad = "ml"      # fallback seguro PoC
        if porcion is None: porcion = 100.0   # fallback PoC
        base_qty = 100.0                      # asumimos primera columna "por 100"

        nutrientes = _extraer_nutrientes(lines, porcion, unidad, base_qty=base_qty)

        return {
            "nombre": nombre,
            "marca": marca,
            "categoria": categoria,
            "unidad_base": unidad,   # 'ml' o 'g'
            "base_qty": base_qty,    # típicamente 100
            "porcion": porcion,      # porción detectada
            "nutrientes": nutrientes # { por_base, por_porcion }
        }
    except:
        return {
            "nombre": nombre,
            "marca": marca,
            "categoria": categoria,
            "unidad_base": None,
            "base_qty": 100.0,
            "porcion": None,
            "nutrientes": {}
        }
