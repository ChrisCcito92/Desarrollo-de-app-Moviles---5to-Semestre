const prisma = require("../prismaClient");
const redis = require("../redisClient");
const { agregarNotificacion } = require("../jobs/notificacionQueue");
require("dotenv").config();

const CACHE_TTL = 60;

async function obtenerPedido(req, res) {
  const { id } = req.params;
  const cacheKey = `pedido:${id}`;

  try {
    const cached = await redis.get(cacheKey);
    if (cached) {
      console.log(`🟢 CACHE HIT — pedido:${id}`);
      return res.status(200).json({ fuente: "cache", data: cached });
    }

    console.log(`🔴 CACHE MISS — consultando MySQL para pedido:${id}`);

    const pedido = await prisma.pedido.findUnique({
      where: { id_pedido: parseInt(id) },
      include: {
        usuario: { select: { nombre: true, correo: true, telefono: true } },
        direccion: true,
        distribuidor: { select: { nombre_comercial: true, telefono_contacto: true } },
        repartidor: { select: { nombre_completo: true, latitud_actual: true, longitud_actual: true } },
        detalles: {
          include: {
            producto: { select: { tipo_bidon: true, precio_unitario: true } },
          },
        },
      },
    });

    if (!pedido) {
      return res.status(404).json({ error: "Pedido no encontrado." });
    }

    if (
      req.usuario.tipo_usuario === "cliente" &&
      pedido.id_usuario !== req.usuario.id_usuario
    ) {
      return res.status(403).json({ error: "No tienes permiso para ver este pedido." });
    }

    await redis.set(cacheKey, pedido, { ex: CACHE_TTL });

    return res.status(200).json({ fuente: "base_de_datos", data: pedido });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Error interno del servidor." });
  }
}

async function crearPedido(req, res) {
  const { id_direccion, id_distribuidor, metodo_pago, detalles, observaciones } = req.body;
  const id_usuario = req.usuario.id_usuario;

  if (!id_direccion || !id_distribuidor || !metodo_pago || !detalles?.length) {
    return res.status(422).json({ error: "Faltan campos obligatorios." });
  }
  if (!["efectivo", "tarjeta"].includes(metodo_pago)) {
    return res.status(422).json({ error: "Método de pago inválido." });
  }

  try {
    const direccion = await prisma.direccion.findFirst({
      where: { id_direccion, id_usuario },
    });
    if (!direccion) {
      return res.status(422).json({ error: "La dirección no pertenece al usuario autenticado." });
    }

    const distribuidor = await prisma.distribuidor.findFirst({
      where: { id_distribuidor, estado: "activo" },
    });
    if (!distribuidor) {
      return res.status(409).json({ error: "El distribuidor no está disponible." });
    }

    for (const item of detalles) {
      if (!item.id_producto || item.cantidad < 1) {
        return res.status(422).json({ error: "Cantidad mínima por producto: 1." });
      }
      const producto = await prisma.producto.findFirst({
        where: { id_producto: item.id_producto, activo: true },
      });
      if (!producto || producto.stock_disponible < item.cantidad) {
        return res.status(409).json({
          error: `Stock insuficiente para el producto ${item.id_producto}.`,
        });
      }
    }

    const resultado = await prisma.$transaction(async (tx) => {
      let total_pagar = 0;
      const detallesData = [];

      for (const item of detalles) {
        const producto = await tx.producto.findUnique({
          where: { id_producto: item.id_producto },
        });
        const subtotal = Number(producto.precio_unitario) * item.cantidad;
        total_pagar += subtotal;
        detallesData.push({
          id_producto: item.id_producto,
          cantidad: item.cantidad,
          precio_unitario_pedido: producto.precio_unitario,
          subtotal,
        });

        await tx.producto.update({
          where: { id_producto: item.id_producto },
          data: { stock_disponible: { decrement: item.cantidad } },
        });
      }

      const pedido = await tx.pedido.create({
        data: {
          id_usuario,
          id_direccion,
          id_distribuidor,
          metodo_pago,
          total_pagar,
          observaciones,
          detalles: { create: detallesData },
        },
        include: { detalles: true },
      });

      return pedido;
    });

    await agregarNotificacion({
      id_pedido: resultado.id_pedido,
      tipo_evento: "confirmado",
      mensaje: `Tu pedido #${resultado.id_pedido} fue confirmado.`,
    });

    return res.status(201).json({ mensaje: "Pedido creado exitosamente.", data: resultado });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Error interno del servidor." });
  }
}

async function actualizarEstado(req, res) {
  const { id } = req.params;
  const { estado_pedido } = req.body;
  const estadosValidos = ["aceptado", "en_camino", "entregado", "cancelado"];

  if (!estadosValidos.includes(estado_pedido)) {
    return res.status(422).json({ error: "Estado no válido." });
  }

  try {
    const pedido = await prisma.pedido.findUnique({
      where: { id_pedido: parseInt(id) },
    });

    if (!pedido) return res.status(404).json({ error: "Pedido no encontrado." });

    if (req.usuario.tipo_usuario === "cliente") {
      return res.status(403).json({ error: "No tienes permiso para cambiar el estado." });
    }

    const actualizado = await prisma.pedido.update({
      where: { id_pedido: parseInt(id) },
      data: {
        estado_pedido,
        fecha_entrega_real: estado_pedido === "entregado" ? new Date() : undefined,
      },
    });

    await redis.del(`pedido:${id}`);
    console.log(`🗑️  Caché invalidado para pedido:${id}`);

    await agregarNotificacion({
      id_pedido: parseInt(id),
      tipo_evento: estado_pedido,
      mensaje: `Tu pedido #${id} ahora está: ${estado_pedido}.`,
    });

    return res.status(200).json({ mensaje: "Estado actualizado.", data: actualizado });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Error interno del servidor." });
  }
}

async function listarPedidosUsuario(req, res) {
  const id_usuario = req.usuario.id_usuario;

  try {
    const pedidos = await prisma.pedido.findMany({
      where: { id_usuario },
      include: {
        detalles: {
          include: {
            producto: { select: { tipo_bidon: true } },
          },
        },
        distribuidor: { select: { nombre_comercial: true } },
      },
      orderBy: { fecha_pedido: "desc" },
    });

    return res.status(200).json({ data: pedidos });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Error interno del servidor." });
  }
}

module.exports = { obtenerPedido, crearPedido, actualizarEstado, listarPedidosUsuario };