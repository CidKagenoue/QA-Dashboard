-- CreateTable
CREATE TABLE "maintenance_inspections" (
    "id" SERIAL NOT NULL,
    "equipment" TEXT NOT NULL,
    "inspectionType" TEXT NOT NULL,
    "inspectionInstitution" TEXT NOT NULL,
    "contactInfo" TEXT,
    "locationIds" INTEGER[] NOT NULL DEFAULT ARRAY[]::INTEGER[],
    "frequency" TEXT NOT NULL,
    "selfContact" BOOLEAN NOT NULL DEFAULT false,
    "lastInspectionDate" TIMESTAMP(3),
    "dueDate" TIMESTAMP(3) NOT NULL,
    "status" TEXT DEFAULT 'Open',
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "maintenance_inspections_pkey" PRIMARY KEY ("id")
);
