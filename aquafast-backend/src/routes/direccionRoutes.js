const express = require("express");
const router = express.Router();
const { verificarToken } = require("../middlewares/auth");
const prisma = require("../prismaClient");

// GET /api/direcciones — listar direcciones del usuario autenticado
router.get("/", verificarToken, async (req, res) => {
  try {
    const direcciones = await prisma.direccion.findMany({
      where: { id_usuario: req.usuario.id_usuario },
      orderBy: [{ predeterminada: "desc" }, { id_direccion: "asc" }],
    });
    return res.status(200).json({ data: direcciones });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Error interno del servidor." });
  }
});

// POST /api/direcciones — crear nueva dirección
router.post("/", verificarToken, async (req, res) => {
  const { alias, calle_referencia, latitud, longitud, predeterminada } = req.body;

  // Se compara con null para no rechazar coordenadas cercanas a 0 (Quito está casi sobre la línea equinoccial)
  if (!alias || !calle_referencia || latitud == null || longitud == null) {
    return res.status(422).json({ error: "Todos los campos son obligatorios." });
  }

  try {
    const direccion = await prisma.$transaction(async (tx) => {
      // Si es la primera dirección del usuario, se marca como predeterminada automáticamente
      const cantidad = await tx.direccion.count({
        where: { id_usuario: req.usuario.id_usuario },
      });
      const esPredeterminada = Boolean(predeterminada) || cantidad === 0;

      // Solo puede haber una predeterminada por usuario
      if (esPredeterminada) {
        await tx.direccion.updateMany({
          where: { id_usuario: req.usuario.id_usuario },
          data: { predeterminada: false },
        });
      }

      return tx.direccion.create({
        data: {
          id_usuario: req.usuario.id_usuario,
          alias,
          calle_referencia,
          latitud,
          longitud,
          predeterminada: esPredeterminada,
        },
      });
    });

    return res.status(201).json({ mensaje: "Dirección creada.", data: direccion });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Error interno del servidor." });
  }
});

// DELETE /api/direcciones/:id — eliminar dirección
router.delete("/:id", verificarToken, async (req, res) => {
  const idDireccion = parseInt(req.params.id);

  try {
    const direccion = await prisma.direccion.findFirst({
      where: { id_direccion: idDireccion, id_usuario: req.usuario.id_usuario },
    });
    if (!direccion) {
      return res.status(404).json({ error: "Dirección no encontrada." });
    }

    // La clave foránea de Pedido impide borrar direcciones con historial
    const pedidosAsociados = await prisma.pedido.count({
      where: { id_direccion: idDireccion },
    });
    if (pedidosAsociados > 0) {
      return res.status(409).json({
        error: "No puedes eliminar esta dirección porque tiene pedidos registrados.",
      });
    }

    await prisma.$transaction(async (tx) => {
      await tx.direccion.delete({ where: { id_direccion: idDireccion } });

      // Si se borró la predeterminada, la siguiente dirección toma su lugar
      if (direccion.predeterminada) {
        const siguiente = await tx.direccion.findFirst({
          where: { id_usuario: req.usuario.id_usuario },
          orderBy: { id_direccion: "asc" },
        });
        if (siguiente) {
          await tx.direccion.update({
            where: { id_direccion: siguiente.id_direccion },
            data: { predeterminada: true },
          });
        }
      }
    });

    return res.status(200).json({ mensaje: "Dirección eliminada." });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Error interno del servidor." });
  }
});

module.exports = router;