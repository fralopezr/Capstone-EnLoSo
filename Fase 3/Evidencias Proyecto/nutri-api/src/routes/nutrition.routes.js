import { Router } from "express";
import { postNutriscoreOff, postSellosCl, postAnalyze } from "../controllers/nutrition.controller.js";

const router = Router();

router.post("/nutriscore-off", postNutriscoreOff);
router.post("/sellos-cl", postSellosCl);
router.post("/analyze", postAnalyze);

export default router;
