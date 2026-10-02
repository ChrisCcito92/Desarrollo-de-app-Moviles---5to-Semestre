const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const prisma = require("../prismaClient");
require("dotenv").config();

// Roles que se pueden elegir en el registro público (repartidor no)
const ROLES_REGISTRO = ["cliente", "distribuidor"];

async function registro(req, res) {
  const { nombre, correo, telefono, contrasena, distribuidor } = req.body;
  const tipo_usuario = req.body.tipo_usuario || "cliente";

  if (!nombre || !correo || !telefono || !contrasena) {
    return res.status(422).json({ error: "Todos los campos son obligatorios." });
  }
  if (!ROLES_REGISTRO.includes(tipo_usuario)) {
    return res.status(422).json({ error: "Rol no válido." });
  }

  // Validaciones extra si se registra una distribuidora.
  // Los productos y el stock se agregan después desde "Mi inventario".
  let datosDistribuidor = null;
  if (tipo_usuario === "distribuidor") {
    const { nombre_comercial, latitud, longitud, radio_cobertura_km } = distribuidor || {};

    const lat = Number(latitud);
    const lng = Number(longitud);
    const radio = radio_cobertura_km ? Number(radio_cobertura_km) : 5;

    if (!nombre_comercial || !nombre_comercial.trim()) {
      return res.status(422).json({ error: "El nombre comercial es obligatorio." });
    }
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return res.status(422).json({ error: "La ubicación de la distribuidora es obligatoria." });
    }
    if (!Number.isFinite(radio) || radio <= 0 || radio > 100) {
      return res.status(422).json({ error: "El radio de cobertura no es válido." });
    }

    datosDistribuidor = {
      nombre_comercial: nombre_comercial.trim(),
      latitud: lat,
      longitud: lng,
      radio,
    };
  }

  try {
    const contrasena_hash = await bcrypt.hash(contrasena, 10);

    // Usuario y distribuidora se crean juntos: si algo falla, no se guarda nada
    const usuario = await prisma.$transaction(async (tx) => {
      const nuevoUsuario = await tx.usuario.create({
        data: { nombre, correo, telefono, contrasena_hash, tipo_usuario },
        select: { id_usuario: true, nombre: true, correo: true, tipo_usuario: true },
      });

      if (datosDistribuidor) {
        await tx.distribuidor.create({
          data: {
            id_usuario: nuevoUsuario.id_usuario,
            nombre_comercial: datosDistribuidor.nombre_comercial,
            telefono_contacto: telefono,
            latitud_base: datosDistribuidor.latitud,
            longitud_base: datosDistribuidor.longitud,
            radio_cobertura_km: datosDistribuidor.radio,
          },
        });
      }

      return nuevoUsuario;
    });

    return res.status(201).json({ mensaje: "Usuario registrado.", usuario });
  } catch (err) {
    if (err.code === "P2002") {
      return res.status(409).json({ error: "El correo o teléfono ya está registrado." });
    }
    console.error(err);
    return res.status(500).json({ error: "Error interno del servidor." });
  }
}

async function login(req, res) {
  const { correo, contrasena } = req.body;

  if (!correo || !contrasena) {
    return res.status(422).json({ error: "Correo y contraseña son obligatorios." });
  }

  try {
    const usuario = await prisma.usuario.findUnique({ where: { correo } });

    if (!usuario || !usuario.estado) {
      return res.status(401).json({ error: "Credenciales inválidas." });
    }

    const contrasenaValida = await bcrypt.compare(contrasena, usuario.contrasena_hash);
    if (!contrasenaValida) {
      return res.status(401).json({ error: "Credenciales inválidas." });
    }

    const payload = {
      id_usuario: usuario.id_usuario,
      tipo_usuario: usuario.tipo_usuario,
    };

    const accessToken = jwt.sign(payload, process.env.JWT_SECRET, {
      expiresIn: process.env.JWT_EXPIRES_IN || "15m",
    });
    const refreshToken = jwt.sign(payload, process.env.JWT_REFRESH_SECRET, {
      expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || "7d",
    });

    // Se devuelven los tokens y los datos del usuario (sin la contraseña)
    return res.status(200).json({
      accessToken,
      refreshToken,
      usuario: {
        id_usuario: usuario.id_usuario,
        nombre: usuario.nombre,
        correo: usuario.correo,
        tipo_usuario: usuario.tipo_usuario,
      },
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Error interno del servidor." });
  }
}

async function refresh(req, res) {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    return res.status(401).json({ error: "Refresh token ausente." });
  }
  try {
    const payload = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);
    const nuevoAccessToken = jwt.sign(
      { id_usuario: payload.id_usuario, tipo_usuario: payload.tipo_usuario },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || "15m" }
    );
    return res.status(200).json({ accessToken: nuevoAccessToken });
  } catch {
    return res.status(401).json({ error: "Refresh token inválido o expirado." });
  }
}

module.exports = { registro, login, refresh };