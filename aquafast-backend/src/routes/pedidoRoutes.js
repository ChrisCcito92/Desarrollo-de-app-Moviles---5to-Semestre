const express = require("express");
const router = express.Router();
const { verificarToken, autorizar } = require("../middlewares/auth");
const {
  obtenerPedido,
  crearPedido,
  actualizarEstado,
  listarPedidosUsuario,
  listarPedidosDistribuidor,
  calificarPedido,
} = require("../controllers/pedidoController");

// Todos los endpoints de pedidos requieren token.
// Las rutas fijas van antes de "/:id" para que Express no las confunda con un id.

// GET /api/pedidos/mis-pedidos?pagina=1&limite=20 — historial del cliente
router.get("/mis-pedidos", verificarToken, autorizar("cliente"), listarPedidosUsuario);

// GET /api/pedidos/distribuidor?estado=pendiente&pagina=1&limite=10 — panel del distribuidor
router.get("/distribuidor", verificarToken, autorizar("distribuidor"), listarPedidosDistribuidor);

// GET /api/pedidos/:id — detalle (con caché Redis)
router.get("/:id", verificarToken, obtenerPedido);

// POST /api/pedidos — crear pedido
router.post("/", verificarToken, autorizar("cliente"), crearPedido);

// PATCH /api/pedidos/:id/estado — distribuidor avanza el estado / cliente cancela
router.patch("/:id/estado", verificarToken, autorizar("distribuidor", "cliente"), actualizarEstado);

// PATCH /api/pedidos/:id/calificacion — cliente califica un pedido entregado (1 a 5)
router.patch("/:id/calificacion", verificarToken, autorizar("cliente"), calificarPedido);

module.exports = router;