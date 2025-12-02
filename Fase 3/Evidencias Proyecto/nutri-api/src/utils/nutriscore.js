// --- Helpers seguros ---
const getBase = (nutrientes = {}, key) => {
  try {
    const v = nutrientes[key] ?? {};
    // Permitimos payload simple: nutrientes.key = número
    if (typeof v === "number") return Number(v) || 0;
    return Number(v?.por_base ?? 0) || 0;
  } catch {
    return 0;
  }
};

const kcalToKJ = (kcal) => kcal * 4.184;

// thresholds ascendentes; devuelve 0..len
const pointsFromThresholds = (value, thresholds) => {
  for (let i = 0; i < thresholds.length; i++) {
    if (value <= thresholds[i]) return i;
  }
  return thresholds.length;
};

// --- Umbrales OFF (alimento general) ---
// Negativos 0..10
const OFF_NEG_ENERGY_KJ = [335, 670, 1005, 1340, 1675, 2010, 2345, 2680, 3015, 3350];
const OFF_NEG_SUGARS_G  = [4.5, 9, 13.5, 18, 22.5, 27, 31, 36, 40, 45];
const OFF_NEG_SATFAT_G  = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
const OFF_NEG_SODIUM_MG = [90, 180, 270, 360, 450, 540, 630, 720, 810, 900];

// Positivos 0..5
const fvnlPoints = (pct = 0) => (pct >= 80 ? 5 : pct >= 60 ? 2 : pct >= 40 ? 1 : 0);
const OFF_POS_FIBER_G   = [0.9, 1.9, 2.8, 3.7, 4.7];
const OFF_POS_PROTEIN_G = [1.6, 3.2, 4.8, 6.4, 8.0];

// Nutri-Score OFF clásico (alimentos “generales”)
export function nutriscoreOffFood({ nutrientes = {}, fvnl_pct = 0, es_queso = false }) {
  const energia_kcal = getBase(nutrientes, "energia_kcal");
  const sugars_g = getBase(nutrientes, "azucares_g") || getBase(nutrientes, "azucar_g") || getBase(nutrientes, "azucares_totales_g");
  const satfat_g = getBase(nutrientes, "grasa_saturada_g") || getBase(nutrientes, "grasas_saturadas_g");
  const sodium_mg = getBase(nutrientes, "sodio_mg");
  const fiber_g = getBase(nutrientes, "fibra_g");
  const protein_g = getBase(nutrientes, "proteinas_g") || getBase(nutrientes, "proteina_g");

  const energy_kj = kcalToKJ(energia_kcal);

  const neg_energy = pointsFromThresholds(energy_kj, OFF_NEG_ENERGY_KJ);
  const neg_sugar  = pointsFromThresholds(sugars_g, OFF_NEG_SUGARS_G);
  const neg_sat    = pointsFromThresholds(satfat_g, OFF_NEG_SATFAT_G);
  const neg_sod    = pointsFromThresholds(sodium_mg, OFF_NEG_SODIUM_MG);
  const negatives  = neg_energy + neg_sugar + neg_sat + neg_sod;

  const pos_fvnl  = fvnlPoints(fvnl_pct || 0);
  const pos_fiber = pointsFromThresholds(fiber_g, OFF_POS_FIBER_G);
  const pos_prot  = pointsFromThresholds(protein_g, OFF_POS_PROTEIN_G);

  const positives = (negatives < 11 || es_queso)
    ? (pos_fvnl + pos_fiber + pos_prot)
    : (pos_fvnl + pos_fiber);

  const final_score = negatives - positives;

  let letter = "E";
  if (final_score <= -1) letter = "A";
  else if (final_score <= 2) letter = "B";
  else if (final_score <= 10) letter = "C";
  else if (final_score <= 18) letter = "D";

  return {
    inputs_100: {
      energy_kj: Number(energy_kj.toFixed(2)),
      sugars_g, sat_fat_g: satfat_g, sodium_mg, fiber_g, protein_g, fvnl_pct: fvnl_pct || 0
    },
    neg_points: { energy: neg_energy, sugars: neg_sugar, sat_fat: neg_sat, sodium: neg_sod, total: negatives },
    pos_points: { fvnl: pos_fvnl, fiber: pos_fiber, protein: pos_prot, total: positives },
    final_score,
    letter,
    algo: "off_food_classic_v1"
  };
}

// --- Sellos Chile (por 100 g/ml) ---
const CHILE_SOLIDS = {
  energia_kcal: 275.0,
  azucares_g: 10.0,
  grasa_saturada_g: 4.0,
  sodio_mg: 400.0
};
const CHILE_LIQUIDS = {
  energia_kcal: 70.0,
  azucares_g: 5.0,
  grasa_saturada_g: 3.0,
  sodio_mg: 100.0
};

export function sellosChile({ nutrientes = {}, unidad_base = "" }) {
  const unit = String(unidad_base || "").toLowerCase();
  const isLiquid = unit.includes("ml") || unit === "l" || unit.includes("litro");
  const limits = isLiquid ? CHILE_LIQUIDS : CHILE_SOLIDS;

  const energia_kcal = getBase(nutrientes, "energia_kcal");
  const azucares_g = getBase(nutrientes, "azucares_g") || getBase(nutrientes, "azucar_g") || getBase(nutrientes, "azucares_totales_g");
  const sat_g = getBase(nutrientes, "grasa_saturada_g") || getBase(nutrientes, "grasas_saturadas_g");
  const sodio_mg = getBase(nutrientes, "sodio_mg");

  const sellos = [];
  if (energia_kcal >= limits.energia_kcal) sellos.push("ALTO EN CALORÍAS");
  if (azucares_g >= limits.azucares_g)    sellos.push("ALTO EN AZÚCARES");
  if (sat_g >= limits.grasa_saturada_g)   sellos.push("ALTO EN GRASAS SATURADAS");
  if (sodio_mg >= limits.sodio_mg)        sellos.push("ALTO EN SODIO");

  return {
    unidad_base: unit || null,
    categoria_liquido: isLiquid,
    valores_100: { energia_kcal, azucares_g, grasa_saturada_g: sat_g, sodio_mg },
    sellos,
    cumple_sin_sellos: sellos.length === 0
  };
}
