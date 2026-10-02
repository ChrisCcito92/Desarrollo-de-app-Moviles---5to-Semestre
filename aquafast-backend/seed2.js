require("dotenv").config();
const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

async function seed() {
  // Verificar si ya existe el distribuidor
  const existe = await prisma.distribuidor.findFirst();
  if (existe) {
    console.log("✅ Ya existen datos, actualizando productos...");
    
    // Agregar más productos al distribuidor existente
    await prisma.producto.createMany({
      data: [
        {
          id_distribuidor: existe.id_distribuidor,
          tipo_bidon: "Bidón 20 litros",
          precio_unitario: 2.50,
          stock_disponible: 100,
          activo: true,
        },
        {
          id_distribuidor: existe.id_distribuidor,
          tipo_bidon: "Bidón 10 litros",
          precio_unitario: 1.50,
          stock_disponible: 50,
          activo: true,
        },
        {
          id_distribuidor: existe.id_distribuidor,
          tipo_bidon: "Bidón 5 litros",
          precio_unitario: 0.75,
          stock_disponible: 80,
          activo: true,
        },
      ],
      skipDuplicates: true,
    });
    console.log("✅ Productos agregados correctamente");
    await prisma.$disconnect();
    return;
  }

  const dist = await prisma.distribuidor.create({
    data: {
      nombre_comercial: "Distribuidora El Líquido",
      telefono_contacto: "0987654321",
      latitud_base: -0.2201641,
      longitud_base: -78.5123274,
      radio_cobertura_km: 5.00,
    },
  });

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

  console.log("✅ Distribuidor y productos creados correctamente");
  await prisma.$disconnect();
}

seed();