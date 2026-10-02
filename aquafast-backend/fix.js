require("dotenv").config();
const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

async function fix() {
  // Eliminar en orden por dependencias
  await prisma.notificacion.deleteMany({});
  console.log("Notificaciones eliminadas");
  
  await prisma.detallePedido.deleteMany({});
  console.log("Detalles eliminados");
  
  await prisma.pedido.deleteMany({});
  console.log("Pedidos eliminados");
  
  await prisma.producto.deleteMany({});
  console.log("Productos eliminados");

  // Obtener el distribuidor
  const dist = await prisma.distribuidor.findFirst();
  if (!dist) {
    console.log("No hay distribuidor");
    await prisma.$disconnect();
    return;
  }

  // Crear productos limpios
  await prisma.producto.createMany({
    data: [
      {
        id_distribuidor: dist.id_distribuidor,
        tipo_bidon: "Bidón 20 litros",
        precio_unitario: 2.50,
        stock_disponible: 100,
        activo: true,
      },
      {
        id_distribuidor: dist.id_distribuidor,
        tipo_bidon: "Bidón 10 litros",
        precio_unitario: 1.50,
        stock_disponible: 50,
        activo: true,
      },
      {
        id_distribuidor: dist.id_distribuidor,
        tipo_bidon: "Bidón 5 litros",
        precio_unitario: 0.75,
        stock_disponible: 80,
        activo: true,
      },
    ],
  });
  console.log("Productos recreados correctamente");

  // Verificar dirección del usuario 1
  const direccion = await prisma.direccion.findFirst({
    where: { id_usuario: 1 }
  });
  
  if (!direccion) {
    await prisma.direccion.create({
      data: {
        id_usuario: 1,
        alias: "Casa",
        calle_referencia: "Av. Amazonas y Naciones Unidas",
        latitud: -0.1806532,
        longitud: -78.4678897,
        predeterminada: true,
      }
    });
    console.log("Dirección creada para usuario 1");
  } else {
    console.log("Dirección ya existe:", direccion.alias);
  }

  await prisma.$disconnect();
}

fix();