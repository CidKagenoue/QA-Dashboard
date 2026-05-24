-- CreateTable
CREATE TABLE IF NOT EXISTS "BranchDepartment" (
    "branchId" INTEGER NOT NULL,
    "departmentId" INTEGER NOT NULL,

    CONSTRAINT "BranchDepartment_pkey" PRIMARY KEY ("branchId","departmentId")
);

-- CreateIndex
CREATE INDEX IF NOT EXISTS "BranchDepartment_departmentId_idx" ON "BranchDepartment"("departmentId");

-- AddForeignKey
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'BranchDepartment_branchId_fkey'
  ) THEN
    ALTER TABLE "BranchDepartment"
      ADD CONSTRAINT "BranchDepartment_branchId_fkey"
      FOREIGN KEY ("branchId") REFERENCES "Branch"("id")
      ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;

-- AddForeignKey
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'BranchDepartment_departmentId_fkey'
  ) THEN
    ALTER TABLE "BranchDepartment"
      ADD CONSTRAINT "BranchDepartment_departmentId_fkey"
      FOREIGN KEY ("departmentId") REFERENCES "Department"("id")
      ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;

-- Ensure the mandatory fallback records exist.
INSERT INTO "Branch" ("name")
SELECT 'Ander'
WHERE NOT EXISTS (
  SELECT 1 FROM "Branch" WHERE lower("name") = lower('Ander')
);

INSERT INTO "Department" ("name", "updatedAt")
SELECT 'Ander', CURRENT_TIMESTAMP
WHERE NOT EXISTS (
  SELECT 1 FROM "Department" WHERE lower("name") = lower('Ander')
);

-- Initial backfill: keep existing behavior by allowing every current department for every branch.
INSERT INTO "BranchDepartment" ("branchId", "departmentId")
SELECT b."id", d."id"
FROM "Branch" b
CROSS JOIN "Department" d
ON CONFLICT ("branchId", "departmentId") DO NOTHING;
