# app.py
from flask import Flask, request, jsonify
from ocr_processor import procesar_imagen_base64

app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 8 * 1024 * 1024  # 8 MB (opcional, por tamaño de imágenes)

@app.route("/health", methods=["GET"])
def health():
    return "ok", 200

@app.route("/analyze", methods=["POST"])
def analyze():
    """
    Request JSON:
    {
      "image_b64": "<base64>",   # obligatorio
      "nombre": "str",           # opcional
      "marca": "str",            # opcional
      "categoria": "str"         # opcional
    }
    Respuesta: valores por_base (p. ej. por 100 ml/g) y por_porcion (porción del envase).
    """
    try:
        payload = request.get_json(force=True, silent=True) or {}
        image_b64 = payload.get("image_b64")
        if not image_b64:
            return jsonify({"error": "Falta 'image_b64'"}), 400

        out = procesar_imagen_base64(
            image_b64=image_b64,
            nombre=payload.get("nombre"),
            marca=payload.get("marca"),
            categoria=payload.get("categoria"),
        )
        return jsonify(out), 200
    except Exception:
        return jsonify({
            "nombre": None,
            "marca": None,
            "categoria": None,
            "unidad_base": None,
            "base_qty": 100.0,
            "porcion": None,
            "nutrientes": {}
        }), 200

if __name__ == "__main__":
    #HOST = "10.99.147.6"  # IP de tu PC en el hotspot (Wi-Fi)
    #HOST = "192.168.100.3"
    HOST = "192.168.1.82"
    PORT = 8000
    print(f"API escuchando en: http://{HOST}:{PORT}/analyze  |  Salud: http://{HOST}:{PORT}/health")
    app.run(host=HOST, port=PORT, debug=False)
