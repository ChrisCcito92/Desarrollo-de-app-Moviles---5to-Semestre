const prisma = require("../prismaClient");
const redis = require("../redisClient");
const { agregarNotificacion } = require("../jobs/notificacionQueue");
require("dotenv").config();

const CACHE_TTL = 60;

const ESTADOS_VALIDOS = ["pendiente", "aceptado", "en_camino", "entregado", "cancelado"];

// Flujo permitido de estados: un pedido solo puede avanzar en este orden
const TRANSICIONES = {
  pendiente: ["aceptado", "cancelado"],
  aceptado: ["en_camino", "cancelado"],
  en_camino: ["entregado"],
  entregado: [],
  cancelado: [],
};

// Lee ?pagina= y ?limite= con valores seguros por defecto
function leerPaginacion(query, limitePorDefecto = 10) {
  const pagina = Math.max(parseInt(query.pagina) || 1, 1);
  const limite = Math.min(Math.max(parseInt(query.limite) || limitePorDefecto, 1), 50);
  return { pagina, limite, skip: (pagina - 1) * limite };
}

async function obtenerPedido(req, res) {
  const { id } = req.params;
  const cacheKey = `pedido:${id}`;

  try {
    let cached = null;
    try {
      cached = await redis.get(cacheKey);
    } catch (cacheError) {
      console.warn("⚠️ Redis no disponible (get):", cacheError.cause?.code || cacheError.message);
    }

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

    try {
      await redis.set(cacheKey, pedido, { ex: CACHE_TTL });
    } catch (cacheError) {
      console.warn("⚠️ Redis no disponible (set):", cacheError.cause?.code || cacheError.message);
    }

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

    try {
      await agregarNotificacion({
        id_pedido: resultado.id_pedido,
        tipo_evento: "confirmado",
        mensaje: `Tu pedido #${resultado.id_pedido} fue confirmado.`,
      });
    } catch (notifError) {
      console.warn("⚠️ Notificación no encolada:", notifError.cause?.code || notifError.message);
    }

    return res.status(201).json({ mensaje: "Pedido creado exitosamente.", data: resultado });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Error interno del servidor." });
  }
}

async function actualizarEstado(req, res) {
  const { id } = req.params;
  const { estado_pedido } = req.body;
  const rol = req.usuario.tipo_usuario;

  if (!ESTADOS_VALIDOS.includes(estado_pedido) || estado_pedido === "pendiente") {
    return res.status(422).json({ error: "Estado no válido." });
  }

  try {
    const pedido = await prisma.pedido.findUnique({
      where: { id_pedido: parseInt(id) },
      include: { detalles: true },
    });

    if (!pedido) return res.status(404).json({ error: "Pedido no encontrado." });

    // Autorización según el rol
    if (rol === "cliente") {
      if (pedido.id_usuario !== req.usuario.id_usuario) {
        return res.status(403).json({ error: "No tienes permiso para modificar este pedido." });
      }
      if (estado_pedido !== "cancelado") {
        return res.status(403).json({ error: "Como cliente solo puedes cancelar tus pedidos." });
      }
      if (pedido.estado_pedido !== "pendiente") {
        return res.status(409).json({ error: "Solo puedes cancelar un pedido que aún está pendiente." });
      }
    } else if (rol === "distribuidor") {
      const distribuidor = await prisma.distribuidor.findUnique({
        where: { id_usuario: req.usuario.id_usuario },
      });
      if (!distribuidor || distribuidor.id_distribuidor !== pedido.id_distribuidor) {
        return res.status(403).json({ error: "Este pedido no pertenece a tu distribuidora." });
      }
    } else {
      return res.status(403).json({ error: "No tienes permiso para cambiar el estado." });
    }

    // Regla de negocio: validar que el cambio de estado siga el flujo correcto
    if (!TRANSICIONES[pedido.estado_pedido].includes(estado_pedido)) {
      return res.status(409).json({
        error: `No se puede pasar de "${pedido.estado_pedido}" a "${estado_pedido}".`,
      });
    }

    const actualizado = await prisma.$transaction(async (tx) => {
      // Si se cancela, se devuelve el stock reservado
      if (estado_pedido === "cancelado") {
        for (const detalle of pedido.detalles) {
          await tx.producto.update({
            where: { id_producto: detalle.id_producto },
            data: { stock_disponible: { increment: detalle.cantidad } },
          });
        }
      }

      return tx.pedido.update({
        where: { id_pedido: parseInt(id) },
        data: {
          estado_pedido,
          fecha_entrega_real: estado_pedido === "entregado" ? new Date() : undefined,
        },
      });
    });

    try {
      await redis.del(`pedido:${id}`);
      console.log(`🗑️  Caché invalidado para pedido:${id}`);
    } catch (cacheError) {
      console.warn("⚠️ Redis no disponible (del):", cacheError.cause?.code || cacheError.message);
    }

    try {
      await agregarNotificacion({
        id_pedido: parseInt(id),
        tipo_evento: estado_pedido,
        mensaje: `Tu pedido #${id} ahora está: ${estado_pedido}.`,
      });
    } catch (notifError) {
      console.warn("⚠️ Notificación no encolada:", notifError.cause?.code || notifError.message);
    }

    return res.status(200).json({ mensaje: "Estado actualizado.", data: actualizado });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Error interno del servidor." });
  }
}

