const redis = require("../redisClient");

/**
 * COLA ASÍNCRONA SIMPLE CON UPSTASH REDIS
 * Simula una cola de trabajo para enviar notificaciones
 * sin bloquear la respuesta al cliente.
 */

async function agregarNotificacion(data) {
  const trabajo = {
    id: Date.now(),
    data,
    creadoEn: new Date().toISOString(),
  };

  // Agrega el trabajo a una lista en Redis
  await redis.lpush("cola:notificaciones", JSON.stringify(trabajo));
  console.log(`📬 Notificación encolada para pedido #${data.id_pedido}`);
  return trabajo;
}

async function procesarNotificaciones() {
  console.log("⚙️  Procesando cola de notificaciones...");

  const item = await redis.rpop("cola:notificaciones");
  if (!item) {
    console.log("📭 Cola vacía, nada que procesar.");
    return;
  }

  const trabajo = typeof item === "string" ? JSON.parse(item) : item;
  console.log(`✅ Notificación procesada:`, trabajo.data);

  // Aquí iría la lógica real: Firebase, email, SMS, etc.
}

module.exports = { agregarNotificacion, procesarNotificaciones };