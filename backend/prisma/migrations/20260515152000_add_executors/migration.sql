CREATE TABLE "executors" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "executors_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "executors_name_key" ON "executors"("name");

INSERT INTO "executors" ("name", "createdAt", "updatedAt")
SELECT DISTINCT TRIM("executor"), NOW(), NOW()
FROM "jap_gpp_entries"
WHERE "executor" IS NOT NULL
  AND TRIM("executor") <> ''
ON CONFLICT ("name") DO NOTHING;