async function listarPedidosUsuario(req, res) {
  const id_usuario = req.usuario.id_usuario;
  const { pagina, limite, skip } = leerPaginacion(req.query, 20);

  try {
    const where = { id_usuario };

    const [pedidos, total] = await prisma.$transaction([
      prisma.pedido.findMany({
        where,
        include: {
          detalles: {
            include: {
              producto: { select: { tipo_bidon: true } },
            },
          },
          distribuidor: { select: { nombre_comercial: true } },
        },
        orderBy: { fecha_pedido: "desc" },
        skip,
        take: limite,
      }),
      prisma.pedido.count({ where }),
    ]);

    return res.status(200).json({
      data: pedidos,
      paginacion: { pagina, limite, total, total_paginas: Math.ceil(total / limite) },
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Error interno del servidor." });
  }
}

async function listarPedidosDistribuidor(req, res) {
  const { pagina, limite, skip } = leerPaginacion(req.query, 10);
  const { estado } = req.query;

  if (estado && !ESTADOS_VALIDOS.includes(estado)) {
    return res.status(422).json({ error: "Filtro de estado no válido." });
  }

  try {
    const distribuidor = await prisma.distribuidor.findUnique({
      where: { id_usuario: req.usuario.id_usuario },
    });

    if (!distribuidor) {
      return res.status(403).json({ error: "Tu cuenta no está vinculada a ninguna distribuidora." });
    }

    const where = { id_distribuidor: distribuidor.id_distribuidor };
    if (estado) where.estado_pedido = estado;

    const [pedidos, total] = await prisma.$transaction([
      prisma.pedido.findMany({
        where,
        include: {
          usuario: { select: { nombre: true, telefono: true } },
          direccion: {
            select: { alias: true, calle_referencia: true, latitud: true, longitud: true },
          },
          detalles: {
            include: {
              producto: { select: { tipo_bidon: true } },
            },
          },
        },
        orderBy: { fecha_pedido: "desc" },
        skip,
        take: limite,
      }),
      prisma.pedido.count({ where }),
    ]);

    return res.status(200).json({
      distribuidor: distribuidor.nombre_comercial,
      data: pedidos,
      paginacion: { pagina, limite, total, total_paginas: Math.ceil(total / limite) },
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Error interno del servidor." });
  }
}

async function calificarPedido(req, res) {
  const { id } = req.params;
  const calificacion = parseInt(req.body.calificacion);

  if (!Number.isInteger(calificacion) || calificacion < 1 || calificacion > 5) {
    return res.status(422).json({ error: "La calificación debe ser un número entre 1 y 5." });
  }

  try {
    const pedido = await prisma.pedido.findUnique({
      where: { id_pedido: parseInt(id) },
    });

    if (!pedido) return res.status(404).json({ error: "Pedido no encontrado." });

    if (pedido.id_usuario !== req.usuario.id_usuario) {
      return res.status(403).json({ error: "No tienes permiso para calificar este pedido." });
    }
    if (pedido.estado_pedido !== "entregado") {
      return res.status(409).json({ error: "Solo puedes calificar pedidos entregados." });
    }
    if (pedido.calificacion_pedido !== null) {
      return res.status(409).json({ error: "Este pedido ya fue calificado." });
    }

    const actualizado = await prisma.$transaction(async (tx) => {
      const pedidoCalificado = await tx.pedido.update({
        where: { id_pedido: parseInt(id) },
        data: { calificacion_pedido: calificacion },
      });

      // Se recalcula el promedio del distribuidor con todas sus calificaciones
      const { _avg } = await tx.pedido.aggregate({
        where: {
          id_distribuidor: pedido.id_distribuidor,
          calificacion_pedido: { not: null },
        },
        _avg: { calificacion_pedido: true },
      });

      await tx.distribuidor.update({
        where: { id_distribuidor: pedido.id_distribuidor },
        data: {
          calificacion_promedio: Number((_avg.calificacion_pedido ?? 0).toFixed(2)),
        },
      });

      return pedidoCalificado;
    });

    try {
      await redis.del(`pedido:${id}`);
      console.log(`🗑️  Caché invalidado para pedido:${id}`);
    } catch (cacheError) {
      console.warn("⚠️ Redis no disponible (del):", cacheError.cause?.code || cacheError.message);
    }

    return res.status(200).json({ mensaje: "¡Gracias por tu calificación!", data: actualizado });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Error interno del servidor." });
  }
}

module.exports = {
  obtenerPedido,
  crearPedido,
  actualizarEstado,
  listarPedidosUsuario,
  listarPedidosDistribuidor,
  calificarPedido,
};