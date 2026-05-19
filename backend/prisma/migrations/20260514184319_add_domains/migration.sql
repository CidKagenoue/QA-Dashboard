-- CreateTable
CREATE TABLE "domains" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "domains_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "jap_gpp_entries" (
    "id" SERIAL NOT NULL,
    "source" TEXT NOT NULL DEFAULT 'JAP',
    "year" INTEGER,
    "startYear" INTEGER,
    "endYear" INTEGER,
    "goalMeasure" TEXT NOT NULL,
    "domainId" INTEGER,
    "riskField" TEXT,
    "resourcesBudget" TEXT,
    "priority" TEXT,
    "realisation" TEXT,
    "executor" TEXT,
    "startDate" TIMESTAMP(3),
    "endDate" TIMESTAMP(3),
    "remark" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "jap_gpp_entries_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "domains_name_key" ON "domains"("name");

-- AddForeignKey
ALTER TABLE "jap_gpp_entries" ADD CONSTRAINT "jap_gpp_entries_domainId_fkey" FOREIGN KEY ("domainId") REFERENCES "domains"("id") ON DELETE SET NULL ON UPDATE CASCADE;
