-- CreateTable
CREATE TABLE `Usuario` (
    `id_usuario` INTEGER NOT NULL AUTO_INCREMENT,
    `nombre` VARCHAR(100) NOT NULL,
    `correo` VARCHAR(120) NOT NULL,
    `telefono` VARCHAR(15) NOT NULL,
    `contrasena_hash` VARCHAR(255) NOT NULL,
    `tipo_usuario` ENUM('cliente', 'distribuidor', 'repartidor') NOT NULL DEFAULT 'cliente',
    `fecha_registro` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `estado` BOOLEAN NOT NULL DEFAULT true,

    UNIQUE INDEX `Usuario_correo_key`(`correo`),
    UNIQUE INDEX `Usuario_telefono_key`(`telefono`),
    PRIMARY KEY (`id_usuario`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Direccion` (
    `id_direccion` INTEGER NOT NULL AUTO_INCREMENT,
    `id_usuario` INTEGER NOT NULL,
    `alias` VARCHAR(40) NOT NULL,
    `calle_referencia` VARCHAR(150) NOT NULL,
    `latitud` DECIMAL(10, 7) NOT NULL,
    `longitud` DECIMAL(10, 7) NOT NULL,
    `predeterminada` BOOLEAN NOT NULL DEFAULT false,

    PRIMARY KEY (`id_direccion`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Distribuidor` (
    `id_distribuidor` INTEGER NOT NULL AUTO_INCREMENT,
    `nombre_comercial` VARCHAR(100) NOT NULL,
    `telefono_contacto` VARCHAR(15) NOT NULL,
    `latitud_base` DECIMAL(10, 7) NOT NULL,
    `longitud_base` DECIMAL(10, 7) NOT NULL,
    `radio_cobertura_km` DECIMAL(5, 2) NOT NULL,
    `calificacion_promedio` DECIMAL(3, 2) NOT NULL DEFAULT 0.00,
    `estado` ENUM('activo', 'inactivo') NOT NULL DEFAULT 'activo',

    PRIMARY KEY (`id_distribuidor`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Repartidor` (
    `id_repartidor` INTEGER NOT NULL AUTO_INCREMENT,
    `id_distribuidor` INTEGER NOT NULL,
    `nombre_completo` VARCHAR(100) NOT NULL,
    `placa_vehiculo` VARCHAR(10) NULL,
    `latitud_actual` DECIMAL(10, 7) NULL,
    `longitud_actual` DECIMAL(10, 7) NULL,
    `disponible` BOOLEAN NOT NULL DEFAULT true,

    PRIMARY KEY (`id_repartidor`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Producto` (
    `id_producto` INTEGER NOT NULL AUTO_INCREMENT,
    `id_distribuidor` INTEGER NOT NULL,
    `tipo_bidon` VARCHAR(40) NOT NULL,
    `precio_unitario` DECIMAL(6, 2) NOT NULL,
    `stock_disponible` INTEGER NOT NULL DEFAULT 0,
    `activo` BOOLEAN NOT NULL DEFAULT true,

    PRIMARY KEY (`id_producto`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Pedido` (
    `id_pedido` INTEGER NOT NULL AUTO_INCREMENT,
    `id_usuario` INTEGER NOT NULL,
    `id_direccion` INTEGER NOT NULL,
    `id_distribuidor` INTEGER NOT NULL,
    `id_repartidor` INTEGER NULL,
    `fecha_pedido` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `estado_pedido` ENUM('pendiente', 'aceptado', 'en_camino', 'entregado', 'cancelado') NOT NULL DEFAULT 'pendiente',
    `total_pagar` DECIMAL(7, 2) NOT NULL,
    `metodo_pago` ENUM('efectivo', 'tarjeta') NOT NULL,
    `tiempo_estimado_min` INTEGER NULL,
    `fecha_entrega_real` DATETIME(3) NULL,
    `calificacion_pedido` INTEGER NULL,
    `observaciones` VARCHAR(200) NULL,

    PRIMARY KEY (`id_pedido`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `DetallePedido` (
    `id_detalle` INTEGER NOT NULL AUTO_INCREMENT,
    `id_pedido` INTEGER NOT NULL,
    `id_producto` INTEGER NOT NULL,
    `cantidad` INTEGER NOT NULL,
    `precio_unitario_pedido` DECIMAL(6, 2) NOT NULL,
    `subtotal` DECIMAL(7, 2) NOT NULL,

    PRIMARY KEY (`id_detalle`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Notificacion` (
    `id_notificacion` INTEGER NOT NULL AUTO_INCREMENT,
    `id_pedido` INTEGER NOT NULL,
    `tipo_evento` VARCHAR(30) NOT NULL,
    `mensaje` VARCHAR(200) NOT NULL,
    `fecha_envio` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `leida` BOOLEAN NOT NULL DEFAULT false,

    PRIMARY KEY (`id_notificacion`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `Direccion` ADD CONSTRAINT `Direccion_id_usuario_fkey` FOREIGN KEY (`id_usuario`) REFERENCES `Usuario`(`id_usuario`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Repartidor` ADD CONSTRAINT `Repartidor_id_distribuidor_fkey` FOREIGN KEY (`id_distribuidor`) REFERENCES `Distribuidor`(`id_distribuidor`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Producto` ADD CONSTRAINT `Producto_id_distribuidor_fkey` FOREIGN KEY (`id_distribuidor`) REFERENCES `Distribuidor`(`id_distribuidor`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Pedido` ADD CONSTRAINT `Pedido_id_usuario_fkey` FOREIGN KEY (`id_usuario`) REFERENCES `Usuario`(`id_usuario`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Pedido` ADD CONSTRAINT `Pedido_id_direccion_fkey` FOREIGN KEY (`id_direccion`) REFERENCES `Direccion`(`id_direccion`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Pedido` ADD CONSTRAINT `Pedido_id_distribuidor_fkey` FOREIGN KEY (`id_distribuidor`) REFERENCES `Distribuidor`(`id_distribuidor`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Pedido` ADD CONSTRAINT `Pedido_id_repartidor_fkey` FOREIGN KEY (`id_repartidor`) REFERENCES `Repartidor`(`id_repartidor`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `DetallePedido` ADD CONSTRAINT `DetallePedido_id_pedido_fkey` FOREIGN KEY (`id_pedido`) REFERENCES `Pedido`(`id_pedido`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `DetallePedido` ADD CONSTRAINT `DetallePedido_id_producto_fkey` FOREIGN KEY (`id_producto`) REFERENCES `Producto`(`id_producto`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Notificacion` ADD CONSTRAINT `Notificacion_id_pedido_fkey` FOREIGN KEY (`id_pedido`) REFERENCES `Pedido`(`id_pedido`) ON DELETE RESTRICT ON UPDATE CASCADE;
