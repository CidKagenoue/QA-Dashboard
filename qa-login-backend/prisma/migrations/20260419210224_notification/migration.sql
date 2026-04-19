-- CreateEnum
CREATE TYPE "NotificationModule" AS ENUM ('WHS_TOURS', 'OVA', 'JAP', 'MAINTENANCE');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "NotificationType" ADD VALUE 'OVA_TICKET_CREATED';
ALTER TYPE "NotificationType" ADD VALUE 'WHS_NEW_TASK';
ALTER TYPE "NotificationType" ADD VALUE 'WHS_COMMENT';
ALTER TYPE "NotificationType" ADD VALUE 'WHS_NEW_REPORT';
ALTER TYPE "NotificationType" ADD VALUE 'OVA_DEADLINE';
ALTER TYPE "NotificationType" ADD VALUE 'OVA_NEW_ACTION';
ALTER TYPE "NotificationType" ADD VALUE 'OVA_1';
ALTER TYPE "NotificationType" ADD VALUE 'OVA_2';
ALTER TYPE "NotificationType" ADD VALUE 'OVA_3';
ALTER TYPE "NotificationType" ADD VALUE 'JAP_NEW';
ALTER TYPE "NotificationType" ADD VALUE 'JAP_COMMENT';
ALTER TYPE "NotificationType" ADD VALUE 'JAP_STATUS_CHANGE';
ALTER TYPE "NotificationType" ADD VALUE 'MAINTENANCE_DUE';

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "notifyJapGpp" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "notifyMaintenance" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "notifyOva" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "notifyWhsTours" BOOLEAN NOT NULL DEFAULT true;

-- CreateTable
CREATE TABLE "NotificationSetting" (
    "id" SERIAL NOT NULL,
    "userId" INTEGER NOT NULL,
    "module" "NotificationModule" NOT NULL,
    "type" "NotificationType" NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "email" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "NotificationSetting_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "NotificationSetting_userId_type_key" ON "NotificationSetting"("userId", "type");

-- AddForeignKey
ALTER TABLE "NotificationSetting" ADD CONSTRAINT "NotificationSetting_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
