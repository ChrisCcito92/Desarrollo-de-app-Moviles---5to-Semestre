require("dotenv").config();
const express = require("express");
const app = express();

// Middleware para leer JSON
app.use(express.json());

// Rutas
app.use("/api/auth", require("./src/routes/authRoutes"));
app.use("/api/pedidos", require("./src/routes/pedidoRoutes"));

// Ruta de prueba
app.get("/", (req, res) => {
  res.json({ mensaje: "🚀 AquaFast API corriendo correctamente." });
});

// Iniciar servidor
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`✅ Servidor corriendo en http://localhost:${PORT}`);
});