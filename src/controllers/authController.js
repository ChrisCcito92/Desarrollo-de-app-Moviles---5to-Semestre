const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const prisma = require("../prismaClient");
require("dotenv").config();

async function registro(req, res) {
  const { nombre, correo, telefono, contrasena, tipo_usuario } = req.body;

  if (!nombre || !correo || !telefono || !contrasena) {
    return res.status(422).json({ error: "Todos los campos son obligatorios." });
  }

  try {
    const contrasena_hash = await bcrypt.hash(contrasena, 10);
    const usuario = await prisma.usuario.create({
      data: { nombre, correo, telefono, contrasena_hash, tipo_usuario },
      select: { id_usuario: true, nombre: true, correo: true, tipo_usuario: true },
    });
    return res.status(201).json({ mensaje: "Usuario registrado.", usuario });
  } catch (err) {
    if (err.code === "P2002") {
      return res.status(409).json({ error: "El correo o teléfono ya está registrado." });
    }
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

    return res.status(200).json({ accessToken, refreshToken });
  } catch (err) {
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