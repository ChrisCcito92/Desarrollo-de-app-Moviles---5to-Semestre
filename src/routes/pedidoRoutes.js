const express = require("express");
const router = express.Router();
const { verificarToken, autorizar } = require("../middlewares/auth");
const {
  obtenerPedido,
  crearPedido,
  actualizarEstado,
  listarPedidosUsuario,
} = require("../controllers/pedidoController");

// Todos los endpoints de pedidos requieren token
router.get("/mis-pedidos", verificarToken, autorizar("cliente"), listarPedidosUsuario);
router.get("/:id", verificarToken, obtenerPedido);
router.post("/", verificarToken, autorizar("cliente"), crearPedido);
router.patch("/:id/estado", verificarToken, autorizar("distribuidor", "repartidor"), actualizarEstado);

module.exports = router;