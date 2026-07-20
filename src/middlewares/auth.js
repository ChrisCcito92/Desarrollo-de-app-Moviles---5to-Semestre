const jwt = require("jsonwebtoken");
require("dotenv").config();

function verificarToken(req, res, next) {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];

  if (!token) {
    return res.status(401).json({
      error: "Token ausente. Debes autenticarte para acceder a este recurso.",
    });
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    req.usuario = payload;
    next();
  } catch (err) {
    if (err.name === "TokenExpiredError") {
      return res.status(401).json({
        error: "Token expirado. Usa el refresh token para obtener uno nuevo.",
      });
    }
    return res.status(401).json({ error: "Token inválido." });
  }
}

function autorizar(...rolesPermitidos) {
  return (req, res, next) => {
    if (!rolesPermitidos.includes(req.usuario.tipo_usuario)) {
      return res.status(403).json({
        error: `Acceso denegado. Se requiere rol: ${rolesPermitidos.join(" o ")}.`,
      });
    }
    next();
  };
}

module.exports = { verificarToken, autorizar };