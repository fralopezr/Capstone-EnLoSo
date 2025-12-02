import express from "express";
import nutritionRoutes from "./src/routes/nutrition.routes.js";

const app = express();
app.use(express.json());

// Rutas
app.use("/api", nutritionRoutes);

// Salud
app.get("/health", (_, res) => res.json({ ok: true }));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Nutri API escuchando en :${PORT}`));
