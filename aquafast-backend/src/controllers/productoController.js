const prisma = require("../prismaClient");

// Por debajo de esta cantidad, el producto se marca como "stock bajo"
const UMBRAL_STOCK_BAJO = 10;

async function obtenerDistribuidorDelUsuario(id_usuario) {
  return prisma.distribuidor.findUnique({ where: { id_usuario } });
}

function validarTipo(tipo_bidon) {
  const tipo = (tipo_bidon ?? "").toString().trim();
  if (tipo.length < 3 || tipo.length > 40) {
    return { error: "El nombre del producto debe tener entre 3 y 40 caracteres." };
  }
  return { valor: tipo };
}

function validarPrecio(precio_unitario) {
  const precio = Number(precio_unitario);
  if (!Number.isFinite(precio) || precio <= 0 || precio > 100) {
    return { error: "El precio debe ser mayor a 0 y máximo $100." };
  }
  return { valor: Number(precio.toFixed(2)) };
}

function validarStock(stock_disponible) {
  const stock = Number(stock_disponible);
  if (!Number.isInteger(stock) || stock < 0 || stock > 100000) {
    return { error: "El stock debe ser un número entero entre 0 y 100000." };
  }
  return { valor: stock };
}

// GET /api/distribuidores/mis-productos
async function listarMisProductos(req, res) {
  try {
    const distribuidor = await obtenerDistribuidorDelUsuario(req.usuario.id_usuario);
    if (!distribuidor) {
      return res.status(403).json({ error: "Tu cuenta no está vinculada a ninguna distribuidora." });
    }

    const productos = await prisma.producto.findMany({
      where: { id_distribuidor: distribuidor.id_distribuidor },
      include: { _count: { select: { detalles: true } } },
      orderBy: [{ activo: "desc" }, { tipo_bidon: "asc" }],
    });

    const activos = productos.filter((p) => p.activo);
    const resumen = {
      total_productos: productos.length,
      productos_activos: activos.length,
      stock_total: activos.reduce((suma, p) => suma + p.stock_disponible, 0),
      productos_stock_bajo: activos.filter((p) => p.stock_disponible < UMBRAL_STOCK_BAJO).length,
      umbral_stock_bajo: UMBRAL_STOCK_BAJO,
    };

    return res.status(200).json({
      distribuidor: distribuidor.nombre_comercial,
      resumen,
      data: productos,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Error interno del servidor." });
  }
}

// POST /api/distribuidores/mis-productos
async function crearProducto(req, res) {
  const tipo = validarTipo(req.body.tipo_bidon);
  if (tipo.error) return res.status(422).json({ error: tipo.error });

  const precio = validarPrecio(req.body.precio_unitario);
  if (precio.error) return res.status(422).json({ error: precio.error });

  const stock = validarStock(req.body.stock_disponible);
  if (stock.error) return res.status(422).json({ error: stock.error });

  try {
    const distribuidor = await obtenerDistribuidorDelUsuario(req.usuario.id_usuario);
    if (!distribuidor) {
      return res.status(403).json({ error: "Tu cuenta no está vinculada a ninguna distribuidora." });
    }

    const repetido = await prisma.producto.findFirst({
      where: { id_distribuidor: distribuidor.id_distribuidor, tipo_bidon: tipo.valor },
    });
    if (repetido) {
      return res.status(409).json({ error: `Ya tienes un producto llamado "${tipo.valor}".` });
    }

    const producto = await prisma.producto.create({
      data: {
        id_distribuidor: distribuidor.id_distribuidor,
        tipo_bidon: tipo.valor,
        precio_unitario: precio.valor,
        stock_disponible: stock.valor,
      },
    });

    return res.status(201).json({ mensaje: "Producto agregado.", data: producto });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Error interno del servidor." });
  }
}

// PATCH /api/distribuidores/mis-productos/:idProducto
// Acepta: tipo_bidon, precio_unitario, stock_disponible (valor exacto),
// incremento (suma bidones al stock) y activo (true/false)
async function actualizarProducto(req, res) {
  const idProducto = parseInt(req.params.idProducto);
  const { tipo_bidon, precio_unitario, stock_disponible, incremento, activo } = req.body;

  try {
    const distribuidor = await obtenerDistribuidorDelUsuario(req.usuario.id_usuario);
    if (!distribuidor) {
      return res.status(403).json({ error: "Tu cuenta no está vinculada a ninguna distribuidora." });
    }

    const producto = await prisma.producto.findUnique({ where: { id_producto: idProducto } });
    if (!producto || producto.id_distribuidor !== distribuidor.id_distribuidor) {
      return res.status(404).json({ error: "Producto no encontrado." });
    }

    const data = {};

    if (tipo_bidon !== undefined) {
      const tipo = validarTipo(tipo_bidon);
      if (tipo.error) return res.status(422).json({ error: tipo.error });

      const repetido = await prisma.producto.findFirst({
        where: {
          id_distribuidor: distribuidor.id_distribuidor,
          tipo_bidon: tipo.valor,
          id_producto: { not: idProducto },
        },
      });
      if (repetido) {
        return res.status(409).json({ error: `Ya tienes un producto llamado "${tipo.valor}".` });
      }
      data.tipo_bidon = tipo.valor;
    }

    if (precio_unitario !== undefined) {
      const precio = validarPrecio(precio_unitario);
      if (precio.error) return res.status(422).json({ error: precio.error });
      data.precio_unitario = precio.valor;
    }

    if (stock_disponible !== undefined && incremento !== undefined) {
      return res.status(422).json({ error: "Envía el stock exacto o un incremento, no ambos." });
    }

    if (stock_disponible !== undefined) {
      const stock = validarStock(stock_disponible);
      if (stock.error) return res.status(422).json({ error: stock.error });
      data.stock_disponible = stock.valor;
    }

    if (incremento !== undefined) {
      const cantidad = Number(incremento);
      if (!Number.isInteger(cantidad) || cantidad < 1 || cantidad > 10000) {
        return res.status(422).json({ error: "La cantidad a agregar debe ser un entero entre 1 y 10000." });
      }
      data.stock_disponible = { increment: cantidad };
    }

    if (activo !== undefined) {
      if (typeof activo !== "boolean") {
        return res.status(422).json({ error: "El campo activo debe ser verdadero o falso." });
      }
      data.activo = activo;
    }

    if (Object.keys(data).length === 0) {
      return res.status(422).json({ error: "No se envió ningún cambio." });
    }

    const actualizado = await prisma.producto.update({
      where: { id_producto: idProducto },
      data,
    });

    return res.status(200).json({ mensaje: "Producto actualizado.", data: actualizado });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Error interno del servidor." });
  }
}

// DELETE /api/distribuidores/mis-productos/:idProducto
// Si el producto ya aparece en pedidos, se desactiva para no perder el historial
async function eliminarProducto(req, res) {
  const idProducto = parseInt(req.params.idProducto);

  try {
    const distribuidor = await obtenerDistribuidorDelUsuario(req.usuario.id_usuario);
    if (!distribuidor) {
      return res.status(403).json({ error: "Tu cuenta no está vinculada a ninguna distribuidora." });
    }

    const producto = await prisma.producto.findUnique({
      where: { id_producto: idProducto },
      include: { _count: { select: { detalles: true } } },
    });
    if (!producto || producto.id_distribuidor !== distribuidor.id_distribuidor) {
      return res.status(404).json({ error: "Producto no encontrado." });
    }

    if (producto._count.detalles > 0) {
      await prisma.producto.update({
        where: { id_producto: idProducto },
        data: { activo: false },
      });
      return res.status(200).json({
        mensaje: "El producto tiene pedidos registrados, así que se desactivó en lugar de eliminarse.",
        eliminado: false,
      });
    }

    await prisma.producto.delete({ where: { id_producto: idProducto } });
    return res.status(200).json({ mensaje: "Producto eliminado.", eliminado: true });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Error interno del servidor." });
  }
}

module.exports = { listarMisProductos, crearProducto, actualizarProducto, eliminarProducto };