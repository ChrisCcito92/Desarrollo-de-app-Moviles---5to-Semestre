require("dotenv").config();
const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

async function seed() {
  const dist = await prisma.distribuidor.create({
    data: {
      nombre_comercial: "Distribuidora El Liquido",
      telefono_contacto: "0987654321",
      latitud_base: -0.2201641,
      longitud_base: -78.5123274,
      radio_cobertura_km: 5.00,
    },
  });

  await prisma.producto.create({
    data: {
      id_distribuidor: dist.id_distribuidor,
      tipo_bidon: "Bidon 20 litros",
      precio_unitario: 2.50,
      stock_disponible: 100,
    },
  });

  await prisma.direccion.create({
    data: {
      id_usuario: 1,
      alias: "Casa",
      calle_referencia: "Av. Amazonas y Naciones Unidas",
      latitud: -0.1806532,
      longitud: -78.4678897,
      predeterminada: true,
    },
  });

  console.log("✅ Datos de prueba creados correctamente");
  await prisma.$disconnect();
}

seed();