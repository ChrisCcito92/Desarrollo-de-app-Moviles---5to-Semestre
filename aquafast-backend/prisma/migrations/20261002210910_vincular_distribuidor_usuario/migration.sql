/*
  Warnings:

  - A unique constraint covering the columns `[id_usuario]` on the table `Distribuidor` will be added. If there are existing duplicate values, this will fail.

*/
-- AlterTable
ALTER TABLE `distribuidor` ADD COLUMN `id_usuario` INTEGER NULL;

-- CreateIndex
CREATE UNIQUE INDEX `Distribuidor_id_usuario_key` ON `Distribuidor`(`id_usuario`);

-- CreateIndex
CREATE INDEX `Pedido_id_usuario_fecha_pedido_idx` ON `Pedido`(`id_usuario`, `fecha_pedido`);

-- CreateIndex
CREATE INDEX `Pedido_id_distribuidor_estado_pedido_fecha_pedido_idx` ON `Pedido`(`id_distribuidor`, `estado_pedido`, `fecha_pedido`);

-- AddForeignKey
ALTER TABLE `Distribuidor` ADD CONSTRAINT `Distribuidor_id_usuario_fkey` FOREIGN KEY (`id_usuario`) REFERENCES `Usuario`(`id_usuario`) ON DELETE SET NULL ON UPDATE CASCADE;
