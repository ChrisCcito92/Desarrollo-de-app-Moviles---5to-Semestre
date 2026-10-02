const express = require("express");
const router = express.Router();
const { verificarToken, autorizar } = require("../middlewares/auth");
const prisma = require("../prismaClient");
const {
  listarMisProductos,
  crearProducto,
  actualizarProducto,
  eliminarProducto,
} = require("../controllers/productoController");

// ─── Inventario del distribuidor autenticado ─────────────────────────────
// GET    /api/distribuidores/mis-productos              — consultar productos y stock
// POST   /api/distribuidores/mis-productos              — agregar producto
// PATCH  /api/distribuidores/mis-productos/:idProducto  — editar, reponer stock, activar/desactivar
// DELETE /api/distribuidores/mis-productos/:idProducto  — eliminar (o desactivar si tiene pedidos)
router.get("/mis-productos", verificarToken, autorizar("distribuidor"), listarMisProductos);
router.post("/mis-productos", verificarToken, autorizar("distribuidor"), crearProducto);
router.patch("/mis-productos/:idProducto", verificarToken, autorizar("distribuidor"), actualizarProducto);
router.delete("/mis-productos/:idProducto", verificarToken, autorizar("distribuidor"), eliminarProducto);

// GET /api/distribuidores — lista distribuidores activos
router.get("/", verificarToken, async (req, res) => {
  try {
    const distribuidores = await prisma.distribuidor.findMany({
      where: { estado: "activo" },
      select: {
        id_distribuidor: true,
        nombre_comercial: true,
        telefono_contacto: true,
        latitud_base: true,
        longitud_base: true,
        radio_cobertura_km: true,
        calificacion_promedio: true,
      },
      orderBy: { calificacion_promedio: "desc" },
    });
    return res.status(200).json({ data: distribuidores });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Error interno del servidor." });
  }
});

// GET /api/distribuidores/:id/productos — productos activos con stock (vista del cliente)
router.get("/:id/productos", verificarToken, async (req, res) => {
  const { id } = req.params;
  try {
    const productos = await prisma.producto.findMany({
      where: {
        id_distribuidor: parseInt(id),
        activo: true,
        stock_disponible: { gt: 0 },
      },
      select: {
        id_producto: true,
        tipo_bidon: true,
        precio_unitario: true,
        stock_disponible: true,
      },
    });
    if (!productos.length) {
      return res.status(404).json({ error: "No hay productos disponibles para este distribuidor." });
    }
    return res.status(200).json({ data: productos });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Error interno del servidor." });
  }
});

module.exports = router;