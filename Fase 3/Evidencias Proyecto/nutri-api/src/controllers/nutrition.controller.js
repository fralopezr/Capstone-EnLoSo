import { nutriscoreOffFood, sellosChile } from "../utils/nutriscore.js";

// Nota: tratamos faltantes en utils, acá solo encauzamos el payload.

export const postNutriscoreOff = (req, res) => {
  try {
    const { nutrientes, fvnl_pct = 0, es_queso = false } = req.body || {};
    const result = nutriscoreOffFood({ nutrientes, fvnl_pct, es_queso });
    res.json({ nutriscore: result });
  } catch (e) {
    // Respuesta consistente pero sin romper (preferencia: errores silenciosos)
    res.status(200).json({ nutriscore: { error: true, message: "No se pudo calcular", detail: String(e) } });
  }
};

export const postSellosCl = (req, res) => {
  try {
    const result = sellosChile(req.body || {});
    res.json({ sellos_chile: result });
  } catch (e) {
    res.status(200).json({ sellos_chile: { error: true, message: "No se pudo evaluar sellos", detail: String(e) } });
  }
};

export const postAnalyze = (req, res) => {
  try {
    const ns = nutriscoreOffFood({
      nutrientes: req.body?.nutrientes,
      fvnl_pct: req.body?.fvnl_pct || 0,
      es_queso: !!req.body?.es_queso
    });
    const sc = sellosChile(req.body || {});
    res.json({ nutriscore_off: ns, sellos_chile: sc });
  } catch (e) {
    res.status(200).json({ error: true, message: "No se pudo analizar", detail: String(e) });
  }
};
