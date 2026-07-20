const express = require("express");
const router = express.Router();
const { registro, login, refresh } = require("../controllers/authController");

// Endpoints públicos — no requieren token
router.post("/registro", registro);
router.post("/login", login);
router.post("/refresh", refresh);

module.exports = router;